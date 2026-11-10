import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/book.dart';
import '../models/shelf.dart';
import '../../../core/services/file_service.dart';
import '../../../core/services/thumbnail_service.dart';
import '../../../core/services/cbz_service.dart';
import '../../../core/utils/sort_utils.dart';
import '../../../core/utils/book_path_utils.dart';
import '../../../core/widgets/app_banner.dart';
import '../../viewer/providers/viewer_provider.dart';

class LibraryState {
  final List<Book> books;
  final List<Shelf> shelves;
  // 本棚の追加（ディレクトリ選択〜登録）の最中
  final bool isLoading;
  // ファイルの同期（スキャン・サムネ生成）の最中
  final bool isSyncing;
  const LibraryState(
      {this.books = const [],
      this.shelves = const [],
      this.isLoading = false,
      this.isSyncing = false});
  LibraryState copyWith(
          {List<Book>? books,
          List<Shelf>? shelves,
          bool? isLoading,
          bool? isSyncing}) =>
      LibraryState(
          books: books ?? this.books,
          shelves: shelves ?? this.shelves,
          isLoading: isLoading ?? this.isLoading,
          isSyncing: isSyncing ?? this.isSyncing);
}

class LibraryNotifier extends StateNotifier<LibraryState> {
  final Ref ref;
  LibraryNotifier(this.ref) : super(const LibraryState()) {
    _init();
  }
  final _fileService = FileService();
  final _thumbnailService = ThumbnailService();
  final _cbzService = CbzService();
  final _uuid = const Uuid();

  void _init() async {
    await _load();
    await syncAll();
  }

  Future<void> _load() async {
    if (!Hive.isBoxOpen('books') || !Hive.isBoxOpen('shelves')) return;
    final books = Hive.box<Book>('books').values.toList();
    final shelves = Hive.box<Shelf>('shelves').values.toList();
    books.sort((a, b) => SortUtils.compareNatural(a.title, b.title));
    shelves.sort((a, b) => SortUtils.compareNatural(a.name, b.name));
    state = state.copyWith(books: books, shelves: shelves);
  }

  // 起動時・F5・本棚追加などから並行して呼ばれても、同じファイルが二重に
  // 登録されないよう、実行中なら同じ結果を共有する
  Future<({int added, int updated, int removed})>? _syncing;

  Future<({int added, int updated, int removed})> syncAll() {
    final running = _syncing;
    if (running != null) return running;
    state = state.copyWith(isSyncing: true);
    final future = _syncAllImpl();
    _syncing = future;
    return future.whenComplete(() {
      _syncing = null;
      if (mounted) state = state.copyWith(isSyncing: false);
    });
  }

