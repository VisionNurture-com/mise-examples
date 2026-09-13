#!/usr/bin/env bash
# mode: M2
# 要るもの: mise（v2026.9.0 以上）・uv（v0.12 系）・ネットワーク
#
# 測ること: `mise sync python --uv` は何を同期するのか。
#           記事は「uv の .python-version に書かれた版を mise へリンクする」と書く。
#           公式は「uv が入れた処理系を mise へ symlink する（2-way）」と書く。どちらが実体か。
#
# 🔴 M2（機械依存・CI では測らない）。uv のインストール先はホームに置かれる大域の状態で、
#    scripts/isolate.sh では遮れない。CI の clean runner には uv の処理系が無い。
#
# 🔴 mise の呼び出しは isolate.sh を通す。遮れるのは「設定の探索」だけで、
#    インストール先（~/.local/share/mise/installs）は遮られない。sync が
#    書くのはそちらなので、観測には影響しない。
#
# 🔴 .python-version は 1 つも作らない。作らずに同期が起きれば、
#    「宣言ファイルを見ている」という説明が成り立たないことが示せる。
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
rm -rf "$out"; mkdir -p "$out/work"
m() { bash "$repo/scripts/isolate.sh" "$out/work" "$@"; }

command -v uv >/dev/null || { echo "uv が要ります（M2）" >&2; exit 1; }

# mise が持っていない版を uv 側に用意する（版が重なると由来が一意に決まらない）
UVONLY="3.11"

# 🔴 前回の実行が張ったリンクを外して、同じ地点から測る。
#    外さないと "before" が前回の結果に汚染され、sync が何もしない run になる
#    （2026-09-12 実測: 再走で miseHadItBefore が 0 → 2 に化けた）。
#    消すのは symlink のものだけで、実インストールには触らない。
installs="$HOME/.local/share/mise/installs/python"
[ -d "$installs" ] && find "$installs" -maxdepth 1 -type l -exec rm -f {} + 2>/dev/null || true

m ls python > "$out/before.txt" 2>&1 || true
before_has=$(grep -cE "^python[[:space:]]+$UVONLY" "$out/before.txt" || true)

# マイナー指定が何に解決されるかを sync の前後で測る。
# sync は uv の別名（cpython-3.14-...）と同じ名前の入口を mise 側に作る。
# その入口ができると、mise.toml の python = "3.14" はそちらへ束縛され、
# mise 自身が持つ最新パッチへの解決を通らなくなる。
MINOR="3.14"
mkdir -p "$out/minor"
printf '[tools]\npython = "%s"\n' "$MINOR" > "$out/minor/mise.toml"
minor_resolves() {
  bash "$repo/scripts/isolate.sh" "$out/minor" trust >/dev/null 2>&1 || true
  bash "$repo/scripts/isolate.sh" "$out/minor" ls --current 2>/dev/null \
    | grep -E '^python[[:space:]]' | awk '{print $2}' | head -1
}
minor_before=$(minor_resolves); minor_before="${minor_before:-none}"

uv python install "$UVONLY" > "$out/uv-install.txt" 2>&1 || true

m sync python --uv > "$out/sync.txt" 2>&1 || true
m ls python > "$out/after.txt" 2>&1 || true
after_has=$(grep -cE "^python[[:space:]]+$UVONLY" "$out/after.txt" || true)

# 両方向が起きたかを出力から数える（文言ではなく方向の語で数える）
uv_to_mise=$(grep -c 'from uv to mise' "$out/sync.txt" || true)
mise_to_uv=$(grep -c 'from mise to uv' "$out/sync.txt" || true)

# mise 側の実体がリンクかどうか
whr=$(m where "python@$UVONLY" 2>/dev/null | tail -1 || true)
link=false
if [ -n "$whr" ] && [ -L "$whr" ]; then link=true; fi
printf '%s\n' "${whr:-none}" > "$out/where.txt"
ls -ld "${whr:-/nonexistent}" > "$out/where-ls.txt" 2>&1 || true

# 🔴 uv の一覧に mise のパスが出ることは「同期の証拠にならない」。
#    uv は PATH 上の処理系を素で見つけるため、同期していなくても出る。
#    mise → uv 方向の実体は「uv のストアに版のディレクトリが増える」ことで見る。
uv python list --only-installed > "$out/uv-list.txt" 2>&1 || true
ls -l "$HOME/.local/share/uv/python" > "$out/uv-store.txt" 2>&1 || true

minor_after=$(minor_resolves); minor_after="${minor_after:-none}"
# 束縛が別名へ移ったか（== マイナー指定がパッチ版でなく別名に解決されるか）
minor_bound_to_alias=$([ "$minor_after" = "$MINOR" ] && echo true || echo false)

# 宣言ファイルは 1 つも作っていないことを記録に残す
pv_count=$(find "$out/work" -name '.python-version' 2>/dev/null | wc -l | tr -d ' ')

cat > "$out/summary.json" <<JSON
{
  "uvOnlyVersion": "$UVONLY",
  "miseHadItBefore": ${before_has:-0},
  "miseHasItAfter": ${after_has:-0},
  "miseEntryIsSymlink": $link,
  "minorSpec": "$MINOR",
  "minorResolvedBeforeSync": "$minor_before",
  "minorResolvedAfterSync": "$minor_after",
  "minorBoundToAliasAfterSync": $minor_bound_to_alias,
  "syncedUvToMiseAny": $([ "${uv_to_mise:-0}" -gt 0 ] && echo true || echo false),
  "syncedUvToMise": ${uv_to_mise:-0},
  "syncedMiseToUv": ${mise_to_uv:-0},
  "pythonVersionFilesCreated": ${pv_count:-0},
  "measuredAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "miseVersion": "$(mise --version | awk '{print $1}')",
  "uvVersion": "$(uv --version | awk '{print $2}')"
}
JSON
cat "$out/summary.json"
