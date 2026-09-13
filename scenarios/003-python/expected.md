# 003-python — 期待する観測

pyenv から移ってきたときに置いたままの `.python-version` を、mise はそのまま読むのか。

| キー | 期待値 | 意味 |
|---|---|---|
| `defaultTools` | 0 | 🔴 **既定では `.python-version` を読まない**。何も有効にならない |
| `enabledTools` | 1 | `idiomatic_version_file_enable_tools = ["python"]` を入れると読む |
| `toolVersionsTools` | 1 | asdf 互換の `.tool-versions` は**設定なしで読む** |
| `naiveSeesParent` | true | 遮らずに測ると親ディレクトリの設定が届く（比較が成立しない）|

## ここが分かれ目

**`.tool-versions` と `.python-version` は、既定の扱いが違う。**

- `.tool-versions`（asdf 互換）… 設定なしで読む
- `.python-version`（pyenv 系の版ファイル）… **設定を入れないと読まない**

公式の設定リファレンスも「By default, idiomatic version files are disabled.
You can enable them for specific tools with this setting.」と書いており、
既定値は `[]` である。

つまり「pyenv の設定ファイルをそのまま置いておけば動く」とは限らない。
**`.tool-versions` なら動き、`.python-version` なら動かない。**
