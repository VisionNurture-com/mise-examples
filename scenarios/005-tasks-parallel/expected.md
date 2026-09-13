# 005-tasks-parallel — 期待する観測

`depends` に 6 本並べたとき、同時に何本まで走るか。

| キー | 期待値 | 何を確かめたか |
|---|---|---|
| `defaultPeakConcurrency` | 6 | 🔴 既定では 6 本**すべて**が同時に走った（4 本ではない）|
| `jobs2PeakConcurrency` | 2 | `--jobs 2` で 2 本に絞られる |
| `jobs8PeakConcurrency` | 6 | `--jobs 8` は上限のほうが大きく、依存の本数（6）で頭打ちになる |
| `depsGraphHasLines` | true | `mise tasks deps` が依存の木を出す |
| `namedDepsShowsPost` | false | 🔴 **タスク名を指定した形**（`mise tasks deps main`）には `depends_post` が**出ない** |
| `allDepsShowsPost` | true | **引数なしの形**（`mise tasks deps`）には `after (post)` として出る |

## 🔴 公式ドキュメントと実装が食い違っている

`docs/tasks/running-tasks.md` は「Tasks run with a maximum of **four** parallel jobs by default」
と書いている。しかし設定の正本 `settings.toml` は `[jobs] default = 8` で、
`mise settings get jobs` も **8** を返し、依存 6 本は全部同時に走った。

`settings.toml` に `task.jobs` のような**タスク専用の設定は存在しない**（`[jobs]` ただ 1 つ）。
したがって「4」はドキュメント側の誤りと読める。⚠️ **いつからずれたかは未検証**
（CHANGELOG に `jobs` の既定値を変えた記録は無い）。

## 後処理は「引数なしの形」でしか見えない

公式は `mise tasks deps` が `depends` / `wait_for` / `depends_post` を含むと書いている
（`docs/tasks/running-tasks.md` §Execution order）。これは**引数なしの形**では正しい。

```
$ mise tasks deps main      # 事前の依存だけ
main
├── t6
...

$ mise tasks deps           # 後処理も出る
after (post)
└── main
    ├── t6
    ...
```

後処理が動かないと思ったときに `mise tasks deps <タスク名>` を叩くと、**もともと出ない**ので
確かめたことにならない。

## 測るときの注意

同時実行数は体感では数えられない。各タスクに開始と終了を 1 行ずつ同じファイルへ追記させ、
**行の順序だけ**で数える。秒未満の時刻精度を要求しないので、macOS でも Linux でも同じ手順が使える。
