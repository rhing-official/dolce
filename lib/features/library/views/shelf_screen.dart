import 'dart:io';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../providers/library_provider.dart';
import '../models/book.dart';
import '../widgets/read_progress_bar.dart';
import '../../../core/providers/tab_provider.dart';
import '../../../core/providers/selection_provider.dart';
import '../../../core/utils/sort_utils.dart';
import '../../../core/utils/book_path_utils.dart';
import '../../../l10n/app_localizations.dart';

class ShelfScreen extends ConsumerStatefulWidget {
  final String shelfId;
  final bool isActive;
  const ShelfScreen({super.key, required this.shelfId, this.isActive = true});
  @override
  ConsumerState<ShelfScreen> createState() => _ShelfScreenState();
}

class _ShelfScreenState extends ConsumerState<ShelfScreen> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // 矢印キーによる「現在の注目項目」インデックス。フォーカスは個々の
  // カード(InkWell)には渡さず(descendantsAreFocusable: false)、この
  // インデックスだけで移動先をハイライト表示する。カードにフォーカスを
  // 渡す既定のFlutterのDirectionalFocusIntentに任せると、フォーカスが
  // 乗ったカードのTooltipやホバー時のチェックボックス表示など、
  // 矢印キーでの連続移動を妨げる副作用が起きるため
  int? _highlightIndex;
  int _columns = 1;
  final Map<int, GlobalKey> _itemKeys = {};
  String? _lastPath;

  void _moveHighlight(int length, int delta) {
    if (length == 0) return;
    setState(() {
      _highlightIndex = _highlightIndex == null
          ? 0
          : (_highlightIndex! + delta).clamp(0, length - 1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _itemKeys[_highlightIndex]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.5, duration: const Duration(milliseconds: 150));
      }
    });
  }

  // フォーカスはタブがアクティブになった時と画面内クリック時のみ取得する。
  // buildのたびにrequestFocusすると、サイドバーの検索欄など他所にフォーカスが
  // ある状態でも、無関係な再ビルドのたびにフォーカスを奪ってしまう
  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant ShelfScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollByPage(bool up) {
    final amount = _scrollController.position.viewportDimension * 0.8;
    final target = _scrollController.offset + (up ? -amount : amount);
    _scrollController.animateTo(
        target.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryProvider);
    final tab =
        ref.watch(tabProvider).tabs[ref.watch(tabProvider).currentIndex];
    final shelf = state.shelves.firstWhere((s) => s.id == widget.shelfId,
        orElse: () => state.shelves.first);
    final currentPath = tab.path ?? shelfRootPath(shelf);
    final shelfBooks = state.books.where((b) => b.shelfId == widget.shelfId);
    final currentBooks = shelfBooks
        .where((b) => bookIsAtFolder(b, currentPath))
        .toList()
      ..sort((a, b) => SortUtils.compareBooks(a, b));
    final subFolders = shelfBooks
        .map((b) => immediateChildFolder(b, currentPath))
        .whereType<String>()
        .toSet()
        .toList()
      ..sort((a, b) =>
          SortUtils.compareNatural(folderDisplayName(a), folderDisplayName(b)));

    final allIds = [...subFolders, ...currentBooks.map((b) => b.id)];

    if (_lastPath != currentPath) {
      _lastPath = currentPath;
      _highlightIndex = null;
      _itemKeys.clear();
    }

    void activateHighlighted() {
      final idx = _highlightIndex;
      if (idx == null || idx >= allIds.length) return;
      if (idx < subFolders.length) {
        final path = subFolders[idx];
        final fName = p.basename(path);
        ref.read(tabProvider.notifier).navigateTo(widget.shelfId,
            path: path, title: fName, segments: [...tab.segments, fName]);
      } else {
        final book = currentBooks[idx - subFolders.length];
        ref.read(tabProvider.notifier).openBook(book.id, book.title, false,
            segments: [...tab.segments, book.title]);
      }
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      descendantsAreFocusable: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        final isCtrl = HardwareKeyboard.instance.isControlPressed;

        if (isCtrl && key == LogicalKeyboardKey.arrowUp) {
          _scrollController.jumpTo(0);
          return KeyEventResult.handled;
        }
        if (isCtrl && key == LogicalKeyboardKey.arrowDown) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.pageUp) {
          _scrollByPage(true);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.pageDown) {
          _scrollByPage(false);
          return KeyEventResult.handled;
        }
        if (isCtrl && key == LogicalKeyboardKey.keyA) {
          ref.read(selectionProvider.notifier).selectAll(allIds);
          return KeyEventResult.handled;
        }
        if (!isCtrl && key == LogicalKeyboardKey.arrowDown) {
          _moveHighlight(allIds.length, _columns);
          return KeyEventResult.handled;
        }
        if (!isCtrl && key == LogicalKeyboardKey.arrowUp) {
          _moveHighlight(allIds.length, -_columns);
          return KeyEventResult.handled;
        }
        if (!isCtrl && key == LogicalKeyboardKey.arrowRight) {
          _moveHighlight(allIds.length, 1);
          return KeyEventResult.handled;
        }
        if (!isCtrl && key == LogicalKeyboardKey.arrowLeft) {
          _moveHighlight(allIds.length, -1);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space) {
          activateHighlighted();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _focusNode.requestFocus(),
        child: Scaffold(
          body: LayoutBuilder(builder: (context, constraints) {
            final cols = ((constraints.maxWidth - 48) / 240).ceil();
            _columns = cols < 1 ? 1 : cols;
            return GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20),
              itemCount: subFolders.length + currentBooks.length,
              itemBuilder: (context, index) {
                final itemKey = _itemKeys.putIfAbsent(index, () => GlobalKey());
                if (index < subFolders.length) {
                  return _FolderItem(
                      key: itemKey,
                      path: subFolders[index],
                      shelfId: widget.shelfId,
                      index: index,
                      allIds: allIds,
                      highlighted: index == _highlightIndex);
                }
                return _BookItem(
                    key: itemKey,
                    book: currentBooks[index - subFolders.length],
                    index: index,
                    allIds: allIds,
                    highlighted: index == _highlightIndex);
              },
            );
          }),
        ),
      ),
    );
  }
}

