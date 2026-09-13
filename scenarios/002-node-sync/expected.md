# 002-node-sync — 期待する観測

nvm で入れた node を `mise sync node --nvm` で取り込むと、mise は**コピーではなくリンク**を作る。

| キー | 期待値 | 意味 |
|---|---|---|
| `syncedAllNvmVersions` | true | nvm に入っていた**全版**を取り込んだ |
| `everySyncedIsSymlink` | true | 🔴 取り込んだ**全版**を `mise ls node` が **`(symlink)`** と表示する |
| `wherePointsAtMise` | true | ⚠️ `mise where` が返すのは **mise 側のパス**。nvm への依存はここに出ない |
| `backingIsNvm` | true | そのパス自体が `~/.nvm/versions/node/vXX` への symlink |
| `brokenLabelCount` | 1 | nvm 側を消すと `(broken symlink)` に変わる |
| `selfHealed` | true | 🔵 それでも次に使うと mise が**取り直して**動く |

## ここが分かれ目

`mise sync node --nvm` は **入れ直しを省く**コマンドであって、**nvm から独立させる**コマンドではない。

- 取り込んだ版は nvm のディレクトリを指したままである
- `mise where` はそれを**見せない**。`ls -ld` して初めて分かる
- 見分けがつくのは `mise ls` の **`(symlink)`** という 1 語だけ

だから「nvm を消す」と、その版は一度 `(broken symlink)` になる。
🔵 ただし壊れたままにはならない。次に使ったときに mise が同じ版を取り直し、リンクは実体に置き換わる。

つまり **`sync` で省けるのは「今すぐの再取得」であって、「いつかの再取得」ではない。**

## 測り方

`mise` の呼び出しは `scripts/isolate.sh` を通している。遮られるのは**設定の探索**だけで、
インストール先（`~/.local/share/mise/installs`）は遮られない。`sync` が書くのはそちらなので、観測は成立する。

🔴 **M2（機械依存）**。nvm はホームに置かれる大域の状態で、clean runner には無い。CI では測らない。

🔴 **件数は突合キーにしない**（2026-09-12 に是正）。当初は `syncedCount: 2` / `markedSymlink: 2` と
**絶対値で固定**していた。これは 002 を書いた環境（nvm に 20 系と 22 系の 2 版）の値で、
**nvm に 3 版入っている別のマシンで走らせた瞬間に壊れた**。何版入っているかは測る機械の状態であって、
`mise sync` の挙動ではない。**挙動のほうを真偽値で押さえ、件数は `results/` の生ログに残す**
（`nvmVersionCount` / `syncedCount` / `markedSymlink` は突合表に載せず、参考値として summary に置く）。
