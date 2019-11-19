# LiliumToonGraph (Experimental)

トゥーンシェーダーでもシェーダーグラフを使いたい！

![](https://github.com/you-ri/LiliumToonGraph/blob/master/Docs/screenshot.png?raw=true)

+ [カスタムファンクション版](https://github.com/you-ri/LiliumToonGraph/issues/10)を開発中。こちらに移行します。
+ UniversalRP対応トゥーンシェーダーです。旧LWRP対応版は[こちら](https://github.com/you-ri/LiliumToonGraph/tree/lwrp)。
+ 表現の実験中。PBRと親和性の高いトゥーンシェーダーを目指しています。
![](https://i.imgur.com/uvc6CwX.gif)
+ ShaderGraphパッケージ及びUniversalRPパッケージ内のInternalクラスを利用します。前方互換性はほとんどないと思われます。
+ PBRマスターノードを改造する形で開発しました。まだ無駄なコードが残っています。
+ カスタムマスターノードのサンプルにどうぞ。ソースファイルの　`Toon` を `PBR` に変換してパッケージ内を検索すると元になったソースファイルが見つかります。Wikiの方にも書いています。 https://github.com/you-ri/LiliumToonGraph/wiki

## System requirements

+ Unity 2019.3.0b8

## How to use

### Exsample Scene
Assets/Lilium/Toon/Exsample/ToonExsample.unity

### Toon shader graph
1. Right click in the project window.
2. Select `Create > Shader > Toon Graph`

## Licenses

MIT

"Assets/UnityChan", "Assets/DanishStatues" and "Packages" Folders License below to their licenses.

© Unity Technologies Japan/UCL
