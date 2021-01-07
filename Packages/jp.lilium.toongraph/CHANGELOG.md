# Change Log

## [0.4.1-preview.1]
- 変更：SSS Curvatureによる色計算を変更
- 修正：Shade Shiftの影響を修正

## [0.4.0-preivew.1] -2020-12-29
- 変更：Custom UniversalRP パッケージを削除。
- 変更：ToonTarget kSourceCodeGuid を変更。すべてのShaderGraphでTargetの再追加が作業が必要になります。

## [0.3.0-prevew.11] - 2020-12-16
- Unity2020.2.0
- URP 10.2.2 
- 変更：ShaderGraphのMasterStackに対応
- 変更：影色計算をSSSベースに変更
- 追加：SSS用曲率を設定するためのCurvatureスロットを追加
- 追加：影色を取得するためのShadeColor出力スロットを追加
- 変更：ToonLightingノードのShadeスロットを廃止。代わりにSSSスロットを追加
- 追加：ToonStylizingサブグラフを追加
- 追加：Lighting Environentを追加
- 変更：Stylized Input系ShaderGraphを一旦削除

## [0.2.2-preivew.8] - 2020 - 08 - 09

- Unity2020.1.1
- 変更：サブシェーダの入力型の改善
- 変更：影色計算の変更
- 追加：ヘアシェーダーを追加

## [0.2.1-preview.7] - 2020 - 07 - 28

- Unity2020.1.0
- UniversalRP v8.2.0
- 変更：スペキュラの強さと色の調整
- 変更：影色はカメラが向いている方向に影響される
- 追加：透明なマテリアルのサポートを追加

## [0.2.0-preview.2] - 2020 - 07 - 23

- Unity2020.1.0b16
- UniveralRP v8.1.0
- 変更：プロパティリファレンス名をUnity標準に合わせる
- 変更：スペキュラ色計算
- 変更：メタリックセットアップをディフォルトに
- 追加：RampTextureのサポート
- 追加：影色のサポート