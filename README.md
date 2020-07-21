# LiliumToonGraph (Experimental)

トゥーンシェーダーでもシェーダーグラフを使いたい！

![](https://github.com/you-ri/LiliumToonGraph/blob/master/Docs/screenshot.png?raw=true)

+ UniversalRP対応トゥーンシェーダーです。
+ UniversalRPのPBRライティングモデルを参考にカスタムファンクション上でトゥーンライティングモデルを実装してます。
+ アウトラインはToonマスターノードで実装しています。これはPBRマスターノードを改造する形で開発しました。
+ 表現の実験中。PBRと親和性の高いトゥーンシェーダーを目指しています。
![](https://i.imgur.com/uvc6CwX.gif)
+ カスタムマスターノードのサンプルにどうぞ。ソースファイルの`Toon`を`PBR`に変換してパッケージ内を検索すると元になったソースファイルが見つかります。Wikiの方にも書いています。 https://github.com/you-ri/LiliumToonGraph/wiki
+ URP8.1.0

アウトライン機能に[Render Feature](https://github.com/Unity-Technologies/UniversalRenderingExamples)を使わない理由はアウトラインの色をライティングで変化させたいからです。RenderFeatureでこれらの機能が実装できれば、マスターノードを改造しなくてよくなるのだけど。。。

旧LWRPマスターノードでトゥーンライティングモデルを実装しているバージョンは[こちら](https://github.com/you-ri/LiliumToonGraph/tree/lwrp)

旧URPマスターノードでトゥーンライティングモデルを実装しているバージョンは[こちら](https://github.com/you-ri/LiliumToonGraph/tree/urp-master-node-toon)

## System requirements
+ Unity 2020.1.0b16f or later

## How to use

### Exsample Scene
Assets/LiliumToonGraph/Sample/ToonSample.unity

### Toon shader graph
1. Right click in the project window.
2. Select `Create > Shader > Toon Graph`


## Reference

- [西川善司の「試験に出るゲームグラフィックス」（1）「GUILTY GEAR Xrd -SIGN-」で実現された「アニメにしか見えないリアルタイム3Dグラフィックス」の秘密，前編](https://www.4gamer.net/games/216/G021678/20140703095/)
- [【Unite Tokyo 2018】『崩壊3rd』開発者が語るアニメ風レンダリングの極意](https://www.slideshare.net/UnityTechnologiesJapan002/unite-tokyo-20183rd)
- [MToon](https://github.com/Santarh/MToon)

## Licenses

MIT

"Assets/UnityChan", "Assets/DanishStatues" and "Packages" Folders License below to their licenses.

© Unity Technologies Japan/UCL
