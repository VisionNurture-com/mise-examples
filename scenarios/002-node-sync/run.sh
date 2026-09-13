#!/usr/bin/env bash
# mode: M2
# 要るもの: mise（v2026.9.0 以上）・nvm（v0.40 系）・nvm で入れた node 20 系と 22 系
#
# 測ること: `mise sync node --nvm` は何をするのか。コピーなのか、リンクなのか。
#           そして元の nvm を消したらどうなるのか。
#
# 🔴 M2（機械依存・CI では測らない）。nvm はホームに置かれる大域の状態で、
#    scripts/isolate.sh では遮れない。CI の clean runner には nvm が無い。
#
# 🔴 mise の呼び出しは isolate.sh を通す。遮れるのは「設定の探索」だけで、
#    インストール先（~/.local/share/mise/installs）は遮られない。sync が
#    書くのはそちらなので、観測には影響しない。
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
rm -rf "$out"; mkdir -p "$out/work"
m() { bash "$repo/scripts/isolate.sh" "$out/work" "$@"; }

[ -s "$HOME/.nvm/nvm.sh" ] || { echo "nvm が要ります（M2）" >&2; exit 1; }

nvm_versions=$(ls "$HOME/.nvm/versions/node" | sed 's/^v//' | sort)
echo "$nvm_versions" > "$out/nvm-versions.txt"

# 前回の実行が残した同期結果を消して、同じ地点から測る
while read -r v; do m uninstall "node@$v" >/dev/null 2>&1 || true; done <<< "$nvm_versions"

m ls node > "$out/before.txt" 2>&1 || true
m sync node --nvm > "$out/sync.log" 2>&1
m ls node > "$out/after.txt" 2>&1 || true

synced_count=$(grep -c 'Synced node@' "$out/sync.log" || true)
marked_symlink=$(grep -c '(symlink)' "$out/after.txt" || true)
nvm_count=$(grep -c . "$out/nvm-versions.txt" || true)

# 🔴 件数そのものは突合キーにしない。nvm に何版入っているかは測る機械の状態で、
#    別のマシンで走らせた瞬間に食い違う（実際に 2 → 3 で壊れた）。
#    揺れる量はそのまま比べず、決定論的な代理量へ落とす。ここでは真偽値にする。
synced_all=$([ "$synced_count" = "$nvm_count" ] && echo true || echo false)
all_symlink=$([ "$marked_symlink" = "$synced_count" ] && echo true || echo false)

# 代表 1 版で「実体がどこを指すか」を見る
v=$(head -1 <<< "$nvm_versions")
where=$(m where "node@$v" 2>/dev/null | tr -d '\r')
echo "$where" > "$out/where.txt"
ls -ld "$where" > "$out/where-ls.txt" 2>&1 || true

where_points_at_mise=$(grep -q '/mise/installs/node/' "$out/where.txt" && echo true || echo false)
backing_is_nvm=$(grep -q '\-> .*/\.nvm/versions/node/' "$out/where-ls.txt" && echo true || echo false)

# 元の nvm 側を退避して、mise がどう見えるか・どう振る舞うかを測る（測り終えたら戻す）
mv "$HOME/.nvm/versions/node/v$v" "$HOME/.nvm/versions/node/v$v.moved"
m ls node > "$out/broken.txt" 2>&1 || true
broken_label=$(grep -c '(broken symlink)' "$out/broken.txt" || true)
m exec "node@$v" -- node --version > "$out/selfheal.log" 2>&1 || true
self_healed=$(grep -qE "^v$v$" "$out/selfheal.log" && echo true || echo false)
mv "$HOME/.nvm/versions/node/v$v.moved" "$HOME/.nvm/versions/node/v$v"

cat > "$out/summary.json" <<JSON
{
  "syncedAllNvmVersions": ${synced_all},
  "everySyncedIsSymlink": ${all_symlink},
  "nvmVersionCount": ${nvm_count},
  "syncedCount": ${synced_count},
  "markedSymlink": ${marked_symlink},
  "wherePointsAtMise": ${where_points_at_mise},
  "backingIsNvm": ${backing_is_nvm},
  "brokenLabelCount": ${broken_label},
  "selfHealed": ${self_healed}
}
JSON
cat "$out/summary.json"
