import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolce/core/utils/thumb_image.dart';
import 'package:dolce/core/widgets/skeleton.dart';

// 画像が届くまでスケルトンを出し、届いたら画像に置き換わることの確認
class _SlowImage extends ImageProvider<_SlowImage> {
  final Completer<ui.Codec> completer;
  _SlowImage(this.completer);

  @override
  Future<_SlowImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
          _SlowImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
          codec: completer.future, scale: 1.0);
}

void main() {
  testWidgets('thumbFrameBuilderはデコード前はスケルトン、後は画像', (tester) async {
    final completer = Completer<ui.Codec>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SkeletonScope(
          child: SizedBox(
            width: 100,
            height: 140,
            child: Image(
              image: _SlowImage(completer),
              fit: BoxFit.cover,
              frameBuilder: thumbFrameBuilder(),
            ),
          ),
        ),
      ),
    ));
    expect(find.byType(SkeletonBox), findsOneWidget);
    expect(find.byType(RawImage), findsNothing);

    // 1x1の透明PNGをデコードして届ける
    final png = base64Decode1x1();
    completer.complete(await tester.runAsync(() => ui.instantiateImageCodec(png)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SkeletonBox), findsNothing);
    expect(find.byType(RawImage), findsOneWidget);
  });
}

// 1x1の赤いPNG
Uint8List base64Decode1x1() => Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0, 0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
