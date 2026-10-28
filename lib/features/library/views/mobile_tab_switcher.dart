import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../core/providers/tab_provider.dart';
import '../../../core/utils/tab_title_utils.dart';
import '../../../core/widgets/swipe_tab_switch_area.dart';
import '../../../l10n/app_localizations.dart';
import '../models/book.dart';

// デスクトップのタブバー・垂直タブ帯の代替。モバイルでは常時表示のタブ列を
// 持たず、ポップアップの「現在のタブ数」アイコンからこのボトムシートを開いて
// タブの切替・追加・削除を行う。ブラウザアプリのタブ切り替え画面を模した
// 2列グリッド表示（本を開いているタブは表紙画像、それ以外は種別アイコン）
class MobileTabSwitcher extends ConsumerWidget {
  const MobileTabSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabState = ref.watch(tabProvider);
    final notifier = ref.read(tabProvider.notifier);

    return SwipeTabSwitchArea(
      // シート内のどこをスワイプしてもタブ切り替えができるようにする
      onSwipeLeft: notifier.previousTab,
      onSwipeRight: notifier.nextTab,
      child: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(children: [
                    Text('タブ (${tabState.tabs.length})',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ]),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 72),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: tabState.tabs.length,
                    itemBuilder: (context, index) {
                      final tab = tabState.tabs[index];
                      return _TabCard(
                        tab: tab,
                        active: index == tabState.currentIndex,
                        onSelect: () {
                          notifier.selectTab(index);
                          Navigator.of(context).pop();
                        },
                        onClose: () => notifier.closeTab(index),
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.small(
                heroTag: 'mobileTabSwitcherAddTab',
                tooltip: AppLocalizations.of(context)!.newTab,
                onPressed: () {
                  notifier.addLibraryTab();
                  Navigator.of(context).pop();
                },
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabCard extends StatelessWidget {
  final TabItem tab;
  final bool active;
  final VoidCallback onSelect;
  final VoidCallback onClose;
  const _TabCard({
    required this.tab,
    required this.active,
    required this.onSelect,
    required this.onClose,
  });

  IconData get _icon {
    if (tab.isSettings) return Icons.settings;
    if (tab.isFavorites) return Icons.star;
    if (tab.isInformation) return Icons.info_outline;
    if (tab.bookId != null) return Icons.book;
    return Icons.folder;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final book =
        tab.bookId != null ? Hive.box<Book>('books').get(tab.bookId!) : null;
    final thumbnailPath = book?.thumbnailPath;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: active ? colorScheme.primary : Colors.transparent,
          width: 3,
        ),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SizedBox(
              height: 32,
              child: Row(children: [
                const SizedBox(width: 8),
                Icon(_icon, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(tabDisplayTitle(context, tab.title),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                ),
                InkWell(
                  onTap: onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close, size: 16),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: InkWell(
                onTap: onSelect,
                child: Container(
                  width: double.infinity,
                  color: colorScheme.surfaceContainerHighest,
                  child: thumbnailPath != null
                      ? Image.file(File(thumbnailPath),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          gaplessPlayback: true)
                      : Center(
                          child: Icon(_icon,
                              size: 48, color: colorScheme.onSurfaceVariant)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
