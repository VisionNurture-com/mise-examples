# 002-node-pin — 期待する観測

`mise use` は `mise.toml` に**書いたとおりの語**を残す。`--pin` を付けると**解決した結果の版**に置き換わる。

| キー | 期待値 | 意味 |
|---|---|---|
| `pinnedNodeIsConcrete` | true | 🔴 `--pin` を付けると `node = "24.21.0"` のように**具体版**が書かれる |
| `unpinnedNodeValue` | lts | 付けないと `lts` という**記号のまま**残る |
| `unpinnedNpmValue` | latest | 同じく `latest` のまま残る |

## ここが分かれ目

`node = "lts"` と書いたファイルをチームで共有すると、**読む人と読む時期で指すものが変わる**。
`lts` は 2026 年 9 月には Node 24 系を指すが、次の LTS が出れば同じ 1 行が別の版を指す。

公式は npm を固定する手段としてこの形を挙げている。

```sh
mise use --pin node@lts npm@latest
```

> This writes the resolved concrete versions to `mise.toml`.
> —— [mise 公式 `Pinning npm version`](https://mise.jdx.dev/lang/node.html)

🔵 **`mise.lock`（ロックファイル）とは層が違う。**`--pin` が固めるのは **`mise.toml` に書く版の文字列**で、
ロックファイルが固めるのは**取得した実体**である。
