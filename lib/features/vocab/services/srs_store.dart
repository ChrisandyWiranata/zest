import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/day.dart';
import 'srs_scheduler.dart';

/// Penyimpanan lokal status SRS per kartu per user (JSON di
/// SharedPreferences). Kunci: `srs.<uid>.<category>.<masteryKey>`.
class SrsStore {
  SrsStore(this._prefs, this.uid);

  final SharedPreferences _prefs;
  final String uid;

  static const _legacyPrefix = 'mastery.';

  static String stateKey(String uid, String category, String id) =>
      'srs.$uid.$category.$id';

  String _key(String category, String id) => stateKey(uid, category, id);

  Future<SrsCard?> get(String category, String id) async {
    final raw = _prefs.getString(_key(category, id));
    return raw == null ? null : _tryParse(raw);
  }

  Future<Map<String, SrsCard>> loadAll(String category) async {
    final prefix = 'srs.$uid.$category.';
    final map = <String, SrsCard>{};
    for (final k in _prefs.getKeys()) {
      if (!k.startsWith(prefix)) continue;
      final id = k.substring(prefix.length);
      final raw = _prefs.getString(k);
      final card = raw == null ? null : _tryParse(raw);
      if (card != null) map[id] = card;
    }
    return map;
  }

  /// Parsing toleran: record yang rusak atau format lama (bukan `{n,i,e,d}`)
  /// dilewati, tidak membuat aplikasi crash.
  SrsCard? _tryParse(String raw) {
    try {
      return SrsCard.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> update(String category, String id, SrsCard card) async {
    await _prefs.setString(_key(category, id), card.toJson());
  }

  /// Kunci-kunci kartu yang sudah "hafal" (interval matang).
  Future<Set<String>> masteredKeys(String category) async {
    final all = await loadAll(category);
    return all.entries
        .where((e) => isMature(e.value))
        .map((e) => e.key)
        .toSet();
  }

  /// Migrasi status lama `mastery.<category>.<key> = true` menjadi kartu SRS
  /// baru (interval 1 hari) agar progres sebelum fitur ini tidak hilang.
  /// Idempoten: hanya men-seed bila kartu SRS belum ada.
  Future<void> migrateLegacy(String category) async {
    final prefix = '$_legacyPrefix$category.';
    final today = epochDay(DateTime.now());
    for (final k in _prefs.getKeys()) {
      if (!k.startsWith(prefix)) continue;
      if (_prefs.getBool(k) != true) continue;
      final id = k.substring(prefix.length);
      if (_prefs.getString(_key(category, id)) != null) continue;
      await update(category, id, srsGood(null, today));
    }
  }
}
