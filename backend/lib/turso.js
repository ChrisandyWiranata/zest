import { createClient } from '@libsql/client';

const url = process.env.TURSO_URL;
const authToken = process.env.TURSO_TOKEN;

if (!url || !authToken) {
  throw new Error(
    'TURSO_URL dan TURSO_TOKEN wajib diset (Vercel env var atau backend/.env.local).',
  );
}

const client = createClient({ url, authToken });

/**
 * Ubah baris libsql jadi objek biasa dengan normalisasi tipe yang sama
 * dengan parsePipeline() di sisi Flutter: integer & real jadi number,
 * boolean jadi boolean, null tetap null.
 */
function toObjects(resultSet) {
  return resultSet.rows.map((row) => {
    const out = {};
    for (const key of Object.keys(row)) {
      const value = row[key];
      if (value == null) {
        out[key] = null;
        continue;
      }
      if (value instanceof BigInt) {
        out[key] = Number(value);
        continue;
      }
      if (typeof value === 'number') {
        out[key] = value;
        continue;
      }
      if (typeof value === 'boolean') {
        out[key] = value ? 1 : 0;
        continue;
      }
      out[key] = value;
    }
    return out;
  });
}

async function all(sql, args = []) {
  return toObjects(await client.execute({ sql, args }));
}

async function run(sql, args = []) {
  await client.execute({ sql, args });
}

/** Jalankan banyak statement dalam satu transaksi atomik. */
async function batch(statements) {
  if (statements.length === 0) return;
  await client.batch(statements, 'write');
}

// ---------------------------------------------------------------------------
// Konten (publik, dibaca semua pengguna)
// ---------------------------------------------------------------------------

export function listCategories() {
  return all(
    `SELECT c.slug AS category, c.title AS title, c.level AS level,
            c.description AS description, COUNT(v.id) AS total
     FROM categories c
     LEFT JOIN vocabularies v ON v.category = c.slug
     GROUP BY c.slug
     ORDER BY c.sort_order ASC, c.slug ASC`,
  );
}

export function listWords(category) {
  return all(
    'SELECT * FROM vocabularies WHERE category = ? ORDER BY timestamp ASC',
    [category],
  );
}

export function listVideos(category, type) {
  if (type) {
    return all(
      'SELECT * FROM videos WHERE category = ? AND LOWER(TRIM(type)) = ? ORDER BY order_index ASC',
      [category, type],
    );
  }
  return all(
    'SELECT * FROM videos WHERE category = ? ORDER BY order_index ASC',
    [category],
  );
}

// ---------------------------------------------------------------------------
// Profil user
// ---------------------------------------------------------------------------

export function findMeta(uid) {
  return all('SELECT 1 FROM user_meta WHERE user_id = ?', [uid]);
}

export function upsertUser(user, lastSeen) {
  return run(
    `INSERT INTO users (user_id, email, display_name, avatar_url, created_at, last_seen_at)
     VALUES (?, ?, ?, ?, ?, ?)
     ON CONFLICT(user_id) DO UPDATE SET
       email = excluded.email,
       display_name = excluded.display_name,
       avatar_url = excluded.avatar_url,
       last_seen_at = excluded.last_seen_at`,
    [
      user.uid,
      user.email ?? '',
      user.displayName ?? '',
      user.photoUrl ?? '',
      lastSeen,
      lastSeen,
    ],
  );
}

export function putMeta(uid, version, lastSync) {
  return run(
    `INSERT INTO user_meta (user_id, version, last_sync) VALUES (?, ?, ?)
     ON CONFLICT(user_id) DO UPDATE SET
       version = excluded.version,
       last_sync = excluded.last_sync`,
    [uid, version, lastSync],
  );
}

// ---------------------------------------------------------------------------
// Progres user
// ---------------------------------------------------------------------------

export function fetchStats(uid) {
  return all('SELECT * FROM user_stats WHERE user_id = ?', [uid]);
}

export function fetchSrs(uid, category) {
  return all(
    'SELECT * FROM user_srs_states WHERE user_id = ? AND category = ?',
    [uid, category],
  );
}

export function fetchWatched(uid, category) {
  return all('SELECT video_key FROM user_watched WHERE user_id = ? AND category = ?', [
    uid,
    category,
  ]);
}

const UPSERT_STATS = `INSERT INTO user_stats (user_id, total_xp, streak, last_day, today_xp, today_day, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(user_id) DO UPDATE SET
       total_xp = excluded.total_xp,
       streak = excluded.streak,
       last_day = excluded.last_day,
       today_xp = excluded.today_xp,
       today_day = excluded.today_day,
       updated_at = excluded.updated_at`;

const UPSERT_SRS = `INSERT INTO user_srs_states (user_id, category, mastery_key, n, interval_days, ease, due, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(user_id, category, mastery_key) DO UPDATE SET
       n = excluded.n,
       interval_days = excluded.interval_days,
       ease = excluded.ease,
       due = excluded.due,
       updated_at = excluded.updated_at`;

const INSERT_WATCHED = `INSERT OR IGNORE INTO user_watched (user_id, category, video_key, updated_at)
     VALUES (?, ?, ?, ?)`;

/**
 * Tulis satu payload sinkron penuh (dipakai flush() maupun pushAll()):
 * stats opsional, kartu SRS dan video yang ditonton per kategori.
 * Semua statement masuk satu batch, jadi setengah jadi tidak mungkin.
 */
export function writeSync(uid, { stats, srs, watched, updatedAt }) {
  const statements = [];

  if (stats) {
    statements.push({
      sql: UPSERT_STATS,
      args: [
        uid,
        stats.total ?? 0,
        stats.streak ?? 0,
        stats.lastDay ?? null,
        stats.todayXp ?? 0,
        stats.todayDay ?? null,
        updatedAt,
      ],
    });
  }

  for (const group of srs ?? []) {
    for (const card of group.cards ?? []) {
      statements.push({
        sql: UPSERT_SRS,
        args: [
          uid,
          group.category,
          card.key,
          card.n ?? 0,
          card.interval ?? 0,
          card.ease ?? 2.5,
          card.due ?? 0,
          updatedAt,
        ],
      });
    }
  }

  for (const group of watched ?? []) {
    for (const key of group.keys ?? []) {
      statements.push({
        sql: INSERT_WATCHED,
        args: [uid, group.category, key, updatedAt],
      });
    }
  }

  return batch(statements);
}

export { client };
