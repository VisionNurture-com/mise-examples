// expected.md に書いた期待値と、run.sh が出した summary.json を突き合わせる。
//
// 🔴 この検査が見るのは「値が一致するか」だけで、その値を作った手順は見ない。
//    手順の妥当性は run.sh のレビューで担保する。
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const dir = resolve(repo, 'scenarios');

let bad = 0;
let checked = 0;
let skipped = 0;

// run.sh の先頭に書いた `# mode: M1` を読む。読めなければ null。
const modeOf = (p) => {
  const runPath = resolve(p, 'run.sh');
  if (!existsSync(runPath)) return null;
  const m = readFileSync(runPath, 'utf8').match(/^#\s*mode:\s*([A-Z][0-9])\s*$/m);
  return m ? m[1] : null;
};

for (const id of readdirSync(dir).sort()) {
  const p = resolve(dir, id);
  if (!statSync(p).isDirectory()) continue;

  const summaryPath = resolve(p, 'results/summary.json');
  if (!existsSync(summaryPath)) {
    // 🔴 CI が走らせるのは M1 だけ（.github/workflows/verify.yml の「M1 シナリオを実行する」）。
    //    M0 / M2 は実行されないので results も無い。これを ❌ にすると CI が常に赤くなる
    //    （実際に踏んだ。M0 / M2 のシナリオを足した時点から 8 本が落ちていた）。
    //    🔴 M1 の欠落は今までどおり ❌ のまま。走らせたはずのものが値を出さなかったことを
    //    見逃さないため、ここを一律 SKIP にはしない。
    const mode = modeOf(p);
    if (mode && mode !== 'M1') {
      console.log(`⏸ ${id}: ${mode} のため SKIP（CI が実行するのは M1 のみ）`);
      skipped++;
      continue;
    }
    console.log(`❌ ${id}: results/summary.json がありません（run.sh を実行しましたか）`);
    bad++;
    continue;
  }
  const summary = JSON.parse(readFileSync(summaryPath, 'utf8'));
  const expectedText = readFileSync(resolve(p, 'expected.md'), 'utf8');

  // 🔴 期待値の表は「最初の ## 見出しより前」に置く決まりにしている。
  //    そうしないと、解説の中の表（環境変数の一覧など）まで期待値として拾ってしまう。
  const headingAt = expectedText.search(/^## /m);
  const expected = headingAt === -1 ? expectedText : expectedText.slice(0, headingAt);

  // expected.md の表から「| `キー` | 値 |」を拾う
  const rows = [...expected.matchAll(/^\|\s*`([A-Za-z0-9_.]+)`\s*\|\s*([^|]+?)\s*\|/gm)];
  if (rows.length === 0) {
    console.log(`❌ ${id}/expected.md: 突合できる行が 1 つもありません`);
    bad++;
    continue;
  }
  for (const [, key, want] of rows) {
    const got = summary[key];
    checked++;
    if (got === undefined) {
      console.log(`❌ ${id}: summary.json に ${key} がありません`);
      bad++;
    } else if (String(got) !== want.trim()) {
      console.log(`❌ ${id}: ${key} が食い違います（期待 ${want.trim()} / 実測 ${got}）`);
      bad++;
    }
  }
}

const skipNote = skipped > 0 ? `（M1 以外を ${skipped} 本 SKIP）` : '';
console.log(bad === 0 ? `✅ check:provenance — ${checked} 件すべて一致しました${skipNote}` : `❌ check:provenance — ${bad} 件${skipNote}`);
process.exit(bad === 0 ? 0 : 1);
