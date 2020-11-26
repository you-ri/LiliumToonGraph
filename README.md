# LiliumToonGraph (Experimental)

トゥーンシェーダーでもシェーダーグラフを使いたい！

![](https://github.com/you-ri/LiliumToonGraph/blob/master/Docs/screenshot.png?raw=true)

+ UniversalRP対応トゥーンシェーダーです。
+ アウトラインはToonマスターノードで実装しています。これはPBRマスターノードを改造する形で開発しました。
+ 表現の実験中。PBRと親和性の高いトゥーンシェーダーを目指しています。
![](https://i.imgur.com/uvc6CwX.gif)

アウトライン処理のために改変したUniversalRPパッケージが必要になります。
[Render Feature](https://github.com/Unity-Technologies/UniversalRenderingExamples)を使わない理由はアウトラインの色をShaderGraph側で処理させたいからです。RenderFeatureでこれらの実装できれば、改変しなくてよくなるのだけど。。。

旧LWRPマスターノードでトゥーンライティングモデルを実装しているバージョンは[こちら](https://github.com/you-ri/LiliumToonGraph/tree/lwrp)

旧URPマスターノードでトゥーンライティングモデルを実装しているバージョンは[こちら](https://github.com/you-ri/LiliumToonGraph/tree/urp-master-node-toon)

## Dependenceis
+ Unity2020.2.0b12 or later
+ UniversalRP v10.2.0

## How to use

### Exsample Scene
Assets/Samples/ToonSample.unity

### Toon shader graph
1. Right click in the project window.
2. Select `Create > Shader > Toon Graph` or `Create > Shader > Unlit Graph` or `Create > Shader > PBR Graph`
3. Create node `Sub Graphs > ToonLighting (SmoothstepRamp)` or `Sub Graphs > ToonLighing (TextureRamp)`
4. Connect nodes.

See `Packages/Lilium ToonGraph/Contents/ShaderGraph/Toon (PBR Like Input)`

## Reference

- [西川善司の「試験に出るゲームグラフィックス」（1）「GUILTY GEAR Xrd -SIGN-」で実現された「アニメにしか見えないリアルタイム3Dグラフィックス」の秘密，前編](https://www.4gamer.net/games/216/G021678/20140703095/)
- [【Unite Tokyo 2018】『崩壊3rd』開発者が語るアニメ風レンダリングの極意](https://www.slideshare.net/UnityTechnologiesJapan002/unite-tokyo-20183rd)
- [MToon](https://github.com/Santarh/MToon)
- [HDRI Heaven](https://hdrihaven.com/)

## Licenses

MIT

"Assets/UnityChan" and "Packages/com.unity.render-pipelines.universal" Folders License below to their licenses.

© Unity Technologies Japan/UCL
