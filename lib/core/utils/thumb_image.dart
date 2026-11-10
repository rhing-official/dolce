import 'dart:io';
import 'package:flutter/widgets.dart';
import '../widgets/skeleton.dart';

/// 一覧・カード用のサムネイル。表示サイズは小さいのに元画像を全解像度で
/// デコードするとメモリとデコード時間を大量に消費するため、デコード時に縮小する。
/// precacheImageと表示側で同じProviderを使うとキャッシュキーが一致する
ImageProvider thumbProvider(String path) =>
    ResizeImage(FileImage(File(path)), width: kThumbDecodeWidth);

const int kThumbDecodeWidth = 300;

/// サムネイルのデコード中はスケルトンを出し、画像が届いたらフェードインする
/// `Image.frameBuilder`。画像が固定サイズの時は[width]/[height]を同じに渡す
/// （省略時は親の制約いっぱいに広がる）。キャッシュ済みで同期的に読めた時は
/// 何も挟まない
ImageFrameBuilder thumbFrameBuilder({double? width, double? height}) =>
    (context, child, frame, wasSynchronouslyLoaded) {
      if (wasSynchronouslyLoaded) return child;
      if (frame == null) {
        return SizedBox(
            width: width ?? double.infinity,
            height: height ?? double.infinity,
            child: const SkeletonBox());
      }
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 180),
        builder: (_, opacity, child) => Opacity(opacity: opacity, child: child),
        child: child,
      );
    };
