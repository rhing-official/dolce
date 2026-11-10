import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as dom;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/epub_service.dart';

/// EPUBの1章分をHTMLとして描画する（リフロー表示。縦書き・外部CSSは未対応）。
/// 章内の画像はzipから、内部リンクは該当章/アンカーへ、外部URLはブラウザで開く
class EpubReader extends StatefulWidget {
  final EpubBook book;
  final int chapterIndex;
  final String html;
  // 章ジャンプ後にスクロールしたいアンカーID（表示後に1度だけ消費される）
  final String? Function() takeAnchor;
  // 他の章への内部リンク。(章番号, アンカー)
  final void Function(int chapter, String? anchor) onJump;

  const EpubReader({
    super.key,
    required this.book,
    required this.chapterIndex,
    required this.html,
    required this.takeAnchor,
    required this.onJump,
  });

  @override
  State<EpubReader> createState() => _EpubReaderState();
}

class _EpubReaderState extends State<EpubReader> {
  final GlobalKey<HtmlWidgetState> _htmlKey = GlobalKey();

  String get _chapterPath => widget.book.chapters[widget.chapterIndex];

  @override
  void initState() {
    super.initState();
    final anchor = widget.takeAnchor();
    if (anchor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // 画像等のレイアウト確定を少し待ってからスクロールする
        await Future<void>.delayed(const Duration(milliseconds: 200));
        _htmlKey.currentState?.scrollToAnchor(anchor);
      });
    }
  }

  Widget? _imageOf(String src) {
    final bytes =
        widget.book.bytesOf(EpubBook.resolvePath(_chapterPath, src));
    if (bytes == null) return null;
    return Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true);
  }

  Widget? _customWidget(dom.Element e) {
    if (e.localName == 'img') {
      final src = e.attributes['src'];
      return src == null ? null : _imageOf(src);
    }
    // 表紙ページに多い <svg><image xlink:href="..."/></svg>
    if (e.localName == 'svg') {
      final image = e.querySelector('image');
      final href = image?.attributes['xlink:href'] ?? image?.attributes['href'];
      return href == null ? null : _imageOf(href);
    }
    return null;
  }

  Future<bool> _onTapUrl(String url) async {
    // 同じ章内のアンカー(#id)はHtmlWidget側のスクロール処理に任せる
    if (url.startsWith('#')) return false;
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasScheme) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    // 他の章への相対リンク
    final target =
        widget.book.chapterIndexOfPath(EpubBook.resolvePath(_chapterPath, url));
    if (target != null) {
      final hash = url.indexOf('#');
      widget.onJump(target, hash >= 0 ? url.substring(hash + 1) : null);
      return true;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFAF7F0),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 96),
              child: HtmlWidget(
                widget.html,
                key: _htmlKey,
                textStyle: const TextStyle(
                    fontSize: 18, height: 1.8, color: Color(0xFF222222)),
                customWidgetBuilder: _customWidget,
                onTapUrl: _onTapUrl,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
