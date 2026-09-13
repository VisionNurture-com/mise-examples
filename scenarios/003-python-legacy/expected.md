# 003-python-legacy — 期待する観測

レガシー値 `python.uv_venv_auto = true` を、いまの mise に与えると何が起きるか。

| キー | 期待値 | 意味 |
|---|---|---|
| `legacyUvPython` | 3.13.13 | `true` は `UV_PYTHON` を出す |
| `legacyUvPythonShape` | version | 🔴 **入るのは版番号だけで、処理系の実パスではない** |
| `stringUvPython` | none | `"create\|source"` は `UV_PYTHON` を出さない |
| `legacyWarnLines` | 0 | 🔴 **非推奨の警告が 1 行も出ない** |
| `stringWarnLines` | 0 | 対照（そもそも非推奨ではない）|
| `legacySourcedVenv` | true | `.venv` は有効になる |
| `stringSourcedVenv` | true | 同上 |

## ここが分かれ目

公式ドキュメントは `true` について「**it warns since mise 2026.7.0** and will be removed in
mise 2027.7.0」と書いている。**mise 2026.9.5 で、その警告は出ない。**

警告の機構そのものは生きている。同じ測り方で `task_output`（非推奨・警告開始 2026.8.0）を与えると出る。

```
positive : mise WARN  deprecated [setting.task_output]: Use task.output instead. This will be removed in mise 2027.2.0.
legacy   : (deprecation 警告 0 行)
```

上流のソースを追うと、警告は次の経路で落ちている。

1. `visit_bool` が `deprecated_at!("2026.7.0", "2027.7.0", "python.uv_venv_auto.true", ...)` を呼ぶ
2. `warn_deprecated_now(key)` は `SETTINGS_META.get(key)` が `None` なら何も出さずに戻る
3. `settings.toml` の `[python.uv_venv_auto]` には `deprecated` / `deprecated_warn_at` /
   `deprecated_remove_at` が無く、`python.uv_venv_auto.true` という表も無い
4. `SETTINGS_META` は `build.rs` が `settings.toml` の表と `deprecated*` から生成する

つまり `true` を書いたまま放っておいても、**mise は何も教えてくれない**。

## 測っていないこと

上流がこれを不具合と見なすかは確かめていない。ここに書いたのは
「2026.9.5 で測ったら出なかった」ことと「公式は出ると書いている」ことの 2 つだけである。
