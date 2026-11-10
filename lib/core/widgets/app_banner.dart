import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/block_theme.dart';

OverlayEntry? _currentBanner;
Timer? _currentTimer;

/// アプリのお知らせを画面の上端中央に重ねて表示する（レイアウトは押し下げない）。
/// 直前のバナーは消してから出し、[duration]後に自動で消える。
/// 自動で消す処理は、このバナー自身のエントリだけを閉じる（後から出た別の
/// バナーを誤って消さないため）
void showAppBanner(BuildContext context, String message,
    {Duration duration = const Duration(seconds: 4)}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _dismiss();

  late final OverlayEntry entry;
  void close() {
    if (_currentBanner == entry) _dismiss();
  }

  entry = OverlayEntry(
    builder: (ctx) => Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        minimum: const EdgeInsets.only(top: 16),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          type: MaterialType.transparency,
          child: blockMaterialBox(
            ctx,
            color: Theme.of(ctx).colorScheme.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Text(message),
              ),
            ),
          ),
        ),
      ),
      ),
    ),
  );
  _currentBanner = entry;
  overlay.insert(entry);
  _currentTimer = Timer(duration, close);
}

void _dismiss() {
  _currentTimer?.cancel();
  _currentTimer = null;
  _currentBanner?.remove();
  _currentBanner = null;
}
