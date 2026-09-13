#!/usr/bin/env bash
# mise を「そのディレクトリの設定だけ」で走らせる。
#
# なぜ要るか:
#   mise は設定ファイルを親ディレクトリへ遡って読む。何もしないと、
#   実行した人のホームにある ~/.config/mise/config.toml や ~/.tool-versions が
#   混ざり、「設定を入れた場合 / 入れない場合」の比較が成立しない。
#
# 何をしているか（2 つとも要る）:
#   MISE_CEILING_PATHS   … 指定したパス "自身を含めて" そこから上を読まなくなる。
#                          したがって遮りたいディレクトリの "親" ではなく、
#                          測りたいディレクトリの "親" を渡す。
#   MISE_GLOBAL_CONFIG_FILE … 上の指定だけではホームのグローバル設定が残るため、
#                          空のファイルへ向けて無効にする。
#
#   なお mise は "実行時のカレントディレクトリ" から設定を探すため、
#   このスクリプトは測るディレクトリへ cd してから mise を呼ぶ。
#
# 使い方: isolate.sh <測るディレクトリ> <mise に渡す引数...>
set -euo pipefail

target="${1:?測るディレクトリを渡してください}"
shift

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
parent="$(cd "$target/.." && pwd)"

cd "$target"

MISE_CEILING_PATHS="$parent" \
MISE_GLOBAL_CONFIG_FILE="$repo/empty.toml" \
  mise "$@"