// 複数選択中に、選択済みの項目を右クリック（長押し）した場合はこちらを優先する。
// お気に入り切替/削除を選択中の全項目（本・フォルダ混在）にまとめて適用する。
Future<bool> _showBatchMenuIfApplicable({
  required BuildContext context,
  required WidgetRef ref,
  required Offset globalPosition,
  required String shelfId,
  required String itemId,
}) async {
  final selection = ref.read(selectionProvider);
  if (selection.selectedIds.length <= 1 ||
      !selection.selectedIds.contains(itemId)) {
    return false;
  }
  final libState = ref.read(libraryProvider);
  final ids = selection.selectedIds;
  final selectedBooks =
      libState.books.where((b) => ids.contains(b.id)).toList();
  final selectedFolderPaths =
      ids.where((id) => !selectedBooks.any((b) => b.id == id)).toList();
  final shelf = libState.shelves
      .firstWhere((s) => s.id == shelfId, orElse: () => libState.shelves.first);
  final allFav = selectedBooks.every((b) => b.isFavorite) &&
      selectedFolderPaths.every((path) => shelf.favoriteFolders.contains(path));

  final loc = AppLocalizations.of(context)!;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1), Offset.zero & overlay.size),
    items: [
      PopupMenuItem(
          value: 'favorite',
          child: Text(allFav ? loc.removeFromFavorites : loc.addToFavorites)),
      PopupMenuItem(value: 'delete', child: Text(loc.delete)),
    ],
  );
  final notifier = ref.read(libraryProvider.notifier);
  switch (selected) {
    case 'favorite':
      for (final b in selectedBooks) {
        if (b.isFavorite != !allFav) await notifier.toggleBookFavorite(b);
      }
      for (final path in selectedFolderPaths) {
        await notifier.toggleFolderFavorite(shelfId, path, !allFav);
      }
      break;
    case 'delete':
      var allSucceeded = true;
      for (final b in selectedBooks) {
        if (!await notifier.removeBook(b.id)) allSucceeded = false;
      }
      for (final path in selectedFolderPaths) {
        if (!await notifier.removeFolder(shelfId, path)) allSucceeded = false;
      }
      ref.read(selectionProvider.notifier).clear();
      if (!allSucceeded && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.deleteFailed)));
      }
      break;
  }
  return true;
}

