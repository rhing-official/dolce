import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:pdfrx/pdfrx.dart';

/// PDFの1ページを指定倍率でPNGにレンダリングする。
/// pdfrxのrender()は生のBGRAピクセルを返すため、Image.memory等で扱える
/// PNGへ変換する（pdfx時代のrender(format: png)と同じ戻り値に揃える）
Future<Uint8List?> renderPdfPagePng(PdfPage page, {double scale = 2}) async {
  final width = (page.width * scale).round();
  final height = (page.height * scale).round();
  final image = await page.render(fullWidth: width.toDouble(), fullHeight: height.toDouble());
  if (image == null) return null;
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(image.pixels);
    final descriptor = ui.ImageDescriptor.raw(buffer,
        width: image.width,
        height: image.height,
        pixelFormat: ui.PixelFormat.bgra8888);
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    return data?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// PDFの1ページを指定倍率で描画し、PNGへ再エンコードせずに`ui.Image`のまま返す。
/// PNGエンコード→Image.memoryでの再デコードは、ページ送りのたびに無駄な
/// 往復になるため、表示側はRawImageで直接描画する
Future<ui.Image?> renderPdfPageImage(PdfPage page, {double scale = 2}) async {
  final image = await page.render(
      fullWidth: (page.width * scale).roundToDouble(),
      fullHeight: (page.height * scale).roundToDouble());
  if (image == null) return null;
  final completer = Completer<ui.Image?>();
  try {
    ui.decodeImageFromPixels(
        image.pixels, image.width, image.height, ui.PixelFormat.bgra8888,
        (result) => completer.complete(result));
    return await completer.future;
  } finally {
    image.dispose();
  }
}
