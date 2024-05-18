import pg, { Client } from "pg";

const db = new Client(
  "postgresql://postgres:postgres@127.0.0.1:54322/postgres",
);

db.connect();
console.log("Connected to database");

const users = await db.query<{
  id: string;
}>("SELECT id FROM users");

console.log(users.rows);

// ダミーデータの作成
const text =
  "INSERT INTO users_earthquake_settings(id, region_id, min_jma_intensity) VALUES ";
const values: [string, number, string][] = [];
for (const user of users.rows) {
  // region_id は 1 から 47 のランダムな整数をランダム数生成
  const region_ids = Array.from(
    { length: Math.floor(Math.random() * 47) },
    (_, i) => i + 1,
  );
  const jma_intensity_choices = [
    "0",
    "1",
    "2",
    "3",
    "4",
    "5-",
    "5+",
    "6-",
    "6+",
    "7",
  ];
  const jma_intensity = jma_intensity_choices[
    Math.floor(Math.random() * jma_intensity_choices.length)
  ];
  for (const region_id of region_ids) {
    values.push([user.id, region_id, jma_intensity]);
  }
}

const sql = text + values.map((e) => `('${e[0]}', ${e[1]}, '${e[2]}')`).join(", ");

await db.query(sql);
console.log("Inserted dummy data");

process.exit(0);
