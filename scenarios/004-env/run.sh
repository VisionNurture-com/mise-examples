#!/usr/bin/env bash
# mode: M1
# 要るもの: mise（v2026.9.0 以上）
#
# 測ること: [env] の 7 つの書き方が、それぞれ何を変えるか。
#
#   basic     … 変数をそのまま書く
#   file      … _.file で .env を読む
#   path      … _.path で PATH にディレクトリを足す
#   source    … _.source でシェルスクリプトを読む
#   redact    … redactions でタスク実行時の出力をマスクする
#   required  … required = true で未設定を検出する
#   envswitch … MISE_ENV で環境別ファイルへ切り替える
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
rm -rf "$out"; mkdir -p "$out"

iso() { bash "$repo/scripts/isolate.sh" "$here/cases/$1" "${@:2}"; }

for c in basic file path source redact required envswitch; do
  iso "$c" trust >/dev/null 2>&1 || true
done

iso basic env  > "$out/basic.txt"  2>&1 || true
iso file env   > "$out/file.txt"   2>&1 || true
iso path env   > "$out/path.txt"   2>&1 || true
iso source env > "$out/source.txt" 2>&1 || true
iso redact run show > "$out/redact.txt" 2>&1 || true

# required は失敗することが観測対象なので、終了コードを拾う
if iso required env > "$out/required.txt" 2>&1; then required_fails=false; else required_fails=true; fi

# MISE_ENV は isolate.sh の外から渡す（環境変数はそのまま引き継がれる）
iso envswitch env > "$out/envswitch-base.txt" 2>&1 || true
MISE_ENV=production iso envswitch env > "$out/envswitch-prod.txt" 2>&1 || true

# 親の設定が届くかは「ツール」で見る。mise env は環境変数しか出さないため、
# ここで mise env を使うと親の [tools] を取りこぼす。
( cd "$here/cases/basic" && mise ls --current > "$out/naive.txt" 2>&1 || true )

has() { grep -qE "$2" "$out/$1" && echo true || echo false; }
value_of() { sed -n "s/^export APP_ENV=['\"]*\([a-z]*\)['\"]*$/\1/p" "$out/$1" | head -1; }

cat > "$out/summary.json" <<JSON
{
  "basicSet": $(has basic.txt '^export GREETING=.?hello'),
  "fileSet": $(has file.txt '^export FROM_FILE=.?yes'),
  "pathAdded": $(grep -q "cases/path/bin" "$out/path.txt" && echo true || echo false),
  "sourceSet": $(has source.txt '^export FROM_SOURCE=.?yes'),
  "redactedInRun": $(has redact.txt 'API_KEY=\[redacted\]'),
  "plainInRun": $(has redact.txt 'PUBLIC_URL=https://example\.com'),
  "requiredFails": $required_fails,
  "envDefault": "$(value_of envswitch-base.txt)",
  "envProduction": "$(value_of envswitch-prod.txt)",
  "naiveSeesParent": $(grep -qE '^jq[[:space:]]' "$out/naive.txt" && echo true || echo false)
}
JSON
cat "$out/summary.json"
