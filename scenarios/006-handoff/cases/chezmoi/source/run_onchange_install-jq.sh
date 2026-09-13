#!/bin/sh
# chezmoi は設定ファイルを配るもので、ツールの実体は持たない。
# 版を固定して入れるには、こうして自分でスクリプトを書くことになる。
set -eu
v=1.8.1
case "$(uname -s)" in Darwin) os=macos ;; *) os=linux ;; esac
case "$(uname -m)" in arm64|aarch64) arch=arm64 ;; *) arch=amd64 ;; esac
mkdir -p "$HOME/bin"
curl -fsSL -o "$HOME/bin/jq" \
  "https://github.com/jqlang/jq/releases/download/jq-$v/jq-$os-$arch"
chmod 0755 "$HOME/bin/jq"
