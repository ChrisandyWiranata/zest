import 'package:shared_preferences/shared_preferences.dart';

class VideoProgressStore {
  VideoProgressStore(this._prefs, this.uid);

  final SharedPreferences _prefs;
  final String uid;

  static String key(String uid, String category, String id) =>
      'watched_video.$uid.$category.$id';

  static String resumeKey(String uid, String category, String id) =>
      'resume_video.$uid.$category.$id';

  String _key(String category, String id) => key(uid, category, id);

  String _resumeKey(String category, String id) => resumeKey(uid, category, id);

  Future<bool> isWatched(String category, String id) async =>
      _prefs.getBool(_key(category, id)) ?? false;

  Future<void> setWatched(String category, String id, bool watched) async {
    await _prefs.setBool(_key(category, id), watched);
  }

  /// Posisi menonton terakhir dalam milidetik (null = belum pernah).
  Future<int?> getResume(String category, String id) async =>
      _prefs.getInt(_resumeKey(category, id));

  Future<void> setResume(String category, String id, int milliseconds) async {
    await _prefs.setInt(_resumeKey(category, id), milliseconds);
  }

  /// Jumlah video yang pernah ditonton user (lintas kategori).
  Future<int> countWatched() async {
    final prefix = 'watched_video.$uid.';
    var n = 0;
    for (final k in _prefs.getKeys()) {
      if (k.startsWith(prefix) && _prefs.getBool(k) == true) n++;
    }
    return n;
  }

  /// Kunci video yang sudah ditonton dalam satu kategori (untuk sinkron).
  Future<Set<String>> watchedKeys(String category) async {
    final prefix = 'watched_video.$uid.$category.';
    final set = <String>{};
    for (final k in _prefs.getKeys()) {
      if (k.startsWith(prefix) && _prefs.getBool(k) == true) {
        set.add(k.substring(prefix.length));
      }
    }
    return set;
  }
}
