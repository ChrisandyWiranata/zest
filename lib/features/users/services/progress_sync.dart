import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/day.dart';
import '../../progress/services/xp_store.dart';
import '../../videos/services/video_progress_store.dart';
import '../../vocab/services/srs_scheduler.dart';
import '../../vocab/services/srs_store.dart';
import 'api_user_repo.dart';

/// Status sinkronisasi progres, untuk UI (badge/indikator).
enum SyncStatus {
  /// Belum ada perubahan yang menunggu.
  idle,

  /// Ada perubahan lokal yang belum terkirim.
  pending,

  /// Sedang mengirim batch ke backend.
  syncing,

  /// Batch terakhir berhasil.
  synced,

  /// Batch terakhir gagal; perubahan tetap antre (status [pending]/antre).
  error,
}

/// Pengirim perubahan progres user ke backend (fire-and-forget, satu POST
/// berisi stats + seluruh SRS + seluruh video per kategori). Diinstance per
/// user setelah login.
class ProgressSync {
  ProgressSync(this._uid, this._repo, [this._prefs]) {
    _lastSyncAt = _prefs?.getInt(lastSyncKey(_uid));
    if (hasPending) _status.value = SyncStatus.pending;
  }

  final String _uid;
  final ApiUserRepo _repo;
  final SharedPreferences? _prefs;

  /// Status sinkron lintas-batch; dipakai halaman profil.
  final ValueNotifier<SyncStatus> _status = ValueNotifier(SyncStatus.idle);
  ValueNotifier<SyncStatus> get status => _status;

  int? _lastSyncAt;
  int? get lastSyncAt => _lastSyncAt;

  static String lastSyncKey(String uid) => 'sync.$uid.last_at';

  final Map<String, Map<String, SrsCard>> _cards = {};
  final Map<String, Set<String>> _watched = {};
  XpSnapshot? _stats;

  void srsChanged(String category, String key, SrsCard card) {
    (_cards[category] ??= {})[key] = card;
    if (_status.value != SyncStatus.syncing) {
      _status.value = SyncStatus.pending;
    }
  }

  void videoChanged(String category, String key) {
    (_watched[category] ??= {}).add(key);
    if (_status.value != SyncStatus.syncing) {
      _status.value = SyncStatus.pending;
    }
  }

  void statsChanged(XpSnapshot stats) {
    _stats = stats;
    if (_status.value != SyncStatus.syncing) {
      _status.value = SyncStatus.pending;
    }
  }

  bool get hasPending =>
      _stats != null || _cards.isNotEmpty || _watched.isNotEmpty;

  List<SrsGroup> _srsGroups() => [
    for (final entry in _cards.entries)
      SrsGroup(entry.key, Map.of(entry.value)),
  ];

  List<WatchedGroup> _watchedGroups() => [
    for (final entry in _watched.entries)
      WatchedGroup(entry.key, Set.of(entry.value)),
  ];

  Future<void> _markSynced(int updatedAt) async {
    _lastSyncAt = updatedAt;
    await _prefs?.setInt(lastSyncKey(_uid), updatedAt);
    _status.value = hasPending ? SyncStatus.pending : SyncStatus.synced;
  }

  /// Kirim semua perubahan tertunda dalam satu request. Kelompok data hanya
  /// dibersihkan setelah server mengonfirmasi sukses, jadi tak ada progres yang
  /// hilang bila request gagal (status → [SyncStatus.error]).
  Future<void> flush() async {
    if (!hasPending) return;
    _status.value = SyncStatus.syncing;
    try {
      final updatedAt = await _repo.writeSync(
        stats: _stats,
        srs: _srsGroups(),
        watched: _watchedGroups(),
      );
      _stats = null;
      _cards.clear();
      _watched.clear();
      await _markSynced(updatedAt);
    } catch (e) {
      debugPrint('flush(): gagal menyinkronkan -> $e');
      _status.value = SyncStatus.error;
    }
  }

