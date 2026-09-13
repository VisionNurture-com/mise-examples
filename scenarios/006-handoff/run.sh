#!/usr/bin/env bash
# mode: M1
# 要るもの: mise（v2026.9.0 以上）・ネットワーク（jq の取得）
#           pipx:ansible-core@2.21.4 / chezmoi@2.72.1（測る側の道具・mise で入れる）
#
# 測ること: 同じ到達点を 3 通りで書いて渡すと、何が違うか。
#
#   到達点 T1 … 版を固定した jq（1.8.1）が使える
#   到達点 T2 … 環境変数 HANDOFF=ok が入る
#   到達点 T3 … dotfile ~/.handoffrc（handoff=ok）が置かれる
#
#   mise / ansible / chezmoi … 上の 3 つを各ツールの書き方で宣言し、適用する
#
# 🔴 適用先は毎回 使い捨ての HOME で、実際のホームには触れない。
# 🔴 時間は測らない（測り直すたびに動くため突合キーにできない）。
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
rm -rf "$out"; mkdir -p "$out"          # 🔴 前回の出力が残ると突合が前回の値で緑を返す

ANSIBLE="pipx:ansible-core@2.21.4"
CHEZMOI="chezmoi@2.72.1"
JQ_VER="1.8.1"

iso() { bash "$repo/scripts/isolate.sh" "$here/cases/$1" "${@:2}"; }

# 🔴 HOME を差し替えると mise のデータディレクトリごと動く。測る側の道具（ansible /
#    chezmoi）まで見えなくなるため、実体のパスを "差し替える前に" 解決しておく。
#    これを怠ると Ansible が 1 度も走らないまま「到達できなかった」と出る（実際に踏んだ）。
mw() { MISE_GLOBAL_CONFIG_FILE="$repo/empty.toml" mise where "$1"; }

# 🔴 測る側の道具が「すでに入っていること」を当てにしない。手元に入っていても CI には
#    無く、mise where が not installed で落ちる。2026-09-12 の push から CI が 3 回続けて
#    赤いまま進んだ原因がこれだった。宣言を持たない使い方なので、ここで明示的に入れる。
MISE_GLOBAL_CONFIG_FILE="$repo/empty.toml" mise install "$ANSIBLE" "$CHEZMOI"

ANSIBLE_BIN="$(mw "$ANSIBLE")/bin"
CHEZMOI_BIN="$(mw "$CHEZMOI")"

# 宣言の量 —— 空行と # / --- で始まる行を除いて数える
# 🔴 `._*` を除くのは macOS の tar が作る AppleDouble 対策。
#    これを除かずに Linux 側で数えると、同じ題材がファイル数 2 → 4・行数 7 → 38 に化ける（実際に踏んだ）。
decl_find()  { find "$here/cases/$1" -type f -not -name '._*'; }
decl_files() { decl_find "$1" | wc -l | tr -d ' '; }
decl_lines() { cat $(decl_find "$1" | sort) | grep -vcE '^\s*(#|---\s*$|$)' || true; }

# 🔴 bin/ は作らない。ここで先に作ると、それを作る仕事まで測る対象から消える。
#    実際に踏んだ: macOS は mkdir の既定が 0755 で Ansible の該当タスクが ok、
#    Ubuntu は umask の差で 0775 になり changed —— 環境差に見えて、原因はハーネスだった。
newhome() { local h="$out/home-$1"; rm -rf "$h"; mkdir -p "$h"; echo "$h"; }

# ============================================================ dry-run（🔴 まっさらな状態で先に測る）
#    適用したあとに dry-run を測ると、前の段が作ったものに助けられて通ってしまう。
#    実際に踏んだ: Ansible の --check は適用後だと rc=0 だが、まっさらだと
#    「前の段が実際には作らない」ため次の段が落ちる（リモートで先に出た）。
hmd="$(newhome mise-dry)"
iso mise trust >/dev/null 2>&1 || true
if ( export HOME="$hmd"; iso mise bootstrap dotfiles apply --dry-run --yes ) > "$out/mise-dryrun.txt" 2>&1; then mise_dry=true; else mise_dry=false; fi

had="$(newhome ansible-dry)"
if ( cd "$here/cases/ansible"; export HOME="$had"; "$ANSIBLE_BIN/ansible-playbook" -i 'localhost,' -c local --check playbook.yml ) > "$out/ansible-dryrun.txt" 2>&1; then ans_dry=true; else ans_dry=false; fi

hcd="$(newhome chezmoi-dry)"
if ( export HOME="$hcd"; "$CHEZMOI_BIN/chezmoi" --source "$here/cases/chezmoi/source" --destination "$hcd" --no-tty apply --dry-run ) > "$out/chezmoi-dryrun.txt" 2>&1; then cz_dry=true; else cz_dry=false; fi

# ============================================================ mise
hm="$(newhome mise)"
iso mise trust >/dev/null 2>&1 || true
( export HOME="$hm"; iso mise install ) > "$out/mise-apply.txt" 2>&1 || true
( export HOME="$hm"; iso mise bootstrap dotfiles apply --yes ) >> "$out/mise-apply.txt" 2>&1 || true
( export HOME="$hm"; iso mise x -- jq --version ) > "$out/mise-t1.txt" 2>&1 || true
( export HOME="$hm"; iso mise env ) > "$out/mise-t2.txt" 2>&1 || true

# 2 回目 —— まだ変更が残っていると報告されるか
( export HOME="$hm"; iso mise install ) >> "$out/mise-apply2.txt" 2>&1 || true
( export HOME="$hm"; iso mise bootstrap dotfiles apply --yes ) >> "$out/mise-apply2.txt" 2>&1 || true
if ( export HOME="$hm"; iso mise bootstrap dotfiles status --missing ) > "$out/mise-status2.txt" 2>&1; then mise_changed2=false; else mise_changed2=true; fi

