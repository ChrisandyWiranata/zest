import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zest/core/network/api_client.dart';
import 'package:zest/features/auth/models/app_user.dart';
import 'package:zest/features/progress/services/xp_store.dart';
import 'package:zest/features/users/services/api_user_repo.dart';
import 'package:zest/features/users/services/progress_sync.dart';
import 'package:zest/features/videos/services/video_progress_store.dart';
import 'package:zest/features/vocab/services/srs_scheduler.dart';
import 'package:zest/features/vocab/services/srs_store.dart';

class FakeApiClient implements ApiClient {
  final posts = <(String, Map<String, dynamic>)>[];
  final gets = <String>[];

  final Map<String, Map<String, dynamic>> postResponses = {};
  final Map<String, Map<String, dynamic>> getResponses = {};

  Object? postError;
  Object? getError;

  @override
  String? idToken;

  @override
  Future<void> Function()? onUnauthorized;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final error = getError;
    if (error != null) throw error;
    gets.add(path);
    return getResponses[path] ?? const {};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final error = postError;
    if (error != null) throw error;
    posts.add((path, body));
    return postResponses[path] ?? const {};
  }
}

const _user = AppUser(uid: 'u1', email: 'a@x.com', displayName: 'Ana');

/// Bentuk respons backend: `srs[category][masteryKey] = {n, interval, ease, due}`.
Map<String, dynamic> _srsPayload(
  String category,
  List<Map<String, dynamic>> cards,
) => {
  category: {
    for (final card in cards)
      card['mastery_key'].toString(): {
        'n': card['n'],
        'interval': card['interval_days'],
        'ease': card['ease'],
        'due': card['due'],
      },
  },
};

