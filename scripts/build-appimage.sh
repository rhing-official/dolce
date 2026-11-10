#!/usr/bin/env bash
# flutter build linux --release の出力から AppImage（dolce-linux-x86_64.AppImage）を作る。
# 使い方: scripts/build-appimage.sh  （リポジトリルートで実行）
# 必要: appimagetool（PATH上。CIではダウンロードして置く）
set -euo pipefail

BUNDLE=build/linux/x64/release/bundle
APPDIR=build/AppDir
OUT=dolce-linux-x86_64.AppImage
APP_ID=io.github.rhing_official.dolce

[ -x "$BUNDLE/dolce" ] || { echo "先に flutter build linux --release を実行してください" >&2; exit 1; }

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
# Flutterのバンドルは実行ファイルと同じ階層のlib/・data/を相対参照する
cp -a "$BUNDLE/." "$APPDIR/usr/bin/"
cp "$APP_ID.desktop" "$APPDIR/$APP_ID.desktop"
cp dolce-icon-256.png "$APPDIR/$APP_ID.png"
# AppStreamのメタ情報（無いとappimagetoolが警告する）
mkdir -p "$APPDIR/usr/share/metainfo"
cp "$APP_ID.metainfo.xml" "$APPDIR/usr/share/metainfo/$APP_ID.appdata.xml"
ln -s "usr/bin/dolce" "$APPDIR/AppRun"

rm -f "$OUT"
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 appimagetool "$APPDIR" "$OUT"
echo "作成: $OUT"
