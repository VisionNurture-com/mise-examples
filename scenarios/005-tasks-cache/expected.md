# 005-tasks-cache — 期待する観測

`sources` / `outputs` で飛ばされるときに mise が何と言うか。出力を消したらどうなるか。

| キー | 期待値 | 何を確かめたか |
|---|---|---|
| `freshFirstBuilds` | true | 1 回目は走る |
| `freshSecondBuilds` | false | 2 回目は入力が変わらないので走らない |
| `freshSecondRuns` | false | コマンド行そのものが表示されない（本当に走っていない）|
| `freshSkipLine` | [build] sources up-to-date, skipping | 飛ばしたときの**実際の 1 行** |
| `freshRebuildsWhenOutputDeleted` | true | 出力を消すと作り直す |
| `artifactFirstRuns` | true | 成果物キャッシュを有効にしても、初回はキャッシュが無いので走る |
| `artifactSecondRuns` | false | 出力を消した 2 回目は**走らない** |
| `artifactSecondHitsCache` | true | 代わりに「restored outputs from cache」と言う |
| `artifactSecondPrintsBuiltAnyway` | true | 🔴 走っていないのに `BUILT` が出る（**ログの再生**）|
| `artifactRestoresDeletedOutput` | true | 消した `dist/app.txt` が**復元される** |
| `artifactWithoutExperimentalSucceeds` | false | `experimental` を立てずに書くと**タスクが失敗する** |
| `artifactWithoutExperimentalErrors` | true | 文言は「task artifact caching is experimental」|

## 2 つの機構は別物

公式は冒頭の表で分けている（`docs/tasks/caching.md`）。

| 機構 | 何を比べるか | 当たったとき |
|---|---|---|
| Freshness checks（`sources`/`outputs`）| 更新時刻 | いまある出力をそのまま残して飛ばす |
| Artifact cache（`cache = { enabled = true }`・experimental）| 入力の**中身** | 出力を**復元**し、ログを再生する |

したがって「出力を消したらどうなるか」で挙動が分かれる。前者は作り直し、後者は復元する。

## 🔴 判定を出力の文言に寄せない

キャッシュがヒットすると mise は**捕まえておいたログを再生する**ため、`BUILT` の行は
**走っていないときにも出る**。実際にこの測定で一度騙された。走ったかどうかは、
mise がコマンドを表示する `[build] $ ` の行で見る。

## 測るときの注意

`scripts/isolate.sh` が遮るのは**設定ファイルだけ**で、タスクのキャッシュは残る。
測り直しても 1 回目からヒットするため、`MISE_CACHE_DIR` と `MISE_TASK_CACHE_DIR` を
一時ディレクトリへ向けて隔離する。**この汚染もこの測定で実際に起きた。**
