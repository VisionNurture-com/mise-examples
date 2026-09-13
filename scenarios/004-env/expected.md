# 004-env — 期待する観測

`[env]` の 7 つの書き方が、それぞれ何を変えるか。

| キー | 期待値 | 何を確かめたか |
|---|---|---|
| `basicSet` | true | `[env] GREETING = "hello"` がそのまま入る |
| `fileSet` | true | `_.file = ".env"` で `.env` の中身が入る |
| `pathAdded` | true | `_.path = ["./bin"]` でそのディレクトリが PATH に載る |
| `sourceSet` | true | `_.source = "./setup.sh"` でスクリプトの export が入る |
| `redactedInRun` | true | `redactions = ["*_KEY", ...]` を書くと `mise run` の出力で `API_KEY` が `[redacted]` になる |
| `plainInRun` | true | パターンに当たらない `PUBLIC_URL` は**そのまま出る**（マスクは対象を選ぶ）|
| `requiredFails` | true | `required = true` の変数が未設定だと mise が**エラーで止まる** |
| `envDefault` | base | `MISE_ENV` を指定しないと `mise.toml` の値 |
| `envProduction` | prod | `MISE_ENV=production` で `mise.production.toml` の値に切り替わる |
| `naiveSeesParent` | true | 遮らずに測ると親ディレクトリの設定が届く |

## `mise env --redacted` の読み違いに注意

`--redacted` は**マスクしない**。公式のヘルプがそう明記している。

> `--redacted` selects variables marked for redaction; **it does not mask their values.**

つまり `--redacted` は「どの変数がマスク対象になっているか」を選んで並べるための
フラグであって、値を隠すためのものではない。**値を隠すのは `mise run` の出力側**である。

## 測るときの注意

親の設定が届いているかは **ツール**で見る。`mise env` は環境変数しか出さないため、
ここで `mise env` を使うと親の `[tools]` を取りこぼす。
