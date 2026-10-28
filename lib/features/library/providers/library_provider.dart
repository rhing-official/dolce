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
import '../../viewer/providers/viewer_provider.dart';

class LibraryState {
  final List<Book> books;
  final List<Shelf> shelves;
  final bool isLoading;
  const LibraryState(
      {this.books = const [], this.shelves = const [], this.isLoading = false});
  LibraryState copyWith(
          {List<Book>? books, List<Shelf>? shelves, bool? isLoading}) =>
      LibraryState(
          books: books ?? this.books,
          shelves: shelves ?? this.shelves,
          isLoading: isLoading ?? this.isLoading);
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

  Future<({int added, int updated, int removed})> syncAll() async {
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
    for (final shelf in shelfBox.values.toList()) {
      try {
        final actualFiles = await _fileService.scanFolder(shelf.folderPath);
        final actualPaths = actualFiles.map((f) => f.path).toSet();
        final dbBooks =
            bookBox.values.where((b) => b.shelfId == shelf.id).toList();
        final dbBooksByPath = {for (final b in dbBooks) b.filePath: b};
        debugPrint(
            '[Sync] 本棚「${shelf.name}」: フォルダ内${actualFiles.length}件 / DB登録${dbBooks.length}件');
        for (final entry in actualFiles) {
          final existing = dbBooksByPath[entry.path];
          if (existing == null) {
            final bId = _uuid.v4();
            final thumb = await _thumbnailService.generateThumbnail(
                entry.path, bId, entry.ext);
            final format = entry.ext == 'pdf' ? BookFormat.pdf : BookFormat.cbz;
            final number = format == BookFormat.cbz
                ? await _cbzService.readComicInfoNumber(entry.path)
                : null;
            final book = Book()
              ..id = bId
              ..title = entry.name
              ..filePath = entry.path
              ..relPath = entry.relPath
              ..shelfId = shelf.id
              ..thumbnailPath = thumb
              ..addedAt = DateTime.now()
              ..format = format
              ..totalPages = 0
              ..lastPage = 0
              ..isFinished = false
              ..number = number
              ..fileSize = entry.size
              ..fileModifiedAt = entry.modified;
            await bookBox.put(bId, book);
            added++;
            debugPrint('[Sync] 追加: ${entry.path}');
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
        for (final dbBook in dbBooks) {
          if (!actualPaths.contains(dbBook.filePath)) {
            await bookBox.delete(dbBook.id);
            removed++;
            debugPrint('[Sync] 削除: ${dbBook.filePath}');
          }
        }
      } catch (e, st) {
        // 1つの本棚の同期に失敗しても、他の本棚の同期と再読み込みは継続する
        debugPrint('[Sync] 本棚「${shelf.name}」の同期エラー: $e\n$st');
      }
    }
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
    state = state.copyWith(books: List.of(state.books));
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ディレクトリ選択がキャンセルされました')),
          );
        }
        return;
      }
      final shelfId = _fileService.generateShelfId(picked.path);
      final shelf =
          Shelf(id: shelfId, name: picked.name, folderPath: picked.path);
      await Hive.box<Shelf>('shelves').put(shelfId, shelf);
      await syncAll();

      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearMaterialBanners();
        messenger.showMaterialBanner(
          MaterialBanner(
            content: Text('本棚を追加しました: ${shelf.name}'),
            actions: [
              TextButton(
                onPressed: () => messenger.hideCurrentMaterialBanner(),
                child: const Text('閉じる'),
              ),
            ],
          ),
        );
        Future.delayed(const Duration(seconds: 4), () {
          messenger.hideCurrentMaterialBanner();
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>(
    (ref) => LibraryNotifier(ref));
