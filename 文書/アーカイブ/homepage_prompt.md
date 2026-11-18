# dolce 紹介ページ 現状反映の依頼

このリポジトリ（HomePage-Rhing）に、dolce の紹介ページ `src/app/services/dolce/page.tsx` が既にあります。内容が古いので、**現状の dolce に合わせて更新**してください。作り直しではなく、既存の構成・部品・文体を活かした改修です。

まず `CLAUDE.md`（特に「文章の書き方」「素材・アセット」）と `文書/実装内容チェックリスト.md`、既存の `src/app/services/dolce/`、`src/app/services/daidai/page.tsx`、`src/components/ui/CtaCard.tsx`、`src/components/EnvironmentList.tsx` を読んでから着手してください。dolce 本体のソースはここに無いので、機能の事実は下記のみを根拠にし、書かれていない機能は足さないでください。

## dolce の現状（v1.4.1、2026-11 時点）

- キャッチコピー: **「本と、二人きり」**（旧「本と、甘美な贅沢を。」は廃止）
- PDF・CBZ・EPUB の電子書籍/コミックを、ローカルで管理して読める、クロスプラットフォームリーダー
- 対応OS: Android / Windows / Linux。macOS は CI でビルドのみ。iOS は未対応
- クラウド同期なし。データは端末の中だけに保存。ネット接続不要。ここが最大の訴求点
- 配布は **GitHub Releases のみ**: https://github.com/rhing-official/dolce/releases
  - Windows: `dolce-windows.zip` / `*.msix`
  - Linux: `dolce-linux-x86_64.AppImage`
  - Android: `dolce-android.apk`
  - macOS: `dolce-macos.zip`
- Microsoft Store と Flathub では配布していない。ページに載せない
- 見た目: 版画風UI（太い枠と硬い影）。アクセント色はプリセット10色かカラーコード（#RRGGBB）で指定でき、気に入った色は＋でプリセットに登録できる。表示言語は日本語/英語

## 直すべき点

1. **キャッチコピー**: ヒーロー、`metadata.title/description` を「本と、二人きり」に合わせる。`description` に EPUB も入れる
2. **対応形式**: PDF・CBZ に加えて **EPUB**（リフロー表示）を追加する。カードは3枚になる。フッター注記のアカウント登録・クラウド同期が不要、の趣旨は維持
3. **機能紹介に足すもの**（既存の BOOKSHELF / ORGANIZE / VIEWER の節に混ぜるか、新しい節にする。一般向けに「できること」で書く）:
   - 目次（PDF/EPUB）と、書籍内リンクのジャンプ。目次はキー `T` でも開ける
   - 自動ページめくり（再生ボタン、長押しで秒数を選べる、キー `P`）
   - 本棚: フォルダを登録すると階層のまま一覧。サムネイル、検索、複数選択、`F5` で再スキャン
   - 本の並び順: 巻数情報が全冊に有る時は巻数順、無ければタイトルの自然順
   - 同じフォルダの前後の本へ移る操作と、最終ページで「次の本を開く」
   - 版画風UIとアクセント色の設定、日本語/英語
4. **キー操作の表**: 主要なものだけを一覧にして載せる（`←` `→` / `Space` / `T` / `P` / `Ctrl+F` / `Ctrl+B` / `Ctrl+I` / `F1` / `F5` / `Ctrl+T` / `Ctrl+W`）。既存の「キーボードショートカット」の箇条書きから、この表へ誘導してよい
5. **ダウンロード**: 「対応プラットフォーム」カードの Android / Windows / Linux / macOS に、Releases への導線を付ける（`Platform.url` は既に対応済み）。各OSの取得ファイル名を添える。Linux には AppImage の実行手順（`chmod +x` のあと実行。FUSE が無い環境は `--appimage-extract-and-run`）を短く載せる。macOS は「配布はあるが動作確認の環境が無い」旨を正直に書く。iOS は対応予定のまま
6. **動作確認環境**（`EnvironmentList`）: 現状は 2026/9/15 時点の Windows 11 / Zorin OS 18 / Android 16。dolce は v1.4.1 まで更新されているので、日付が古いことを最終報告で指摘する（勝手に日付を更新しない）
7. **「これからのdolce」**: iOS・macOS の記述はそのまま。Microsoft Store や Flathub への言及は入れない
8. **サイトの他の箇所**: `/services` の一覧のカード説明、サイトマップ、`文書/実装内容チェックリスト.md` に dolce の説明文が有れば、同じ内容に直す

## 維持するもの

- 既存のモバイル専用UI（ナビゲーションピル、タブ一覧グリッド、右スワイプ、ハンバーガーメニュー）の節。ここに書かれた内容は事実として維持する
- 既存のレイアウト、`CtaCard`、`EnvironmentList`、目次（CONTENTS）、GitHub / GitDiagram のカード
- ロゴ（`public/logos/dolce.png`、`public/downloads/logos/dolce.zip`）
- 3つの柱（ローカル完結 / クロスプラットフォーム / 迷わない操作性）。文言は現状に合わせて微修正してよい

## スクリーンショット

- 実機の画像は用意しない。`[SCREENSHOT: 説明]` のプレースホルダ（`ScreenshotPlaceholder`）を使い続ける。**画像を自分で生成・撮影・加工しない**
- 既存の7箇所は維持する。新しい節に画像が要る場合だけ、プレースホルダを増やす
- プレースホルダを増やした場合は、`文書/スクリーンショット撮影リスト.md` にも撮影項目を追記する
- 参考: dolce リポジトリの `docs/screenshots/main.png` に既存の1枚が有る（`/home/arata/Rhing/Applications/dolce/docs/screenshots/main.png`）。使うかどうかは、使う前に私に確認する

## 文章のルール（CLAUDE.md の「文章の書き方」に従う）

- 括弧は、読み仮名・固有名の併記・コード/技術名の併記以外では使わない
- 日本語は、文法を崩さない範囲で漢字を使う（出来る・為・有る・無い。形式名詞は平仮名）
- 一般向けの文面に外部サービス名や専門用語を出さない。EPUB・PDF・CBZ・AppImage などの形式名・配布物名は、ここでは必要なので使ってよい
- カードの本文は左揃え。長い説明はカードに詰めず、別の節に回す
- 既存の文言の一括書き換えはしない。この依頼で触れる箇所だけ直す

## 進め方・完了条件

- 変更前に、現状との差分と作業方針を短く報告する
- `npm run lint` と `npx tsc --noEmit`、`npm test`（vitest）が通ること。`npm run dev` で `/services/dolce` を開いて目視確認する
- コミットとプッシュは、確認を取ってから行う（`/diary` 経由を除く）
- 最終報告に、直した点、未対応の点（環境確認日の古さ、スクリーンショット未差し込みなど）、私が判断すべき点をまとめる
