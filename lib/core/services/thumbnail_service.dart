import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import '../utils/pdf_render.dart';
import 'epub_service.dart';
import 'file_service.dart';

class ThumbnailService {
  // 保存するサムネイルの幅(px)。一覧の表示サイズ(最大でも数百px)より十分大きく、
  // 元画像（数千px）をそのまま保存してデコードコストを増やすことはしない
  static const int _kThumbWidth = 400;
  // これを超えるサムネイルは過去バージョンの元解像度のまま保存されたものとみなし縮小する
  static const int _kShrinkThresholdBytes = 120 * 1024;

  /// [bytes]（PNG/JPEG等）を幅[_kThumbWidth]に縮小してPNGで保存する。
  /// デコードできない形式は元のバイト列をそのまま保存する
  static Future<void> _writeScaled(Uint8List bytes, File out) async {
    try {
      final codec =
          await ui.instantiateImageCodec(bytes, targetWidth: _kThumbWidth);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (data != null) {
        await out.writeAsBytes(data.buffer.asUint8List());
        return;
      }
    } catch (_) {}
    await out.writeAsBytes(bytes);
  }

  /// 過去に元解像度のまま保存された大きなサムネイルを縮小する（一度だけ）
  Future<void> shrinkIfLarge(String thumbPath) async {
    try {
      final f = File(thumbPath);
      if (!await f.exists() || await f.length() <= _kShrinkThresholdBytes) {
        return;
      }
      await _writeScaled(await f.readAsBytes(), f);
    } catch (_) {}
  }

  // ext: 拡張子（ドット無し・小文字。例: "pdf"）。呼び出し側(scanFolder結果)で
  // 既に判明している値を渡す。AndroidではfilePathがcontent:// URIになり、
  // 文字列末尾一致でのフォーマット判定に頼るのは本来避けたいため
  Future<String?> generateThumbnail(
      String filePath, String bookId, String ext) async {
    try {
      final cacheDir = await getApplicationSupportDirectory();
      final thumbDir =
          Directory(p.join(cacheDir.path, 'dolce', 'thumbnails'));

      if (!await thumbDir.exists()) {
        await thumbDir.create(recursive: true);
      }

      final thumbPath = p.join(thumbDir.path, '$bookId.png');
      final thumbFile = File(thumbPath);

      if (await thumbFile.exists()) return thumbPath;

      if (ext == 'pdf') {
        return await _generatePdfThumbnail(filePath, thumbFile, thumbPath);
      } else if (ext == 'epub') {
        final file = await FileService.materializeLocalFile(filePath);
        final epub = await EpubService.open(file.path);
        final cover = epub.coverBytes();
        if (cover != null) {
          await _writeScaled(cover, thumbFile);
          return thumbPath;
        }
      } else if (ext == 'cbz' || ext == 'zip') {
        final file = await FileService.materializeLocalFile(filePath);
        final stream = InputFileStream(file.path);
        try {
          final archive = ZipDecoder().decodeStream(stream);
          final imageFiles = archive.files.where((f) {
            final name = f.name.toLowerCase();
            return f.isFile &&
                (name.endsWith('.jpg') ||
                    name.endsWith('.png') ||
                    name.endsWith('.jpeg'));
          }).toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          if (imageFiles.isNotEmpty) {
            await _writeScaled(
                Uint8List.fromList(imageFiles.first.content as List<int>),
                thumbFile);
            return thumbPath;
          }
        } finally {
          await stream.close();
        }
      }
    } catch (e) {
      print('[Thumbnail] 致命的エラー: $e');
    }
    return null;
  }

  Future<String?> _generatePdfThumbnail(
      String filePath, File thumbFile, String thumbPath) async {
    // pdfrxでPDFの1ページ目をレンダリングする（poppler-utilsに依存せず
    // Android/Windows/Linux含む全プラットフォームで動作する）
    PdfDocument? document;
    try {
      final file = await FileService.materializeLocalFile(filePath);
      document = await PdfDocument.openFile(file.path);
      final first = document.pages.first;
      final bytes = await renderPdfPagePng(first,
          scale: _kThumbWidth / first.width);
      if (bytes == null) return null;
      await thumbFile.writeAsBytes(bytes);
      return thumbPath;
    } catch (e) {
      print('[Thumbnail] PDF表紙生成エラー: $e');
      return null;
    } finally {
      await document?.dispose();
    }
  }
}
