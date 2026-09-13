#!/usr/bin/env bash
# mode: M1
# 要るもの: mise（v2026.9.0 以上）
#
# 測ること:
#   (1) [tools] に書いた場合と書かない場合で、有効になるツールがどう変わるか
#   (2) 親ディレクトリの設定が、遮らないと下へ届いてしまうこと
#
# なぜ (2) を測るか:
#   mise は設定を親ディレクトリへ遡って読む。遮らずに測ると「書かない場合」にも
#   ツールが出てしまい、比較が成立しない。cases/mise.toml をわざと置いて、
#   遮った場合と遮らない場合の差そのものを観測する。
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
rm -rf "$out"; mkdir -p "$out"

for case in with without; do
  bash "$repo/scripts/isolate.sh" "$here/cases/$case" trust >/dev/null 2>&1 || true
  bash "$repo/scripts/isolate.sh" "$here/cases/$case" ls --current > "$out/$case.txt" 2>&1 || true
done

# 遮らずに測る（親の設定が届くことの確認）
( cd "$here/cases/without" && mise ls --current > "$out/naive.txt" 2>&1 || true )

with=$(bash "$repo/scripts/count-tools.sh" "$out/with.txt")
without=$(bash "$repo/scripts/count-tools.sh" "$out/without.txt")
naive_sees_parent=$(grep -qE '^jq[[:space:]]' "$out/naive.txt" && echo true || echo false)

cat > "$out/summary.json" <<JSON
{
  "withTools": $with,
  "withoutTools": $without,
  "naiveSeesParent": $naive_sees_parent
}
JSON
cat "$out/summary.json"
