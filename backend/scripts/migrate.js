import { client } from '../lib/turso.js';
import { userTables } from '../lib/schema.js';

for (const sql of userTables) {
  await client.execute(sql);
  console.log('ok:', sql.split('\n')[0].trim());
}

console.log(`\nSelesai — ${userTables.length} tabel user_* dipastikan ada.`);
