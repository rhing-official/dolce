import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/viewer_provider.dart';
import '../../../core/providers/tab_provider.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../core/widgets/interactive_swipe_back.dart' show kSwipeGestureVelocityThreshold;
import '../../../core/widgets/mobile_nav_popup.dart';
import '../../../core/utils/system_nav_bar_inset.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/models/app_settings.dart';
import '../../../l10n/app_localizations.dart';

// app.dart側でサイドバーがこのメニューと重ならないよう高さを共有する。
// 120だとページ数表示行+Slider+ページ送りボタン行の実際の高さに対して
// 6px足りず、デスクトップ・モバイル両方の下部パネルで
// 「BOTTOM OVERFLOWED BY 6.0 PIXELS」が発生していたため126に修正
// （以前はモバイル側だけ_kMobileNavRowExtraHeightで個別に帳尻を
// 合わせていたが、根本原因はプラットフォーム共通のこちら側だった）
const double kViewerBottomMenuHeight = 126;

// モバイルでは、この下にナビゲーションポップアップの行を同じパネル内に
// 追加で積む分の高さ（区切り線とその余白込み）
const double _kMobileNavRowExtraHeight = kMobileNavPopupHeight + 8;

class ViewerScreen extends ConsumerStatefulWidget {
  final String bookId;
  final bool isActive;
  const ViewerScreen({super.key, required this.bookId, this.isActive = true});
  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  final FocusNode _focusNode = FocusNode();

