# 003-python-uv — 期待する観測

`python.uv_venv_auto` はいつ効くのか。`.venv` があれば効くのか。

| キー | 期待値 | 意味 |
|---|---|---|
| `nolockHasVenv` | true | `.venv` は作ってある |
| `nolockHasUvLock` | false | `uv.lock` は作っていない |
| `nolockSourcedVenv` | false | 🔴 **`.venv` があっても、`uv.lock` が無ければ何も起きない** |
| `withlockHasUvLock` | true | `uv init` + `uv add` で `uv.lock` ができる |
| `withlockSourcedVenv` | true | `uv.lock` があれば `.venv` が有効になる |
| `seqSourcedVenv` | true | 記事どおりの順で踏んでも `mise exec` からは `.venv` に解決される |

## ここが分かれ目

**`uv.lock` の有無が「uv プロジェクトかどうか」の定義になっている。**

上流の実装は、カレントから上へ `uv.lock` を探して uv プロジェクトの根を決める。

```rust
pub(crate) fn uv_root() -> Option<PathBuf> {
    file::find_up(dirs::CWD.as_ref()?, &["uv.lock"]).map(|p| p.parent().unwrap().to_path_buf())
}
```

したがって `uv venv` だけを実行して `uv sync` / `uv lock` を通していないディレクトリでは、
`.venv` が目の前にあっても設定は無視される。`mise exec -- python` は mise 管理の処理系を指したままになる。

```
nolock   → <HOME>/.local/share/mise/installs/python/3.13/bin/python
withlock → .../cases/withlock/.venv/bin/python
```

## 測っていないこと

`seqSourcedVenv` は **`mise exec`** で測った。
`mise activate` を入れたシェルで `which python` を打つ経路は測っていない。
2 つは別の経路で、後者はシェルのフックが走るタイミングに依存する。
