# 003-python-sync — 期待する観測

`mise sync python --uv` は何を同期するのか。宣言ファイルか、処理系か。

| キー | 期待値 | 意味 |
|---|---|---|
| `uvOnlyVersion` | 3.11 | mise が持っていない版を uv 側に用意する |
| `miseHadItBefore` | 0 | 同期前、mise にその版は無い |
| `miseHasItAfter` | 2 | 同期後、`3.11` と `3.11.14` の 2 行が増える |
| `miseEntryIsSymlink` | true | 🔴 **実体はコピーではなくリンク** |
| `syncedUvToMiseAny` | true | uv → mise 方向が起きた |
| `pythonVersionFilesCreated` | 0 | 🔴 **`.python-version` を 1 つも作っていないのに同期が起きる** |
| `minorSpec` | 3.14 | マイナー指定が何に解決されるかを前後で測る |
| `minorResolvedBeforeSync` | 3.14.7 | 同期前は**入っている中で最新のパッチ版**に解決される |
| `minorResolvedAfterSync` | 3.14 | 🔴 **同期後は uv の別名そのものに解決される** |
| `minorBoundToAliasAfterSync` | true | 🔴 **同じ `mise.toml` のまま、解決先が変わる** |

## ここが分かれ目

**このコマンドは宣言ファイルを見ていない。**測定では `.python-version` を 1 つも作っていない。
同期されるのは「どちらかのツールが**インストールした処理系**」である。

リンク先を見れば分かる。

```
<HOME>/.local/share/mise/installs/python/3.11 -> <HOME>/.local/share/uv/python/cpython-3.11-macos-aarch64-none
```

そして方向は片側ではない。素の状態から 1 度走らせると、両方向が同じ出力に並ぶ。

```
Synced python@3.11    from uv to mise
Synced python@3.11.14 from uv to mise
...
Synced python@3.14.5  from mise to uv
Synced python@3.14.7  from mise to uv
```

## 再走では `syncedMiseToUv` が 0 になる

`from mise to uv` の側は、1 度走らせると uv のストアにその版のディレクトリができ、
**次からは同期するものが残っていない**。したがって再走の `syncedMiseToUv` は 0 になる。
突合表に載せていないのはこのためで、両方向が起きることは上の生出力が根拠になる。

## 🔴 同期は「入る版」を増やすだけでなく「指定の意味」を変える

`mise sync python --uv` は、uv が持つ**別名**（`cpython-3.14-macos-aarch64-none` のような、
パッチ版を指すリンク）と同じ名前の入口を mise 側にも作る。

```
Synced python@3.14 from uv to mise
<HOME>/.local/share/mise/installs/python/3.14 -> <HOME>/.local/share/uv/python/cpython-3.14-macos-aarch64-none
```

この入口ができると、`mise.toml` の `python = "3.14"` はそちらに束縛される。

| 状態 | `python = "3.14"` の解決先 |
|---|---|
| 同期前 | **3.14.7**（入っている中で最新のパッチ版）|
| 同期後 | **3.14**（uv の別名）|
| 別名リンクを外した後 | **3.14.7**（戻る）|

`mise.toml` は 1 文字も変えていない。**変わったのは機械の側**である。

同期後は、その指定がどのパッチ版になるかを **uv の別名が決める**。uv が新しいパッチ版を入れれば
別名の指す先が動き、mise 側の指定も一緒に動く。同期しなければ mise 自身の解決が使われる。

どちらが良いかはプロジェクトによる。ここで測ったのは**どちらになるか**であって、
どちらを選ぶべきかではない。

## 証拠にならないもの

`uv python list` に mise のパスが出ることは、**同期の証拠にならない**。
uv は PATH 上の処理系を素で見つけるため、同期していなくても出る。