  /// Sinkronkan penuh data lokal ke cloud (backfill): statistik + seluruh
  /// status SRS + video yang ditonton per kategori. Data lokal tidak dihapus.
  /// Dipakai tombol "Sinkronkan progres" di halaman Profil.
  Future<void> pushAll({
    required XpStore xpStore,
    required SrsStore srsStore,
    required VideoProgressStore videoProgressStore,
    required Future<Iterable<String>> Function() getCategories,
  }) async {
    _status.value = SyncStatus.syncing;
    try {
      final categories = (await getCategories()).toList();
      final srs = <SrsGroup>[];
      final watched = <WatchedGroup>[];
      for (final category in categories) {
        final cards = await srsStore.loadAll(category);
        if (cards.isNotEmpty) srs.add(SrsGroup(category, cards));
        final keys = await videoProgressStore.watchedKeys(category);
        if (keys.isNotEmpty) watched.add(WatchedGroup(category, keys));
      }

      final updatedAt = await _repo.writeSync(
        stats: await xpStore.snapshot(),
        srs: srs,
        watched: watched,
      );
      await _markSynced(updatedAt);
    } catch (e) {
      debugPrint('pushAll(): gagal menyinkronkan -> $e');
      _status.value = SyncStatus.error;
    }
  }
}

/// Migrasi data lama (tahap sebelum fitur akun, kunci tanpa `uid`) ke ruang
/// nama user + push ke backend. Idempoten: hanya berjalan pada login pertama.
Future<void> migrateLegacyUserData(
  SharedPreferences prefs,
  ApiUserRepo repo,
  String uid,
) async {
  final now = DateTime.now();
  final today = epochDay(now);

  // --- XP (xp.<field> tanpa uid) ---
  const xpLegacyFields = [
    'total',
    'streak',
    'lastDay',
    'today.xp',
    'today.day',
  ];
  var xpFound = false;
  for (final field in xpLegacyFields) {
    final value = prefs.get('xp.$field');
    if (value != null) {
      xpFound = true;
      await _prefsSet(prefs, XpStore.fieldKey(uid, field), value);
    }
  }

  // --- SRS + status "mastery" lama (tanpa uid) ---
  final srsByCategory = <String, Map<String, SrsCard>>{};
  final featKeys = prefs.getKeys().where(_isLegacySrsOrMastery).toList();
  for (final k in featKeys) {
    if (k.startsWith('srs.')) {
      final parts = k.split('.');
      if (parts.length != 3) continue;
      final raw = prefs.getString(k);
      if (raw == null) continue;
      final card = _trySrs(raw);
      if (card == null) continue;
      final category = parts[1];
      final id = parts[2];
      (srsByCategory[category] ??= {})[id] = card;
      await prefs.setString(SrsStore.stateKey(uid, category, id), raw);
    } else if (k.startsWith('mastery.')) {
      if (prefs.getBool(k) != true) continue;
      final parts = k.split('.');
      if (parts.length != 3) continue;
      final category = parts[1];
      final id = parts[2];
      final existing = srsByCategory[category]?[id];
      if (existing == null) {
        final card = srsGood(null, today);
        (srsByCategory[category] ??= {})[id] = card;
        await prefs.setString(
          SrsStore.stateKey(uid, category, id),
          card.toJson(),
        );
      }
    }
  }

  // --- Video ditonton (watched_video.<cat>.<id> tanpa uid) ---
  final watchedByCategory = <String, Set<String>>{};
  final watchedKeys = prefs
      .getKeys()
      .where((k) => k.startsWith('watched_video.') && k.split('.').length == 3)
      .toList();
  for (final k in watchedKeys) {
    if (prefs.getBool(k) != true) continue;
    final parts = k.split('.');
    final category = parts[1];
    final id = parts[2];
    (watchedByCategory[category] ??= {}).add(id);
    await prefs.setBool(VideoProgressStore.key(uid, category, id), true);
  }

  // Satu request untuk seluruh data legacy yang ditemukan.
  if (xpFound || srsByCategory.isNotEmpty || watchedByCategory.isNotEmpty) {
    await repo.writeSync(
      stats: xpFound
          ? XpSnapshot(
              total: prefs.getInt('xp.total') ?? 0,
              streak: prefs.getInt('xp.streak') ?? 0,
              lastDay: prefs.getInt('xp.lastDay'),
              todayXp: prefs.getInt('xp.today.xp') ?? 0,
              todayDay: prefs.getInt('xp.today.day'),
            )
          : null,
      srs: [
        for (final entry in srsByCategory.entries)
          SrsGroup(entry.key, entry.value),
      ],
      watched: [
        for (final entry in watchedByCategory.entries)
          WatchedGroup(entry.key, entry.value),
      ],
    );
  }

  // Hapus kunci legacy agar tidak terhitung ganda.
  final legacyKeys = prefs
      .getKeys()
      .where(
        (k) =>
            _isLegacySrsOrMastery(k) ||
            (k.startsWith('xp.') && xpLegacyFields.contains(k.substring(3))) ||
            (k.startsWith('watched_video.') && k.split('.').length == 3),
      )
      .toList();
  for (final k in legacyKeys) {
    await prefs.remove(k);
  }
}

