#!/usr/bin/env bash
# mode: M1
# 要るもの: mise（v2026.9.0 以上）・ネットワーク（node の取得）
#
# 測ること: CI で mise を使うときに効いてくる 3 点。
#
#   1. install が冪等か（2 回目は入れ直さないか）
#   2. 対話できない環境で、信頼するパスの宣言だけで設定を読めるか
#   3. タスク経由で [env] が実際に渡るか
#
# なお jdx/mise-action そのものは、このリポジトリの .github/workflows/verify.yml が
# 毎回の CI で実際に使っている。ここで測るのは action の内側で起きることのほう。
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
rm -rf "$out"; mkdir -p "$out"

iso() { bash "$repo/scripts/isolate.sh" "$here/cases/$1" "${@:2}"; }

# 1 回目は trust を通してから入れる
iso project trust >/dev/null 2>&1 || true
iso project install > "$out/install1.txt" 2>&1 || true
iso project install > "$out/install2.txt" 2>&1 || true

# 対話できない状況を作る: 信頼を取り消したうえで、宣言だけで読めるかを見る
iso project trust --untrust >/dev/null 2>&1 || true
# 🔴 CI では、信頼の確認を飛ばす条件が 3 つ重なる。
#      MISE_TRUSTED_CONFIG_PATHS … そのパスの下を信頼済みとして扱う（action が設定）
#      MISE_YES=1                … 確認そのものを省く（action が設定）
#      CI                        … 立っているだけで確認を省く（値は見ていない・実測）
#    そのままだと「信頼していない状態」を作れないため、この 1 回だけ 3 つとも外す。
if env -u MISE_TRUSTED_CONFIG_PATHS -u MISE_YES -u CI -u GITHUB_ACTIONS bash -c 'bash "$0" "$1" env' "$repo/scripts/isolate.sh" "$here/cases/project" > "$out/untrusted.txt" 2>&1; then untrusted_ok=true; else untrusted_ok=false; fi
if MISE_TRUSTED_CONFIG_PATHS="$here/cases/project" iso project env > "$out/declared.txt" 2>&1; then declared_ok=true; else declared_ok=false; fi

MISE_TRUSTED_CONFIG_PATHS="$here/cases/project" iso project run ci > "$out/task.txt" 2>&1 || true
( cd "$here/cases/project" && mise ls --current > "$out/naive.txt" 2>&1 || true )

has() { grep -qE "$2" "$out/$1" && echo true || echo false; }

cat > "$out/summary.json" <<JSON
{
  "secondInstallIsNoop": $(has install2.txt 'already installed'),
  "readableWithoutTrust": $untrusted_ok,
  "readableWithDeclaredPath": $declared_ok,
  "envReachesTask": $(has task.txt 'NODE_ENV=test'),
  "naiveSeesParent": $(grep -qE '^jq[[:space:]]' "$out/naive.txt" && echo true || echo false)
}
JSON
cat "$out/summary.json"
