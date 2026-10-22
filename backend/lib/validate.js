/**
 * Validasi payload request. Murni (tanpa I/O) supaya bisa di-unit-test tanpa
 * DB. Semua pelanggaran → ValidationError (400) — bukan 500 dari SQL.
 */

export const LIMITS = {
  /** Maksimal kategori per request /api/me/progress?categories=... */
  categoriesPerRequest: 64,
  /** Maksimal total statement DB per POST /api/me/sync. */
  syncStatements: 20_000,
  /** Maksimal panjang kategori & key (slug/bahasa, angka, url pendek). */
  idLength: 128,
};

export class ValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ValidationError';
    this.status = 400;
  }
}

function assertId(value, label) {
  if (typeof value !== 'string' || value.length === 0) {
    throw new ValidationError(`${label} harus berupa teks non-kosong.`);
  }
  if (value.length > LIMITS.idLength) {
    throw new ValidationError(`${label} terlalu panjang (maks ${LIMITS.idLength}).`);
  }
  return value;
}

function assertNumberOrUndefined(value, label) {
  if (value === undefined) return;
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new ValidationError(`${label} harus berupa angka.`);
  }
}

function assertNumberOrNull(value, label) {
  if (value === undefined || value === null) return null;
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new ValidationError(`${label} harus berupa angka atau null.`);
  }
  return value;
}

/** Parse `?categories=a,b,c` → daftar unik, terpotong, ter-validasi. */
export function parseCategories(raw) {
  const list = (raw ?? '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  if (list.length > LIMITS.categoriesPerRequest) {
    throw new ValidationError(
      `Terlalu banyak kategori (maks ${LIMITS.categoriesPerRequest}).`,
    );
  }
  return [...new Set(list)];
}

/**
 * Validasi body POST /api/me/sync. Mengembalikan bentuk yang siap diteruskan
 * ke writeSync(); field stats boleh null, srs/watched selalu array.
 */
export function validateSyncPayload(body) {
  const input = body && typeof body === 'object' && !Array.isArray(body) ? body : {};

  let stats = null;
  if (input.stats != null) {
    if (typeof input.stats !== 'object' || Array.isArray(input.stats)) {
      throw new ValidationError('stats harus berupa objek.');
    }
    stats = {
      total: assertNumberOrNull(input.stats.total, 'stats.total'),
      streak: assertNumberOrNull(input.stats.streak, 'stats.streak'),
      lastDay: assertNumberOrNull(input.stats.lastDay, 'stats.lastDay'),
      todayXp: assertNumberOrNull(input.stats.todayXp, 'stats.todayXp'),
      todayDay: assertNumberOrNull(input.stats.todayDay, 'stats.todayDay'),
    };
  }

  if (input.srs != null && !Array.isArray(input.srs)) {
    throw new ValidationError('srs harus berupa array.');
  }
  if (input.watched != null && !Array.isArray(input.watched)) {
    throw new ValidationError('watched harus berupa array.');
  }

  const srs = [];
  for (const group of input.srs ?? []) {
    if (!group || typeof group !== 'object' || Array.isArray(group)) {
      throw new ValidationError('Setiap grup srs harus berupa objek.');
    }
    const category = assertId(group.category, 'Kategori srs');
    const cards = group.cards ?? [];
    if (!Array.isArray(cards)) {
      throw new ValidationError('srs.cards harus berupa array.');
    }
    const validated = [];
    for (const card of cards) {
      if (!card || typeof card !== 'object' || Array.isArray(card)) {
        throw new ValidationError('Setiap kartu srs harus berupa objek.');
      }
      assertId(card.key, 'Kunci kartu srs');
      assertNumberOrUndefined(card.n, 'card.n');
      assertNumberOrUndefined(card.interval, 'card.interval');
      assertNumberOrUndefined(card.ease, 'card.ease');
      assertNumberOrUndefined(card.due, 'card.due');
      validated.push(card);
    }
    srs.push({ category, cards: validated });
  }

  const watched = [];
  for (const group of input.watched ?? []) {
    if (!group || typeof group !== 'object' || Array.isArray(group)) {
      throw new ValidationError('Setiap grup watched harus berupa objek.');
    }
    const category = assertId(group.category, 'Kategori watched');
    const keys = group.keys ?? [];
    if (!Array.isArray(keys)) {
      throw new ValidationError('watched.keys harus berupa array.');
    }
    for (const key of keys) {
      assertId(key, 'Kunci video watched');
    }
    watched.push({ category, keys });
  }

  const statements =
    (stats ? 1 : 0) +
    srs.reduce((total, group) => total + group.cards.length, 0) +
    watched.reduce((total, group) => total + group.keys.length, 0);
  if (statements > LIMITS.syncStatements) {
    throw new ValidationError(
      `Payload sinkron terlalu besar (maks ${LIMITS.syncStatements} entri).`,
    );
  }

  return { stats, srs, watched };
}
