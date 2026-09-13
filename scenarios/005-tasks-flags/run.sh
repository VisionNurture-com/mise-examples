#!/usr/bin/env bash
# mode: M0
# 要るもの: mise のみ（追加の道具は不要）
#
# 測ること: usage で宣言したブールフラグを「付けずに」実行したとき、
#           環境変数 usage_verbose がどうなるか。宣言のしかたで変わるか。
#
#   flags        … flag "-v --verbose"（default を書かない）
#   flagsdefault … flag "-v --verbose" default="false"（default を書く）
#
#   公式は「非空文字列 "false" も ${var:+value} を満たすので、その展開は
#   フラグが有効かどうかの判定にはならない」と書いている
#   （docs/tasks/task-arguments.md §Conditional Flags）が、
#   どちらの宣言でそうなるのかは書いていない。そこを測る。
#
# 判定を値の見た目に寄せない: 空文字列と未設定を区別するため
#   printenv の終了コードで見る（未設定なら非 0）。
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
rm -rf "$out"; mkdir -p "$out"

iso() { bash "$repo/scripts/isolate.sh" "$here/cases/$1" "${@:2}"; }

for c in flags flagsdefault; do iso "$c" trust >/dev/null 2>&1 || true; done

iso flags        run probe           > "$out/absent.txt"         2>&1 || true
iso flags        run probe --verbose > "$out/present.txt"        2>&1 || true
iso flagsdefault run probe           > "$out/absent-default.txt" 2>&1 || true

val() { sed -n "s/^$2=//p" "$out/$1" | head -1; }
plus() { [ "$(val "$1" PLUS)" = "[YES]" ] && echo true || echo false; }

cat > "$out/summary.json" <<JSON
{
  "absentIsSet": $(val absent.txt SET),
  "absentValue": "$(val absent.txt VALUE)",
  "absentPlusExpands": $(plus absent.txt),
  "absentDashDefault": "$(val absent.txt DASH)",
  "presentValue": "$(val present.txt VALUE)",
  "presentPlusExpands": $(plus present.txt),
  "defaultDeclaredIsSet": $(val absent-default.txt SET),
  "defaultDeclaredValue": "$(val absent-default.txt VALUE)",
  "defaultDeclaredPlusExpands": $(plus absent-default.txt)
}
JSON
cat "$out/summary.json"
