#!/usr/bin/env bash
# mode: M0
# 要るもの: mise のみ（追加の道具は不要）
#
# 測ること: sources / outputs で飛ばされたときに mise が実際に何と言うか。
#           そして「出力を消したら」どうなるか。
#
#   fresh    … sources / outputs だけ（更新時刻の比較）
#   artifact … さらに cache = { enabled = true } を足したもの（experimental）
#
#   公式は 2 つを別の機構として並べている
#   （docs/tasks/caching.md の冒頭表: Freshness checks / Artifact cache）。
#   前者は「出力をそのまま残して飛ばす」、後者は「消された出力を復元する」。
#
# 前回の状態を持ち越さない: 毎回 dist/ とキャッシュを消してから測る。
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
rm -rf "$out"; mkdir -p "$out"

# 🔴 キャッシュも隔離する。isolate.sh が遮るのは「設定ファイル」だけで、
#    タスクの成果物キャッシュは MISE_CACHE_DIR（既定はホーム配下）に残り、
#    測り直しても 1 回目からヒットする。実際にこの測定で起きた。
tmp_cache="$(mktemp -d)"
trap 'rm -rf "$tmp_cache"' EXIT
export MISE_CACHE_DIR="$tmp_cache/cache"
export MISE_TASK_CACHE_DIR="$tmp_cache/task-cache"

iso() { bash "$repo/scripts/isolate.sh" "$here/cases/$1" "${@:2}"; }

for c in fresh artifact artifact-noexp; do
  rm -rf "$here/cases/$c/dist"
  iso "$c" trust >/dev/null 2>&1 || true
done

# --- freshness だけの場合 -------------------------------------------------
iso fresh run build > "$out/fresh-1.txt" 2>&1 || true   # 1 回目: 走る
iso fresh run build > "$out/fresh-2.txt" 2>&1 || true   # 2 回目: 入力が変わらない
rm -rf "$here/cases/fresh/dist"
iso fresh run build > "$out/fresh-3.txt" 2>&1 || true   # 3 回目: 出力を消した直後

# --- 成果物キャッシュを有効にした場合 -------------------------------------
iso artifact run build > "$out/art-1.txt" 2>&1 || true
rm -rf "$here/cases/artifact/dist"
iso artifact run build > "$out/art-2.txt" 2>&1 || true  # 出力を消した直後
art_restored=$([ -f "$here/cases/artifact/dist/app.txt" ] && echo true || echo false)

# --- experimental を立てずに同じことを書いた場合 ---------------------------
rm -rf "$here/cases/artifact-noexp/dist"
if iso artifact-noexp run build > "$out/noexp.txt" 2>&1; then noexp_ok=true; else noexp_ok=false; fi

# 🔴 判定を出力文言に寄せない。
#    成果物キャッシュがヒットすると mise は「捕まえておいたログを再生する」ため、
#    BUILT の行はキャッシュヒットのときにも出る（docs/tasks/caching.md:
#    "Restores declared outputs and replays captured logs"）。
#    実際に走ったかどうかは、mise がコマンドを表示する "[build] $ " の行で見る。
ran()  { grep -q '^\[build\] \$ ' "$out/$1" && echo true || echo false; }
built() { grep -q '^BUILT$' "$out/$1" && echo true || echo false; }
hit()  { grep -q 'restored outputs from cache' "$out/$1" && echo true || echo false; }

# 飛ばされたときの行を、文言そのものとして取り出す
skip_line="$(grep -iE 'up-to-date|skip' "$out/fresh-2.txt" | head -1 | sed 's/"/\\"/g' || true)"
printf '%s\n' "$skip_line" > "$out/skip-line.txt"

cat > "$out/summary.json" <<JSON
{
  "freshFirstBuilds": $(built fresh-1.txt),
  "freshSecondBuilds": $(built fresh-2.txt),
  "freshSecondRuns": $(ran fresh-2.txt),
  "freshSkipLine": "$skip_line",
  "freshRebuildsWhenOutputDeleted": $(built fresh-3.txt),
  "artifactFirstRuns": $(ran art-1.txt),
  "artifactSecondRuns": $(ran art-2.txt),
  "artifactSecondHitsCache": $(hit art-2.txt),
  "artifactSecondPrintsBuiltAnyway": $(built art-2.txt),
  "artifactRestoresDeletedOutput": $art_restored,
  "artifactWithoutExperimentalSucceeds": $noexp_ok,
  "artifactWithoutExperimentalErrors": $(grep -q 'artifact caching is experimental' "$out/noexp.txt" && echo true || echo false)
}
JSON
cat "$out/summary.json"
