#!/usr/bin/env bash
# mode: M1
# 要るもの: mise（v2026.9.0 以上）・ネットワーク（node と npm を取りに行く）
#
# 測ること: `mise use --pin` は mise.toml に何を書くか。
#
#   pinned   … mise use --pin node@lts npm@latest
#   unpinned … mise use       node@lts npm@latest
#
# 🔴 作業ディレクトリを results/ の下に作る。cases/ に置くと mise が
#    そこへ書き込み、リポジトリの追跡ファイルが実行のたびに変わる。
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
rm -rf "$out"; mkdir -p "$out/work/pinned" "$out/work/unpinned"

: > "$out/work/pinned/mise.toml"
: > "$out/work/unpinned/mise.toml"

bash "$repo/scripts/isolate.sh" "$out/work/pinned"   trust >/dev/null 2>&1 || true
bash "$repo/scripts/isolate.sh" "$out/work/unpinned" trust >/dev/null 2>&1 || true

bash "$repo/scripts/isolate.sh" "$out/work/pinned"   use --pin node@lts npm@latest > "$out/pinned.log"   2>&1
bash "$repo/scripts/isolate.sh" "$out/work/unpinned" use       node@lts npm@latest > "$out/unpinned.log" 2>&1

cp "$out/work/pinned/mise.toml"   "$out/pinned.toml"
cp "$out/work/unpinned/mise.toml" "$out/unpinned.toml"

value_of() { awk -F'"' -v k="$2" '$0 ~ "^"k" = " { print $2 }' "$1"; }

pinned_node=$(value_of "$out/pinned.toml" node)
unpinned_node=$(value_of "$out/unpinned.toml" node)
unpinned_npm=$(value_of "$out/unpinned.toml" npm)

is_concrete() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo true || echo false; }

cat > "$out/summary.json" <<JSON
{
  "pinnedNodeIsConcrete": $(is_concrete "$pinned_node"),
  "unpinnedNodeValue": "${unpinned_node}",
  "unpinnedNpmValue": "${unpinned_npm}"
}
JSON
cat "$out/summary.json"
