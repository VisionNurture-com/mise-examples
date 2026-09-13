# 002-node-idiomatic — 期待する観測

`.nvmrc` を読ませる設定を入れると、`package.json` の `devEngines` も一緒に有効になる。両方あるとどちらが勝つのか。

| キー | 期待値 | 意味 |
|---|---|---|
| `bothSource` | package.json | 🔴 **`.nvmrc` と `package.json` が両方あると、`package.json` が勝つ** |
| `bothDisabledSource` | .nvmrc | `node:package.json` だけを無効化すると `.nvmrc` が効く |
| `pkgJsonTools` | 1 | `package.json` だけでも版が決まる |
| `pkgJsonDisabledTools` | 0 | それを無効化すると何も残らない |

## ここが分かれ目

`idiomatic_version_file_enable_tools = ["node"]` は **1 つの設定で 3 種類のファイルをまとめて有効にする**。

- `.nvmrc`
- `.node-version`
- `package.json` の `devEngines.runtime`

nvm から移ってきた人が欲しいのはふつう `.nvmrc` だが、**`package.json` に `devEngines` があるとそちらが先に効く**。
`.nvmrc` に `22`、`devEngines` に `24.x` と書いてあれば、**選ばれるのは 24 系**である。

`.nvmrc` だけを効かせたいなら、`package.json` を名指しで外す。

```toml
[settings]
idiomatic_version_file_enable_tools = ["node"]
idiomatic_version_file_disable_files = ["node:package.json"]
```

この個別無効化は [#11470](https://github.com/jdx/mise/pull/11470)（2026-07-29）で入った。