  // 下部メニューバーのスライド(showUI)をAnimationControllerで駆動する。
  // ガラス効果(BackdropFilter)はスライド中の毎フレーム再計算が非常に重いため、
  // スライド中はブラー無しの不透明背景に切り替え、静止した時だけガラスにする
  // （サイドバーで実際に発生したジャンクと同じ原因を先回りして回避する）。
  // 200msだと速すぎて動きが目に留まらなかったため、体感できる速さまで伸ばし、
  // イージングも付けて動き自体をはっきりさせる
  late final AnimationController _menuAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000));
  late final Animation<double> _menuCurve = CurvedAnimation(
      parent: _menuAnim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic);
  bool? _wasShowUI;

  // 自動めくり秒数の選択パネル（長押しのままドラッグして選択 + 自由入力）
  static const List<int> _autoPagePresets = [3, 5, 10, 15, 30];
  OverlayEntry? _autoMenuEntry;
  final List<GlobalKey> _autoItemKeys =
      List.generate(_autoPagePresets.length, (_) => GlobalKey());
  final ValueNotifier<int?> _autoHover = ValueNotifier(null);
  // テキストボックスの内容は、プリセット選択や再オープンで上書きしない
  // （一度入力/表示した内容を次回もそのまま保持する）
  late final TextEditingController _autoText = TextEditingController();
  bool _autoTextInitialized = false;

  // フォーカスはタブがアクティブになった時と画面タップ時(onTapUp)のみ取得する。
  // buildのたびにrequestFocusすると、サイドバーの検索欄など他所にフォーカスが
  // ある状態でも、無関係な再ビルドのたびにフォーカスを奪ってしまう
  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
      _applyImmersiveModeIfAndroid();
    }
  }

  @override
  void didUpdateWidget(covariant ViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _focusNode.requestFocus();
      _applyImmersiveModeIfAndroid();
      if (ref.read(autoPlayPrefProvider)) {
        ref.read(viewerProvider(widget.bookId).notifier).startAutoPlay();
      }
    } else if (oldWidget.isActive && !widget.isActive) {
      _restoreSystemUiIfAndroid();
      ref
          .read(viewerProvider(widget.bookId).notifier)
          .stopAutoPlay(keepPref: true);
    }
    if (oldWidget.bookId != widget.bookId) {
      ref
          .read(viewerProvider(oldWidget.bookId).notifier)
          .stopAutoPlay(keepPref: true);
    }
  }

  // Androidの3ボタン/ジェスチャーナビゲーションバーは、下部メニューの
  // アイコン行と重なり誤タップの原因になる（実機検証で確認済み）ため、
  // ビューア表示中はイマーシブモードで隠す。上端から下スワイプすれば
  // 一時的に再表示できる(immersiveSticky)。デスクトップには存在しない
  // 概念なのでAndroidのみで行う
  void _applyImmersiveModeIfAndroid() {
    if (!Platform.isAndroid) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _restoreSystemUiIfAndroid() {
    if (!Platform.isAndroid) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _handleZoom(PointerScrollEvent event) {
    final double zoomFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
    final double currentScale =
        _transformationController.value.getMaxScaleOnAxis();
    final double newScale = (currentScale * zoomFactor).clamp(1.0, 10.0);
    if (newScale == 1.0 && currentScale == 1.0) {
      _transformationController.value = Matrix4.identity();
      return;
    }
    final Offset localCursor = event.localPosition;
    final Matrix4 matrix = _transformationController.value;
    final double dx =
        (localCursor.dx - matrix.getTranslation().x) / currentScale;
    final double dy =
        (localCursor.dy - matrix.getTranslation().y) / currentScale;
    setState(() {
      _transformationController.value = Matrix4.identity()
        ..translate(
            localCursor.dx - dx * newScale, localCursor.dy - dy * newScale)
        ..scale(newScale);
    });
  }

  @override
  void dispose() {
    if (widget.isActive) _restoreSystemUiIfAndroid();
    _closeAutoPageMenu();
    _autoHover.dispose();
    _autoText.dispose();
    _transformationController.dispose();
    _focusNode.dispose();
    _menuAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(viewerProvider(widget.bookId));
    final notifier = ref.read(viewerProvider(widget.bookId).notifier);
    notifier.autoPageBlocked =
        () => _transformationController.value.getMaxScaleOnAxis() > 1.01;
    final settings = ref.watch(settingsProvider);
    final tabNotifier = ref.read(tabProvider.notifier);
    final bool isLeftToNext =
        settings.pageDirection == PageDirection.leftToNext;

    // このタブが実際に表示されている時だけファイルを開いてページ画像を読み込む
    // （IndexedStackは全タブを同時にbuildするため、isActiveで絞らないと
    // 非表示の背景タブも一斉にファイルを開いてしまう）。
    // ロード中(isLoading)でもFocus等のウィジェットツリーは常に維持し、
    // 下のGestureDetector/Image部分だけをスピナー表示に切り替える
    // （以前はここで早期returnしてFocusごと取り除いていたため、ロード完了
    // までの間に押した↑/↓等のキー操作が拾われず消える不具合があった）
    if (widget.isActive) notifier.ensureActive();

    if (_wasShowUI != state.showUI) {
      _wasShowUI = state.showUI;
      state.showUI ? _menuAnim.forward() : _menuAnim.reverse();
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      descendantsAreFocusable: false,
      onKeyEvent: (node, event) {
        final isDown = event is KeyDownEvent;
        final isRepeat = event is KeyRepeatEvent;
        if (!isDown && !isRepeat) return KeyEventResult.ignored;
        final key = event.logicalKey;
        final isCtrl = HardwareKeyboard.instance.isControlPressed;
        final isAlt = HardwareKeyboard.instance.isAltPressed;

        // ★ Ctrl+Tab などのブラウザ制御系は無視（親ウィジェットにスルーさせる）
        if (isCtrl && key == LogicalKeyboardKey.tab)
          return KeyEventResult.ignored;

        if (isDown) {
          if (key == LogicalKeyboardKey.escape) {
            final tabState = ref.read(tabProvider);
            tabNotifier.closeBook(tabState.tabs[tabState.currentIndex]);
            return KeyEventResult.handled;
          }

          if (isCtrl) {
            if (key == LogicalKeyboardKey.arrowLeft ||
                key == LogicalKeyboardKey.numpad4) {
              isLeftToNext
                  ? notifier.jumpToPage(state.totalPages - 1)
                  : notifier.jumpToPage(0);
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowRight ||
                key == LogicalKeyboardKey.numpad6) {
              isLeftToNext
                  ? notifier.jumpToPage(0)
                  : notifier.jumpToPage(state.totalPages - 1);
              return KeyEventResult.handled;
            }
          }
          if (!isCtrl && !isAlt && key == LogicalKeyboardKey.keyP) {
            notifier.toggleAutoPlay();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.space ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter) {
            notifier.toggleUI();
            return KeyEventResult.handled;
          }
        }

        // ページめくり・本の切替は長押し中(KeyRepeatEvent)も連続して実行する
        // Alt+矢印はタブ履歴の戻る/進むショートカット(app.dartの
        // _onGlobalKey)と競合するため、ここでは処理しない
        if (!isCtrl && !isAlt) {
          if (key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.numpad4) {
            notifier.nextPage();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.arrowRight ||
              key == LogicalKeyboardKey.numpad6) {
            notifier.previousPage();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.arrowDown) {
            notifier.switchBook(true);
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.arrowUp) {
            notifier.switchBook(false);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor:
            state.showUI ? SystemMouseCursors.basic : SystemMouseCursors.none,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(children: [
            LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth;
              // ズーム未使用時（スケール1.0）はInteractiveViewer側に
              // パンできる余地が無く、パンを有効にしたままだと縦スワイプの
              // ジェスチャーアリーナを食い合ってしまう。ズーム中だけパンを
              // 有効にすることで、非ズーム時は下の縦スワイプ（本の切替）に
              // 確実にジェスチャーを渡す
              final isZoomed =
                  _transformationController.value.getMaxScaleOnAxis() > 1.01;
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) _handleZoom(event);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // 画面タップ3分割: 左1/3=前ページ・中央1/3=UI表示切替・
                  // 右1/3=次ページ（ページめくり方向はpageDirection設定で反転）
                  onTapUp: (details) {
                    _focusNode.requestFocus();
                    final dx = details.localPosition.dx;
                    if (dx < width / 3) {
                      isLeftToNext
                          ? notifier.nextPage()
                          : notifier.previousPage();
                    } else if (dx > width * 2 / 3) {
                      isLeftToNext
                          ? notifier.previousPage()
                          : notifier.nextPage();
                    } else {
                      notifier.toggleUI();
                    }
                  },
                  // モバイルのみ：縦スワイプで同フォルダ内の前/次の本へ遷移する
                  // （↑/↓キーのswitchBookとマッピングを揃える。上スワイプ＝
                  // 次の本＝↓キー、下スワイプ＝前の本＝↑キー）。ズーム中は
                  // パン操作を優先するためスキップする
                  onVerticalDragEnd: isMobilePlatform
                      ? (details) {
                          if (isZoomed) return;
                          final velocity = details.primaryVelocity ?? 0;
                          if (velocity <= -kSwipeGestureVelocityThreshold) {
                            notifier.switchBook(true);
                          } else if (velocity >=
                              kSwipeGestureVelocityThreshold) {
                            notifier.switchBook(false);
                          }
                        }
                      : null,
                  child: SizedBox.expand(
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 1.0,
                      maxScale: 10.0,
                      panEnabled: isZoomed,
                      scaleEnabled: false,
                      child: Center(
                          child: notifier.currentImageBytes != null
                              ? Image.memory(notifier.currentImageBytes!,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                  gaplessPlayback: true)
                              : const CircularProgressIndicator(
                                  color: Colors.white24)),
                    ),
                  ),
                ),
              );
            }),
            AnimatedBuilder(
              animation: _menuCurve,
              builder: (context, _) {
                final t = _menuCurve.value;
                final slideDistance = kViewerBottomMenuHeight +
                    (isMobilePlatform ? _kMobileNavRowExtraHeight : 0.0) +
                    10;
                // ビューアはシステムナビゲーションバーをイマーシブモードで
                // 隠しているため、ここでのMediaQuery.padding.bottomは常に0を
                // 返してしまう。バーがある他のページと下端の座標を揃えるため、
                // バーが表示されている時にキャッシュされた高さ分だけ持ち上げる
                final navBarLift =
                    Platform.isAndroid ? SystemNavBarInset.bottom : 0.0;
                return Positioned(
                  bottom: -slideDistance + slideDistance * t + navBarLift * t,
                  left: 0,
                  right: 0,
                  child: _buildBottomMenu(settings, state, notifier),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }

  // ビューアは常に黒背景の読書画面なので、テーマ色ではなく黒基調のガラス
  // （半透明の黒＋ブラー）にする。開閉スライド中も含めて常時ガラス効果を
  // 適用する（以前はスライド中だけ不透明な黒にフォールバックしていたが、
  // このパネルはサイドバーよりずっと小さく、常時ガラスにしても体感できる
  // ジャンクは生じなかったため統一した）
  Widget _buildBottomMenu(AppSettings settings, state, notifier) {
    final bool isLeftToNext =
        settings.pageDirection == PageDirection.leftToNext;
    final loc = AppLocalizations.of(context)!;
    final content = Column(children: [
      SizedBox(
        height: 30,
        child: Stack(children: [
          Positioned(
            left: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Text('${state.totalPages}',
                  style: const TextStyle(color: Colors.white70, fontSize: 18)),
            ),
          ),
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Text('${state.currentPage + 1}',
                  style: const TextStyle(color: Colors.white70, fontSize: 18)),
            ),
          ),
        ]),
      ),
      Directionality(
          textDirection: isLeftToNext ? TextDirection.rtl : TextDirection.ltr,
          child: Slider(
              value: state.currentPage.toDouble(),
              max: (state.totalPages - 1).toDouble().clamp(0.0, double.infinity),
              onChanged: (v) => notifier.jumpToPage(v.toInt()))),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
            tooltip: isLeftToNext ? loc.jumpToLastPage : loc.jumpToFirstPage,
            icon: const Icon(Icons.skip_previous, color: Colors.white),
            onPressed: () =>
                notifier.jumpToPage(isLeftToNext ? state.totalPages - 1 : 0)),
        IconButton(
            tooltip: isLeftToNext ? loc.jumpToFirstPage : loc.jumpToLastPage,
            icon: const Icon(Icons.skip_next, color: Colors.white),
            onPressed: () =>
                notifier.jumpToPage(isLeftToNext ? 0 : state.totalPages - 1)),
        const SizedBox(width: 8),
        GestureDetector(
          onLongPressStart: (details) =>
              _showAutoPageMenu(details.globalPosition),
          onLongPressMoveUpdate: (details) =>
              _autoHover.value = _autoItemAt(details.globalPosition),
          onLongPressEnd: (details) {
            final index = _autoItemAt(details.globalPosition);
            if (index != null) _applyAutoPageSeconds(_autoPagePresets[index]);
          },
          // tooltip未指定の理由は向き固定ボタンと同じ（長押しが競合するため）
          // 長押しメニューと競合しないよう、ツールチップはホバー専用(manual)
          child: Tooltip(
            message: loc.autoPageTooltip,
            triggerMode: TooltipTriggerMode.manual,
            child: IconButton(
                icon: Icon(state.autoPlay ? Icons.pause : Icons.play_arrow,
                    color: Colors.white),
                onPressed: notifier.toggleAutoPlay),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
            tooltip: isLeftToNext ? loc.nextBook : loc.previousBook,
            icon: _bookNavIcon(isNext: isLeftToNext),
            onPressed: () => notifier.switchBook(isLeftToNext)),
        IconButton(
            tooltip: isLeftToNext ? loc.previousBook : loc.nextBook,
            icon: _bookNavIcon(isNext: !isLeftToNext),
            onPressed: () => notifier.switchBook(!isLeftToNext)),
        // 画面の向き固定はAndroid専用（デスクトップはウィンドウが自由に
        // リサイズできるフローティングウィンドウで「向き」の概念が無い）。
        // タップで縦↔左90度をトグルし、長押しで右90度・180度も選べる
        // （タブレットではどちらの向きで持つか任意なため必須）
        if (Platform.isAndroid) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onLongPressStart: (details) =>
                _showOrientationMenu(details.globalPosition),
            // tooltip未指定: IconButton標準のTooltipは長押しで自身を表示する
            // ため、指定するとこのGestureDetectorのonLongPressStartと
            // ジェスチャーが競合し、長押しメニューが開かなくなる
            child: IconButton(
                icon:
                    const Icon(Icons.screen_lock_rotation, color: Colors.white),
                onPressed: _toggleOrientation),
          ),
        ],
      ]),
      // モバイルでは、デスクトップのタブバー・サイドバー・パスバーの機能を
      // 集約したナビゲーションポップアップの行を、別パネルとして重ねるのでは
      // なくこのページ送りパネルの下段として同じガラス背景の中に統合する
      // （2枚のガラスパネルが重なって視認性が悪くなるのを避けるため）
      if (isMobilePlatform) ...[
        const Divider(height: 8, color: Colors.white12),
        const SizedBox(
            height: kMobileNavPopupHeight,
            child: MobileNavIconRow(iconColor: Colors.white)),
      ],
    ]);

    final panelHeight = kViewerBottomMenuHeight +
        (isMobilePlatform ? _kMobileNavRowExtraHeight : 0.0);

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: SizedBox(
          height: panelHeight,
          child: Stack(fit: StackFit.expand, children: [
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  // Border(top: ...)は角丸を無視して直線を引いてしまい、
                  // 上端の角が四角く見えてしまうため、borderRadiusを持つ
                  // Border.allで角丸に沿った縁取りにする
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16), width: 1),
                ),
              ),
            ),
            content,
          ]),
        ),
      ),
    );
  }

  // 本の切り替えは矢印キーの↓(次の本)/↑(前の本)に対応しているため、
  // アイコンもそれに合わせて下向き/上向き矢印にする
  Widget _bookNavIcon({required bool isNext}) {
    return Icon(
      isNext ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
      color: Colors.white,
      size: 32,
    );
  }

  // タップ1回では縦↔左90度のみをトグルする（最も使う頻度が高い組み合わせ）。
  // 右90度・180度は長押しメニュー([_showOrientationMenu])からのみ選べる
  void _toggleOrientation() {
    final settings = ref.read(settingsProvider);
    final next =
        settings.screenOrientationLock == ScreenOrientationLock.portraitUp
            ? ScreenOrientationLock.landscapeLeft
            : ScreenOrientationLock.portraitUp;
    ref.read(settingsProvider.notifier).state =
        settings.copyWith(screenOrientationLock: next);
  }

  Future<void> _showOrientationMenu(Offset globalPosition) async {
    final loc = AppLocalizations.of(context)!;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final current = ref.read(settingsProvider).screenOrientationLock;
    final selected = await showMenu<ScreenOrientationLock>(
      context: context,
      position: RelativeRect.fromRect(
          globalPosition & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        CheckedPopupMenuItem(
            value: ScreenOrientationLock.portraitUp,
            checked: current == ScreenOrientationLock.portraitUp,
            child: Text(loc.orientationPortrait)),
        CheckedPopupMenuItem(
            value: ScreenOrientationLock.landscapeLeft,
            checked: current == ScreenOrientationLock.landscapeLeft,
            child: Text(loc.orientationLandscapeLeft)),
        CheckedPopupMenuItem(
            value: ScreenOrientationLock.landscapeRight,
            checked: current == ScreenOrientationLock.landscapeRight,
            child: Text(loc.orientationLandscapeRight)),
        CheckedPopupMenuItem(
            value: ScreenOrientationLock.portraitDown,
            checked: current == ScreenOrientationLock.portraitDown,
            child: Text(loc.orientationPortraitDown)),
      ],
    );
    if (selected == null || !mounted) return;
    final settings = ref.read(settingsProvider);
    ref.read(settingsProvider.notifier).state =
        settings.copyWith(screenOrientationLock: selected);
  }

  int? _autoItemAt(Offset global) {
    if (_autoMenuEntry == null) return null;
    for (var i = 0; i < _autoItemKeys.length; i++) {
      final box = _autoItemKeys[i].currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(global)) return i;
    }
    return null;
  }

  void _closeAutoPageMenu() {
    _autoMenuEntry?.remove();
    _autoMenuEntry = null;
    _autoHover.value = null;
  }

  void _applyAutoPageSeconds(int seconds) {
    _closeAutoPageMenu();
    if (!mounted) return;
    final value = seconds.clamp(1, 3600);
    final settings = ref.read(settingsProvider);
    ref.read(settingsProvider.notifier).state =
        settings.copyWith(autoPageSeconds: value);
    final notifier = ref.read(viewerProvider(widget.bookId).notifier);
    notifier.stopAutoPlay();
    notifier.startAutoPlay();
    _focusNode.requestFocus();
  }

  void _showAutoPageMenu(Offset globalPosition) {
    _closeAutoPageMenu();
    final loc = AppLocalizations.of(context)!;
    final overlay = Overlay.of(context);
    final screen = MediaQuery.of(context).size;
    final current = ref.read(settingsProvider).autoPageSeconds;
    if (!_autoTextInitialized) {
      _autoText.text = '$current';
      _autoTextInitialized = true;
    }
    final controller = _autoText;
    const panelWidth = 180.0;
    final left = (globalPosition.dx - panelWidth / 2)
        .clamp(8.0, (screen.width - panelWidth - 8).clamp(8.0, double.infinity));
    final bottom = screen.height - globalPosition.dy + 8;

    void submit() {
      final v = int.tryParse(controller.text);
      if (v == null || v < 1) return;
      _applyAutoPageSeconds(v);
    }

    _autoMenuEntry = OverlayEntry(builder: (context) {
      return Stack(children: [
        Positioned.fill(
            child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeAutoPageMenu)),
        Positioned(
          left: left,
          bottom: bottom,
          width: panelWidth,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ValueListenableBuilder<int?>(
                valueListenable: _autoHover,
                builder: (context, hover, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < _autoPagePresets.length; i++)
                        Container(
                          key: _autoItemKeys[i],
                          height: 36,
                          color: hover == i
                              ? Theme.of(context).highlightColor
                              : null,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(children: [
                            SizedBox(
                                width: 24,
                                child: _autoPagePresets[i] == current
                                    ? const Icon(Icons.check, size: 16)
                                    : null),
                            Text(loc.autoPageSecondsItem(_autoPagePresets[i])),
                          ]),
                        ),
                      const Divider(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: InputDecoration(
                                  isDense: true,
                                  suffixText: loc.autoPageSecondsUnit),
                              onSubmitted: (_) => submit(),
                            ),
                          ),
                          // 入力中の秒数が現在有効な値と一致する時だけ白く強調する
                          ListenableBuilder(
                            listenable: controller,
                            builder: (context, _) {
                              final active =
                                  int.tryParse(controller.text) == current;
                              return IconButton(
                                  icon: Icon(Icons.check,
                                      color: active
                                          ? Colors.white
                                          : Colors.white38),
                                  onPressed: submit);
                            },
                          ),
                        ]),
                      ),
                    ]),
              ),
            ),
          ),
        ),
      ]);
    });
    overlay.insert(_autoMenuEntry!);
  }
}
