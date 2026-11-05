---
name: drawio
description: draw.io (.drawio) の図を作る・直すときの手順とルール。構成図・フロー図・AWS構成図などを .drawio で作成/編集するとき、図の見た目を確認するとき、PNG に書き出すときに使う。
---

# draw.io の図を作る・直す

`.drawio` は mxGraph の XML。**XML を直接、最小限だけ書き換える**（生成スクリプトを作って丸ごと作り直さない。Git の差分が読みやすくなる）。

## 手順

1. 既存の図を直すときは、まず `.drawio` を読み、今の PNG（`<name>.drawio.png`）があれば Read で見て配置を把握する。
2. 下の「ルール」に沿って XML を書く・直す。座標は書く前に計算する（アイコンの左上・幅・高さ、矢印の通り道、ラベルの位置）。
3. チェックする:
   ```bash
   python3 scripts/drawio-validate.py <file>.drawio
   ```
   ERROR はすべて直す。
4. PNG にして **Read で画像を見て確認する**（必須。XML だけ見て「できた」と言わない）:
   ```bash
   node scripts/drawio-render.js <file>.drawio /tmp/review.png --scale 1
   ```
   ビューアが無いと言われたら `bash scripts/setup-drawio-viewer.sh` を先に実行する。
   確認すること: 文字と矢印・図形の重なり、矢印が文字の上を通っていないか、意図しない改行、はみ出し、ラベルがどの矢印のものか分かるか。
5. 問題があれば 2 に戻る。問題がなくなるまで繰り返す。
6. コミットすると `.githooks/pre-commit` が、チェック・`<name>.drawio.png`・`<name>.drawio.url.txt`（app.diagrams.net で開くURL）の作成を自動で行う。
   フックが無効なら `git config core.hooksPath .githooks` で有効にする。

## ルール

### 文字
- `mxGraphModel` に `defaultFontFamily="Noto Sans JP"` を付ける。**それだけでは PNG に反映されないので、文字を持つすべての要素（図形・矢印・グループ・テキスト）の style に `fontFamily=Noto Sans JP;` を書く。**
- 文字サイズはこのリポジトリの標準: タイトル 16 / アイコン名 13（太字）/ グループ名 12 / 矢印ラベル 11。
- 折り返しを許す要素（`whiteSpace=wrap`）は幅を十分に取る。目安: 日本語 1 文字 = 文字サイズと同じ px、英数字 = 0.6 倍。折り返させたくない文字は `whiteSpace=wrap` を付けない。

### 矢印
- **矢印（`edge="1"`）は XML で図形より先に書く**（同じ親の中で）。XML の順番が描画の順番なので、矢印が最背面になる。
- つなぎ先は必ず `source` / `target` で指定する（座標だけで置かない）。ただし文字だけの要素（`text;`）につなぐと `exitX` などが効かないことがあるので、そのときは `sourcePoint` / `targetPoint` で座標を書く。
- 他の図形やその名前の上を通らないようにする。通りそうなら、出る位置（`exitX`/`exitY`）と経由点（`<Array as="points">`）でう回させる。アイコン名は下に出るので、**アイコンの下辺から矢印を出すと名前の上を通る**点に注意。
- **ラベルは矢印の線から 20px 以上離す。** `<mxPoint y="-28" as="offset"/>`（1行）/ `y="-36"`（2行、11px のとき）で線の上側に置く。ラベルの位置を線に沿って動かすときは `mxGeometry` の `x`（-1〜1）か offset の `x` を使う。
- 流れが分かるようにラベルに番号（①②…）を付ける。補助的な流れ（ログなど）は `dashed=1`。

### グループ（AWS Cloud / Region / VPC など）
- `container=1` にし、中の要素は `parent` をグループにして**座標はグループからの相対位置**で書く（draw.io で枠ごと動かせる）。
- 矢印は `parent="1"` にして、経由点（`points`）は**ページ上の絶対座標**で書く。
- 枠の線をラベルがまたがないよう、枠の外と中で十分な余白を取る。

### その他
- 背景色は付けない。`page="1"` のままでよい。
- AWS アイコンの書き方と色: [references/aws-icons.md](references/aws-icons.md)

## 仕上げのチェックリスト（報告の前に全部確認する）

- [ ] `drawio-validate.py` が OK（ERROR なし）
- [ ] 全テキスト要素に `fontFamily` がある
- [ ] 矢印が図形より先に書かれている（最背面）
- [ ] PNG を Read で見て、文字と矢印・図形の重なりがない
- [ ] 矢印ラベルが線から 20px 以上離れていて、どの矢印のものか分かる
- [ ] 日本語の意図しない改行・はみ出しがない
- [ ] 報告では、PNG で確認したかどうかをはっきり書く（確認できなかったらそう書く）
