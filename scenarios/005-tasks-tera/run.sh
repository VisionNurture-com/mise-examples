#!/usr/bin/env bash
# mode: M0
# 要るもの: mise のみ（追加の道具は不要）
#
# 測ること: 引数を Tera テンプレート関数で書いたタスクを実行したとき、
#           非推奨の警告が出るか。出るなら、その警告が指す「廃止される版」は何か。
#
#   tera  … run = 'echo "Hello, {{arg(name="who")}}"'（非推奨の書き方）
#   usage … 同じことを usage フィールドで書いたもの（陽性対照。ここで警告が出たら測定が壊れている）
#
# なぜ版を測るか: 公式ドキュメントは 2026-06-16 に廃止版を 2026.11.0 → 2027.5.0 へ
#   訂正している（jdx/mise#10453「CLI と食い違うので合わせた」）。
#   ドキュメントは実装とずれうるため、版は CLI の実出力から取る。
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
rm -rf "$out"; mkdir -p "$out"

iso() { bash "$repo/scripts/isolate.sh" "$here/cases/$1" "${@:2}"; }

for c in tera usage; do iso "$c" trust >/dev/null 2>&1 || true; done

# 警告の出力先（stdout / stderr）が分からないため両方を捕まえる。
iso tera  run greet Taro > "$out/tera.txt"  2>&1 || true
iso usage run greet Taro > "$out/usage.txt" 2>&1 || true

warn_line="$(grep -i 'deprecat' "$out/tera.txt" | head -1 || true)"
printf '%s\n' "$warn_line" > "$out/warn-line.txt"

# 警告行に現れる「YYYY.M.P」形式の版をすべて拾う
versions="$(printf '%s' "$warn_line" | grep -oE '20[0-9]{2}\.[0-9]+\.[0-9]+' | paste -sd, - || true)"

has_warn=$([ -n "$warn_line" ] && echo true || echo false)
ctl_warn=$(grep -qi 'deprecat' "$out/usage.txt" && echo true || echo false)
tera_ok=$(grep -q 'Hello, Taro' "$out/tera.txt" && echo true || echo false)
usage_ok=$(grep -q 'Hello, Taro' "$out/usage.txt" && echo true || echo false)

cat > "$out/summary.json" <<JSON
{
  "teraWarns": $has_warn,
  "teraWarnVersions": "$versions",
  "controlUsageWarns": $ctl_warn,
  "teraStillWorks": $tera_ok,
  "usageWorks": $usage_ok
}
JSON
cat "$out/summary.json"