class _FolderItem extends ConsumerStatefulWidget {
  final String path, shelfId;
  final int index;
  final List<String> allIds;
  final bool highlighted;
  const _FolderItem(
      {super.key,
      required this.path,
      required this.shelfId,
      required this.index,
      required this.allIds,
      this.highlighted = false});
  @override
  ConsumerState<_FolderItem> createState() => _FolderItemState();
}

class _FolderItemState extends ConsumerState<_FolderItem> {
  bool _hover = false;

  // 表紙スタックのサムネイルが1枚ずつ非同期にデコードされて次々と
  // ポップインして見える(ちらつき)のを防ぐため、全サムネイルの
  // precacheが完了するまでスタック表示自体を保留する
  List<String> _precachingPaths = const [];
  bool _thumbsReady = false;

  void _ensureThumbsPrecached(List<String> paths) {
    if (listEquals(_precachingPaths, paths)) return;
    _precachingPaths = paths;
    _thumbsReady = paths.isEmpty;
    if (paths.isEmpty) return;
    Future.wait(paths.map((path) =>
            precacheImage(FileImage(File(path)), context).catchError((_) {})))
        .then((_) {
      if (mounted && listEquals(_precachingPaths, paths)) {
        setState(() => _thumbsReady = true);
      }
    });
  }

