# LiliumToonGraph (Experimental)

トゥーンシェーダーでもシェーダーグラフを使いたい！

+ URP対応トゥーンシェーダーです。
+ 表現の実験中。
+ ShaderGraphパッケージ及びUniversalRPパッケージ内のInternalクラスを利用します。前方互換性はほとんどないと思われます。
+ PBRマスターノードを改造する形で開発しました。まだ無駄なコードが残っています。
+ カスタムマスターノードのサンプルにどうぞ。ソースファイルの　`Toon` を `PBR` に変換してパッケージ内を検索すると元になったソースファイルが見つかります。Wikiの方にも書いています。 https://github.com/you-ri/LiliumToonGraph/wiki

![](https://github.com/you-ri/LiliumToonGraph/blob/master/Docs/screenshot.png?raw=true)


## System requirements

+ Unity 2019.3.0b7

## How to use

### Exsample Scene
Assets/Lilium/Toon/Exsample/ToonExsample.unity

### Toon shader graph
1. Right click in the project window.
2. Select `Create > Shader > Toon Graph`

## Licenses

MIT

"Assets/UnityChan", "Assets/UnityHDRI", "Assets/DanishStatues" and "Packages" Folders License below to their licenses.
