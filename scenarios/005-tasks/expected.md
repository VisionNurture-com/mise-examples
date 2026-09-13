# 005-tasks — 期待する観測

`[tasks]` の 6 つの書き方が、それぞれ何を変えるか。

| キー | 期待値 | 何を確かめたか |
|---|---|---|
| `order` | PREPARE,MAIN,CLEANUP | `depends` は**前**に、`depends_post` は**後**に走る |
| `fileTaskRuns` | true | `mise-tasks/` に置いた実行ファイルが、設定に書かなくてもタスクになる |
| `timeoutFires` | true | `timeout = "1s"` の指定で、5 秒かかる処理が**打ち切られて失敗する** |
| `usageArgPassed` | true | `usage` で宣言した引数が `$usage_name` として受け取れる |
| `firstRunBuilds` | true | 1 回目は実行される |
| `secondRunSkips` | true | 2 回目は `sources` が変わっていないので**飛ばされる** |
| `naiveSeesParent` | true | 遮らずに測ると親ディレクトリの設定が届く |

## make との違いが出るところ

`sources` / `outputs` を書くと、**入力が変わっていなければ実行を飛ばす**。
make と同じ考え方だが、宣言する場所が `mise.toml` の中にあり、
ツールのバージョン・環境変数・タスクが 1 つのファイルに並ぶ。

## 測るときの注意

差分実行は **2 回続けて走らせないと観測できない**。また、前回の出力（`dist/`）が
残っていると 1 回目から飛ばされるため、測る前に消す。
