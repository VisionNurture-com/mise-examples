# 006-team — 期待する観測

同じ設定を渡された別のマシンで、同じものが入るか。

| キー | 期待値 | 何を確かめたか |
|---|---|---|
| `lockCreatedWhenEnabled` | true | `[settings] lockfile = true` を書くと `mise.lock` が生まれる |
| `lockCreatedWhenNotEnabled` | false | 🔴 **書かないと生まれない**。既定では版は固定されない |
| `localOverrides` | true | `mise.local.toml` が共有設定（`mise.toml`）を上書きする |
| `readableWithoutTrust` | false | `[env]` を含む設定は、信頼していないと**読めずに止まる** |
| `readableWithTrustedPath` | true | 信頼するパスを宣言すると、確認なしで読める |
| `signedInstallSucceeds` | true | 署名済みマニフェスト（`packslip:`）から入る |
| `unapprovedStamperBlocks` | true | 🔴 **承認していないスタンパーを要求すると、インストールが止まる** |
| `toolVersionsRead` | 1 | asdf 互換の `.tool-versions` は設定なしで読まれる |
| `naiveSeesParent` | true | 遮らずに測ると親ディレクトリの設定が届く |

## lockfile が守る範囲

`mise.lock` に載るのは **`[tools]` に書いたものだけ**である。
実行した人のホームの設定から入ってくる道具は、lockfile では固定されない。
「lockfile を置いたから全員同じ」とは言えない。

## 署名と承認は別の層

`packslip:` は**発行者の署名**を確かめる。`packslip.stampers` はそれに加えて
**「誰が承認したか」**を要求する。承認の指定に実体が無ければ、
mise はインストールを進めずに止まる（実測でエラー終了した）。

## 測るときの注意

署名検証そのものを通すため、**測る前に毎回アンインストールする**。
入ったままだと `already installed` で終わり、検証が走らない。
lockfile も同様に、前回の `mise.lock` を消してから測る。
