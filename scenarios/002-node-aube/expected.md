# 002-node-aube — 期待する観測

公式が 2026-09-02 に node のページへ載せた `aube` を、既存の npm プロジェクトで走らせる。

| キー | 期待値 | 意味 |
|---|---|---|
| `aubeInstalled` | true | `mise use aube` で入る（既定のバックエンドは `packslip:`）|
| `aubrOnPath` | true | 🔵 **aube 2.2.14 から、公式の例どおりの `mise exec -- aubr` が動く**（2.2.13 までは動かなかった）|
| `aubrDirectWorks` | true | 実体の隣に `aubr` はある。直に叩けば動く |
| `lockfileUnchanged` | true | 🔵 既存の `package-lock.json` を**書き換えない** |
| `installedFromExistingLock` | true | その lockfile のまま依存が入る |

## ここが分かれ目

**公式の例が動くかどうかは、aube の版で変わる。**

公式 [`docs/lang/node.md`](https://mise.jdx.dev/lang/node.html) の `Run projects with aube` はこう書いている。

```sh
mise use aube
mise exec -- aubr test
```

| aube の版 | `mise exec -- aubr` | 測った条件 |
|---|:--:|---|
| **2.2.13**（2026-09-09）| ❌ 動かない | mise 2026.9.4 / linux-arm64、および mise 2026.9.5・2026.9.6 / macos-arm64 |
| **2.2.14**（2026-09-11）| ✅ 動く | mise 2026.9.5 / macos-arm64、および CI の ubuntu-latest / macos-latest |

2.2.13 では、`aubr` と `aubx` は実体の隣にあるのに、mise が PATH へ通す `.mise-bins/` には `aube` しか入っていなかった。

```
installs/aube/2.2.13/aube          ← 実体
installs/aube/2.2.13/aubr -> aube  ← ある。ただし PATH には出ない
installs/aube/2.2.13/.mise-bins/aube -> ../aube   ← PATH に出るのはこれだけ
```

返るエラーはこれだった。

```
mise ERROR "aubr" couldn't exec process: No such file or directory
```

2.2.14 で `.mise-bins/` に `aubr` も入るようになり、例のとおりで動く。
**mise の版を上げても解決しない**（2026.9.6 でも 2.2.13 なら動かない）ことは切り分けて確かめた。

🔴 **このシナリオは版を固定している。**`aube = "latest"` にしていた間は、同じスクリプトが日によって違う値を出していた（2026-09-12 は false / 2026-09-13 は true）。
上流が動く題材を測るときは、**測った版そのものを宣言に書く**。

## 乗り換えの重さ

`aube install` は**既存の `package-lock.json` を書き換えずに**依存を入れた（sha256 が前後で一致）。
公式の "reads and writes existing `package-lock.json` … in place, so a project can try it without a
lockfile migration" のうち、**読む側は確かめた**。書く側（`aube add` 等で lockfile が更新される経路）は**測っていない**。
