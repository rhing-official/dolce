import 'package:flutter/material.dart';

// 左右スワイプでタブ切り替えを行う領域。GestureDetectorではなくLisener
// で生のポインタイベントだけを観測するのは、GestureDetectorのドラッグ系
// レコグナイザーが内包するボタン等のタップ用レコグナイザーと同じジェスチャー
// アリーナに加わってしまい、Android実機上ではタップそのものが反応しなく
// なる不具合が実機検証で見つかったため。Listenerはアリーナに参加しない
// ため、内包するウィジェットのタップ操作に一切影響しない
class SwipeTabSwitchArea extends StatefulWidget {
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final Widget child;
  const SwipeTabSwitchArea({
    super.key,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.child,
  });

  @override
  State<SwipeTabSwitchArea> createState() => _SwipeTabSwitchAreaState();
}

class _SwipeTabSwitchAreaState extends State<SwipeTabSwitchArea> {
  Offset? _dragStart;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) => _dragStart = event.position,
      onPointerUp: (event) {
        final start = _dragStart;
        _dragStart = null;
        if (start == null) return;
        final delta = event.position - start;
        if (delta.dx.abs() < 40 || delta.dx.abs() <= delta.dy.abs()) return;
        if (delta.dx < 0) {
          widget.onSwipeLeft();
        } else {
          widget.onSwipeRight();
        }
      },
      child: widget.child,
    );
  }
}
