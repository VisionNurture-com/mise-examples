# 006-handoff — 期待する観測

同じ到達点を 3 通りで書いて渡すと、何が違うか。**同じ 3 つのことを、mise / Ansible / chezmoi で書いて測る。**

- **T1** 版を固定した `jq`（1.8.1）が使えること
- **T2** 環境変数 `HANDOFF=ok` が入ること
- **T3** dotfile `~/.handoffrc`（`handoff=ok`）が置かれること

| キー | 期待値 | 何を確かめたか |
|---|---|---|
| `declFilesMise` | 2 | mise が T1〜T3 を書くのに要したファイル数 |
| `declFilesAnsible` | 2 | Ansible が同じことを書くのに要したファイル数 |
| `declFilesChezmoi` | 3 | chezmoi が同じことを書くのに要したファイル数 |
| `declLinesMise` | 7 | 同・行数（空行とコメントを除く）|
| `declLinesAnsible` | 29 | 🔴 **mise の 4 倍を超える**。版を固定して入れる段を自分で書くため |
| `declLinesChezmoi` | 10 | 設定ファイルは短いが、ツールは別途スクリプトが要る |
| `t1Mise` | true | `[tools] jq = "1.8.1"` で版が固定されて入る |
| `t1Ansible` | true | `get_url` で固定版のバイナリを取れば入る |
| `t1Chezmoi` | true | `run_onchange_` スクリプトを書けば入る |
| `t2Mise` | true | `[env]` が `mise env` に出る |
| `t2Ansible` | true | `lineinfile` が `.profile` に書く |
| `t2Chezmoi` | true | `dot_profile` を配る |
| `t3Mise` | true | `[dotfiles]` の copy モードで置かれる |
| `t3Ansible` | true | `copy` モジュールで置かれる |
| `t3Chezmoi` | true | `dot_handoffrc` が置かれる |
| `dryRunMise` | true | まっさらな状態で `mise bootstrap dotfiles apply --dry-run` が通る |
| `dryRunAnsible` | false | 🔴 **まっさらな状態では `ansible-playbook --check` が落ちる**。前の段が実際には作らないため、次の段が「置き場所が無い」で止まる |
| `dryRunChezmoi` | true | まっさらな状態で `chezmoi apply --dry-run` が通る |
| `secondRunChangedMise` | false | 2 回目のあと `dotfiles status --missing` が rc=0（同期済み）|
| `ansibleChangedFirst` | 4 | 1 回目に 4 タスクすべてが変更を報告する |
| `ansibleChangedSecond` | 0 | 🔵 **2 回目は 0**。冪等である |
| `secondRunChangedChezmoi` | false | 2 回目のあと `chezmoi status` が空 |
| `remoteApplyMise` | true | `mise bootstrap remote` が実在する |
| `remoteSshMise` | true | `mise ssh` が実在する |
| `remoteInventoryAnsible` | true | インベントリのホストを列挙できる（SSH は張っていない）|
| `chezmoiSshSubcommandExists` | true | 🔴 **`chezmoi ssh` は実在する**。測る前の予測は「無い」で、**外れた** |
| `chezmoiRemoteSubcommandExists` | false | `chezmoi remote` というサブコマンドは無い |
| `miseRemoteInstallMiseFlag` | 2 | `mise bootstrap remote --help` に `--install-mise` が現れる回数 |
| `chezmoiSshInstallsOnHost` | 1 | `chezmoi ssh --help` の説明に「install chezmoi」が現れる回数 |

## 「リモートへ渡す口」は 3 つともあるが、同じものではない

🔴 **測る前の予測「chezmoi はリモートへ適用する機構を持たない」は外れた。**`chezmoi ssh` は実在する。
ただし 3 つは**残すものが違う**。

| ツール | 口 | ターゲットに何が残るか |
|---|---|---|
| mise | `mise bootstrap remote` | 既定では残さない。**残したいときだけ `--install-mise`** を付ける |
| mise | `mise ssh` | 通常の OpenSSH。GitHub の借用アクセスはセッションが終われば消える |
| chezmoi | `chezmoi ssh` | 🔴 **ホストに chezmoi を入れて `init --apply` を走らせ、シェルを開く**（自己申告）|
| Ansible | インベントリ + SSH | エージェントを残さない。ただし**ターゲット側に Python が要る** |

「エージェントレス」という一語では 3 つの差は書けない。**何が残るかで分かれる。**

## 宣言の量は「どの層を持っているか」で決まる

mise が 7 行で済むのは短く書けるからではなく、**ツールの版を固定して入れる層を最初から持っている**ためである。
Ansible の 29 行のうち大半は、その層を自分で書いた分（配布物の URL をプラットフォームごとに組み立て、置いて、実行権を付ける）である。
chezmoi は設定ファイルの層だけを持つので、ツールは `run_onchange_` スクリプトへ出た。

🔴 **これは「mise が優れている」という観測ではない。**持っている層が違えば書く量は変わる、というだけである。
手放すものは別の表に載せる（Ansible のモジュール群とインベントリ、chezmoi のテンプレートと暗号化の蓄積）。

## dry-run は「まっさらな状態」で測らないと意味が変わる

適用したあとに dry-run を測ると、前の段が作ったものに助けられて通ってしまう。
本シナリオは **3 つとも、適用していない使い捨ての HOME で dry-run を測っている**。

その条件で分かれたのが `dryRunAnsible` である。
Ansible の `--check` は各タスクに「変更するふり」をさせるので、**先のタスクが作るはずのディレクトリは実在しない**。
そのため後続のタスクが「置き場所が無い」で落ち、**計画を最後まで見せられない**。
mise と chezmoi は、宣言全体から差分を出す形なので最後まで出る。

🔴 **これは「Ansible の dry-run が使えない」という意味ではない。**
すでに動いている相手に当てるぶんには通る。**まっさらな相手に対してだけ、最後まで見えない**という違いである。

## 測るときの注意

🔴 **`HOME` を差し替えると mise のデータディレクトリごと動く。**
測る側の道具（`ansible-playbook` / `chezmoi`）まで見えなくなるため、**実体のパスを差し替える前に解決**している。
これを怠ると Ansible が 1 度も走らないまま、`t1`〜`t3` がすべて `false` で出る（実際に踏んだ）。

適用先は毎回 `results/home-*` を作り直している。実際のホームには触れない。
時間は測っていない。測り直すたびに動くため、突合キーにできないからである。
