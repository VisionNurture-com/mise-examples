#!/usr/bin/env bash
# mode: M1
# 要るもの: mise（v2026.9.0 以上）・ネットワーク（aube を取りに行く）・npm（lockfile を先に作る）
#
# 測ること: 公式が 2026-09 に node のページへ載せた aube を、既存の npm プロジェクトで走らせる。
#           既存の package-lock.json は書き換わるのか。公式の例どおりに動くのか。
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
rm -rf "$out"; mkdir -p "$out/work"
cp "$here/cases/project/package.json" "$here/cases/project/mise.toml" "$out/work/"
w="$out/work"
m() { bash "$repo/scripts/isolate.sh" "$w" "$@"; }

# sha256 の取り方は macOS と Linux で違う。どちらでも同じ形で取る。
sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi; }

m trust >/dev/null 2>&1 || true
m install > "$out/install.log" 2>&1

# 先に npm で lockfile を作る。aube が「既存の lockfile をそのまま読む」かを測るため。
( cd "$w" && npm install --package-lock-only > "$out/npm.log" 2>&1 )
before=$(sha "$w/package-lock.json")

m exec -- aube --version > "$out/version.txt" 2>&1 || true
aube_installed=$(grep -qE '^[0-9]+\.[0-9]+\.[0-9]+' "$out/version.txt" && echo true || echo false)

# 公式 docs/lang/node.md の例は `mise exec -- aubr test` と書いている。そのまま試す。
aubr_rc=0
m exec -- aubr --version > "$out/aubr-via-mise.log" 2>&1 || aubr_rc=$?
aubr_on_path=$([ "$aubr_rc" -eq 0 ] && echo true || echo false)

# 実体の隣には aubr がある。直に叩けば動くのかを分けて測る。
root=$(m where aube 2>/dev/null | tr -d '\r')
aubr_direct=false
if [ -x "$root/aubr" ]; then
  "$root/aubr" --version > "$out/aubr-direct.log" 2>&1 && aubr_direct=true
fi

m exec -- aube install > "$out/aube-install.log" 2>&1
after=$(sha "$w/package-lock.json")
lockfile_unchanged=$([ "$before" = "$after" ] && echo true || echo false)
installed=$([ -d "$w/node_modules/left-pad" ] && echo true || echo false)

cat > "$out/summary.json" <<JSON
{
  "aubeInstalled": ${aube_installed},
  "aubrOnPath": ${aubr_on_path},
  "aubrDirectWorks": ${aubr_direct},
  "lockfileUnchanged": ${lockfile_unchanged},
  "installedFromExistingLock": ${installed}
}
JSON
cat "$out/summary.json"
