# LiliumToonGraph

トゥーンシェーダーでもシェーダーグラフを使いたい！

+ LWRP 専用トゥーンシェーダーです。
+ ShaderGraphパッケージ内のInternalクラスを利用します。前方互換性は低いと思われます。
+ 絶賛開発中です。仕様変更も大いにあります。
+ PBRマスターノードを改造する形で開発しました。まだ無駄なコードが残っています。
+ HDRP 対応もできたらいいな。
+ カスタムマスターノードのサンプルにどうぞ。ソースファイルの　`Toon` を `PBR` に変換してパッケージ内を検索すると元になったソースファイルが見つかります。

![](https://imgur.com/bZlHaz0.png)


## System requirements

+ Unity 2019.1.0b8
+ Windows: Direct3D 11 support

## How to use

### Exsample Scene
Assets/Lilium/Toon/ToonExsample.unity

### Create toon shader graph
1. Projectウインドウで右クリック
2. Create > Shader > Toon Graph を選択

## Licenses

MIT

"Assets/UnityChan", "Assets/UnityHDRI", "Assets/DanishStatues" and "Packages" Folders License below to their licenses.
