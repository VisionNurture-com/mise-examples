#!/usr/bin/env bash
# mode: M1
# 要るもの: mise（v2026.9.0 以上）
#
# 測ること: idiomatic な版ファイルを有効にしたとき、どのファイルが勝つか。
#
#   both             … .nvmrc(22) と package.json の devEngines(24.x) の両方を置く
#   both-disabled    … 上に加えて package.json だけを個別に無効化する
#   pkgjson          … package.json だけを置く
#   pkgjson-disabled … package.json だけを置き、それを無効化する（何も残らない）
#
# 🔴 「.nvmrc を有効にした」＝「.nvmrc が読まれる」ではない。同じ設定で
#    package.json の devEngines も一緒に有効になり、そちらが先に効く。
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
rm -rf "$out"; mkdir -p "$out"

for case in both both-disabled pkgjson pkgjson-disabled; do
  bash "$repo/scripts/isolate.sh" "$here/cases/$case" trust >/dev/null 2>&1 || true
  bash "$repo/scripts/isolate.sh" "$here/cases/$case" ls --current > "$out/$case.txt" 2>&1 || true
done

# 「どの設定ファイルから来たか」の列だけを取る。
#
# 🔴 列の位置で取ってはいけない。mise は版が symlink のとき
#    `node  22.23.2 (symlink)  /path/.nvmrc  22` のように列を 1 つ増やす。
#    位置で取ると "(symlink)" を設定ファイル名として拾う（実際に 1 度やった）。
#    パスらしい列（"/" を含む最初の列）を探して、その末尾だけを名前とする。
source_of() {
  awk 'NR==1 { for (i = 1; i <= NF; i++) if ($i ~ /\//) { n = split($i, a, "/"); print a[n]; exit } }' "$1"
}

both_source=$(source_of "$out/both.txt")
both_disabled_source=$(source_of "$out/both-disabled.txt")
pkgjson_tools=$(bash "$repo/scripts/count-tools.sh" "$out/pkgjson.txt")
pkgjson_disabled_tools=$(bash "$repo/scripts/count-tools.sh" "$out/pkgjson-disabled.txt")

cat > "$out/summary.json" <<JSON
{
  "bothSource": "${both_source}",
  "bothDisabledSource": "${both_disabled_source}",
  "pkgJsonTools": ${pkgjson_tools},
  "pkgJsonDisabledTools": ${pkgjson_disabled_tools}
}
JSON
cat "$out/summary.json"
