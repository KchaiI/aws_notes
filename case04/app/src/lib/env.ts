// DATABASE_URL が未設定なら、個別環境変数から組み立てる
// ECS では Secrets Manager から DB_USER と DB_PASSWORD が来るので、
// それらを URL エンコードして接続文字列を作る
if (!process.env.DATABASE_URL && process.env.DB_HOST) {
  const user = encodeURIComponent(process.env.DB_USER ?? "");
  const password = encodeURIComponent(process.env.DB_PASSWORD ?? "");
  const host = process.env.DB_HOST;
  const port = process.env.DB_PORT ?? "5432";
  const dbname = process.env.DB_NAME ?? "taskapi";

  process.env.DATABASE_URL = `postgresql://${user}:${password}@${host}:${port}/${dbname}`;
}