# ============================================================ ansible
ha="$(newhome ansible)"
apb() { ( cd "$here/cases/ansible"; export HOME="$ha"; "$ANSIBLE_BIN/ansible-playbook" -i 'localhost,' -c local "$@" playbook.yml ); }
apb > "$out/ansible-apply.txt" 2>&1 || true
apb > "$out/ansible-apply2.txt" 2>&1 || true
# 到達点の確認
( export HOME="$ha"; "$ha/bin/jq" --version ) > "$out/ansible-t1.txt" 2>&1 || true
cat "$ha/.profile" > "$out/ansible-t2.txt" 2>&1 || true
# リモートのホストを列挙できるか（SSH は張らない）
if ( cd "$here/cases/ansible"; export HOME="$ha"; "$ANSIBLE_BIN/ansible-playbook" -i 'devbox,' --list-hosts playbook.yml ) > "$out/ansible-remote.txt" 2>&1; then ans_remote=true; else ans_remote=false; fi

# ============================================================ chezmoi
hc="$(newhome chezmoi)"
cz() { ( export HOME="$hc"; "$CHEZMOI_BIN/chezmoi" --source "$here/cases/chezmoi/source" --destination "$hc" --no-tty "$@" ); }
cz apply > "$out/chezmoi-apply.txt" 2>&1 || true
cz apply > "$out/chezmoi-apply2.txt" 2>&1 || true
cz status > "$out/chezmoi-status2.txt" 2>&1 || true
( export HOME="$hc"; "$hc/bin/jq" --version ) > "$out/chezmoi-t1.txt" 2>&1 || true
cat "$hc/.profile" > "$out/chezmoi-t2.txt" 2>&1 || true
# リモートへ適用する口があるか —— サブコマンドの有無を rc で測る
cz ssh --help    > "$out/chezmoi-ssh.txt"    2>&1 && cz_ssh=true    || cz_ssh=false
cz remote --help > "$out/chezmoi-remote.txt" 2>&1 && cz_remote=true || cz_remote=false
( export HOME="$hc"; "$CHEZMOI_BIN/chezmoi" --help ) > "$out/chezmoi-help.txt" 2>&1 || true

# mise 側のリモートの口
MISE_GLOBAL_CONFIG_FILE="$repo/empty.toml" mise bootstrap remote --help > "$out/mise-remote-help.txt" 2>&1 && mise_remote=true || mise_remote=false
MISE_GLOBAL_CONFIG_FILE="$repo/empty.toml" mise ssh --help              > "$out/mise-ssh-help.txt"    2>&1 && mise_ssh=true    || mise_ssh=false

# ============================================================ 判定
has()  { grep -qE "$2" "$out/$1" && echo true || echo false; }
t3()   { [ -f "$1/.handoffrc" ] && grep -qx 'handoff=ok' "$1/.handoffrc" && echo true || echo false; }
ansch(){ local v; v="$(grep -oE 'changed=[0-9]+' "$out/$1" | tail -1 | cut -d= -f2)"; echo "${v:--1}"; }   # -1 = 走っていない
cnt()  { grep -cE -- "$2" "$out/$1" || true; }

cat > "$out/summary.json" <<JSON
{
  "measuredAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "miseVersion": "$(mise --version | awk '{print $1}')",
  "ansibleCoreVersion": "2.21.4",
  "chezmoiVersion": "2.72.1",
  "declFilesMise": $(decl_files mise),
  "declFilesAnsible": $(decl_files ansible),
  "declFilesChezmoi": $(decl_files chezmoi),
  "declLinesMise": $(decl_lines mise),
  "declLinesAnsible": $(decl_lines ansible),
  "declLinesChezmoi": $(decl_lines chezmoi),
  "t1Mise": $(has mise-t1.txt "^jq-$JQ_VER\$"),
  "t1Ansible": $(has ansible-t1.txt "^jq-$JQ_VER\$"),
  "t1Chezmoi": $(has chezmoi-t1.txt "^jq-$JQ_VER\$"),
  "t2Mise": $(has mise-t2.txt '^export HANDOFF=.?ok'),
  "t2Ansible": $(has ansible-t2.txt '^export HANDOFF=ok$'),
  "t2Chezmoi": $(has chezmoi-t2.txt '^export HANDOFF=ok$'),
  "t3Mise": $(t3 "$hm"),
  "t3Ansible": $(t3 "$ha"),
  "t3Chezmoi": $(t3 "$hc"),
  "dryRunMise": $mise_dry,
  "dryRunAnsible": $ans_dry,
  "dryRunChezmoi": $cz_dry,
  "secondRunChangedMise": $mise_changed2,
  "ansibleChangedFirst": $(ansch ansible-apply.txt),
  "ansibleChangedSecond": $(ansch ansible-apply2.txt),
  "secondRunChangedChezmoi": $([ -s "$out/chezmoi-status2.txt" ] && echo true || echo false),
  "remoteApplyMise": $mise_remote,
  "remoteSshMise": $mise_ssh,
  "remoteInventoryAnsible": $ans_remote,
  "chezmoiSshSubcommandExists": $cz_ssh,
  "chezmoiRemoteSubcommandExists": $cz_remote,
  "miseRemoteInstallMiseFlag": $(cnt mise-remote-help.txt '--install-mise'),
  "chezmoiSshInstallsOnHost": $(cnt chezmoi-ssh.txt 'install chezmoi')
}
JSON
cat "$out/summary.json"
