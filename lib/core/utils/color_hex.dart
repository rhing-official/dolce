import 'package:flutter/material.dart';

extension ColorHex on Color {
  /// `#RRGGBB`（大文字）。透明度は含めない（版画UIのアクセントは常に不透明）
  String toHexString() {
    final rgb = (toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '#${rgb.toUpperCase()}';
  }
}

/// `RRGGBB` / `#RRGGBB`（大文字小文字は問わない）を不透明な[Color]にする。
/// 3桁・8桁（透明度付き）・不正な文字を含む場合はnull
Color? tryParseHexColor(String input) {
  final hex = input.trim().replaceFirst('#', '');
  if (hex.length != 6) return null;
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}
