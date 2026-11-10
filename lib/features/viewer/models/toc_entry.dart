import 'dart:ui';

/// 目次の1項目。pageIndexは0始まりのページ番号（EPUBでは章番号）
class TocEntry {
  final String title;
  final int pageIndex;
  final int depth;
  const TocEntry(this.title, this.pageIndex, this.depth);
}

/// ページ内リンク。rectはページ画像に対する正規化座標（0〜1、左上原点）。
/// pageIndexへのジャンプか、外部URLのどちらかを持つ
class BookLink {
  final Rect rect;
  final int? pageIndex;
  final Uri? url;
  const BookLink(this.rect, {this.pageIndex, this.url});
}
