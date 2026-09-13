// 公開して困る情報が混ざっていないかを見る。
//
// 🔴 これは網ではない。見るのは機械で決められる 4 つの型だけで、
//    書き手にしか分からない言い回しは通り抜ける。公開の前に必ず目で読む。
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SKIP = new Set(['.git', 'node_modules', 'results']);
const SKIP_FILES = new Set(['check-neutrality.mjs']);

// 公開用の連絡先。.github/workflows/verify.yml の identity ジョブが期待値として持つ。
const PUBLIC_CONTACT = 'blog@techbizplusd.com';

const PATTERNS = [
  { name: '絶対パス（ホーム配下）', re: /\/Users\/[A-Za-z0-9._-]+\// },
  {
    name: '実在しそうなメールアドレス',
    re: /[A-Za-z0-9._%+-]+@(?!example\.)[A-Za-z0-9.-]+\.[A-Za-z]{2,}/,
    // 公開用の連絡先だけは、公開されることが前提なので通す。
    // 🔴 除外は「その行に公開前提のアドレスしか無いとき」に限る。
    //    他のアドレスが同じ行に混ざっていたら通さない。
    allow: (hit) => hit === PUBLIC_CONTACT,
  },
  {
    name: '.local ホスト名',
    // 🔴 うしろに拡張子が続くものは名前の一部（例: mise.local.toml）なので当てない。
    //    ホスト名として使われている .local だけを拾う。
    re: /\b[A-Za-z0-9-]+\.local\b(?!\.[A-Za-z])/,
  },
  { name: 'IPv4 アドレス（プライベート帯）', re: /\b(?:10|192\.168|172\.(?:1[6-9]|2\d|3[01]))\.\d{1,3}\.\d{1,3}\b/ },
];

let bad = 0;
let files = 0;

const walk = (d) => {
  for (const name of readdirSync(d)) {
    if (SKIP.has(name)) continue;
    const p = resolve(d, name);
    if (statSync(p).isDirectory()) {
      walk(p);
      continue;
    }
    if (SKIP_FILES.has(name)) continue;
    if (!/\.(md|mjs|js|json|sh|toml|ya?ml|txt)$/.test(name)) continue;
    files++;
    const text = readFileSync(p, 'utf8');
    text.split('\n').forEach((line, i) => {
      for (const { name: label, re, allow } of PATTERNS) {
        const m = line.match(re);
        if (!m) continue;
        if (allow && allow(m[0], line)) continue;
        {
          console.log(`❌ ${relative(repo, p)}:${i + 1} ${label}`);
          bad++;
        }
      }
    });
  }
};

walk(repo);
console.log(bad === 0 ? `✅ check:neutrality — ${files} ファイルに該当なし` : `❌ check:neutrality — ${bad} 件`);
console.log('   ※ 機械で決められる 4 つの型だけを見ています。公開の前に目で読んでください。');
process.exit(bad === 0 ? 0 : 1);
