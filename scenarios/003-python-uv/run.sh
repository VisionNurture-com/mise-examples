#!/usr/bin/env bash
# mode: M2
# 要るもの: mise（v2026.9.0 以上）/ uv（v0.12 以上）/ ネットワーク
#
# 測ること: `python.uv_venv_auto = "source"` が効く条件と、効いたときに python が何を指すか。
#
#   nolock   … .venv はあるが uv.lock が無い（公式は「無ければ何もしない」と書く）
#   withlock … uv.lock がある（uv sync 済み）
#   seq      … 記事 sec04-05 の手順を書かれた順のまま踏み、uv sync 直後に python を見る
#
# 🔴 ケースは毎回作り直す（前回の .venv / uv.lock が残ると条件が混ざる）。
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
# 🔴 ケースは実行のたびに作る「生成物」なので results/ の下に置く。
#    cases/ に置くと uv init が書く pyproject.toml（作者のメールアドレス）や
#    .venv の絶対パスがリポジトリへ入る（2026-09-12 に check:neutrality が検出）。
cases="$out/work"
rm -rf "$out"; mkdir -p "$out" "$cases"

PYV="3.13"
iso() { bash "$repo/scripts/isolate.sh" "$@"; }
# 隔離したまま任意のコマンドを走らせる（uv 自身を呼ぶため）
raw() {
  local dir="$1"; shift
  ( cd "$dir" && MISE_CEILING_PATHS="$(cd "$dir/.." && pwd)" \
      MISE_GLOBAL_CONFIG_FILE="$repo/empty.toml" "$@" )
}
# mise 越しに .venv の解決先を見る
whichpy() {
  iso "$1" exec -- python -c 'import sys; print(sys.executable)' 2>&1 | tail -1
}

mktoml() {
  cat > "$1/mise.toml" <<TOML
[tools]
python = "$PYV"

[settings]
python.uv_venv_auto = "source"
TOML
}

### nolock: .venv はあるが uv.lock が無い
mkdir -p "$cases/nolock"; mktoml "$cases/nolock"
iso "$cases/nolock" trust >/dev/null 2>&1 || true
raw "$cases/nolock" uv venv --python "$PYV" > "$out/nolock-venv.txt" 2>&1 || true
whichpy "$cases/nolock" > "$out/nolock.txt" 2>&1 || true
nolock_has_lock=$([ -f "$cases/nolock/uv.lock" ] && echo true || echo false)
nolock_has_venv=$([ -d "$cases/nolock/.venv" ] && echo true || echo false)

### withlock: uv init + uv add で uv.lock を作る
mkdir -p "$cases/withlock"; mktoml "$cases/withlock"
iso "$cases/withlock" trust >/dev/null 2>&1 || true
raw "$cases/withlock" uv init --no-workspace  > "$out/withlock-init.txt" 2>&1 || true
raw "$cases/withlock" uv add requests         > "$out/withlock-add.txt"  2>&1 || true
whichpy "$cases/withlock" > "$out/withlock.txt" 2>&1 || true
withlock_has_lock=$([ -f "$cases/withlock/uv.lock" ] && echo true || echo false)

### seq: 記事 sec04-05 の順のまま（mise.toml は uv init のあとに追記する）
mkdir -p "$cases/seq"
iso "$cases/seq" use "python@$PYV" > "$out/seq-use.txt" 2>&1 || true
raw "$cases/seq" uv init --no-workspace > "$out/seq-init.txt" 2>&1 || true
raw "$cases/seq" uv add requests        > "$out/seq-add.txt"  2>&1 || true
cat >> "$cases/seq/mise.toml" <<'TOML'

[settings]
python.uv_venv_auto = "source"
TOML
iso "$cases/seq" trust >/dev/null 2>&1 || true
raw "$cases/seq" uv sync > "$out/seq-sync.txt" 2>&1 || true
whichpy "$cases/seq" > "$out/seq.txt" 2>&1 || true

inv() { grep -q '/\.venv/bin/python' "$1" && echo true || echo false; }

cat > "$out/summary.json" <<JSON
{
  "nolockHasUvLock": $nolock_has_lock,
  "nolockHasVenv": $nolock_has_venv,
  "nolockSourcedVenv": $(inv "$out/nolock.txt"),
  "withlockHasUvLock": $withlock_has_lock,
  "withlockSourcedVenv": $(inv "$out/withlock.txt"),
  "seqSourcedVenv": $(inv "$out/seq.txt"),
  "measuredAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "miseVersion": "$(mise --version | awk '{print $1}')",
  "uvVersion": "$(uv --version | awk '{print $2}')"
}
JSON
cat "$out/summary.json"
