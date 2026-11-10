import 'package:flutter_test/flutter_test.dart';
import 'package:dolce/core/utils/book_path_utils.dart';
import 'package:dolce/features/library/models/book.dart';

Book b(String path) => Book()
  ..title = path.split('/').last.replaceAll('.cbz', '')
  ..filePath = path
  ..shelfId = 's';

void main() {
  const root = '/lib/小説';
  test('フラットなタイトル順ではなく、表示順（サブフォルダ→本）の先頭が選ばれる', () {
    final books = [
      b('$root/支倉/マグダラ/1.cbz'), // タイトル「1」は全体の先頭になる
      b('$root/ノベライズ/あ/話.cbz'), // フォルダ順では先頭
      b('$root/直下.cbz'),
    ];
    final r = booksInDisplayOrder(books, root);
    expect(r.map((e) => e.filePath), [
      '$root/ノベライズ/あ/話.cbz',
      '$root/支倉/マグダラ/1.cbz',
      '$root/直下.cbz',
    ]);
  });

  test('limitで打ち切り、空でも落ちない', () {
    final books = [for (var i = 1; i <= 9; i++) b('$root/a/$i.cbz')];
    expect(booksInDisplayOrder(books, root).length, 5);
    expect(booksInDisplayOrder([], root), isEmpty);
  });
}
