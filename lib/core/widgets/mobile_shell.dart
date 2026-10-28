import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tab_provider.dart';
import '../utils/system_nav_bar_inset.dart';
import 'interactive_swipe_back.dart';
import 'mobile_nav_popup.dart';
import 'tab_content_builder.dart';

// モバイル専用のUIシェル。デスクトップのタブバー・サイドバー・パスバーは
// 実装せず、それらの機能を[MobileNavPopup]の1枚のポップアップへ集約する。
// ビューア表示中はポップアップの代わりにビューア自身が統合パネル
// （ポップアップ行+ページ送り行）を描画するため、ここでは出さない
class MobileShell extends ConsumerWidget {
  const MobileShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabState = ref.watch(tabProvider);
    final currentTab = tabState.tabs[tabState.currentIndex];
    final isBookOpen = currentTab.bookId != null;

    final bottomInset = MediaQuery.of(context).padding.bottom;
    if (bottomInset > 0) SystemNavBarInset.bottom = bottomInset;

    final stack = IndexedStack(
      index: tabState.currentIndex,
      children: tabState.tabs.asMap().entries
          .map<Widget>((entry) => buildTabContent(
              entry.value, entry.key == tabState.currentIndex))
          .toList(),
    );

    return Scaffold(
      // 右スワイプで「1つ戻る」操作。ビューア表示中は、ズーム時の左右パンや
      // 本の切替（縦スワイプ）と競合する・意図しない画面へ飛ぶ不具合があった
      // ため、ビューア以外のタブでのみ有効にする
      body: isBookOpen
          ? stack
          : InteractiveSwipeBackTransition(
              onBack: () => ref.read(tabProvider.notifier).goBack(),
              child: stack,
            ),
      bottomNavigationBar: isBookOpen ? null : const MobileNavPopup(),
    );
  }
}
