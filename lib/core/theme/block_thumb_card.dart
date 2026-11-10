import 'package:flutter/material.dart';
import 'block_theme.dart';

// サムネイル付きカード（フォルダ・本・タブ）の外枠。黒（ダークは明るい線）の
// 太枠と硬い影を描き、選択中（highlighted）はアクセントの太枠にする。
// 影が右・下へはみ出す分、呼び出し側のContainerのmarginで余白を取ること

/// カード外側のContainerに渡す装飾。
BoxDecoration blockThumbDecoration(BuildContext context,
    {required bool highlighted}) {
  final theme = Theme.of(context);
  return BoxDecoration(
    borderRadius: BorderRadius.circular(BlockTheme.radius),
    border: Border.all(
      color: highlighted
          ? theme.colorScheme.primary
          : BlockTheme.lineColor(theme.brightness),
      width: highlighted ? BlockTheme.borderWidth + 2 : BlockTheme.borderWidth,
    ),
    boxShadow: BlockTheme.shadow(theme.colorScheme.primary, theme.brightness),
  );
}

/// 枠の内側に収まる中身のクリップ用の形（Cardのshapeに渡す）。
final RoundedRectangleBorder blockThumbInnerShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(BlockTheme.radius - 1),
);

/// 影の置き場所を含む外側の余白。
const EdgeInsets kBlockThumbMargin = EdgeInsets.fromLTRB(3, 3, 8, 8);
