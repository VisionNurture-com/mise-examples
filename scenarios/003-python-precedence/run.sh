#!/usr/bin/env bash
# mode: M1
# 要るもの: mise（v2026.9.0 以上）
#
# 測ること: Python の版を宣言する場所が 2 つあるとき、どちらが効くか。
#
#   misetoml-wins   … mise.toml [tools] = 3.13 と .python-version = 3.12 が食い違う
#   idiomatic-only  … .python-version = 3.12 だけ（対照）
#   plural          … .python-versions（複数形・1 行目 3.13 / 2 行目 3.12）
#
# 🔴 mise を入れずに解決版だけを見る。処理系はダウンロードしない
#    （`mise ls --current` は宣言の解決結果を出すため、install は要らない）。
#
# 🔴 版は完全指定（3.13.13）にする。マイナー指定（3.13）にすると、
#    003-python-sync が張る別名リンク（installs/python/3.13）が解決先になり、
#    同じ設定でも結果が 3.13.13 → 3.13 に変わる。
#    2026-09-12 に実際に起きた（シナリオを跨いだ汚染）。
#    ここで測りたいのは「どのファイルが勝つか」であって版の丸め方ではない。
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
rm -rf "$out"; mkdir -p "$out"

for case in misetoml-wins idiomatic-only plural; do
  bash "$repo/scripts/isolate.sh" "$here/cases/$case" trust >/dev/null 2>&1 || true
  bash "$repo/scripts/isolate.sh" "$here/cases/$case" ls --current > "$out/$case.txt" 2>&1 || true
done

# 解決された python の版を 1 つ取り出す（無ければ none）
pick() { grep -E '^python[[:space:]]' "$1" | awk '{print $2}' | head -1; }

conflict=$(pick "$out/misetoml-wins.txt"); conflict="${conflict:-none}"
only=$(pick "$out/idiomatic-only.txt");   only="${only:-none}"
plural=$(pick "$out/plural.txt");         plural="${plural:-none}"
plural_count=$(grep -cE '^python[[:space:]]' "$out/plural.txt" || true)

cat > "$out/summary.json" <<JSON
{
  "conflictResolved": "$conflict",
  "idiomaticOnlyResolved": "$only",
  "pluralResolved": "$plural",
  "pluralPythonLines": ${plural_count:-0},
  "measuredAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "miseVersion": "$(mise --version | awk '{print $1}')"
}
JSON
cat "$out/summary.json"
