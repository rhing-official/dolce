import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolce/core/utils/color_hex.dart';

void main() {
  test('6桁は#の有無・大文字小文字によらず同じ不透明色になる', () {
    for (final s in ['f08300', '#F08300', 'F08300', ' #f08300 ']) {
      expect(tryParseHexColor(s)?.toARGB32(), 0xFFF08300, reason: s);
    }
  });

  test('6桁以外・16進以外はnull', () {
    for (final s in ['', 'f083', 'f0830', 'f083001', 'f0830080', 'gggggg', '#']) {
      expect(tryParseHexColor(s), isNull, reason: s);
    }
  });

  test('toHexStringは#RRGGBB（大文字、透明度は無視）', () {
    expect(const Color(0xFFF08300).toHexString(), '#F08300');
    expect(const Color(0x80F08300).toHexString(), '#F08300');
    expect(const Color(0xFF00000A).toHexString(), '#00000A');
  });
}
