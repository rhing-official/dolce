import 'package:flutter/material.dart';
import '../theme/block_theme.dart';

// 版画UIの面（旧：すりガラス風）。不透明なパネル色に黒（ダークは明るい線）の
// 太枠と、ぼかしの無い硬い影を付ける。影は右・下へ[BlockTheme.shadowOffset]だけ
// はみ出すため、呼び出し側でその分の余白を確保し、外側をクリップしないこと。
// 中身は自身の背景を透明にしておくこと（クリップは中身にだけ掛ける）
class GlassPanel extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  const GlassPanel(
      {super.key, required this.child, this.borderRadius = BorderRadius.zero});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: PanelBackground(borderRadius: borderRadius)),
      ClipRRect(borderRadius: borderRadius, child: child),
    ]);
  }
}

// 背景専用レイヤー（childを持たない）。塗り・硬い影（背面）と太枠（前面）を
// 描く。ビューア上のクロームのようにコンテンツを重ねる用途で、背景とコンテンツを
// 別レイヤーにするため分けてある
class PanelBackground extends StatelessWidget {
  final BorderRadius borderRadius;
  const PanelBackground({super.key, this.borderRadius = BorderRadius.zero});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: borderRadius,
        boxShadow: BlockTheme.shadow(theme.colorScheme.primary, brightness),
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: BlockTheme.lineColor(brightness),
            width: BlockTheme.borderWidth,
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
