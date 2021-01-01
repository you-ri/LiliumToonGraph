# LiliumToonGraph (Experimental)

トゥーンシェーダーでもシェーダーグラフを使いたい！

![](https://github.com/you-ri/LiliumToonGraph/blob/master/Docs/screenshot.png?raw=true)

+ UniversalRP対応トゥーンシェーダーです。
+ アウトラインはマスタースタックの `Lilium Toon` ターゲットで実装しています。これは `Universal` ターゲットを改造する形で開発しました。
+ 表現の実験中。PBR環境と親和性の高いトゥーンシェーダーを目指しています。
+ 開発中です。将来のバージョンで仕様が変わります。また実装には処理効率が悪い部分があります。
![](https://i.imgur.com/uvc6CwX.gif)


旧LWRPマスターノードでトゥーンライティングモデルを実装しているバージョンは[こちら](https://github.com/you-ri/LiliumToonGraph/tree/lwrp)

旧URPマスターノードでトゥーンライティングモデルを実装しているバージョンは[こちら](https://github.com/you-ri/LiliumToonGraph/tree/urp-master-node-toon)

## Dependenceis
+ Unity2020.2.0f1 or later
+ UniversalRP v10.2.x or later

## How to use

### Exsample Scene
Assets/Samples/ToonSample.unity

### Toon shader graph
1. Right click in the project window.
2. Select `Create > Shader > Universal Render Pipeline > Lilium Toon Shader Graph` or `Lit Shader Graph` or `Unlit Shader Graph`
3. Create node `Sub Graphs > ToonLighting (SmoothstepRamp)` or `Sub Graphs > ToonLighing (TextureRamp)`
4. Connect nodes.

See `Assets/Samples/ShaderGraphs/Toon.shadergraph`

## HDRP 偽装について

アウトラインの色をShaderGraphで制御できるようにするにはShaderGraphパッケージのInternalクラスにアクセスし、Master Stackの追加のターゲットを作成する必要があります。
アセンブリをHDRP(Unity.RenderPipelines.HighDefinition.Editor)に偽装することで、この問題を解決しています。

[Render Feature](https://github.com/Unity-Technologies/UniversalRenderingExamples)でアウトラインの色を制御する方法を見つけるか、もしくはカスタムターゲットが正式にサポートされるのを待っています。

## Reference

- [西川善司の「試験に出るゲームグラフィックス」（1）「GUILTY GEAR Xrd -SIGN-」で実現された「アニメにしか見えないリアルタイム3Dグラフィックス」の秘密，前編](https://www.4gamer.net/games/216/G021678/20140703095/)
- [【Unite Tokyo 2018】『崩壊3rd』開発者が語るアニメ風レンダリングの極意](https://www.slideshare.net/UnityTechnologiesJapan002/unite-tokyo-20183rd)
- [MToon](https://github.com/Santarh/MToon) Masataka SUMI
- [HDRI Heaven](https://hdrihaven.com/) Greg Zaal
- [Fast Subsurface Scattering for the Unity URP](https://johnaustin.io/articles/2020/fast-subsurface-scattering-for-the-unity-urp) JOHN AUSTIN

## Licenses

MIT

"Assets/UnityChan" Folders License below to their licenses.

© Unity Technologies Japan/UCL
