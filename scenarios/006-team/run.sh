#!/usr/bin/env bash
# mode: M1
# 要るもの: mise（v2026.9.0 以上）・ネットワーク（署名済みマニフェストの取得）
#
# 測ること: 同じ設定を渡された別のマシンで、同じものが入るか。
#
#   lockon/lockoff … lockfile = true で mise.lock が生まれるか
#   localovr       … mise.local.toml が共有設定を上書きするか
#   trustpath      … 信頼するパスを宣言すると trust の確認を省けるか
#   signed         … 署名済みマニフェスト（packslip）から入るか
#   stamper        … 承認していないスタンパーを要求すると止まるか
#   toolversions   … asdf 互換の .tool-versions を設定なしで読むか
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
rm -rf "$out"; mkdir -p "$out"

iso() { bash "$repo/scripts/isolate.sh" "$here/cases/$1" "${@:2}"; }

for c in lockon lockoff localovr signed stamper toolversions; do
  iso "$c" trust >/dev/null 2>&1 || true
done

# lockfile — 前回の生成物が残っていると差が出ないので消す
rm -f "$here/cases/lockon/mise.lock" "$here/cases/lockoff/mise.lock"
iso lockon install  > "$out/lockon.txt"  2>&1 || true
iso lockoff install > "$out/lockoff.txt" 2>&1 || true

iso localovr env > "$out/localovr.txt" 2>&1 || true

# trustpath は「trust していない状態」で測る。信頼するパスの宣言だけで読めるか。
# 🔴 CI では、信頼の確認を飛ばす条件が 3 つ重なる。
#      MISE_TRUSTED_CONFIG_PATHS … そのパスの下を信頼済みとして扱う（action が設定）
#      MISE_YES=1                … 確認そのものを省く（action が設定）
#      CI                        … 立っているだけで確認を省く（値は見ていない・実測）
#    そのままだと「信頼していない状態」を作れないため、この 1 回だけ 3 つとも外す。
if env -u MISE_TRUSTED_CONFIG_PATHS -u MISE_YES -u CI -u GITHUB_ACTIONS bash -c 'bash "$0" "$1" env' "$repo/scripts/isolate.sh" "$here/cases/trustpath" > "$out/trust-off.txt" 2>&1; then trust_off_ok=true; else trust_off_ok=false; fi
if MISE_TRUSTED_CONFIG_PATHS="$here/cases/trustpath" iso trustpath env > "$out/trust-on.txt" 2>&1; then trust_on_ok=true; else trust_on_ok=false; fi

# 署名済みマニフェスト — 毎回入れ直して署名検証そのものを通す
iso signed uninstall "packslip:github.com/jdx/hk@1.58.1" >/dev/null 2>&1 || true
if iso signed install > "$out/signed.txt" 2>&1; then signed_ok=true; else signed_ok=false; fi

iso stamper uninstall "packslip:github.com/jdx/hk@1.58.1" >/dev/null 2>&1 || true
if iso stamper install > "$out/stamper.txt" 2>&1; then stamper_blocks=false; else stamper_blocks=true; fi

iso toolversions ls --current > "$out/toolversions.txt" 2>&1 || true
( cd "$here/cases/lockon" && mise ls --current > "$out/naive.txt" 2>&1 || true )

exists() { [ -f "$here/cases/$1/mise.lock" ] && echo true || echo false; }
has() { grep -qE "$2" "$out/$1" && echo true || echo false; }

cat > "$out/summary.json" <<JSON
{
  "lockCreatedWhenEnabled": $(exists lockon),
  "lockCreatedWhenNotEnabled": $(exists lockoff),
  "localOverrides": $(has localovr.txt '^export WHO=.?me'),
  "readableWithoutTrust": $trust_off_ok,
  "readableWithTrustedPath": $trust_on_ok,
  "signedInstallSucceeds": $signed_ok,
  "unapprovedStamperBlocks": $stamper_blocks,
  "toolVersionsRead": $(grep -cE '^node[[:space:]]' "$out/toolversions.txt" || true),
  "naiveSeesParent": $(grep -qE '^jq[[:space:]]' "$out/naive.txt" && echo true || echo false)
}
JSON
cat "$out/summary.json"