bool _isLegacySrsOrMastery(String k) =>
    (k.startsWith('srs.') && k.split('.').length == 3) ||
    (k.startsWith('mastery.') && k.split('.').length == 3);

SrsCard? _trySrs(String raw) {
  try {
    return SrsCard.fromJson(raw);
  } catch (_) {
    return null;
  }
}

/// Tarik data user dari cloud ke cache lokal (prefs) dalam satu request.
/// Dipanggil setiap login agar perangkat baru langsung punya data terakhir.
Future<void> hydrateUserData(
  SharedPreferences prefs,
  ApiUserRepo repo,
  String uid, {
  Future<Iterable<String>> Function()? getCategories,
}) async {
  final categories = getCategories == null
      ? const <String>[]
      : (await getCategories()).toList();

  final snapshot = await repo.fetchProgress(categories);
  final stats = snapshot.stats;
  if (stats != null) {
    await _writeStatsToPrefs(prefs, uid, stats);
  }

  for (final category in categories) {
    for (final entry in (snapshot.srs[category] ?? const {}).entries) {
      await prefs.setString(
        SrsStore.stateKey(uid, category, entry.key),
        entry.value.toJson(),
      );
    }
    for (final key in (snapshot.watched[category] ?? const <String>{})) {
      await prefs.setBool(VideoProgressStore.key(uid, category, key), true);
    }
  }
}

Future<void> _writeStatsToPrefs(
  SharedPreferences prefs,
  String uid,
  XpSnapshot stats,
) async {
  await prefs.setInt(XpStore.fieldKey(uid, 'total'), stats.total);
  await prefs.setInt(XpStore.fieldKey(uid, 'streak'), stats.streak);
  final lastDay = stats.lastDay;
  if (lastDay != null) {
    await prefs.setInt(XpStore.fieldKey(uid, 'lastDay'), lastDay);
  }
  await prefs.setInt(XpStore.fieldKey(uid, 'today.xp'), stats.todayXp);
  final todayDay = stats.todayDay;
  if (todayDay != null) {
    await prefs.setInt(XpStore.fieldKey(uid, 'today.day'), todayDay);
  }
}

Future<void> _prefsSet(
  SharedPreferences prefs,
  String key,
  Object value,
) async {
  if (value is bool) {
    await prefs.setBool(key, value);
  } else if (value is int) {
    await prefs.setInt(key, value);
  } else if (value is double) {
    await prefs.setDouble(key, value);
  } else {
    await prefs.setString(key, value.toString());
  }
}
