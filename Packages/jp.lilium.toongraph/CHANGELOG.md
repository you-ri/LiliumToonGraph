# Change Log

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