#!/usr/bin/env bash
# mode: M1
# 要るもの: mise（v2026.9.0 以上）
#
# 測ること: [tasks] の 6 つの書き方が、それぞれ何を変えるか。
#
#   order       … depends / depends_post の実行順
#   filetask    … mise-tasks/ に置いた実行ファイルがタスクになるか
#   timeout     … timeout で打ち切られるか
#   usage       … usage で宣言した引数が受け取れるか
#   incremental … sources / outputs で入力が変わらないときに飛ばすか
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
rm -rf "$out"; mkdir -p "$out"

iso() { bash "$repo/scripts/isolate.sh" "$here/cases/$1" "${@:2}"; }

for c in order filetask timeout usage incremental; do
  iso "$c" trust >/dev/null 2>&1 || true
done

iso order run main > "$out/order.txt" 2>&1 || true
iso filetask run hello > "$out/filetask.txt" 2>&1 || true
if iso timeout run slow > "$out/timeout.txt" 2>&1; then timeout_fires=false; else timeout_fires=true; fi
iso usage run greet Taro > "$out/usage.txt" 2>&1 || true

# 差分実行は 2 回続けて走らせて比べる。前回の出力が残っていると 1 回目から飛ぶため消す。
rm -rf "$here/cases/incremental/dist"
iso incremental run build > "$out/incr1.txt" 2>&1 || true
iso incremental run build > "$out/incr2.txt" 2>&1 || true

( cd "$here/cases/order" && mise ls --current > "$out/naive.txt" 2>&1 || true )

# 実行順は、出力に現れた順に並べる
order="$(grep -oE '^(PREPARE|MAIN|CLEANUP)$' "$out/order.txt" | paste -sd, -)"
has() { grep -qE "$2" "$out/$1" && echo true || echo false; }

cat > "$out/summary.json" <<JSON
{
  "order": "$order",
  "fileTaskRuns": $(has filetask.txt '^FILE_TASK$'),
  "timeoutFires": $timeout_fires,
  "usageArgPassed": $(has usage.txt 'hello Taro'),
  "firstRunBuilds": $(has incr1.txt '^BUILT$'),
  "secondRunSkips": $(has incr2.txt 'up-to-date'),
  "naiveSeesParent": $(grep -qE '^jq[[:space:]]' "$out/naive.txt" && echo true || echo false)
}
JSON
cat "$out/summary.json"
