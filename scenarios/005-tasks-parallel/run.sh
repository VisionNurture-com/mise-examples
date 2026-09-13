#!/usr/bin/env bash
# mode: M0
# 要るもの: mise のみ（追加の道具は不要）
#
# 測ること: depends に並べたタスクは「同時に何本まで」走るか。
#
#   公式は「Tasks run with a maximum of four parallel jobs by default」と書き、
#   --jobs / jobs 設定 / MISE_JOBS で変えられるとしている
#   （docs/tasks/running-tasks.md §Parallelism and output）。
#   依存を 6 本置いて、既定 / --jobs 2 / --jobs 8 の 3 通りで測る。
#
# 時計に頼らない: 各タスクが開始と終了を 1 行ずつ同じファイルへ追記し、
#   その「行の順序」だけで同時実行数を数える。秒未満の精度を要求しない。
#
# あわせて mise tasks deps の出力も取る（記事のトラブルシューティングの受け皿）。
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
case_dir="$here/cases/parallel"
out="$here/results"
rm -rf "$out"; mkdir -p "$out"

iso() { bash "$repo/scripts/isolate.sh" "$case_dir" "$@"; }

iso trust >/dev/null 2>&1 || true

# 実効の jobs 設定を先に記録する（グローバル設定が混ざっていないことの確認）
iso settings get jobs > "$out/jobs-setting.txt" 2>&1 || true

# 事象ログから同時実行数の最大値を数える
peak() {
  awk '
    /^START/ { c++; if (c > m) m = c }
    /^END/   { c-- }
    END      { print m + 0 }
  ' "$1"
}

run_case() {          # $1 = ラベル, 以降 = mise run に足す引数
  local label="$1"; shift
  rm -f "$case_dir/events.log"
  iso run "$@" main > "$out/$label.txt" 2>&1 || true
  cp "$case_dir/events.log" "$out/$label-events.log"
  rm -f "$case_dir/events.log"
  peak "$out/$label-events.log"
}

default_peak=$(run_case default)
jobs2_peak=$(run_case jobs2 --jobs 2)
jobs8_peak=$(run_case jobs8 --jobs 8)

iso tasks deps main > "$out/deps-main.txt" 2>&1 || true
iso tasks deps      > "$out/deps-all.txt"  2>&1 || true
deps_lines=$(grep -cE '[a-z]' "$out/deps-main.txt" || true)

# depends_post は「タスク名を指定した形」では出ず、「引数なしの形」でだけ出る
post_in_named=$(grep -q '(post)' "$out/deps-main.txt" && echo true || echo false)
post_in_all=$(grep -q '(post)' "$out/deps-all.txt" && echo true || echo false)

cat > "$out/summary.json" <<JSON
{
  "defaultPeakConcurrency": $default_peak,
  "jobs2PeakConcurrency": $jobs2_peak,
  "jobs8PeakConcurrency": $jobs8_peak,
  "depsGraphHasLines": $([ "$deps_lines" -gt 0 ] && echo true || echo false),
  "namedDepsShowsPost": $post_in_named,
  "allDepsShowsPost": $post_in_all
}
JSON
cat "$out/summary.json"
