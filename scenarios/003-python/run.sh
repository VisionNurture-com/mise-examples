#!/usr/bin/env bash
# mode: M1
# 要るもの: mise（v2026.9.0 以上）
#
# 測ること: pyenv から引き継いだ `.python-version` を mise が読むかどうか。
#
#   default      … 何も設定しない（既定のまま）
#   enabled      … idiomatic_version_file_enable_tools に "python" を入れる
#   toolversions … asdf 互換の .tool-versions を置く
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
rm -rf "$out"; mkdir -p "$out"

for case in default enabled toolversions; do
  bash "$repo/scripts/isolate.sh" "$here/cases/$case" trust >/dev/null 2>&1 || true
  bash "$repo/scripts/isolate.sh" "$here/cases/$case" ls --current > "$out/$case.txt" 2>&1 || true
done

( cd "$here/cases/default" && mise ls --current > "$out/naive.txt" 2>&1 || true )

d=$(bash "$repo/scripts/count-tools.sh" "$out/default.txt")
e=$(bash "$repo/scripts/count-tools.sh" "$out/enabled.txt")
t=$(bash "$repo/scripts/count-tools.sh" "$out/toolversions.txt")
naive_sees_parent=$(grep -qE '^jq[[:space:]]' "$out/naive.txt" && echo true || echo false)

cat > "$out/summary.json" <<JSON
{
  "defaultTools": $d,
  "enabledTools": $e,
  "toolVersionsTools": $t,
  "naiveSeesParent": $naive_sees_parent
}
JSON
cat "$out/summary.json"
