import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

/// 目次の1項目（章番号 + 章内アンカー）
class EpubTocItem {
  final String title;
  final int chapterIndex;
  final String? fragment;
  final int depth;
  const EpubTocItem(this.title, this.chapterIndex, this.fragment, this.depth);
}

/// 読み込んだEPUB。章（spine）・目次・画像などの資源をzipから提供する
class EpubBook {
  final Map<String, ArchiveFile> _files;
  // spineの各章のzip内パス（正規化済み）
  final List<String> chapters;
  final List<EpubTocItem> toc;
  final String? coverPath;

  EpubBook._(this._files, this.chapters, this.toc, this.coverPath);

  Uint8List? bytesOf(String path) {
    final f = _files[p.posix.normalize(path)];
    if (f == null) return null;
    return Uint8List.fromList(f.content as List<int>);
  }

  Uint8List? coverBytes() => coverPath == null ? null : bytesOf(coverPath!);

  String chapterHtml(int index) {
    final bytes = bytesOf(chapters[index]);
    return bytes == null ? '' : utf8.decode(bytes, allowMalformed: true);
  }

  /// [fromChapterPath]のファイルから見た相対hrefを、zip内の正規化パスへ解決する
  static String resolvePath(String fromPath, String href) {
    final noFragment = href.split('#').first;
    final decoded = Uri.decodeFull(noFragment);
    return p.posix.normalize(p.posix.join(p.posix.dirname(fromPath), decoded));
  }

  /// zip内パスに対応する章番号（無ければnull）
  int? chapterIndexOfPath(String path) {
    final i = chapters.indexOf(p.posix.normalize(path));
    return i < 0 ? null : i;
  }
}

class EpubService {
  static Future<EpubBook> open(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = <String, ArchiveFile>{
      for (final f in archive.files)
        if (f.isFile) p.posix.normalize(f.name): f,
    };

    String text(String path) {
      final f = files[p.posix.normalize(path)];
      if (f == null) throw FormatException('EPUB内に$pathがありません');
      return utf8.decode(f.content as List<int>, allowMalformed: true);
    }

    // container.xml → OPFのパス
    final container = XmlDocument.parse(text('META-INF/container.xml'));
    final opfPath = container
        .findAllElements('rootfile')
        .first
        .getAttribute('full-path')!;
    final opf = XmlDocument.parse(text(opfPath));

    // manifest: id → (パス, properties)
    final manifest = <String, ({String path, String props, String type})>{};
    for (final item in opf.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id == null || href == null) continue;
      manifest[id] = (
        path: EpubBook.resolvePath(opfPath, href),
        props: item.getAttribute('properties') ?? '',
        type: item.getAttribute('media-type') ?? '',
      );
    }

    // spine = 章の並び
    final chapters = <String>[];
    for (final ref in opf.findAllElements('itemref')) {
      final item = manifest[ref.getAttribute('idref')];
      if (item != null && files.containsKey(item.path)) {
        chapters.add(item.path);
      }
    }
    if (chapters.isEmpty) throw const FormatException('EPUBに本文がありません');

    // カバー画像: EPUB3(properties=cover-image) → EPUB2(meta name=cover)
    String? coverPath;
    for (final m in manifest.values) {
      if (m.props.split(' ').contains('cover-image')) coverPath = m.path;
    }
    if (coverPath == null) {
      for (final meta in opf.findAllElements('meta')) {
        if (meta.getAttribute('name') == 'cover') {
          coverPath = manifest[meta.getAttribute('content')]?.path;
        }
      }
    }

    // 目次: EPUB3 nav.xhtml → EPUB2 NCX
    final toc = <EpubTocItem>[];
    String? navPath;
    for (final m in manifest.values) {
      if (m.props.split(' ').contains('nav')) navPath = m.path;
    }
    final chapterIndex = {
      for (var i = 0; i < chapters.length; i++) chapters[i]: i
    };

    void addToc(String title, String fromPath, String href, int depth) {
      final idx = chapterIndex[EpubBook.resolvePath(fromPath, href)];
      if (idx == null || title.trim().isEmpty) return;
      final hash = href.indexOf('#');
      toc.add(EpubTocItem(title.trim(), idx,
          hash >= 0 ? href.substring(hash + 1) : null, depth));
    }

    try {
      if (navPath != null && files.containsKey(navPath)) {
        final doc = html_parser.parse(text(navPath));
        final nav = doc.querySelectorAll('nav').firstWhere(
            (n) => (n.attributes['epub:type'] ?? n.attributes['type'] ?? '')
                .contains('toc'),
            orElse: () => doc.querySelector('nav') ?? dom.Element.tag('nav'));
        void walkOl(dom.Element ol, int depth) {
          for (final li in ol.children.where((e) => e.localName == 'li')) {
            final a = li.children
                .where((e) => e.localName == 'a' || e.localName == 'span')
                .firstOrNull;
            final href = a?.attributes['href'];
            if (a != null && href != null) {
              addToc(a.text, navPath!, href, depth);
            }
            for (final sub in li.children.where((e) => e.localName == 'ol')) {
              walkOl(sub, depth + 1);
            }
          }
        }

        final ol = nav.querySelector('ol');
        if (ol != null) walkOl(ol, 0);
      }
      if (toc.isEmpty) {
        final tocId = opf.findAllElements('spine').first.getAttribute('toc');
        final ncxPath = manifest[tocId]?.path ??
            manifest.values
                .where((m) => m.type == 'application/x-dtbncx+xml')
                .map((m) => m.path)
                .firstOrNull;
        if (ncxPath != null && files.containsKey(ncxPath)) {
          final ncx = XmlDocument.parse(text(ncxPath));
          void walkPoints(XmlElement parent, int depth) {
            for (final pt in parent.childElements
                .where((e) => e.name.local == 'navPoint')) {
              final label = pt.childElements
                  .where((e) => e.name.local == 'navLabel')
                  .firstOrNull
                  ?.innerText;
              final src = pt.childElements
                  .where((e) => e.name.local == 'content')
                  .firstOrNull
                  ?.getAttribute('src');
              if (label != null && src != null) {
                addToc(label, ncxPath, src, depth);
              }
              walkPoints(pt, depth + 1);
            }
          }

          final navMap = ncx.findAllElements('navMap').firstOrNull;
          if (navMap != null) walkPoints(navMap, 0);
        }
      }
    } catch (_) {
      // 目次が壊れていても本文は読めるようにする
    }

    return EpubBook._(files, chapters, toc, coverPath);
  }
}
