# dolce

> 本と、二人きり

PDF・CBZ・EPUB の電子書籍/コミックを、ローカルで管理して読める Flutter 製のクロスプラットフォームリーダーです。クラウド同期はなく、データは端末の中だけに保存されます（[プライバシー](PRIVACY.md)）。

対応OS: Android / Windows / Linux（macOS は CI でビルドのみ）

## 機能

- **形式**: PDF / CBZ / EPUB（EPUB はリフロー表示）
- **本棚**: フォルダを登録すると階層のまま一覧表示。サムネイル表示、検索、お気に入り、複数選択、F5（パスバーの更新ボタン）で再スキャン
- **ビューア**: 左右タップ/キーでページ送り、ページ方向の切り替え、ズーム、自動ページめくり（秒数は再生ボタン長押しで選択・自由入力）
- **目次・リンク**: PDF/EPUB の目次と、書籍内リンクのジャンプ
- **タブ**: 複数タブ、タブ内の戻る/進む履歴
- **見た目**: 版画風UI（太い枠と硬い影）。アクセント色はプリセット10色かカラーコードで指定でき、気に入った色は＋でプリセットに登録できます。日本語/英語

## インストール

[Releases](https://github.com/rhing-official/dolce/releases) から取得します。

| OS | ファイル |
|---|---|
| Windows | `dolce-windows.zip` / `*.msix` |
| Linux | `dolce-linux-x86_64.AppImage` |
| Android | `dolce-android.apk` |
| macOS | `dolce-macos.zip` |

### Linux (AppImage)

```bash
chmod +x dolce-linux-x86_64.AppImage
./dolce-linux-x86_64.AppImage
```

FUSE が無い環境では、展開して実行します。

```bash
./dolce-linux-x86_64.AppImage --appimage-extract-and-run
```

## 主なキー操作

| キー | 動作 |
|---|---|
| `←` / `→` | 前/次ページ |
| `Space` | メニュー表示切り替え |
| `T` | 目次 |
| `P` | 自動ページめくりの開始/停止 |
| `Ctrl+F` | 検索 |
| `Ctrl+B` | お気に入り |
| `Ctrl+I` | 設定 |
| `F1` | 情報 |
| `F5` | 本棚の更新 |
| `Ctrl+T` / `Ctrl+W` | タブを開く/閉じる |

全一覧は [CLAUDE.md](CLAUDE.md) のキー操作表を参照してください。

## ビルド

Flutter（Dart SDK `>=3.0.0 <4.0.0`）が必要です。

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs  # Hiveのアダプタ生成
flutter gen-l10n                                                  # 文言(ja/en)の生成
flutter run -d linux     # / windows / android
flutter test
```

Linux の AppImage は、`flutter build linux --release` のあとに `scripts/build-appimage.sh` で作れます（`appimagetool` が必要）。リリースは `v*` タグの push で GitHub Actions が各OSの成果物を作ります。

## 開発メモ

構成・設計上の注意は [CLAUDE.md](CLAUDE.md)、開発の記録は [日記.md](日記.md) にあります。
