# 003-python-precedence — 期待する観測

Python の版を宣言する場所が 2 つあるとき、どちらが効くのか。

| キー | 期待値 | 意味 |
|---|---|---|
| `conflictResolved` | 3.13.13 | `mise.toml` = 3.13 と `.python-version` = 3.12 が食い違うと、**`mise.toml` が勝つ** |
| `idiomaticOnlyResolved` | 3.12.13 | `.python-version` だけなら、その版が効く（有効化済み）|
| `pluralResolved` | 3.12.13 | `.python-versions`（複数形）も読まれる |
| `pluralPythonLines` | 2 | 🔴 **複数形は 2 版を同時に有効にする** |

## どこで確かめられるか

`mise ls --current` は「どのファイルが効いたか」を列に出す。

```
python  3.13.13  .../cases/misetoml-wins/mise.toml        3.13
python  3.12.13  .../cases/idiomatic-only/.python-version 3.12
python  3.12.13  .../cases/plural/.python-versions        3.12
python  3.13.13  .../cases/plural/.python-versions        3.13
```

読者は自分の環境で同じ列を見れば、どちらが効いているかを推測せずに済む。

公式も「A conflicting Python declaration in `mise.toml` takes precedence over an idiomatic file」
と書いており、実測はこれと一致する。

`.python-versions`（複数形）は uv 側のドキュメントにも
「A project that requires multiple Python versions may define a `.python-versions` file」
としてある。