  // 同じfilePathで重複登録されたBookを1冊に畳む（過去の並行同期で生じた重複の修復）。
  // 残すのは読書進捗が最も進んでいる1冊。戻り値は残したBook
  Future<Book> _dedupeGroup(Box<Book> bookBox, List<Book> group) async {
    group.sort((a, b) {
      if (a.isFinished != b.isFinished) return a.isFinished ? -1 : 1;
      if (a.lastPage != b.lastPage) return b.lastPage.compareTo(a.lastPage);
      return a.addedAt.compareTo(b.addedAt);
    });
    final keep = group.first;
    for (final dup in group.skip(1)) {
      final thumb = dup.thumbnailPath;
      if (thumb != null && thumb != keep.thumbnailPath) {
        try {
          final f = File(thumb);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      await bookBox.delete(dup.id);
      debugPrint('[Sync] 重複を削除: ${dup.filePath}');
    }
    return keep;
  }

  bool _thumbsShrunk = false;

  // 新規ファイルのサムネ生成・ComicInfo読み取りの同時実行数
  static const _kSyncConcurrency = 4;
  // 追加中に一覧へ段階反映する間隔（冊数）
  static const _kSyncProgressEvery = 50;

  Future<({int added, int updated, int removed})> _syncAllImpl() async {
    debugPrint('[Sync] syncAll開始');
    if (!Hive.isBoxOpen('books')) {
      debugPrint('[Sync] booksボックスが開いていないため中断');
      return (added: 0, updated: 0, removed: 0);
    }
    final bookBox = Hive.box<Book>('books');
    final shelfBox = Hive.box<Shelf>('shelves');
    var added = 0;
    var updated = 0;
    var removed = 0;

    // 全Bookを1回だけ走査して shelfId → filePath → Book一覧 にまとめる
    // （本棚ごと・新規1冊ごとに全件を走査するとO(N²)になるため）
    final byShelf = <String, Map<String, List<Book>>>{};
    for (final b in bookBox.values) {
      byShelf
          .putIfAbsent(b.shelfId, () => {})
          .putIfAbsent(b.filePath, () => [])
          .add(b);
    }

    for (final shelf in shelfBox.values.toList()) {
      try {
        final actualFiles = await _fileService.scanFolder(shelf.folderPath);
        final actualPaths = actualFiles.map((f) => f.path).toSet();
        final groups = byShelf.putIfAbsent(shelf.id, () => {});
        // 重複登録の修復と、filePath → Book の引き当て表を作る
        final dbBooksByPath = <String, Book>{};
        for (final entry in groups.entries) {
          dbBooksByPath[entry.key] = entry.value.length > 1
              ? await _dedupeGroup(bookBox, entry.value)
              : entry.value.first;
        }
        debugPrint(
            '[Sync] 本棚「${shelf.name}」: フォルダ内${actualFiles.length}件 / DB登録${dbBooksByPath.length}件');

        final newEntries = <ScannedFile>[];
        for (final entry in actualFiles) {
          final existing = dbBooksByPath[entry.path];
          if (existing == null) {
            newEntries.add(entry);
          } else if (existing.fileSize == null &&
              existing.fileModifiedAt == null) {
            // アップデート直後等でまだ基準値を記録していない既存本。
            // 中身の再読込はせず、今回の値を基準として記録するだけにする
            // （既存蔵書を一斉に再処理してしまわないため）
            existing.fileSize = entry.size;
            existing.fileModifiedAt = entry.modified;
            await existing.save();
          } else if ((entry.size != null && entry.size != existing.fileSize) ||
              (entry.modified != null &&
                  entry.modified != existing.fileModifiedAt)) {
            // ファイル名・パスは変わらないまま中身だけ差し替わったケース
            // （ComicInfo.xmlの追加・更新等）を検知し、派生データを再生成する
            if (existing.format == BookFormat.cbz) {
              existing.number =
                  await _cbzService.readComicInfoNumber(entry.path);
            }
            final oldThumb = existing.thumbnailPath;
            if (oldThumb != null) {
              try {
                final thumbFile = File(oldThumb);
                if (await thumbFile.exists()) await thumbFile.delete();
              } catch (_) {}
            }
            existing.thumbnailPath = await _thumbnailService.generateThumbnail(
                entry.path, existing.id, entry.ext);
            existing.fileSize = entry.size;
            existing.fileModifiedAt = entry.modified;
            await existing.save();
            updated++;
            debugPrint('[Sync] 更新: ${entry.path}');
          }
        }

        // 新規ファイルは数本ずつ並行して処理する。登録するパスは着手時点で
        // dbBooksByPathに予約するため、同じファイルが二重に登録されることは無い
        var next = 0;
        Future<void> worker() async {
          while (next < newEntries.length) {
            final entry = newEntries[next++];
            if (dbBooksByPath.containsKey(entry.path)) continue;
            final bId = _uuid.v4();
            final format = switch (entry.ext) {
              'pdf' => BookFormat.pdf,
              'epub' => BookFormat.epub,
              _ => BookFormat.cbz,
            };
            final book = Book()
              ..id = bId
              ..title = entry.name
              ..filePath = entry.path
              ..relPath = entry.relPath
              ..shelfId = shelf.id
              ..addedAt = DateTime.now()
              ..format = format
              ..totalPages = 0
              ..lastPage = 0
              ..isFinished = false
              ..fileSize = entry.size
              ..fileModifiedAt = entry.modified;
            dbBooksByPath[entry.path] = book;
            book.thumbnailPath = await _thumbnailService.generateThumbnail(
                entry.path, bId, entry.ext);
            if (format == BookFormat.cbz) {
              book.number = await _cbzService.readComicInfoNumber(entry.path);
            }
            await bookBox.put(bId, book);
            added++;
            debugPrint('[Sync] 追加: ${entry.path}');
            if (added % _kSyncProgressEvery == 0) await _load();
          }
        }

        await Future.wait(List.generate(_kSyncConcurrency, (_) => worker()));

        // 過去バージョンで元解像度のまま保存された大きなサムネを、起動後の
        // 最初の同期で一度だけ縮小する
        if (!_thumbsShrunk) {
          final paths = [
            for (final b in dbBooksByPath.values)
              if (b.thumbnailPath != null) b.thumbnailPath!
          ];
          var i = 0;
          Future<void> shrinkWorker() async {
            while (i < paths.length) {
              await _thumbnailService.shrinkIfLarge(paths[i++]);
            }
          }

          await Future.wait(
              List.generate(_kSyncConcurrency, (_) => shrinkWorker()));
        }

        for (final entry in dbBooksByPath.entries) {
          if (!actualPaths.contains(entry.key)) {
            await bookBox.delete(entry.value.id);
            removed++;
            debugPrint('[Sync] 削除: ${entry.key}');
          }
        }
      } catch (e, st) {
        // 1つの本棚の同期に失敗しても、他の本棚の同期と再読み込みは継続する
        debugPrint('[Sync] 本棚「${shelf.name}」の同期エラー: $e\n$st');
      }
    }
    _thumbsShrunk = true;
    await _load();
    debugPrint('[Sync] syncAll完了: 追加$added件 / 更新$updated件 / 削除$removed件');
    return (added: added, updated: updated, removed: removed);
  }

  // 読書履歴（どこまで読んだか）のみを保存する。いつ読んだかの日時は記録しない
  Future<void> updateReadProgress(String bookId, int lastPage, bool isFinished,
      {int? totalPages}) async {
    final book = Hive.box<Book>('books').get(bookId);
    if (book == null) return;
    final totalPagesChanged =
        totalPages != null && book.totalPages != totalPages;
    if (book.lastPage == lastPage &&
        book.isFinished == isFinished &&
        !totalPagesChanged) return;
    book.lastPage = lastPage;
    book.isFinished = isFinished;
    if (totalPagesChanged) book.totalPages = totalPages;
    await book.save();
    // ページをめくるたびにlibraryProviderの全watcher（全タブ・全フォルダ
    // カード）を再ビルドすると非常に重いため、通知はめくり操作が落ち着いてから
    // 1回にまとめる（Book自体は上で更新済みなので、再ビルドまで表示が少し
    // 遅れるだけ）
    _progressNotifyTimer?.cancel();
    _progressNotifyTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) state = state.copyWith(books: List.of(state.books));
    });
  }

  Timer? _progressNotifyTimer;

  @override
  void dispose() {
    _progressNotifyTimer?.cancel();
    super.dispose();
  }

  Future<void> toggleBookFavorite(Book book) async {
    book.isFavorite = !book.isFavorite;
    await book.save();
    _load();
  }

  Future<void> toggleShelfFavorite(Shelf shelf) async {
    shelf.isFavorite = !shelf.isFavorite;
    await shelf.save();
    _load();
  }

  // ファイル削除に成功した場合のみHiveの書籍レコードも削除する。失敗時に
  // レコードだけ消してしまうと、次回のsyncAllでファイルが再スキャンされ
  // 読書進捗を失った新規書籍として復活してしまう
  Future<bool> removeBook(String id) async {
    final book = Hive.box<Book>('books').get(id);
    if (book == null) return true;
    // ビューアがファイルハンドルを開いたままだと（本を開いたタブを閉じた後も
    // ViewerNotifierはautoDisposeではないため生き続ける）、Windows等で
    // 削除がファイル使用中エラーになるため、削除前に明示的に破棄する
    ref.invalidate(viewerProvider(id));
    final success = await _fileService.moveToTrash(book.filePath);
    if (success) {
      final thumbPath = book.thumbnailPath;
      if (thumbPath != null) {
        try {
          final thumb = File(thumbPath);
          if (await thumb.exists()) await thumb.delete();
        } catch (_) {}
      }
      await Hive.box<Book>('books').delete(id);
    }
    _load();
    return success;
  }

  Future<void> removeShelf(String id) async {
    await Hive.box<Shelf>('shelves').delete(id);
    _load();
  }

  Future<void> toggleFolderFavorite(
      String shelfId, String folderPath, bool favorite) async {
    final shelf = Hive.box<Shelf>('shelves').get(shelfId);
    if (shelf != null) {
      final favs = List<String>.from(shelf.favoriteFolders);
      if (favorite) {
        if (!favs.contains(folderPath)) favs.add(folderPath);
      } else {
        favs.remove(folderPath);
      }
      shelf.favoriteFolders = favs;
      await shelf.save();
    }
    _load();
  }

  Future<bool> removeFolder(String shelfId, String folderPath) async {
    final bookBox = Hive.box<Book>('books');
    final books = bookBox.values
        .where((b) => b.shelfId == shelfId && bookIsWithinFolder(b, folderPath))
        .toList();
    var allSucceeded = true;
    for (var b in books) {
      if (!await removeBook(b.id)) allSucceeded = false;
    }
    _load();
    return allSucceeded;
  }

  Future<void> addShelf(BuildContext context) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true);
    try {
      final picked = await _fileService.pickFolder();
      if (picked == null) {
        if (context.mounted) {
          showAppBanner(context, 'ディレクトリ選択がキャンセルされました');
        }
        return;
      }
      final shelfId = _fileService.generateShelfId(picked.path);
      final shelf =
          Shelf(id: shelfId, name: picked.name, folderPath: picked.path);
      await Hive.box<Shelf>('shelves').put(shelfId, shelf);
      await syncAll();

      if (context.mounted) {
        showAppBanner(context, '本棚を追加しました: ${shelf.name}');
      }
    } catch (e) {
      if (context.mounted) {
        showAppBanner(context, 'エラーが発生しました: $e',
            duration: const Duration(seconds: 6));
      }
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>(
    (ref) => LibraryNotifier(ref));
