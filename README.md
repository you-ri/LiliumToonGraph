# LiliumToonGraph (Experimental)

トゥーンシェーダーでもシェーダーグラフを使いたい！

![](https://github.com/you-ri/LiliumToonGraph/blob/master/Docs/screenshot.png?raw=true)

+ UniversalRP対応トゥーンシェーダーです。
+ UniversalRPのPBRライティングモデルを参考にカスタムファンクション上でトゥーンライティングモデルを実装してます。
+ アウトラインはToonマスターノードで実装しています。これはPBRマスターノードを改造する形で開発しました。
+ 表現の実験中。PBRと親和性の高いトゥーンシェーダーを目指しています。
![](https://i.imgur.com/uvc6CwX.gif)
+ カスタムマスターノードのサンプルにどうぞ。ソースファイルの　`Toon` を `PBR` に変換してパッケージ内を検索すると元になったソースファイルが見つかります。Wikiの方にも書いています。 https://github.com/you-ri/LiliumToonGraph/wiki
+ URP7.2.1

アウトライン機能に[Render Feature](https://github.com/Unity-Technologies/UniversalRenderingExamples)を使わない理由はアウトラインの色をライティングによって変化させたいからです。Render Featureでこれらの機能が実装できれば、マスターノードを改造しなくてよくなるのだけど。。。

旧LWRPマスターノードでトゥーンライティングモデルを実装しているバージョンは[こちら](https://github.com/you-ri/LiliumToonGraph/tree/lwrp)

旧URPマスターノードでトゥーンライティングモデルを実装しているバージョンは[こちら](https://github.com/you-ri/LiliumToonGraph/tree/urp-master-node-toon)

## System requirements
+ Unity 2019.3.06f or later

## How to use

### Exsample Scene
Assets/LiliumToonGraph/Sample/ToonSample.unity

### Toon shader graph
1. Right click in the project window.
2. Select `Create > Shader > Toon Graph`

## Licenses

MIT

"Assets/UnityChan", "Assets/DanishStatues" and "Packages" Folders License below to their licenses.

© Unity Technologies Japan/UCL
