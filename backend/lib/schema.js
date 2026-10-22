export const userTables = [
  `CREATE TABLE IF NOT EXISTS users (
    user_id TEXT PRIMARY KEY,
    email TEXT NOT NULL DEFAULT '',
    display_name TEXT NOT NULL DEFAULT '',
    avatar_url TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL,
    last_seen_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS user_stats (
    user_id TEXT NOT NULL,
    total_xp INTEGER NOT NULL DEFAULT 0,
    streak INTEGER NOT NULL DEFAULT 0,
    last_day INTEGER,
    today_xp INTEGER NOT NULL DEFAULT 0,
    today_day INTEGER,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (user_id)
  )`,
  `CREATE TABLE IF NOT EXISTS user_srs_states (
    user_id TEXT NOT NULL,
    category TEXT NOT NULL,
    mastery_key TEXT NOT NULL,
    n INTEGER NOT NULL,
    interval_days INTEGER NOT NULL,
    ease REAL NOT NULL,
    due INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (user_id, category, mastery_key)
  )`,
  `CREATE TABLE IF NOT EXISTS user_watched (
    user_id TEXT NOT NULL,
    category TEXT NOT NULL,
    video_key TEXT NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (user_id, category, video_key)
  )`,
  `CREATE TABLE IF NOT EXISTS user_meta (
    user_id TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    last_sync INTEGER NOT NULL,
    PRIMARY KEY (user_id)
  )`,
];
