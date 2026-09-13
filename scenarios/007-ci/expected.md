# 007-ci — 期待する観測

CI で mise を使うときに効いてくる 3 点。

| キー | 期待値 | 何を確かめたか |
|---|---|---|
| `secondInstallIsNoop` | true | 2 回目の `install` は入れ直さない（`already installed`）。キャッシュが効く前提 |
| `readableWithoutTrust` | false | 🔴 **信頼していない設定は読めずに止まる**。対話できない CI では、これがそのまま失敗になる |
| `readableWithDeclaredPath` | true | 信頼するパスを宣言しておけば、確認なしで読める |
| `envReachesTask` | true | `[env]` の値がタスクの実行時に渡っている |
| `naiveSeesParent` | true | 遮らずに測ると親ディレクトリの設定が届く |

## jdx/mise-action そのものについて

action 自体は、**このリポジトリの `.github/workflows/verify.yml` が毎回の CI で
実際に使っている**。ここで測っているのは、その action の内側で起きることのほうである。

## 対話できない環境で最初に踏むもの

手元では `mise trust` を 1 回打てば済む。CI では打てない。
`readableWithoutTrust` が false であることが、その落とし穴を示している。

## 🔴 action が黙って環境を変えている

`jdx/mise-action` は、実行の前に**ワークフローの環境変数を書き換える**。
CI のログに次の 2 つが出る。

```
MISE_TRUSTED_CONFIG_PATHS: /home/runner/work/mise-examples/mise-examples
MISE_YES: 1
```

🔴 **信頼の確認を飛ばす条件が 3 つ重なっている。**

| きっかけ | 何が起きるか | 誰が立てるか |
|---|---|---|
| `MISE_TRUSTED_CONFIG_PATHS` | そのパスの下を**信頼済みとして扱う** | action |
| `MISE_YES=1` | **確認そのものを省く** | action |
| 🔴 **`CI`** | **立っているだけで確認を省く** | CI サービスがほぼ必ず立てる |

実測（mise v2026.9.4・macOS）で、同じディレクトリに対して次の差が出た。

| 実行 | 結果 |
|---|---|
| 素 | 止まった（`not trusted`）|
| `CI=true` | **読めた** |
| 素（直後に再実行）| 止まった（前の実行で信頼済みになったわけではない）|
| **`CI=false`** | 🔴 **読めた** |
| `CI=1` | 読めた |

**`CI` は値を見ていない。立っているかどうかだけを見ている**（`CI=false` でも省かれる）。

⚠️ **この挙動は公式ドキュメントに記述を見つけられなかった**（`mise trust` のページには
CI についての記載がない）。**実測にもとづく観測**として扱うこと。

これは「手元では trust を聞かれるのに CI では何も起きない」という体感の差であると
同時に、**外から来た設定ファイルが確認なしに読まれる**ということでもある。

このシナリオは、その差に引きずられないよう、
**信頼していない状態を測る 1 回だけ、2 つとも明示的に外している**。
外さずに測ると CI では `readableWithoutTrust` が true になり、手元と食い違う
（実際に 2 度そうなって CI が落ちた）。
