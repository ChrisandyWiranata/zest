import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/day.dart';

/// Ringkasan motivasi: total XP, level, streak harian, XP hari ini.
class XpInfo {
  const XpInfo({
    required this.total,
    required this.streak,
    required this.todayXp,
    required this.level,
  });

  final int total;
  final int streak;
  final int todayXp;
  final int level;
}

/// Data mentah XP (termasuk penanda hari) untuk sinkronisasi cloud.
class XpSnapshot {
  const XpSnapshot({
    required this.total,
    required this.streak,
    this.lastDay,
    required this.todayXp,
    this.todayDay,
  });

  final int total;
  final int streak;
  final int? lastDay;
  final int todayXp;
  final int? todayDay;

  XpInfo toInfo() => XpInfo(
    total: total,
    streak: streak,
    todayXp: todayXp,
    level: total ~/ XpStore.xpPerLevel + 1,
  );
}

/// Penyimpanan lokal XP, level, dan streak harian per user (ruang nama
/// `xp.<uid>.<field>`). Hari dihitung berdasarkan [clock] (default
/// [DateTime.now]) agar bisa diuji. Streak hanya bertambah sekali per hari
/// (sesi pertama).
class XpStore {
  XpStore(this._prefs, this.uid, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SharedPreferences _prefs;
  final String uid;
  final DateTime Function() _clock;

  static const xpPerLevel = 100;

  static String fieldKey(String uid, String field) => 'xp.$uid.$field';

  int _now() => epochDay(_clock());

  Future<XpInfo> load() async {
    final snap = await snapshot();
    return snap.toInfo();
  }

  Future<XpSnapshot> snapshot() async {
    final total = _prefs.getInt(_key('total')) ?? 0;
    final streak = _prefs.getInt(_key('streak')) ?? 0;
    final today = _now();
    final todayDay = _prefs.getInt(_key('today.day'));
    final todayXp = todayDay == today
        ? (_prefs.getInt(_key('today.xp')) ?? 0)
        : 0;
    return XpSnapshot(
      total: total,
      streak: streak,
      lastDay: _prefs.getInt(_key('lastDay')),
      todayXp: todayXp,
      todayDay: todayDay,
    );
  }

  String _key(String field) => fieldKey(uid, field);

  /// Tambah poin, jaga streak (naik sekali per hari, reset bila ada celah).
  Future<XpInfo> addXp(int points) async {
    final today = _now();
    final last = _prefs.getInt(_key('lastDay'));
    if (last != today) {
      final streak = last == today - 1
          ? (_prefs.getInt(_key('streak')) ?? 0) + 1
          : 1;
      await _prefs.setInt(_key('streak'), streak);
      await _prefs.setInt(_key('lastDay'), today);
      await _prefs.setInt(_key('today.xp'), 0);
      await _prefs.setInt(_key('today.day'), today);
    }
    final total = (_prefs.getInt(_key('total')) ?? 0) + points;
    await _prefs.setInt(_key('total'), total);
    await _prefs.setInt(
      _key('today.xp'),
      (_prefs.getInt(_key('today.xp')) ?? 0) + points,
    );
    return XpInfo(
      total: total,
      streak: _prefs.getInt(_key('streak')) ?? 0,
      todayXp: _prefs.getInt(_key('today.xp')) ?? 0,
      level: total ~/ xpPerLevel + 1,
    );
  }
}
