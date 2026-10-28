// interactive_swipe_back.dart
//
// 画面を右方向にスワイプすると、指の動きにリアルタイムに追従して
// 画面全体がスライドし、途中で離すとそのまま「戻る」か元の位置へ
// 復帰するかをアニメーションで確定する、iOS風のインタラクティブな
// スワイプバック遷移。
//
// 使い方:
//   Navigator.of(context).push(slideBackRoute(
//     builder: (context) => const NextScreen(),
//   ));
//
// NextScreen側で戻る操作を自前で用意したい場合は、
// InteractiveSwipeBackTransition を直接使う:
//   InteractiveSwipeBackTransition(
//     onBack: () => Navigator.of(context).pop(),
//     child: NextScreen(),
//   )

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// ==== 調整可能な定数 ====

/// 左右スワイプを「戻る/切り替え」と判定する速度しきい値（px/秒）。
const kSwipeGestureVelocityThreshold = 75.0;

/// トラックパッド/マウスホイールの水平スクロールで「戻る」を
/// 発火させる際のしきい値（px）。
const kSwipeBackScrollThreshold = 2.0;

/// ゆっくり指を離した場合に「戻る」を確定させる、画面幅に対する
/// 位置の閾値（0.4 = 40%）。フリックの場合は
/// [kSwipeGestureVelocityThreshold] の速度判定を優先する。
const kSwipeBackPositionThreshold = 0.4;

/// 戻る/復帰アニメーションの所要時間とカーブ。
const popSlideDuration = Duration(milliseconds: 220);
const popSlideCurve = Curves.easeOutCubic;

// ==== コントローラ ====

/// 右スワイプ「戻る」ジェスチャーの進行状態を保持し、ドラッグ中の
/// 追従・指を離した時のコミット（戻る）／キャンセル（復帰）を
/// 判定・アニメーションするコントローラ。
///
/// 背景（[InteractiveSwipeBackTransition]自身のGestureDetector）以外の
/// 場所（例えば子ウィジェット内の別のドラッグハンドラ）からも、常に
/// 「現在の絶対px」で[syncFromExternalDrag]を呼ぶ設計にすることで、
/// 差分の二重積算を避けられる。
class InteractiveSwipeBackController {
  InteractiveSwipeBackController({
    required TickerProvider vsync,
    required this.onCommit,
  }) : _animationController = AnimationController(vsync: vsync);

  final VoidCallback onCommit;
  final AnimationController _animationController;

  final ValueNotifier<double> progress = ValueNotifier<double>(0);

  /// 呼び出し側（[InteractiveSwipeBackTransition]）が都度反映する画面幅。
  double maxDrag = 1;

  bool isGestureActive = false;

  void syncFromExternalDrag(BuildContext context, double absoluteOffsetPx) {
    if (!isGestureActive) {
      isGestureActive = true;
      _animationController.stop();
      Navigator.of(context).didStartUserGesture();
    }
    progress.value = absoluteOffsetPx.clamp(0.0, maxDrag);
  }

  void endExternalDrag(BuildContext context, double? velocityPxPerSec) {
    if (!isGestureActive) return;
    isGestureActive = false;

    final velocity = velocityPxPerSec ?? 0;
    final bool commit;
    if (velocity <= -kSwipeGestureVelocityThreshold) {
      commit = false;
    } else if (velocity >= kSwipeGestureVelocityThreshold) {
      commit = true;
    } else {
      commit = progress.value / maxDrag >= kSwipeBackPositionThreshold;
    }

    final start = progress.value;
    final target = commit ? maxDrag : 0.0;
    final remaining = (target - start).abs();
    final fraction = maxDrag == 0 ? 0.0 : remaining / maxDrag;
    final duration = Duration(
      milliseconds: (popSlideDuration.inMilliseconds * fraction).round().clamp(
        120,
        popSlideDuration.inMilliseconds,
      ),
    );

    Navigator.of(context).didStopUserGesture();

    _animationController
      ..duration = duration
      ..value = 0;
    final animation = Tween<double>(begin: start, end: target).animate(
      CurvedAnimation(parent: _animationController, curve: popSlideCurve),
    );
    void listener() => progress.value = animation.value;
    animation.addListener(listener);
    _animationController.forward().whenCompleteOrCancel(() {
      animation.removeListener(listener);
      if (commit) {
        onCommit();
        // mobile_shell.dartのように同じウィジェットのままchildだけ差し替える
        // 常駐ラッパーとして使う場合、ここでリセットしないと新しいchildが
        // 「画面外にスライドし切った」オフセットのまま表示され、戻った先が
        // 黒い画面に見えてしまう（スライドし切ってからonCommitを呼ぶ設計の
        // ため）。Navigatorでpopする使い方(slideBackRoute)ではこの直後に
        // ウィジェット自体が破棄されるため、このリセットは無害
        progress.value = 0;
      }
    });
  }

  void dispose() {
    _animationController.dispose();
    progress.dispose();
  }
}

