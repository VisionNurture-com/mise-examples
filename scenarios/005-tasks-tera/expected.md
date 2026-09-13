# 005-tasks-tera — 期待する観測

引数を Tera テンプレート関数（`{{arg()}}`）で書いたタスクを実行したとき、mise が何を言うか。

| キー | 期待値 | 何を確かめたか |
|---|---|---|
| `teraWarns` | true | 非推奨の警告が出る |
| `teraWarnVersions` | 2027.5.0 | 警告行が指す**廃止される版**。CLI の実出力から取った |
| `controlUsageWarns` | false | 陽性対照。`usage` で書いた同じ処理では警告が出ない |
| `teraStillWorks` | true | 警告は出るが、いまはまだ動く |
| `usageWorks` | true | `usage` 版も同じ結果を出す |

## 実出力（そのまま）

```
mise WARN  deprecated [tera_template_task_args]: Task 'greet' uses deprecated Tera template functions (arg(), option(), flag()) in run scripts. Use the 'usage' field instead. See https://mise.jdx.dev/tasks/task-arguments.html This will be removed in mise 2027.5.0.
```

## なぜ版を CLI から取るか

公式ドキュメントは 2026-06-16 のリリース（2026.6.11）で、廃止版を **2026.11.0 → 2027.5.0** へ
訂正している（[jdx/mise#10453](https://github.com/jdx/mise/pull/10453)）。PR の理由は
「The CLI outputs a version different from that given in the docs」——
**ドキュメントのほうが実装とずれていた**。したがって版はドキュメントではなく実出力で確かめる。

## 測るときの注意

警告の出力先が標準出力か標準エラーかは決め打ちできないため、`2>&1` で両方を捕まえる。
片方だけ見ると「出なかった」と誤って結論する。
