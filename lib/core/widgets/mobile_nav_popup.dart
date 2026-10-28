import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tab_provider.dart';
import '../../features/library/providers/library_provider.dart';
import '../../features/library/views/mobile_search_screen.dart';
import '../../features/library/views/mobile_tab_switcher.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../l10n/app_localizations.dart';
import 'glass_panel.dart';
import 'swipe_tab_switch_area.dart';

const double kMobileNavPopupHeight = 52;

// アイコンID→(アイコン, ラベル)。設定画面の表示/並べ替えリストと、
// ポップアップ本体([MobileNavIconRow])の両方から参照する共通定義。
// ラベルは表示言語設定に応じて切り替えるため、constマップではなくcontext
// 引数を取る関数にしてある
(IconData, String) mobileNavIconMeta(BuildContext context, String id) {
  final loc = AppLocalizations.of(context)!;
  return switch (id) {
    'back' => (Icons.arrow_back, loc.navBack),
    'forward' => (Icons.arrow_forward, loc.navForward),
    'search' => (Icons.search, loc.navSearch),
    'addTab' => (Icons.add, loc.navAddTab),
    'tabCount' => (Icons.tab_outlined, loc.navTabList),
    'favorites' => (Icons.star, loc.favorites),
    'settings' => (Icons.settings, loc.settings),
    'information' => (Icons.info_outline, loc.information),
    'addFolder' => (Icons.create_new_folder, loc.addFolder),
    _ => throw ArgumentError('unknown nav icon id: $id'),
  };
}

class _NavAction {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Widget? badge;
  const _NavAction(
      {required this.icon, required this.label, this.onPressed, this.badge});
}

// タブバー・サイドバー・パスバーの機能をここへ集約するモバイル専用ポップアップ。
// 表示するアイコンの並び順・非表示にするアイコンは設定画面から変更でき、
// 非表示にしたものは右端のハンバーガーメニューへ収納される。
// 本棚表示中はこのGlassPanel入りの独立したピルとして下部に常駐させ、ビューア
// 表示中は[MobileNavIconRow]だけをビューア自身のページ送りパネルに埋め込み、
// 2枚のガラスパネルが重なって見えないようにする
class MobileNavPopup extends StatelessWidget {
  const MobileNavPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: GlassPanel(
            borderRadius: BorderRadius.circular(28),
            child: const SizedBox(
              height: kMobileNavPopupHeight,
              child: MobileNavIconRow(),
            ),
          ),
        ),
      ),
    );
  }
}

// 8アイコン+ハンバーガーの横並び本体。背景・余白を持たないため、呼び出し側
// （本棚用の[MobileNavPopup]、ビューア用の統合パネル）が任意の背景に埋め込める
class MobileNavIconRow extends ConsumerWidget {
  final Color? iconColor;
  const MobileNavIconRow({super.key, this.iconColor});

  _NavAction _actionFor(BuildContext context, WidgetRef ref, String id) {
    final tabState = ref.watch(tabProvider);
    final tabNotifier = ref.read(tabProvider.notifier);
    final tab = tabState.tabs[tabState.currentIndex];
    final libraryState = ref.watch(libraryProvider);

    final (icon, label) = mobileNavIconMeta(context, id);
    switch (id) {
      case 'back':
        return _NavAction(
            icon: icon,
            label: label,
            onPressed: tab.historyIndex > 0 ? tabNotifier.undo : null);
      case 'forward':
        return _NavAction(
            icon: icon,
            label: label,
            onPressed: tab.historyIndex < tab.history.length - 1
                ? tabNotifier.redo
                : null);
      case 'search':
        return _NavAction(
            icon: icon,
            label: label,
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MobileSearchScreen())));
      case 'addTab':
        return _NavAction(
            icon: icon, label: label, onPressed: tabNotifier.addLibraryTab);
      case 'tabCount':
        return _NavAction(
          icon: icon,
          label: '$label (${tabState.tabs.length})',
          badge: _CountBadge(count: tabState.tabs.length),
          onPressed: () => showModalBottomSheet(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (_) => const FractionallySizedBox(
                  heightFactor: 0.75, child: MobileTabSwitcher())),
        );
      case 'favorites':
        return _NavAction(
            icon: icon,
            label: label,
            onPressed: tabNotifier.openOrToggleFavorites);
      case 'settings':
        return _NavAction(
            icon: icon,
            label: label,
            onPressed: tabNotifier.openOrToggleSettings);
      case 'information':
        return _NavAction(
            icon: icon,
            label: label,
            onPressed: tabNotifier.openOrToggleInformation);
      case 'addFolder':
        return _NavAction(
          icon: icon,
          label: label,
          onPressed: libraryState.isLoading
              ? null
              : () => ref.read(libraryProvider.notifier).addShelf(context),
        );
    }
    throw ArgumentError('unknown nav icon id: $id');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final hidden = settings.effectiveMobileNavHiddenIcons.toSet();
    final order = settings.effectiveMobileNavIconOrder;
    final visibleIds = order.where((id) => !hidden.contains(id)).toList();
    final hiddenIds = order.where((id) => hidden.contains(id)).toList();
    final color = iconColor ?? Theme.of(context).colorScheme.onSurface;
    final tabNotifier = ref.read(tabProvider.notifier);

    return SwipeTabSwitchArea(
      // ピル全体のどこをスワイプしてもタブ切り替えができるようにする。
      // 左スワイプで前のタブ、右スワイプで次のタブへジャンプする
      onSwipeLeft: tabNotifier.previousTab,
      onSwipeRight: tabNotifier.nextTab,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final id in visibleIds)
            _NavIconButton(action: _actionFor(context, ref, id), color: color),
          if (hiddenIds.isNotEmpty)
            _HamburgerButton(
                hiddenIds: hiddenIds,
                actionFor: (id) => _actionFor(context, ref, id),
                color: color),
        ],
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  final _NavAction action;
  final Color color;
  const _NavIconButton({required this.action, required this.color});

  @override
  Widget build(BuildContext context) {
    final icon = Icon(action.icon, size: 22, color: color);
    return IconButton(
      tooltip: action.label,
      icon: action.badge == null
          ? icon
          : Stack(clipBehavior: Clip.none, children: [
              icon,
              Positioned(right: -4, top: -4, child: action.badge!),
            ]),
      onPressed: action.onPressed,
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
      decoration: BoxDecoration(
          color: colorScheme.inverseSurface, borderRadius: BorderRadius.circular(8)),
      child: Text('$count',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: colorScheme.onInverseSurface)),
    );
  }
}

