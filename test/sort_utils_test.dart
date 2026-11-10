import 'package:flutter_test/flutter_test.dart';
import 'package:dolce/core/utils/sort_utils.dart';
import 'package:dolce/features/library/models/book.dart';

Book b(String title, [double? number]) => Book()
  ..title = title
  ..filePath = '/x/$title'
  ..number = number;

void main() {
  test('全員がNumberを持つ時は巻数順', () {
    final r = SortUtils.sortBooks([b('a', 2), b('b', 1)]);
    expect(r.map((e) => e.title), ['b', 'a']);
  });

  test('1冊だけNumberを持っても先頭にならずタイトル順', () {
    final r = SortUtils.sortBooks([b('c'), b('b', 1), b('a')]);
    expect(r.map((e) => e.title), ['a', 'b', 'c']);
  });

  test('Numberが無ければタイトル順、空でも落ちない', () {
    expect(SortUtils.sortBooks([b('b'), b('a')]).map((e) => e.title),
        ['a', 'b']);
    expect(SortUtils.sortBooks([]), isEmpty);
  });
}