  Future<void> _removeFolder() async {
    final loc = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.deleteFolderTitle),
        content: Text(loc.deleteFolderConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(loc.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(loc.delete)),
        ],
      ),
    );
    if (confirm == true) {
      final success = await ref
          .read(libraryProvider.notifier)
          .removeFolder(widget.shelfId, widget.path);
      if (!success && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.deleteFailed)));
      }
    }
  }

  Future<void> _showFolderMenu(Offset globalPosition, String fName,
      List<String> segments, bool isAnyFavorite) async {
    if (await _showBatchMenuIfApplicable(
        context: context,
        ref: ref,
        globalPosition: globalPosition,
        shelfId: widget.shelfId,
        itemId: widget.path)) {
      return;
    }
    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
          globalPosition & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        PopupMenuItem(
            value: 'favorite',
            child: Text(
                isAnyFavorite ? loc.removeFromFavorites : loc.addToFavorites)),
        PopupMenuItem(value: 'newtab', child: Text(loc.openInNewTab)),
        PopupMenuItem(value: 'delete', child: Text(loc.delete)),
      ],
    );
    if (!mounted) return;
    switch (selected) {
      case 'favorite':
        ref
            .read(libraryProvider.notifier)
            .toggleFolderFavorite(widget.shelfId, widget.path, !isAnyFavorite);
        break;
      case 'delete':
        _removeFolder();
        break;
      case 'newtab':
        ref.read(tabProvider.notifier).navigateTo(widget.shelfId,
            path: widget.path,
            title: fName,
            segments: segments,
            openInNewTab: true);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(libraryProvider);
    final tab =
        ref.watch(tabProvider).tabs[ref.watch(tabProvider).currentIndex];
    final isChecked =
        ref.watch(selectionProvider).selectedIds.contains(widget.path);
    final fName = p.basename(widget.path);

    final booksInFolder = state.books.where((b) =>
        b.shelfId == widget.shelfId && bookIsWithinFolder(b, widget.path));
    final currentShelf = state.shelves.firstWhere((s) => s.id == widget.shelfId,
        orElse: () => state.shelves.first);
    final isAnyFavorite = currentShelf.favoriteFolders.contains(widget.path);

    final sortedBooks = booksInFolder.toList()
      ..sort((a, b) => SortUtils.compareBooks(a, b));
    final thumbBooks = sortedBooks.take(5).toList().reversed.toList();
    _ensureThumbsPrecached(thumbBooks
        .map((b) => b.thumbnailPath)
        .whereType<String>()
        .toList());

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Column(children: [
        Expanded(
            child: Container(
          // Card自体の枠線はサムネイル画像がカードいっぱいに描かれて隠れて
          // しまうため、Cardの外側(デフォルトmarginの隙間)に枠を描く
          decoration: BoxDecoration(
              border: Border.all(
                  color: widget.highlighted
                      ? colorScheme.primary
                      : Colors.transparent,
                  width: 3)),
          child: Card(
          shape: const RoundedRectangleBorder(),
          clipBehavior: Clip.antiAlias,
          color: colorScheme.surfaceContainerHighest,
          elevation: _hover ? 1 : 0,
          child: Listener(
            onPointerDown: (e) {
              if (e.buttons == 4) {
                ref.read(tabProvider.notifier).navigateTo(widget.shelfId,
                    path: widget.path,
                    title: fName,
                    segments: [...tab.segments, fName],
                    openInNewTab: true);
              }
            },
            child: GestureDetector(
              onSecondaryTapDown: (details) => _showFolderMenu(
                  details.globalPosition,
                  fName,
                  [...tab.segments, fName],
                  isAnyFavorite),
              onLongPressStart: (details) => _showFolderMenu(
                  details.globalPosition,
                  fName,
                  [...tab.segments, fName],
                  isAnyFavorite),
              child: InkWell(
                onTap: () {
                  if (HardwareKeyboard.instance.isControlPressed) {
                    ref
                        .read(selectionProvider.notifier)
                        .toggle(widget.path, widget.index);
                  } else if (HardwareKeyboard.instance.isShiftPressed) {
                    ref
                        .read(selectionProvider.notifier)
                        .selectRange(widget.index, widget.allIds);
                  } else {
                    ref.read(tabProvider.notifier).navigateTo(widget.shelfId,
                        path: widget.path,
                        title: fName,
                        segments: [...tab.segments, fName]);
                  }
                },
                child: Stack(children: [
                  if (thumbBooks.isEmpty || !_thumbsReady)
                    Center(
                        child: Icon(Icons.folder,
                            size: 64, color: colorScheme.onSurfaceVariant))
                  else
                    ...thumbBooks.asMap().entries.map((entry) {
                      final i = entry.key;
                      final b = entry.value;
                      return Positioned(
                        top: 0,
                        bottom: 0,
                        left: i * 8.0,
                        right: (thumbBooks.length - 1 - i) * 8.0,
                        child: b.thumbnailPath != null
                            ? Image.file(File(b.thumbnailPath!),
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                color: i < thumbBooks.length - 1
                                    ? Colors.black.withOpacity(0.3)
                                    : null,
                                colorBlendMode: i < thumbBooks.length - 1
                                    ? BlendMode.darken
                                    : null)
                            : Container(
                                color: colorScheme.surfaceContainerHigh),
                      );
                    }),
                  if (booksInFolder.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      left: (thumbBooks.length - 1) * 8.0 + 8.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!
                              .fileCount(booksInFolder.length),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (_hover || isChecked)
                    Positioned(
                        top: 4,
                        left: 4,
                        child: Checkbox(
                            value: isChecked,
                            onChanged: (_) => ref
                                .read(selectionProvider.notifier)
                                .toggle(widget.path, widget.index))),
                  if (isAnyFavorite)
                    const Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(Icons.star, color: Colors.amber, size: 18)),
                ]),
              ),
            ),
          ),
        ),
        )),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Tooltip(
              message: fName,
              child: SizedBox(
                height: 48,
                child: Text(fName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500, height: 1.1),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ),
            )),
      ]),
    );
  }
}

