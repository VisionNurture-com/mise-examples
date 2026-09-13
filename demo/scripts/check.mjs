// デモの前提が満たされているかを見る。
// mise が [env] を読めていれば APP_NAME が入っている。
const name = process.env.APP_NAME;
const greeting = process.env.GREETING;

if (!name) {
  console.error('APP_NAME が入っていません。mise 経由で実行していますか（mise run check）。');
  process.exit(1);
}
console.log(`APP_NAME=${name}`);
console.log(`GREETING=${greeting ?? '(未設定 — .env を作ると入る)'}`);
console.log(`node=${process.version}`);
