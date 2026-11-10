import 'dart:io';
import 'package:flutter/painting.dart';

/// 一覧・カード用のサムネイル。表示サイズは小さいのに元画像を全解像度で
/// デコードするとメモリとデコード時間を大量に消費するため、デコード時に縮小する。
/// precacheImageと表示側で同じProviderを使うとキャッシュキーが一致する
ImageProvider thumbProvider(String path) =>
    ResizeImage(FileImage(File(path)), width: kThumbDecodeWidth);

const int kThumbDecodeWidth = 300;