/// [InteractiveSwipeBackController]を子孫ウィジェットへ配布するための
/// 非購読ルックアップ用スコープ。コントローラのインスタンスはルートの
/// 生存期間中不変なので、値の変化を購読する必要は無い。
class InteractiveSwipeBackScope extends InheritedWidget {
  const InteractiveSwipeBackScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final InteractiveSwipeBackController controller;

  static InteractiveSwipeBackController? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<InteractiveSwipeBackScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(InteractiveSwipeBackScope oldWidget) => false;
}

/// 画面を右スワイプでインタラクティブに戻れるようにするラッパー。
/// ドラッグ中は指の位置にリアルタイムに追従して[child]全体が右へ
/// スライドし、指を離した時、閾値を超えていれば画面外までスライドし
/// 切ってから[onBack]（戻る）を呼び、超えていなければ元の位置へ
/// アニメーションで復帰する。トラックパッド/マウスホイールの右スクロール
/// でも同じく[onBack]を呼ぶ（[_handleScroll]参照）。
///
/// [onNext]は左方向のフリックのみに反応する離散的なコールバックで、
/// 指追従の演出は付かない（隣接画面への切り替え等に使う想定）。
class InteractiveSwipeBackTransition extends StatefulWidget {
  const InteractiveSwipeBackTransition({
    required this.onBack,
    required this.child,
    this.onNext,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback? onNext;
  final Widget child;

  @override
  State<InteractiveSwipeBackTransition> createState() =>
      _InteractiveSwipeBackTransitionState();
}

class _InteractiveSwipeBackTransitionState
    extends State<InteractiveSwipeBackTransition>
    with SingleTickerProviderStateMixin {
  late final InteractiveSwipeBackController _controller =
      InteractiveSwipeBackController(vsync: this, onCommit: widget.onBack);

  double _cumulativeDx = 0;

  /// トラックパッド/マウスホイールの水平スクロールで「戻る」を
  /// 発火させる際のデバウンス用タイマー。
  Timer? _scrollBackTimer;

  @override
  void dispose() {
    _scrollBackTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// タッチではなくトラックパッド/マウスホイール操作向けに、指ドラッグ
  /// での右スワイプと同じ「戻る」を右スクロールでも行えるようにする。
  /// 離散的なスクロールイベントを150msデバウンスしてから直接[onBack]を
  /// 呼ぶだけの単純な実装で、ドラッグ版のような追従アニメーションは
  /// 行わない（トラックパッドのスクロールには連続した「指の位置」に
  /// 相当する情報が無いため）。
  ///
  /// [child]内に縦スクロールするリスト等がある場合、縦スクロール中に
  /// 横方向の微小なノイズで誤って「戻る」が発火しないよう、横方向が
  /// 縦方向より明確に大きいことを条件にする。
  void _handleScroll(PointerScrollEvent event) {
    final dx = event.scrollDelta.dx;
    final dy = event.scrollDelta.dy;
    if (dx <= kSwipeBackScrollThreshold || dx.abs() <= dy.abs()) return;
    _scrollBackTimer?.cancel();
    _scrollBackTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) widget.onBack();
    });
  }

  @override
  Widget build(BuildContext context) {
    _controller.maxDrag = MediaQuery.sizeOf(context).width;
    return InteractiveSwipeBackScope(
      controller: _controller,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) _handleScroll(event);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) {
            _cumulativeDx = _controller.progress.value;
          },
          onHorizontalDragUpdate: (details) {
            _cumulativeDx += details.delta.dx;
            if (_cumulativeDx > 0 || _controller.isGestureActive) {
              _controller.syncFromExternalDrag(
                context,
                _cumulativeDx.clamp(0.0, _controller.maxDrag),
              );
            }
          },
          onHorizontalDragEnd: (details) {
            if (!_controller.isGestureActive) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity <= -kSwipeGestureVelocityThreshold) {
                widget.onNext?.call();
              }
              return;
            }
            _controller.endExternalDrag(context, details.primaryVelocity);
          },
          child: ValueListenableBuilder<double>(
            valueListenable: _controller.progress,
            child: RepaintBoundary(child: widget.child),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(value, 0),
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }
}

// ==== 入場アニメーション ====

/// 画面右外からスライドインしてくる、pushされたページの入場遷移。
Widget buildSlideInFromRightTransition(
  Animation<double> animation,
  Widget child,
) {
  final curved = CurvedAnimation(parent: animation, curve: popSlideCurve);
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(curved),
    child: child,
  );
}

// ==== ルートヘルパー ====

/// 右スワイプでのインタラクティブな「戻る」（[InteractiveSwipeBackTransition]）
/// と、画面右外からのスライド入場（[buildSlideInFromRightTransition]）を
/// 適用した`Navigator.push`用ルート。
Route<T> slideBackRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    opaque: false,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        buildSlideInFromRightTransition(animation, child),
    pageBuilder: (context, animation, secondaryAnimation) {
      return InteractiveSwipeBackTransition(
        onBack: () {
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        },
        child: Builder(builder: builder),
      );
    },
  );
}
