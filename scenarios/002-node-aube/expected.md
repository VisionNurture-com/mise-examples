# 002-node-aube — 期待する観測

公式が 2026-09-02 に node のページへ載せた `aube` を、既存の npm プロジェクトで走らせる。

| キー | 期待値 | 意味 |
|---|---|---|
| `aubeInstalled` | true | `mise use aube` で入る（既定のバックエンドは `packslip:`）|
| `aubrOnPath` | false | 🔴 **公式の例どおりの `mise exec -- aubr` は動かない** |
| `aubrDirectWorks` | true | 実体の隣に `aubr` はある。直に叩けば動く |
| `lockfileUnchanged` | true | 🔵 既存の `package-lock.json` を**書き換えない** |
| `installedFromExistingLock` | true | その lockfile のまま依存が入る |

## ここが分かれ目

**公式の例は、そのままでは動かない。**

公式 [`docs/lang/node.md`](https://mise.jdx.dev/lang/node.html) の `Run projects with aube` はこう書いている。

```sh
mise use aube
mise exec -- aubr test
```

ところが mise が PATH に出すのは `aube` だけである。実測（mise 2026.9.4 / aube 2.2.13 / linux-arm64）:

```
mise ERROR "aubr" couldn't exec process: No such file or directory
```

インストール先を見ると `aubr` と `aubx` は**実体の隣**に置かれているが、
mise が PATH に通す `.mise-bins/` に入っているのは `aube` だけだった。

```
installs/aube/2.2.13/aube          ← 実体
installs/aube/2.2.13/aubr -> aube  ← ある。ただし PATH には出ない
installs/aube/2.2.13/.mise-bins/aube -> ../aube   ← PATH に出るのはこれだけ
```

`mise exec -- aube run <script>` なら動く。

## 乗り換えの重さ

`aube install` は**既存の `package-lock.json` を書き換えずに**依存を入れた（sha256 が前後で一致）。
公式の "reads and writes existing `package-lock.json` … in place, so a project can try it without a
lockfile migration" のうち、**読む側は確かめた**。書く側（`aube add` 等で lockfile が更新される経路）は**測っていない**。
