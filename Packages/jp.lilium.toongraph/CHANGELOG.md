# Change Log

## [Unreleased]
- URP のデカール（Decal Projector・DBuffer 方式）に対応。トゥーンの陰影を計算する前に、デカールの色・法線・金属/AO/滑らかさを塗り込む（Toon Lighting の両方のランプ）。URP Lit ターゲットが自分でもデカールを塗って PBR で照らし、Emission のトゥーン結果に足されてしまうので、ランプのファイルの末尾で `_DBUFFER` を消して止めている。使うにはレンダラーに Decal Renderer Feature（Technique = DBuffer）を足す。半透明（Toon (Transparent)）は URP の仕様でデカールを受けない。アウトラインには塗らない

## [0.8.0-pre.1] - 2026-10-02
- Forward+ で点光源・スポットライト（と反射プローブ）がカメラの位置によって当たったり消えたりしていたのを修正。Toon Lighting サブグラフが渡す Screen Position（0〜1 に正規化済み）を画素の座標とみなしてさらに画面サイズで割っていた（TextureRamp は未設定の値から作っていた）ため、どの画素も画面の隅の区画の光の一覧を引いていた。正規化済みの値をそのまま使うようにした
- Forward+ で追加のディレクショナルライトが当たらなくなっていたのを修正。URP 6.1 で `USE_FORWARD_PLUS` が `USE_CLUSTER_LIGHT_LOOP` に改名され、旧名が未定義になってディレクショナルライトのループが丸ごと消えていた（ライトレイヤーで分けたディレクショナルライトも効かない状態だった）。新しい名前に合わせ、旧 URP 向けの読み替えを `ClusterLightLoopCompat.hlsl` に置いた
- SSS が出る境目を 0.3333 から 0.5 にした
- 直接光の影の境目と SSS の境目をプロジェクト設定で変えられるようにした（Project Settings > Graphics > URP の Lilium Toon。既定は直接光 0.1・SSS 0.5）。`LiliumToonSettings` の値を毎フレーム `_ToonShadeThreshold` / `_ToonSubsurfaceThreshold` としてグローバルへ入れる
- Occlusion の掛け方を変更。直接光は SSS を含めた結果に掛け、間接光（GI）には半分だけ効かせる（GI の関数側では掛けない）
- `UniversalFragmentPBR_Toon` に outlineColor（間接光の色）の出力を追加。Toon Lighting (SmoothstepRamp) の ShadeColor はこれを返す
- 使われていなかった BlinnPhong / BakedLit 用のライティング関数を削除
- アウトラインの変換で `unity_ObjectToWorld` の代わりに `UNITY_MATRIX_M` を使うようにした
- ToonOutlineRenderFeature に Width Scale を追加。アウトラインの太さをマテリアルごとの Outline Width に掛ける倍率で、レンダラーの設定から全体をまとめて調整できる（グローバル `_ToonOutlineWidthScale` をアウトラインのパスの間だけ入れ、OutlineTransform.hlsl の 4 つの変換が読む）

## [0.7.0-preview.1] -
- Unity6
- UniversalRP v17
- Forward Plus
- 

## [0.6.0-preview.x] -
- Unity2021.2.0b14
- UniversalRP v12.0.0
- Occlusion周りの色計算を修正
- Shadow Shiftを追加
- Lighting Environment UIを追加
- 追加ライトの距離減衰のトゥーン化
- SSSの色計算を変更
- 影内のSSSの影響を調整できるように
- Toon Outline Transform Scaled Max Distance サブグラフの修正
- Toon Outline Transform Scaled Max Distance (Screen Space) を追加

## [0.5.0-preview.5] - 2021 - 02 - 25
- Unity2020.2.6f1
- UniversalRP v10.3.1
- Outline Widthを削除し、代わりにOutline Positionスロットを追加。手動によるMasterStackとグラフの再構築作業が必要です。
- SSS Curvatureによる色計算の変更。
- Outline Transformサブグラフを数種類追加。
- Shade Shiftの影響を修正。
- ライトマップで使うとエラーが発生する不具合を修正。

## [0.4.0-preivew.1] - 2020 - 12 - 29
- Custom UniversalRPパッケージを削除。
- ToonTargetのkSourceCodeGuidを変更。すべてのShaderGraphでTargetの再追加作業が必要。

## [0.3.0-preivew.11] - 2020 - 12 - 16
- Unity2020.2.0
- UniversalRP v10.2.2 
- ShaderGraphのMasterStackに対応。
- 影色計算をSSSベースに変更。
- SSS用曲率を設定するためのCurvatureスロットを追加。
- 影色を取得するためのShadeColor出力スロットを追加。
- ToonLightingノードのShadeスロットを廃止。代わりにSSSスロットを追加。
- ToonStylizingサブグラフを追加。
- Lighting Environentを追加。
- Stylized Input系ShaderGraphを一旦削除。

## [0.2.2-preivew.8] - 2020 - 08 - 09

- Unity2020.1.1
- サブシェーダの入力型の改善
- 影色計算の変更
- ヘアシェーダーを追加

## [0.2.1-preview.7] - 2020 - 07 - 28

- Unity2020.1.0
- UniversalRP v8.2.0
- スペキュラの強さと色の調整
- 影色はカメラが向いている方向に影響される
- 透明なマテリアルのサポートを追加

## [0.2.0-preview.2] - 2020 - 07 - 23

- Unity2020.1.0b16
- UniveralRP v8.1.0
- プロパティリファレンス名をUnity標準に合わせる
- スペキュラ色計算
- メタリックセットアップをディフォルトに
- RampTextureのサポート
- 影色のサポート