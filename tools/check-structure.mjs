// シナリオが決まった形を保っているかを見る。形だけを見て、値は check-provenance.mjs が見る。
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const dir = resolve(repo, 'scenarios');
const REQUIRED = ['run.sh', 'expected.md'];

let bad = 0;
let n = 0;

for (const id of readdirSync(dir).sort()) {
  const p = resolve(dir, id);
  if (!statSync(p).isDirectory()) continue;
  n++;
  for (const f of REQUIRED) {
    if (!existsSync(resolve(p, f))) {
      console.log(`❌ ${id}: ${f} がありません`);
      bad++;
    }
  }
  const runPath = resolve(p, 'run.sh');
  if (!existsSync(runPath)) continue;
  const run = readFileSync(runPath, 'utf8');
  // M0 … 追加の道具が要らない / M1 … CI で道具を入れて測る / M2 … 機械依存で CI では測らない
  if (!/^#\s*mode:\s*M[0-2]\s*$/m.test(run)) {
    console.log(`❌ ${id}/run.sh: "# mode: M0|M1|M2" のヘッダがありません`);
    bad++;
  }
  if (!/^#\s*要るもの:/m.test(run)) {
    console.log(`❌ ${id}/run.sh: "# 要るもの:" の宣言がありません`);
    bad++;
  }
  if (!/set -euo pipefail/.test(run)) {
    console.log(`❌ ${id}/run.sh: set -euo pipefail がありません（失敗が伝播しません）`);
    bad++;
  }
  // このリポジトリでは mise を必ず隔離して呼ぶ。素で呼ぶと測定が汚れる。
  if (/(^|\s)mise\s/.test(run.replace(/^#.*$/gm, '')) && !/isolate\.sh/.test(run)) {
    console.log(`❌ ${id}/run.sh: mise を scripts/isolate.sh を通さずに呼んでいます`);
    bad++;
  }
}

if (n === 0) {
  console.log('❌ scenarios/ が空です');
  bad++;
}
console.log(bad === 0 ? `✅ check:structure — シナリオ ${n} 本すべて形は満たしています` : `❌ check:structure — ${bad} 件`);
process.exit(bad === 0 ? 0 : 1);
