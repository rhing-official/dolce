import 'package:flutter_test/flutter_test.dart';
import 'package:dolce/features/settings/models/app_settings.dart';

void main() {
  test('accentPaletteは組み込み色の後ろに登録色を並べ、重複は除く', () {
    final s = AppSettings(
        customAccentColors: [0xFF123456, kAccentPresets.first, 0xFF123456]);
    expect(s.accentPalette.take(kAccentPresets.length), kAccentPresets);
    expect(s.accentPalette.skip(kAccentPresets.length).toList(),
        [0xFF123456]);
  });

  test('copyWithでcustomAccentColorsを更新できる', () {
    final s = AppSettings().copyWith(customAccentColors: [0xFFABCDEF]);
    expect(s.customAccentColors, [0xFFABCDEF]);
    expect(s.copyWith(accentColor: 0xFF000000).customAccentColors,
        [0xFFABCDEF]);
  });
}
