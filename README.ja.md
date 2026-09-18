<div align="center">

<img src="assets/icon.png" width="128" alt="PokeTaskBar アイコン">

# PokeTaskBar v1

**Linear の仕事とスコアが中心です。トークン使用量は脇役で、XP になります。**

[English](README.md) · [한국어](README.ko.md) · **日本語**

</div>

PokeTaskBar v1 は [spawnaudio/spawn-PokeTokenBar](https://github.com/spawnaudio/spawn-PokeTokenBar)（PokeTokenBar v3）から分岐した**新しい macOS アプリ**です。v3 の改名ではありません。

正本は **[英語 README](README.md)** です。

| | PokeTokenBar v3（そのまま） | **PokeTaskBar v1** |
|---|---|---|
| 表示名 | `PokeTokenBar v3` | **`PokeTaskBar v1`** |
| Bundle id | `io.github.chattymin.poketokenbar.v3` | **`io.github.spawnaudio.poketaskbar.v1`** |
| アプリ | `/Applications/PokeTokenBar v3.app` | `/Applications/PokeTaskBar v1.app` |
| セーブ | `~/Library/Application Support/PokeTokenBar v3` | `~/Library/Application Support/PokeTaskBar v1` |
| 再ビルド | `./scripts/rebuild-v3.sh` | **`./scripts/rebuild-v1.sh`** |

- Linear の Issue・Project・Focus・Today がメインループ
- トークン使用は 1:1 XP。**Token usage** ページだけ Tokens、他は XP
- `Coins = floor(XP / 1000)`。ショップは **Requires N Coins**
- ミントは 30 分間 XP 2 倍（性格のリロールではない）
- タマゴは預かり箱。買っても今のポケモンは手放さない。一度に 1 匹、いつでも交代
- 卒業したポケモンは育成不可、図鑑にトロフィー

本家の製品説明は [`Documents/original-PokeTokenBar/README.ja.md`](Documents/original-PokeTokenBar/README.ja.md) にあります。ライセンスと免責は [英語 README](README.md#license--disclaimer) に従います。
