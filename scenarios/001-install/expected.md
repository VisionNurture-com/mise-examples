# 001-install — 期待する観測

`[tools]` に書いたものだけが、そのディレクトリで有効になる。

| キー | 期待値 | 意味 |
|---|---|---|
| `withTools` | 1 | `[tools] node = "24"` を書いたので node が 1 つ有効になる |
| `withoutTools` | 0 | 空の `mise.toml` では何も有効にならない |
| `naiveSeesParent` | true | **遮らずに測ると、親ディレクトリの `[tools] jq` が下まで届く** |

## この 3 つ目が何を示すか

`naiveSeesParent` が true であることは、**遮る手当てが実際に必要だ**という証拠になる。
遮らずに測ると「設定を書かない場合」にも親の設定が出るため、比較が成立しない。

`withoutTools` が 0 で、かつ `naiveSeesParent` が true —— この 2 つが同時に成り立って
はじめて「遮れている」と言える。**`withoutTools` が 0 なだけでは、遮れているのか
そもそも汚染が無いだけなのかを区別できない。**

実測（macOS Apple Silicon / mise v2026.9.4・2026-09-10）では、遮らずに測ると
親の `jq` に加えて、実行した人のホームにある node・python・terraform・watchexec も出た。
