import '../../../core/network/api_client.dart';
import '../../auth/models/app_user.dart';
import '../../progress/services/xp_store.dart';
import '../../vocab/services/srs_scheduler.dart';

/// Hasil `POST /api/me/profile`.
class ProfileSync {
  const ProfileSync({
    required this.firstTime,
    required this.serverNow,
    this.sessionToken,
  });

  /// `true` bila baris `user_meta` belum ada sebelumnya — hanya terjadi pada
  /// login pertama, jadi client bisa menjalankan migrasi data legacy sekali saja.
  final bool firstTime;

  final int serverNow;

  /// Session token HS256 buatan server (TTL 1 hari sejak login Google) —
  /// hanya diisi saat autentikasi memakai Google idToken asli. Web
  /// menyimpannya di prefs supaya reload tidak perlu prompt One Tap;
  /// native mengabaikan.
  final String? sessionToken;
}

/// Kartu SRS satu kategori, siap dikirim ke backend.
class SrsGroup {
  const SrsGroup(this.category, this.cards);

  final String category;
  final Map<String, SrsCard> cards;
}

/// Video yang ditonton satu kategori, siap dikirim ke backend.
class WatchedGroup {
  const WatchedGroup(this.category, this.keys);

  final String category;
  final Set<String> keys;
}

/// Hasil `GET /api/me/progress`: seluruh data yang dibutuhkan hydrate()
/// dalam satu round-trip.
class ProgressSnapshot {
  const ProgressSnapshot({
    this.stats,
    this.srs = const {},
    this.watched = const {},
  });

  final XpSnapshot? stats;
  final Map<String, Map<String, SrsCard>> srs;
  final Map<String, Set<String>> watched;
}

/// Akses data user lewat backend. `uid` tidak pernah dikirim dari klien —
/// backend menurunkan shard dari `sub` idToken.
class ApiUserRepo {
  ApiUserRepo(this._client);

  final ApiClient _client;

  void setIdToken(String? token) => _client.idToken = token;

  Future<ProfileSync> syncProfile(AppUser user) async {
    final json = await _client.post('/me/profile', {
      'email': user.email,
      'displayName': user.displayName,
      'photoUrl': user.photoUrl,
    });
    return ProfileSync(
      firstTime: json['firstTime'] == true,
      serverNow: (json['serverNow'] as num?)?.toInt() ?? 0,
      sessionToken: json['sessionToken'] as String?,
    );
  }

  Future<ProgressSnapshot> fetchProgress(List<String> categories) async {
    final json = await _client.get(
      '/me/progress',
      query: {'categories': categories.join(',')},
    );

    XpSnapshot? stats;
    final rawStats = json['stats'];
    if (rawStats is Map) {
      stats = XpSnapshot(
        total: (rawStats['total_xp'] as num?)?.toInt() ?? 0,
        streak: (rawStats['streak'] as num?)?.toInt() ?? 0,
        lastDay: (rawStats['last_day'] as num?)?.toInt(),
        todayXp: (rawStats['today_xp'] as num?)?.toInt() ?? 0,
        todayDay: (rawStats['today_day'] as num?)?.toInt(),
      );
    }

    final srs = <String, Map<String, SrsCard>>{};
    final rawSrs = json['srs'];
    if (rawSrs is Map) {
      for (final entry in rawSrs.entries) {
        final cards = <String, SrsCard>{};
        final value = entry.value;
        if (value is Map) {
          for (final card in value.entries) {
            final data = card.value;
            if (data is! Map) continue;
            cards[card.key.toString()] = SrsCard(
              n: (data['n'] as num?)?.toInt() ?? 0,
              interval: (data['interval'] as num?)?.toInt() ?? 0,
              ease: (data['ease'] as num?)?.toDouble() ?? 2.5,
              due: (data['due'] as num?)?.toInt() ?? 0,
            );
          }
        }
        srs[entry.key.toString()] = cards;
      }
    }

    final watched = <String, Set<String>>{};
    final rawWatched = json['watched'];
    if (rawWatched is Map) {
      for (final entry in rawWatched.entries) {
        final value = entry.value;
        watched[entry.key.toString()] = value is List
            ? value.map((k) => k.toString()).toSet()
            : <String>{};
      }
    }

    return ProgressSnapshot(stats: stats, srs: srs, watched: watched);
  }

  /// Satu payload untuk stats + seluruh SRS + seluruh video yang ditonton.
  /// Dipakai oleh `ProgressSync.flush()` maupun `pushAll()`.
  /// Mengembalikan `updatedAt` dari server.
  Future<int> writeSync({
    XpSnapshot? stats,
    List<SrsGroup> srs = const [],
    List<WatchedGroup> watched = const [],
  }) async {
    final json = await _client.post('/me/sync', {
      if (stats != null)
        'stats': {
          'total': stats.total,
          'streak': stats.streak,
          'lastDay': stats.lastDay,
          'todayXp': stats.todayXp,
          'todayDay': stats.todayDay,
        },
      'srs': [
        for (final group in srs)
          {
            'category': group.category,
            'cards': [
              for (final entry in group.cards.entries)
                {
                  'key': entry.key,
                  'n': entry.value.n,
                  'interval': entry.value.interval,
                  'ease': entry.value.ease,
                  'due': entry.value.due,
                },
            ],
          },
      ],
      'watched': [
        for (final group in watched)
          {'category': group.category, 'keys': group.keys.toList()},
      ],
    });
    return (json['updatedAt'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }
}
