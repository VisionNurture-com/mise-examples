# 005-tasks-flags — 期待する観測

`usage` で宣言したブールフラグを**付けずに**実行したとき、環境変数がどうなるか。

| キー | 期待値 | 何を確かめたか |
|---|---|---|
| `absentIsSet` | false | `default` を書かない宣言では、フラグを付けないと**変数そのものが無い** |
| `absentValue` | <unset> | 同上（空文字列ではなく未設定）|
| `absentPlusExpands` | false | したがって `${usage_verbose:+YES}` は**展開されない** |
| `absentDashDefault` | [false] | `${usage_verbose:-false}` は既定値を返す |
| `presentValue` | [true] | `--verbose` を付けると文字列 `true` が入る |
| `presentPlusExpands` | true | 付けたときは `:+` も展開される |
| `defaultDeclaredIsSet` | true | 🔴 `default="false"` と宣言すると、**付けなくても変数が設定される** |
| `defaultDeclaredValue` | [false] | その値は**文字列の `false`** |
| `defaultDeclaredPlusExpands` | true | 🔴 非空文字列なので `${usage_verbose:+YES}` が**展開されてしまう** |

## 公式の警告が当たるのはどちらか

公式は「非空文字列 `"false"` も `${var:+value}` を満たすので、その展開はフラグが有効かを
判定しない」と書いている（`docs/tasks/task-arguments.md` §Conditional Flags）が、
**どの宣言でそうなるかは書いていない**。

測ると分かれた。**`default` を書かなければ `${var:+}` は期待どおり動き、`default="false"` を
足した瞬間に壊れる。**フラグを増やすときに後から `default` を書き足すと、
それまで動いていた行が静かに逆の意味になる。

## 測るときの注意

空文字列と未設定は見た目で区別できない。`printenv` の**終了コード**で判定する
（未設定なら非 0）。値だけを `echo` して比べると、この差は消える。
