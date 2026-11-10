import 'package:flutter/material.dart';
import '../theme/block_theme.dart';
import '../theme/block_thumb_card.dart';

// 読み込み中のスケルトンスクリーン用の部品。灰色の面の上をハイライトが
// ゆっくり流れる。多数のカード（グリッド）が個別にAnimationControllerを持たない
// よう、[SkeletonScope]が1つのアニメーションを子孫へ共有する。
// スコープが無い所では、動かない灰色の面になる

/// 子孫の[SkeletonBox]へ、共通のアニメーション（0→1の繰り返し）を提供する。
class SkeletonScope extends StatefulWidget {
  final Widget child;
  const SkeletonScope({super.key, required this.child});

  @override
  State<SkeletonScope> createState() => _SkeletonScopeState();
}

class _SkeletonScopeState extends State<SkeletonScope>
    with SingleTickerProviderStateMixin {
  // TickerModeにより、非表示のタブ(IndexedStack)では自動で止まる
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SkeletonAnimation(notifier: _controller, child: widget.child);
}

class _SkeletonAnimation extends InheritedNotifier<AnimationController> {
  const _SkeletonAnimation({required super.notifier, required super.child});

  static AnimationController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_SkeletonAnimation>()
      ?.notifier;
}

/// スケルトンの面。[width]/[height]を省くと親いっぱいに広がる。
/// [base]/[highlight]で色を指定できる（既定はテーマの面の上に文字色を薄く重ねた色）
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? base;
  final Color? highlight;
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.base,
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = base ??
        Color.alphaBlend(
            scheme.onSurface.withValues(alpha: 0.10), scheme.surfaceContainer);
    final highlightColor = highlight ??
        Color.alphaBlend(
            scheme.onSurface.withValues(alpha: 0.22), scheme.surfaceContainer);
    final radius = borderRadius ?? BorderRadius.circular(4);
    final animation = _SkeletonAnimation.maybeOf(context);
    Widget box(double t) {
      // ハイライトの帯を左から右へ流す（-2〜2の範囲で動かし、端では帯が見えない）
      final slide = -2 + 4 * t;
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: animation == null ? baseColor : null,
          gradient: animation == null
              ? null
              : LinearGradient(
                  begin: Alignment(slide - 1, 0),
                  end: Alignment(slide + 1, 0),
                  colors: [baseColor, highlightColor, baseColor],
                  stops: const [0.0, 0.5, 1.0],
                ),
        ),
        child: const SizedBox.expand(),
      );
    }

    final child = animation == null
        ? box(0)
        : AnimatedBuilder(
            animation: animation, builder: (_, __) => box(animation.value));
    if (width == null && height == null) return child;
    return SizedBox(width: width, height: height, child: child);
  }
}

/// サムネ付きカード（フォルダ・本）の形のスケルトン。本棚グリッドの1マス分。
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: Container(
          margin: kBlockThumbMargin,
          decoration: blockThumbDecoration(context, highlighted: false),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BlockTheme.radius - 1),
            child: const SkeletonBox(borderRadius: BorderRadius.zero),
          ),
        ),
      ),
      // 題名（最大3行）の位置に、太さの違う2本のバー
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: SizedBox(
          height: 48,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            FractionallySizedBox(
                widthFactor: 0.8, child: SkeletonBox(height: 12)),
            SizedBox(height: 6),
            FractionallySizedBox(
                widthFactor: 0.5, child: SkeletonBox(height: 12)),
          ]),
        ),
      ),
    ]);
  }
}

/// 本棚グリッド全面のスケルトン。[SkeletonScope]を内包する。
class SkeletonGrid extends StatelessWidget {
  final int itemCount;
  const SkeletonGrid({super.key, this.itemCount = 12});

  @override
  Widget build(BuildContext context) {
    return SkeletonScope(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            childAspectRatio: 0.7,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20),
        itemCount: itemCount,
        itemBuilder: (_, __) => const SkeletonCard(),
      ),
    );
  }
}

/// ビューアのページ読み込み中（黒い背景の上に、縦長のページの形）。
class PageSkeleton extends StatelessWidget {
  const PageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonScope(
      child: LayoutBuilder(builder: (context, constraints) {
        // 縦長のページ（約0.7）が、画面の高さの8割に収まる大きさで中央に出る
        final height = constraints.maxHeight * 0.8;
        final width = (height * 0.7).clamp(0.0, constraints.maxWidth * 0.8);
        return Center(
          child: SkeletonBox(
            width: width,
            height: width / 0.7,
            borderRadius: BorderRadius.circular(BlockTheme.radius),
            base: Colors.white.withValues(alpha: 0.07),
            highlight: Colors.white.withValues(alpha: 0.16),
          ),
        );
      }),
    );
  }
}

/// EPUBの章の読み込み中（紙色の上に、本文の行の形）。
class TextSkeleton extends StatelessWidget {
  const TextSkeleton({super.key});

  // 行ごとの幅の割合（段落の途中で短い行を混ぜる）
  static const _lines = [
    1.0, 0.96, 1.0, 0.9, 0.5, 0.0, 1.0, 0.94, 1.0, 0.98, 0.7, 0.0, 1.0, 0.92,
    1.0, 0.45,
  ];

  @override
  Widget build(BuildContext context) {
    return SkeletonScope(
      child: ColoredBox(
        color: const Color(0xFFFAF7F0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              child: Column(children: [
                for (final f in _lines)
                  f == 0
                      ? const SizedBox(height: 20)
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: f,
                              child: SkeletonBox(
                                height: 14,
                                base: Colors.black.withValues(alpha: 0.07),
                                highlight: Colors.black.withValues(alpha: 0.15),
                              ),
                            ),
                          ),
                        ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
