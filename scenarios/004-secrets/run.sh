#!/usr/bin/env bash
# mode: M1
# 要るもの: mise（v2026.9.0 以上）・ネットワーク（age / sops / fnox の取得）
#
# 測ること: 秘密の値を「どこに置くか」で何が変わるか。
#
#   plain … [env] に平文で書く
#   local … mise.local.toml で手元だけ上書きする
#   age   … 値そのものを mise.toml の中で暗号化する（Direct age・experimental）
#   sops  … 別ファイルを丸ごと暗号化して読む（experimental）
#   fnox  … 値を mise の設定に置かず、fnox が解決する（公式の推奨）
#
# 🔴 鍵はすべて results/work/ の中に作り、環境変数で明示的に指す。
#    指さないと mise も fnox も実行した人のホームの鍵を探すため、
#    「鍵が無い場合」を測っているつもりで他人の鍵で復号できてしまう。
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$here/results"
work="$out/work"

# 前回の出力を消す。残っていると、測定が落ちても突合が前回の値で緑を返す。
rm -rf "$out"; mkdir -p "$work"
cp -R "$here/cases/." "$work/"

iso() { bash "$repo/scripts/isolate.sh" "$work/$1" "${@:2}"; }

for c in plain local age sops fnox; do
  iso "$c" trust >/dev/null 2>&1 || true
done

# ---- plain: 平文をそのまま置く ----------------------------------------
iso plain env > "$out/plain.txt" 2>&1 || true

# ---- local: mise.local.toml が共有設定を上書きするか -------------------
iso local env > "$out/local.txt" 2>&1 || true
# mise が .gitignore を作るかどうかは「作られたファイルの有無」で見る
if [ -e "$work/local/.gitignore" ]; then mise_writes_gitignore=true; else mise_writes_gitignore=false; fi

# ---- age: 値を mise.toml の中で暗号化する ------------------------------
iso age install > "$out/age-install.txt" 2>&1
iso age exec -- age-keygen -o key.txt > "$out/age-keygen.txt" 2>&1
age_key="$(grep -v '^#' "$work/age/key.txt" | head -1)"

# experimental を立てずに測ると止まるか（設定を一時的に外して 1 回だけ測る）
sed 's/^experimental = true$/experimental = false/' "$work/age/mise.toml" > "$work/age/mise.toml.noexp"
mv "$work/age/mise.toml" "$work/age/mise.toml.keep"
mv "$work/age/mise.toml.noexp" "$work/age/mise.toml"
iso age trust >/dev/null 2>&1 || true
if iso age set --age-encrypt --age-key-file key.txt NOPE=x > "$out/age-noexp.txt" 2>&1; then
  experimental_required=false
else
  experimental_required=true
fi
mv "$work/age/mise.toml.keep" "$work/age/mise.toml"
iso age trust >/dev/null 2>&1 || true

iso age set --age-encrypt --age-key-file key.txt APP_TOKEN=age-secret-demo > "$out/age-set.txt" 2>&1
cp "$work/age/mise.toml" "$out/age-mise.toml"

# 鍵あり / 鍵なし。鍵なしは環境変数を渡さないことで作る。
if MISE_AGE_KEY="$age_key" iso age env > "$out/age-with-key.txt" 2>&1; then age_ok=true; else age_ok=false; fi
if iso age env > "$out/age-no-key.txt" 2>&1; then age_fails=false; else age_fails=true; fi

# ---- sops: 別ファイルを丸ごと暗号化して読む ----------------------------
iso sops install > "$out/sops-install.txt" 2>&1
iso sops exec -- age-keygen -o key.txt > "$out/sops-keygen.txt" 2>&1
sops_key="$(grep -v '^#' "$work/sops/key.txt" | head -1)"
sops_pub="$(iso sops exec -- age-keygen -y key.txt 2>/dev/null | tail -1)"
printf '{\n  "API_TOKEN": "sops-secret-demo"\n}\n' > "$work/sops/.env.json"
iso sops exec -- sops encrypt -i --age "$sops_pub" .env.json > "$out/sops-encrypt.txt" 2>&1
cp "$work/sops/.env.json" "$out/sops-env.json"

if MISE_SOPS_AGE_KEY="$sops_key" iso sops env > "$out/sops-with-key.txt" 2>&1; then sops_ok=true; else sops_ok=false; fi
if iso sops env > "$out/sops-no-key.txt" 2>&1; then sops_fails=false; else sops_fails=true; fi

# ---- fnox: 値を mise の設定に置かない ----------------------------------
iso fnox install > "$out/fnox-install.txt" 2>&1
mkdir -p "$work/fnox/fnoxcfg"
iso fnox exec -- age-keygen -o fnoxcfg/age.txt > "$out/fnox-keygen.txt" 2>&1
fnox_pub="$(iso fnox exec -- age-keygen -y fnoxcfg/age.txt 2>/dev/null | tail -1)"
cat > "$work/fnox/fnox.toml" <<TOML
#:schema https://fnox.jdx.dev/schema.json
default_provider = "age"

[providers.age]
type = "age"
recipients = ["$fnox_pub"]
TOML
fnox_bin="$(iso fnox which fnox 2>/dev/null)"
FNOX_CONFIG_DIR="$work/fnox/fnoxcfg" iso fnox exec -- fnox set DATABASE_URL "postgresql://localhost/demo" > "$out/fnox-set.txt" 2>&1
cp "$work/fnox/mise.toml" "$out/fnox-mise.toml"

iso fnox run show > "$out/fnox-without.txt" 2>&1 || true
( cd "$work/fnox" && FNOX_CONFIG_DIR="$work/fnox/fnoxcfg" "$fnox_bin" exec -- \
    bash "$repo/scripts/isolate.sh" "$work/fnox" run show ) > "$out/fnox-with.txt" 2>&1 || true

# ---- 判定は終了コードと機械可読な出力だけで行う -------------------------
has() { grep -qE "$2" "$out/$1" && echo true || echo false; }
lacks() { grep -qE "$2" "$out/$1" && echo false || echo true; }

cat > "$out/summary.json" <<JSON
{
  "plainInEnv": $(has plain.txt '^export APP_TOKEN=.?plain-value-not-a-real-secret'),
  "localOverrides": $(has local.txt '^export APP_TOKEN=.?from-local-override'),
  "miseWritesGitignore": $mise_writes_gitignore,
  "experimentalRequired": $experimental_required,
  "ageNoPlaintextInToml": $(lacks age-mise.toml 'age-secret-demo'),
  "ageDecryptsWithKey": $age_ok,
  "agePlainInEnv": $(has age-with-key.txt '^export APP_TOKEN=.?age-secret-demo'),
  "ageFailsWithoutKey": $age_fails,
  "sopsNoPlaintextInFile": $(lacks sops-env.json 'sops-secret-demo'),
  "sopsDecryptsWithKey": $sops_ok,
  "sopsFailsWithoutKey": $sops_fails,
  "fnoxNothingInMiseToml": $(lacks fnox-mise.toml 'postgresql'),
  "fnoxUnsetWithout": $(has fnox-without.txt 'DATABASE_URL=<unset>'),
  "fnoxProvidesWithExec": $(has fnox-with.txt 'DATABASE_URL=postgresql://localhost/demo')
}
JSON
cat "$out/summary.json"