class _BookItem extends ConsumerStatefulWidget {
  final Book book;
  final int index;
  final List<String> allIds;
  final bool highlighted;
  const _BookItem(
      {super.key,
      required this.book,
      required this.index,
      required this.allIds,
      this.highlighted = false});
  @override
  ConsumerState<_BookItem> createState() => _BookItemState();
}

class _BookItemState extends ConsumerState<_BookItem> {
  bool _hover = false;

  Future<void> _showBookMenu(
      Offset globalPosition, List<String> segments) async {
    if (await _showBatchMenuIfApplicable(
        context: context,
        ref: ref,
        globalPosition: globalPosition,
        shelfId: widget.book.shelfId,
        itemId: widget.book.id)) {
      return;
    }
    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
          globalPosition & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        PopupMenuItem(
            value: 'favorite',
            child: Text(widget.book.isFavorite
                ? loc.removeFromFavorites
                : loc.addToFavorites)),
        PopupMenuItem(value: 'newtab', child: Text(loc.openInNewTab)),
        PopupMenuItem(value: 'delete', child: Text(loc.delete)),
      ],
    );
    if (!mounted) return;
    switch (selected) {
      case 'favorite':
        ref.read(libraryProvider.notifier).toggleBookFavorite(widget.book);
        break;
      case 'delete':
        final success =
            await ref.read(libraryProvider.notifier).removeBook(widget.book.id);
        if (!success && mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(loc.deleteFailed)));
        }
        break;
      case 'newtab':
        ref.read(tabProvider.notifier).openBook(
            widget.book.id, widget.book.title, true,
            segments: segments);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab =
        ref.watch(tabProvider).tabs[ref.watch(tabProvider).currentIndex];
    final isChecked =
        ref.watch(selectionProvider).selectedIds.contains(widget.book.id);
    final segments = [...tab.segments, widget.book.title];
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Column(children: [
        Expanded(
            child: Container(
          decoration: BoxDecoration(
              border: Border.all(
                  color: widget.highlighted
                      ? colorScheme.primary
                      : Colors.transparent,
                  width: 3)),
          child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: _hover ? 1 : 0,
          child: Stack(children: [
            Listener(
              onPointerDown: (e) {
                if (e.buttons == 4) {
                  ref.read(tabProvider.notifier).openBook(
                      widget.book.id, widget.book.title, true,
                      segments: segments);
                }
              },
              child: GestureDetector(
                onSecondaryTapDown: (details) =>
                    _showBookMenu(details.globalPosition, segments),
                onLongPressStart: (details) =>
                    _showBookMenu(details.globalPosition, segments),
                child: InkWell(
                  onTap: () {
                    if (HardwareKeyboard.instance.isControlPressed) {
                      ref
                          .read(selectionProvider.notifier)
                          .toggle(widget.book.id, widget.index);
                    } else if (HardwareKeyboard.instance.isShiftPressed) {
                      ref
                          .read(selectionProvider.notifier)
                          .selectRange(widget.index, widget.allIds);
                    } else {
                      ref.read(tabProvider.notifier).openBook(
                          widget.book.id, widget.book.title, false,
                          segments: segments);
                    }
                  },
                  child: widget.book.thumbnailPath != null
                      ? Image.file(File(widget.book.thumbnailPath!),
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          gaplessPlayback: true)
                      : const Center(child: Icon(Icons.book, size: 64)),
                ),
              ),
            ),
            Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ReadProgressBar(book: widget.book)),
            if (_hover || isChecked)
              Positioned(
                  top: 4,
                  left: 4,
                  child: Checkbox(
                      value: isChecked,
                      onChanged: (v) => ref
                          .read(selectionProvider.notifier)
                          .toggle(widget.book.id, widget.index))),
            if (widget.book.isFavorite)
              const Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(Icons.star, color: Colors.amber, size: 18)),
          ]),
        ),
        )),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Tooltip(
              message: widget.book.title,
              child: SizedBox(
                height: 48,
                child: Text(widget.book.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500, height: 1.1),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ),
            )),
      ]),
    );
  }
}
