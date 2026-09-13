#!/usr/bin/env bash
# `mise ls --current` の出力から、有効になっているツールの数を数える。
#
# 🔴 grep -c は 0 件のときも "0" を出したうえで終了コード 1 を返す。
#    `|| echo 0` を足すと 0 が 2 行出る。終了コードだけを握りつぶす。
set -euo pipefail
n="$(grep -cE '^[a-zA-Z0-9_-]+[[:space:]]+' "$1" || true)"
echo "${n:-0}"