// 標準のPopupMenuButtonは「押す→離す」で開き、選択は別の新しいタップで
// 行う（showMenu()が生成する別routeへは、ボタン押下時のポインタが
// 引き継がれないため）。Androidネイティブのメニューによくある
// 「押したまま指を動かし、項目の上で離して選択する」操作に対応するため、
// Listenerで生のポインタイベントを追跡し、メニュー項目もOverlayEntryで
// 自前に描画する
class _HamburgerButton extends StatefulWidget {
  final List<String> hiddenIds;
  final _NavAction Function(String id) actionFor;
  final Color color;
  const _HamburgerButton(
      {required this.hiddenIds, required this.actionFor, required this.color});

  @override
  State<_HamburgerButton> createState() => _HamburgerButtonState();
}

class _HamburgerButtonState extends State<_HamburgerButton> {
  static const double _itemHeight = 44;
  static const double _menuWidth = 220;

  final GlobalKey _buttonKey = GlobalKey();
  final ValueNotifier<int?> _hoverIndex = ValueNotifier(null);
  OverlayEntry? _entry;
  List<Rect> _itemRects = const [];

  @override
  void dispose() {
    _entry?.remove();
    _hoverIndex.dispose();
    super.dispose();
  }

  void _closeMenu() {
    _entry?.remove();
    _entry = null;
    _hoverIndex.value = null;
  }

  void _selectAndClose(int index) {
    final action = widget.actionFor(widget.hiddenIds[index]);
    _closeMenu();
    action.onPressed?.call();
  }

  void _openMenu() {
    final buttonBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final buttonTopLeft = buttonBox.localToGlobal(Offset.zero);
    final buttonSize = buttonBox.size;
    final screenSize = MediaQuery.of(context).size;

    final menuHeight = widget.hiddenIds.length * _itemHeight;
    var left = buttonTopLeft.dx + buttonSize.width - _menuWidth;
    left = left.clamp(8.0, screenSize.width - _menuWidth - 8.0);
    // ボトムナビゲーション上のボタンなので、メニューはボタンの上に開く
    final top = buttonTopLeft.dy - menuHeight - 8;

    _itemRects = [
      for (var i = 0; i < widget.hiddenIds.length; i++)
        Rect.fromLTWH(left, top + i * _itemHeight, _menuWidth, _itemHeight),
    ];

    _entry = OverlayEntry(builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeMenu,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: _menuWidth,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ValueListenableBuilder<int?>(
              valueListenable: _hoverIndex,
              builder: (context, hovered, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.hiddenIds.length; i++)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _selectAndClose(i),
                      child: Container(
                        height: _itemHeight,
                        width: _menuWidth,
                        color: hovered == i
                            ? colorScheme.primary.withValues(alpha: 0.15)
                            : null,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(children: [
                          Icon(widget.actionFor(widget.hiddenIds[i]).icon,
                              size: 18),
                          const SizedBox(width: 12),
                          Text(widget.actionFor(widget.hiddenIds[i]).label),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ]);
    });
    Overlay.of(context).insert(_entry!);
  }

  void _updateHover(Offset globalPosition) {
    final index = _itemRects.indexWhere((r) => r.contains(globalPosition));
    _hoverIndex.value = index == -1 ? null : index;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (_entry != null) {
          _closeMenu();
        } else {
          _openMenu();
        }
      },
      onPointerMove: (event) {
        if (_entry != null) _updateHover(event.position);
      },
      onPointerUp: (event) {
        if (_entry == null) return;
        final hovered = _hoverIndex.value;
        // 押した位置から指を動かさずに離した場合はメニューを開いたままにし、
        // 続けて項目を別タップで選択できるようにする（押しっぱなしで
        // ドラッグして離した場合のみ、その場で選択を確定する）
        if (hovered != null) _selectAndClose(hovered);
      },
      child: Tooltip(
        message: AppLocalizations.of(context)!.navMore,
        child: SizedBox(
          key: _buttonKey,
          width: 48,
          height: 48,
          child: Icon(Icons.menu, size: 22, color: widget.color),
        ),
      ),
    );
  }
}
