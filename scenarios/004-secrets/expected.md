# 004-secrets — 期待する観測

秘密の値を、どこに置くと何が変わるか。**置き場所ごとに 4 つのことを測る。**

1. リポジトリに何が残るか（平文か、暗号文か、何も残らないか）
2. 実行時に何が要るか（何も要らない / 復号鍵 / fnox）
3. `mise env` に平文が出るか
4. 鍵が無いとどうなるか（止まるのか、黙って空になるのか）

| キー | 期待値 | 何を確かめたか |
|---|---|---|
| `plainInEnv` | true | `[env]` に平文で書いた値が `mise env` にそのまま出る |
| `localOverrides` | true | `mise.local.toml` が `mise.toml` を上書きする |
| `miseWritesGitignore` | false | **mise は `.gitignore` を書かない**。`mise.local.toml` を除外するのは利用者 |
| `experimentalRequired` | true | `experimental` を立てないと age 暗号化は**エラーで止まる** |
| `ageNoPlaintextInToml` | true | `mise set --age-encrypt` のあと、`mise.toml` に**平文が残らない** |
| `ageDecryptsWithKey` | true | 鍵を渡すと復号され、値が環境に入る |
| `agePlainInEnv` | true | 🔴 鍵があるとき **`mise env` は平文で出す**（公式「復号した値は常に redact 扱い」でも隠れない）|
| `ageFailsWithoutKey` | true | 鍵が無いと**空にならず、止まる**（rc≠0）|
| `sopsNoPlaintextInFile` | true | 暗号化した `.env.json` に**平文が残らない** |
| `sopsDecryptsWithKey` | true | 鍵を渡すと復号され、値が環境に入る |
| `sopsFailsWithoutKey` | true | 鍵が無いと止まる（rc≠0）|
| `fnoxNothingInMiseToml` | true | **`mise.toml` に値も暗号文も入らない**（暗号文は `fnox.toml` 側）|
| `fnoxUnsetWithout` | true | fnox を通さずに `mise run` すると値は**未設定**のまま |
| `fnoxProvidesWithExec` | true | `fnox exec -- mise run` を通すと値が入る |

## 読み違えやすいところ

`mise env` は**隠さない**。公式が意図的だと書いている。

> `mise env` intentionally exports plaintext values, **including those marked as redacted**.

だから `redact = true` も `--redacted` も、`mise env` の出力を守るものではない。
守るのは `mise run`（タスク実行）の**出力**のほうである。

## 測るときの注意

鍵はすべて `results/work/` の中に作り、環境変数で明示的に指している。
`MISE_AGE_KEY` / `MISE_SOPS_AGE_KEY` / `FNOX_CONFIG_DIR` を渡さないと、
mise も fnox も**実行した人のホームにある鍵を探しに行く**（`~/.config/mise/age.txt`・
`~/.ssh/id_ed25519`・`~/.config/fnox/age.txt`）。そのまま測ると、
鍵が無い場合の挙動を測っているつもりで、他人の鍵で復号できてしまう。

`cases/` に置いた設定は読むためのもので、run.sh は毎回 `results/work/` へ写してから
書き換える。暗号文は鍵ごとに変わるため、リポジトリには残さない。
