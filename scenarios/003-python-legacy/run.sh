#!/usr/bin/env bash
# mode: M2
# 要るもの: mise（v2026.9.0 以上）/ uv（v0.12 以上）/ ネットワーク
#
# 測ること: レガシー値 `python.uv_venv_auto = true` を今のmiseに与えると何が起きるか。
#
#   legacy … true を設定（公式は 2026.7.0 から警告し 2027.7.0 で削除すると書く）
#   string … "create|source" を設定（対照）
#
# 判定は警告の「文面」ではなく **警告行の有無** と **UV_PYTHON の値の形**で行う。
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
# 🔴 ケースは生成物なので results/ の下に置く（uv init が実在のメールアドレスを書くため）。
cases="$out/work"
rm -rf "$out"; mkdir -p "$out" "$cases"

PYV="3.13.13"
iso() { bash "$repo/scripts/isolate.sh" "$@"; }
raw() { local d="$1"; shift; ( cd "$d" && MISE_CEILING_PATHS="$(cd "$d/.." && pwd)" \
        MISE_GLOBAL_CONFIG_FILE="$repo/empty.toml" "$@" ); }

setup() { # $1=case  $2=uv_venv_auto の値（TOML リテラル）
  local d="$cases/$1"; mkdir -p "$d"
  cat > "$d/mise.toml" <<TOML
[tools]
python = "$PYV"

[settings]
python.uv_venv_auto = $2
TOML
  iso "$d" trust >/dev/null 2>&1 || true
  raw "$d" uv init --no-workspace >/dev/null 2>&1 || true
  raw "$d" uv add requests        >/dev/null 2>&1 || true
}

setup legacy true
setup string '"create|source"'

for c in legacy string; do
  # env の生出力（stderr も含めて取る = 警告を落とさない）
  iso "$cases/$c" env > "$out/$c-env.txt" 2>"$out/$c-stderr.txt" || true
  iso "$cases/$c" exec -- python -c 'import sys; print(sys.executable)' \
      > "$out/$c-python.txt" 2>>"$out/$c-stderr.txt" || true
done

# UV_PYTHON の値を取り出す
# 🔴 grep は 0 件で rc=1 を返す。set -e 下では握りつぶさないとここで落ちる。
uvpy() { (grep -E '^(export )?UV_PYTHON=' "$1" || true) | head -1 | sed 's/^export //; s/^UV_PYTHON=//' ; }
lg=$(uvpy "$out/legacy-env.txt"); lg="${lg:-none}"
st=$(uvpy "$out/string-env.txt"); st="${st:-none}"

# 警告「行」を数える（文面では判定しない）
warnlines() { grep -ciE '(deprecat|WARN)' "$1" || true; }

# UV_PYTHON が版番号だけか実パスか
shape() { case "$1" in none) echo none;; /*) echo path;; *) echo version;; esac; }

cat > "$out/summary.json" <<JSON
{
  "legacyUvPython": "$lg",
  "legacyUvPythonShape": "$(shape "$lg")",
  "stringUvPython": "$st",
  "legacyWarnLines": $(warnlines "$out/legacy-stderr.txt"),
  "stringWarnLines": $(warnlines "$out/string-stderr.txt"),
  "legacySourcedVenv": $(grep -q '/\.venv/bin/python' "$out/legacy-python.txt" && echo true || echo false),
  "stringSourcedVenv": $(grep -q '/\.venv/bin/python' "$out/string-python.txt" && echo true || echo false),
  "measuredAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "miseVersion": "$(mise --version | awk '{print $1}')",
  "uvVersion": "$(uv --version | awk '{print $2}')"
}
JSON
cat "$out/summary.json"