void main() {
  group('migrateLegacyUserData', () {
    test('menyalin data lama ke namespace user & push ke backend', () async {
      SharedPreferences.setMockInitialValues({
        'xp.total': 50,
        'xp.streak': 2,
        'xp.today.xp': 20,
        'srs.n5.k1': '{"n":2,"i":8,"e":2.5,"d":12345}',
        'watched_video.n5.v1': true,
        'mastery.n5.mk': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final client = FakeApiClient();
      final repo = ApiUserRepo(client);

      await migrateLegacyUserData(prefs, repo, 'u1');

      expect(prefs.getInt('xp.u1.total'), 50);
      expect(prefs.getInt('xp.u1.streak'), 2);
      expect(prefs.getString('srs.u1.n5.k1'), contains('"i":8'));
      expect(prefs.getBool('watched_video.u1.n5.v1'), isTrue);
      expect(
        prefs.getString('srs.u1.n5.mk'),
        isNotNull,
        reason: 'mastery lama di-seed menjadi kartu SRS',
      );

      expect(
        prefs.containsKey('xp.total'),
        isFalse,
        reason: 'kunci legacy dihapus',
      );
      expect(prefs.containsKey('mastery.n5.mk'), isFalse);

      final body = client.posts.single.$2;
      final srs = body['srs'] as List<dynamic>;
      final srsKeys = [
        for (final group in srs) ...((group as Map)['cards'] as List),
      ];
      expect(
        srsKeys.length,
        2,
        reason: '2 kartu (k1 + hasil seed mastery) dalam satu request',
      );
      expect((body['watched'] as List<dynamic>).length, 1);
      expect(body['stats'], isNotNull);
    });

    test('tanpa data lama = tidak mengirim apa pun', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = FakeApiClient();
      final repo = ApiUserRepo(client);

      await migrateLegacyUserData(prefs, repo, 'u1');

      expect(client.posts, isEmpty);
    });
  });

  group('hydrateUserData', () {
    test('menulis snapshot cloud ke prefs lokal', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = FakeApiClient()
        ..getResponses['/me/progress'] = {
          'stats': {
            'total_xp': 120,
            'streak': 3,
            'last_day': 5,
            'today_xp': 7,
            'today_day': 5,
          },
          'srs': _srsPayload('n5', [
            {
              'mastery_key': 'k',
              'n': 2,
              'interval_days': 8,
              'ease': 2.5,
              'due': 999,
            },
          ]),
          'watched': {
            'n5': ['v1'],
          },
        };
      final repo = ApiUserRepo(client);

      await hydrateUserData(
        prefs,
        repo,
        'u1',
        getCategories: () async => ['n5', 'hiragana'],
      );

      expect(prefs.getInt('xp.u1.total'), 120);
      expect(prefs.getInt('xp.u1.streak'), 3);
      expect(prefs.getInt('xp.u1.lastDay'), 5);
      expect(prefs.getInt('xp.u1.today.xp'), 7);
      expect(prefs.getString('srs.u1.n5.k'), isNotNull);
      expect(prefs.getBool('watched_video.u1.n5.v1'), isTrue);
    });

    test('satu GET untuk seluruh kategori', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = FakeApiClient();
      final repo = ApiUserRepo(client);

      await hydrateUserData(
        prefs,
        repo,
        'u1',
        getCategories: () async => ['n5', 'hiragana', 'katakana'],
      );

      expect(client.gets, ['/me/progress']);
    });
  });

  group('ProgressSync', () {
    test('flush mengirim satu request berisi semua kategori', () async {
      SharedPreferences.setMockInitialValues({});
      final client = FakeApiClient();
      final sync = ProgressSync('u1', ApiUserRepo(client));

      sync.srsChanged('n5', 'k1', srsGood(null, 10));
      sync.srsChanged('n5', 'k2', srsGood(null, 10));
      sync.srsChanged('bunpou', 'b1', srsBad(null, 10));
      sync.statsChanged(const XpSnapshot(total: 5, streak: 1, todayXp: 5));
      sync.videoChanged('n5', 'v1');

      expect(sync.hasPending, isTrue);
      await sync.flush();
      expect(sync.hasPending, isFalse);
      expect(sync.status.value, SyncStatus.synced);

      expect(
        client.posts.length,
        1,
        reason: 'tiga operasi tulis lama jadi satu POST /me/sync',
      );
      final body = client.posts.single.$2;
      final srs = body['srs'] as List<dynamic>;
      expect(
        srs.fold<int>(
          0,
          (sum, g) => sum + ((g as Map)['cards'] as List).length,
        ),
        3,
      );
      expect((body['watched'] as List<dynamic>).length, 1);
      expect(body['stats'], isNotNull);
    });

    test('flush gagal → data tetap tertunda', () async {
      SharedPreferences.setMockInitialValues({});
      final client = FakeApiClient()..postError = const ApiException('boom');
      final sync = ProgressSync('u1', ApiUserRepo(client));

      sync.srsChanged('n5', 'k1', srsGood(null, 10));
      await sync.flush();

      expect(sync.status.value, SyncStatus.error);
      expect(sync.hasPending, isTrue, reason: 'retry-safe');
    });
  });

  group('ProgressSync.pushAll', () {
    test('mendorong seluruh data lokal per kategori ke cloud', () async {
      SharedPreferences.setMockInitialValues({
        'xp.u1.total': 100,
        'xp.u1.streak': 3,
        'xp.u1.lastDay': 5,
        'xp.u1.today.xp': 10,
        'xp.u1.today.day': 5,
        'srs.u1.n5.k1': '{"n":2,"i":30,"e":2.5,"d":12345}',
        'watched_video.u1.n5.v1': true,
        'watched_video.u1.n5.v2': true,
        'watched_video.u1.bunpou.b1': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final client = FakeApiClient();
      final sync = ProgressSync('u1', ApiUserRepo(client), prefs);

      await sync.pushAll(
        xpStore: XpStore(prefs, 'u1'),
        srsStore: SrsStore(prefs, 'u1'),
        videoProgressStore: VideoProgressStore(prefs, 'u1'),
        getCategories: () async => ['n5', 'bunpou'],
      );

      expect(sync.status.value, SyncStatus.synced);

      final body = client.posts.single.$2;
      final srs = body['srs'] as List<dynamic>;
      expect(srs.length, 1, reason: 'hanya n5 punya kartu SRS');
      final card = ((srs.single as Map)['cards'] as List).single as Map;
      expect(card['key'], 'k1');
      expect(card['n'], 2);
      expect(card['interval'], 30);
      expect(card['ease'], 2.5, reason: 'ease float harus tiba sebagai number');
      expect(card['due'], 12345);

      final watched = body['watched'] as List<dynamic>;
      final watchedKeys = [
        for (final group in watched) ...((group as Map)['keys'] as List),
      ];
      expect(watchedKeys.length, 3, reason: '2 video n5 + 1 video bunpou');
      expect(body['stats'], isNotNull);
      expect(
        prefs.getString('srs.u1.n5.k1'),
        isNotNull,
        reason: 'data lokal utuh',
      );
    });
  });

  group('ApiUserRepo', () {
    test('syncProfile mengirim identitas tanpa uid', () async {
      final client = FakeApiClient();
      final repo = ApiUserRepo(client);

      final result = await repo.syncProfile(_user);

      final (path, body) = client.posts.single;
      expect(path, '/me/profile');
      expect(body['email'], 'a@x.com');
      expect(body['displayName'], 'Ana');
      expect(body.containsKey('uid'), isFalse);
      expect(result.firstTime, isFalse);
    });

    test('writeSync menyertakan updatedAt dari server', () async {
      final client = FakeApiClient()
        ..postResponses['/me/sync'] = {'updatedAt': 1700};
      final repo = ApiUserRepo(client);

      final updatedAt = await repo.writeSync(
        stats: const XpSnapshot(total: 1, streak: 0, todayXp: 1),
      );

      expect(updatedAt, 1700);
    });
  });
}
