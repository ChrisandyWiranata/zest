import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zest/core/network/api_client.dart';
import 'package:zest/core/utils/animations.dart';
import 'package:zest/features/auth/models/app_user.dart';
import 'package:zest/features/auth/services/auth_service.dart';
import 'package:zest/features/categories/models/category_detail.dart';
import 'package:zest/features/categories/services/categories_service.dart';
import 'package:zest/features/profile/pages/profile_page.dart';
import 'package:zest/features/users/services/api_user_repo.dart';
import 'package:zest/features/users/services/user_session.dart';
import 'package:zest/features/videos/models/video_item.dart';
import 'package:zest/features/videos/services/videos_service.dart';
import 'package:zest/features/vocab/models/word.dart';
import 'package:zest/features/vocab/services/vocab_service.dart';
import 'package:zest/main.dart';

class _FakeAuth implements AuthService {
  AppUser? stored;
  Object? signInError;
  bool cancelled = false;

  /// idToken yang dikembalikan `signIn()` (default kosong, seperti fake lama).
  String signInToken = '';

  /// Bila diisi, `restore()` menunggu future ini dulu (uji re-entrancy).
  Future<void>? restoreDelay;

  int restoreCalls = 0;
  int signInCalls = 0;
  int signOutCalls = 0;

  @override
  Future<AppUser?> restore() async {
    restoreCalls += 1;
    await restoreDelay;
    return stored;
  }

  @override
  Future<AppUser> signIn() async {
    signInCalls += 1;
    if (cancelled) throw const SignInCancelled();
    final error = signInError;
    if (error != null) throw error;
    stored = AppUser(
      uid: 'u1',
      email: 'ana@x.com',
      displayName: 'Ana',
      idToken: signInToken,
    );
    return stored!;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    stored = null;
  }

  @override
  Stream<AppUser> get accountChanges => const Stream.empty();
}

class _FakeClient implements ApiClient {
  final posts = <(String, Map<String, dynamic>)>[];
  final gets = <String>[];

  /// Body yang dikembalikan untuk POST tertentu; default = respons kosong.
  final Map<String, Map<String, dynamic>> postResponses = {};
  final Map<String, Map<String, dynamic>> getResponses = {};

  @override
  String? idToken;

  @override
  Future<void> Function()? onUnauthorized;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    gets.add(path);
    return getResponses[path] ?? const {};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    posts.add((path, body));
    return postResponses[path] ?? const {};
  }
}

class _FakeBatchFailingClient implements ApiClient {
  @override
  String? idToken;

  @override
  Future<void> Function()? onUnauthorized;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async => const {};

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async => throw ApiException('simulasi: write gagal');
}

/// Profil dengan session token yang sudah "mati": memanggil `onUnauthorized`
/// lalu melempar 401 (meniru retry-satu-kali ApiClient asli). Token lain
/// diterima dan menerbitkan `sessionToken` baru.
class _SessionAwareClient implements ApiClient {
  @override
  String? idToken;

  @override
  Future<void> Function()? onUnauthorized;

  final posts = <(String, Map<String, dynamic>)>[];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async => const {};

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    posts.add((path, body));
    if (path == '/me/profile') {
      if (idToken == 'sess-mati') {
        final handler = onUnauthorized;
        if (handler != null) {
          await handler();
          if (idToken != 'sess-mati') return _issuedProfile;
        }
        throw const ApiException('token kedaluwarsa', statusCode: 401);
      }
      return _issuedProfile;
    }
    return const {};
  }

  static const _issuedProfile = {
    'firstTime': false,
    'serverNow': 1,
    'sessionToken': 'sess-baru',
  };
}

/// Semua request gagal seperti jaringan mati (tanpa statusCode → bukan 401).
class _OfflineClient implements ApiClient {
  @override
  String? idToken;

  @override
  Future<void> Function()? onUnauthorized;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async => throw ApiException('jaringan tidak tersedia');

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async => throw ApiException('jaringan tidak tersedia');
}

class _FakeCategoriesService implements CategoriesService {
  @override
  Future<List<CategoryDetail>> getCategories() async => const [
    CategoryDetail(name: 'n5', title: 'N5', total: 1, level: 'n5'),
  ];
}

class _FakeVocabService implements VocabService {
  @override
  Future<List<Word>> getWords(String category) async => [
    Word(category: category, word: '私', read: 'わたし', meaning: 'saya'),
  ];
}

class _FakeVideosService implements VideosService {
  @override
  Future<List<VideoItem>> getVideos(String category, {String? type}) async =>
      const <VideoItem>[];
}

/// JWT palsu yang payloadnya hanya `{exp}` (epoch detik) — cukup untuk cek
/// `isIdTokenFresh`.
String _jwtWithExp(int expSeconds) {
  String encode(Object data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  return '${encode({'alg': 'none'})}.${encode({'exp': expSeconds})}.x';
}

void main() {
  setUp(() => ambientEnabled = false);

  Widget root(UserSession session, {required SharedPreferences prefs}) =>
      ZestRoot(
        prefs: prefs,
        session: session,
        categoriesService: _FakeCategoriesService(),
        vocabService: _FakeVocabService(),
        videosService: _FakeVideosService(),
      );

  group('alur login', () {
    testWidgets('tanpa sesi tersimpan → LoginPage, lalu masuk ke home', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = _FakeClient();
      final auth = _FakeAuth();
      final session = UserSession(
        repo: ApiUserRepo(client),
        prefs: prefs,
        auth: auth,
        getCategories: () async => ['n5'],
      );
      await session.restore();

      await tester.pumpWidget(root(session, prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.text('Masuk dengan Google'), findsOneWidget);
      expect(find.text('Kategori'), findsNothing);

      await tester.tap(find.text('Masuk dengan Google'));
      await tester.pumpAndSettle();

      expect(find.text('Kategori'), findsOneWidget);
      expect(find.text('Masuk dengan Google'), findsNothing);
      expect(
        client.posts.any((w) => w.$1 == '/me/profile'),
        isTrue,
        reason: 'profil dikirim ke backend saat login',
      );

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byType(ProfilePage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Keluar'),
        120,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();

      expect(find.text('Keluar akun?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Keluar'));
      await tester.pumpAndSettle();

      expect(find.text('Masuk dengan Google'), findsOneWidget);
      expect(auth.stored, isNull);
    });

    testWidgets('sesi tersimpan auto-restore langsung ke home', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = _FakeClient();
      final auth = _FakeAuth()
        ..stored = const AppUser(uid: 'u1', email: 'ana@x.com');
      final session = UserSession(
        repo: ApiUserRepo(client),
        prefs: prefs,
        auth: auth,
        getCategories: () async => ['n5'],
      );
      await session.restore();

      await tester.pumpWidget(root(session, prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.text('Kategori'), findsOneWidget);
      expect(find.text('Masuk dengan Google'), findsNothing);
    });

    testWidgets('login dibatalkan → tanpa pesan error', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = _FakeAuth()..cancelled = true;
      final session = UserSession(
        repo: ApiUserRepo(_FakeClient()),
        prefs: prefs,
        auth: auth,
      );

      await tester.pumpWidget(root(session, prefs: prefs));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Masuk dengan Google'));
      await tester.pumpAndSettle();

      expect(find.text('Masuk dengan Google'), findsOneWidget);
      expect(find.textContaining('Coba lagi'), findsNothing);
    });

    testWidgets('signIn gagal → pesan konfigurasi OAuth', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = _FakeAuth()..signInError = StateError('akun tidak valid');
      final session = UserSession(
        repo: ApiUserRepo(_FakeClient()),
        prefs: prefs,
        auth: auth,
      );

      await tester.pumpWidget(root(session, prefs: prefs));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Masuk dengan Google'));
      await tester.pumpAndSettle();

      expect(
        find.text('Gagal masuk lewat Google. Periksa konfigurasi OAuth.'),
        findsOneWidget,
      );
    });

    testWidgets('backend menolak → pesan server', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = UserSession(
        repo: ApiUserRepo(_FakeBatchFailingClient()),
        prefs: prefs,
        auth: _FakeAuth(),
      );

      await tester.pumpWidget(root(session, prefs: prefs));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Masuk dengan Google'));
      await tester.pumpAndSettle();

      expect(
        find.text('Gagal menyiapkan akun di server. Coba lagi.'),
        findsOneWidget,
      );
    });

    testWidgets('layout lebar: split hero + kartu masuk', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = UserSession(
        repo: ApiUserRepo(_FakeClient()),
        prefs: prefs,
        auth: _FakeAuth(),
      );
      await session.restore();

      await tester.pumpWidget(root(session, prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.text('Masuk ke Zest'), findsOneWidget);
      expect(find.text('Masuk dengan Google'), findsOneWidget);
      expect(find.text('Zest'), findsOneWidget);
      expect(
        find.text('すっきり · Belajar bahasa Jepang,\ntiap hari.'),
        findsOneWidget,
      );
    });
  });

  group('adopt (credential web)', () {
    test(
      'sukses → session masuk, idToken diteruskan, profil terkirim',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final client = _FakeClient();
        final session = UserSession(
          repo: ApiUserRepo(client),
          prefs: prefs,
          auth: _FakeAuth(),
          getCategories: () async => ['n5'],
        );

        await session.adopt(
          const AppUser(
            uid: 'u1',
            email: 'ana@x.com',
            displayName: 'Ana',
            idToken: 'tok-123',
          ),
        );

        expect(session.value?.uid, 'u1');
        expect(client.idToken, 'tok-123');
        expect(client.posts.any((w) => w.$1 == '/me/profile'), isTrue);
      },
    );

    test(
      'backend menolak → LoginException profile, session tetap null',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final session = UserSession(
          repo: ApiUserRepo(_FakeBatchFailingClient()),
          prefs: prefs,
          auth: _FakeAuth(),
          getCategories: () async => ['n5'],
        );

        await expectLater(
          session.adopt(
            const AppUser(uid: 'u1', email: 'ana@x.com', idToken: 'tok'),
          ),
          throwsA(
            isA<LoginException>().having((e) => e.stage, 'stage', 'profile'),
          ),
        );
        expect(session.value, isNull);
      },
    );
  });

  group('restore (startup di belakang frame pertama)', () {
    test(
      'prompt Google tidak menjawab → timeout, tetap null (tanpa gantung)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final auth = _FakeAuth()
          ..stored = const AppUser(uid: 'u1', email: 'ana@x.com')
          ..restoreDelay = Completer<void>().future; // tidak pernah selesai
        final session = UserSession(
          repo: ApiUserRepo(_FakeClient()),
          prefs: prefs,
          auth: auth,
          restoreTimeout: const Duration(milliseconds: 50),
        );

        await session.restore();

        expect(session.value, isNull, reason: 'dianggap belum login');
        expect(auth.restoreCalls, 1);
      },
    );

    test('adopt menang duluan → restore tidak hydrate kedua kali', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = _FakeClient();
      final gate = Completer<void>();
      final auth = _FakeAuth()
        ..stored = const AppUser(
          uid: 'u1',
          email: 'ana@x.com',
          idToken: 'dari-restore',
        )
        ..restoreDelay = gate.future;
      final session = UserSession(
        repo: ApiUserRepo(client),
        prefs: prefs,
        auth: auth,
        getCategories: () async => ['n5'],
        restoreTimeout: const Duration(seconds: 5),
      );

      final restoreFuture = session.restore(); // tertahan di auth.restore()
      await session.adopt(
        const AppUser(
          uid: 'u1',
          email: 'ana@x.com',
          displayName: 'Dari Adopt',
          idToken: 'dari-adopt',
        ),
      );
      gate.complete();
      await restoreFuture;

      expect(session.value?.displayName, 'Dari Adopt');
      final profilePosts = client.posts.where((w) => w.$1 == '/me/profile');
      expect(profilePosts, hasLength(1), reason: 'hydrate cukup sekali');
    });

    test(
      'restore selesai null sesudah adopt → sesi tidak di-null-kan',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final client = _FakeClient();
        final gate = Completer<void>();
        final auth = _FakeAuth()
          ..stored =
              null // restore balik "belum login"
          ..restoreDelay = gate.future;
        final session = UserSession(
          repo: ApiUserRepo(client),
          prefs: prefs,
          auth: auth,
          getCategories: () async => ['n5'],
          restoreTimeout: const Duration(seconds: 5),
        );

        final restoreFuture = session.restore();
        await session.adopt(
          const AppUser(uid: 'u1', email: 'ana@x.com', idToken: 'dari-adopt'),
        );
        gate.complete();
        await restoreFuture;

        expect(
          session.value?.uid,
          'u1',
          reason: 'jangan menimpa sesi dengan null',
        );
      },
    );
  });

  group('reauthenticate (401 dari backend)', () {
    /// JWT palsu yang payloadnya hanya `{exp}` — cukup untuk cek isIdTokenFresh.
    String jwt(int expSeconds) {
      String encode(Object data) =>
          base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
      return '${encode({'alg': 'none'})}.${encode({'exp': expSeconds})}.x';
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final fresh = jwt(now + 3600);
    final stale = jwt(now - 60);

    Future<(UserSession, _FakeClient, _FakeAuth)> buildSession({
      bool isWeb = false,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = _FakeClient()..idToken = 'token-basi';
      final auth = _FakeAuth();
      final session = UserSession(
        repo: ApiUserRepo(client),
        prefs: prefs,
        auth: auth,
        isWeb: isWeb,
      );
      session.value = const AppUser(uid: 'u1', email: 'ana@x.com');
      return (session, client, auth);
    }

    test('native: restore menghasilkan token segar → tanpa logout', () async {
      final (session, client, auth) = await buildSession();
      auth.stored = AppUser(uid: 'u1', email: 'ana@x.com', idToken: fresh);

      await session.reauthenticate();

      expect(client.idToken, fresh);
      expect(session.value?.uid, 'u1');
      expect(auth.signOutCalls, 0);
      expect(auth.signInCalls, 0, reason: 'tidak perlu interaksi');
    });

    test('native: token hasil restore basi → coba signIn sekali', () async {
      final (session, client, auth) = await buildSession();
      auth.stored = AppUser(uid: 'u1', email: 'ana@x.com', idToken: stale);
      auth.signInToken = fresh;

      await session.reauthenticate();

      expect(client.idToken, fresh);
      expect(auth.signInCalls, 1);
      expect(auth.signOutCalls, 0);
      expect(session.value?.uid, 'u1');
    });

    test(
      'native: refresh gagal (restore null, signIn batal) → logout',
      () async {
        final (session, client, auth) = await buildSession();
        auth.cancelled = true;

        await session.reauthenticate();

        expect(session.value, isNull);
        expect(client.idToken, isNull);
        expect(auth.signOutCalls, 1);
      },
    );

    test(
      'native: akun berbeda dari sesi aktif → logout (bukan ganti user)',
      () async {
        final (session, client, auth) = await buildSession();
        auth.stored = AppUser(uid: 'lain', email: 'ana@x.com', idToken: fresh);

        await session.reauthenticate();

        expect(session.value, isNull);
        expect(client.idToken, isNull);
      },
    );

    test(
      'web: One Tap memberi credential segar (uid sama) → tanpa logout',
      () async {
        final (session, client, auth) = await buildSession(isWeb: true);
        auth.stored = AppUser(uid: 'u1', email: 'ana@x.com', idToken: fresh);

        await session.reauthenticate();

        expect(
          auth.restoreCalls,
          1,
          reason: 'coba One Tap sekali, bukan langsung logout',
        );
        expect(client.idToken, fresh);
        expect(session.value?.uid, 'u1');
        expect(auth.signOutCalls, 0);
        expect(auth.signInCalls, 0, reason: 'web tidak pakai signIn()');
      },
    );

    test(
      'web: One Tap tidak memberi credential → logout ke LoginPage',
      () async {
        final (session, client, auth) = await buildSession(isWeb: true);
        auth.stored = null;

        await session.reauthenticate();

        expect(auth.restoreCalls, 1);
        expect(session.value, isNull);
        expect(client.idToken, isNull);
        expect(auth.signOutCalls, 1);
      },
    );

    test('web: credential uid berbeda dari sesi aktif → logout', () async {
      final (session, client, auth) = await buildSession(isWeb: true);
      auth.stored = AppUser(uid: 'lain', email: 'ana@x.com', idToken: fresh);

      await session.reauthenticate();

      expect(session.value, isNull);
      expect(client.idToken, isNull);
      expect(auth.signOutCalls, 1);
    });

    test(
      'web: token One Tap hasilnya basi → logout (jangan pakai token 401)',
      () async {
        final (session, client, auth) = await buildSession(isWeb: true);
        auth.stored = AppUser(uid: 'u1', email: 'ana@x.com', idToken: stale);

        await session.reauthenticate();

        expect(session.value, isNull);
        expect(client.idToken, isNull);
        expect(auth.signOutCalls, 1);
      },
    );

    test('panggilan bersamaan hanya melakukan satu refresh', () async {
      final (session, client, auth) = await buildSession();
      final gate = Completer<void>();
      auth.restoreDelay = gate.future;
      auth.stored = AppUser(uid: 'u1', email: 'ana@x.com', idToken: fresh);

      final first = session.reauthenticate();
      final second = session.reauthenticate();
      gate.complete();
      await Future.wait([first, second]);

      expect(auth.restoreCalls, 1);
      expect(client.idToken, fresh);
    });
  });

  group('sesi web tersimpan (session token 1 hari)', () {
    const savedKey = 'session.web.v1';

    String savedJson({String token = 'sess-1'}) => jsonEncode({
      'uid': 'u1',
      'email': 'ana@x.com',
      'displayName': 'Ana',
      'photoUrl': '',
      'sessionToken': token,
      'savedAt': 0,
    });

    test('restore dari sesi tersimpan → masuk tanpa prompt Google', () async {
      SharedPreferences.setMockInitialValues({savedKey: savedJson()});
      final prefs = await SharedPreferences.getInstance();
      final client = _FakeClient();
      final auth = _FakeAuth(); // stored = null → kalau dipanggil balik null
      final session = UserSession(
        repo: ApiUserRepo(client),
        prefs: prefs,
        auth: auth,
        isWeb: true,
        getCategories: () async => ['n5'],
      );

      await session.restore();

      expect(session.value?.uid, 'u1');
      expect(auth.restoreCalls, 0, reason: 'tanpa prompt One Tap sama sekali');
      expect(
        client.idToken,
        'sess-1',
        reason: 'Bearer = session token tersimpan',
      );
    });

    test(
      '401 sesi tersimpan → dibersihkan, lalu One Tap sukses → token baru',
      () async {
        SharedPreferences.setMockInitialValues({
          savedKey: savedJson(token: 'sess-mati'),
        });
        final prefs = await SharedPreferences.getInstance();
        final client = _SessionAwareClient();
        final auth = _FakeAuth()
          ..stored = AppUser(
            uid: 'u1',
            email: 'ana@x.com',
            idToken: _jwtWithExp(
              DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
            ),
          );
        final session = UserSession(
          repo: ApiUserRepo(client),
          prefs: prefs,
          auth: auth,
          isWeb: true,
          getCategories: () async => ['n5'],
        );
        client.onUnauthorized = session.reauthenticate;

        await session.restore();

        expect(
          session.value?.uid,
          'u1',
          reason: 'masuk lagi lewat fallback credential Google',
        );
        expect(auth.restoreCalls, 1, reason: 'satu kali prompt fallback');
        expect(auth.signOutCalls, 0);
        expect(client.idToken, 'sess-baru', reason: 'token lama tergantikan');
        expect(prefs.getString(savedKey), contains('sess-baru'));
        expect(prefs.getString(savedKey), isNot(contains('sess-mati')));
      },
    );

    test(
      '401 sesi tersimpan + One Tap nihil → di LoginPage, key terhapus',
      () async {
        SharedPreferences.setMockInitialValues({
          savedKey: savedJson(token: 'sess-mati'),
        });
        final prefs = await SharedPreferences.getInstance();
        final client = _SessionAwareClient();
        final auth = _FakeAuth();
        final session = UserSession(
          repo: ApiUserRepo(client),
          prefs: prefs,
          auth: auth,
          isWeb: true,
          getCategories: () async => ['n5'],
        );
        client.onUnauthorized = session.reauthenticate;

        await session.restore();

        expect(session.value, isNull);
        expect(auth.restoreCalls, 1, reason: 'fallback prompt Google sekali');
        expect(
          prefs.getString(savedKey),
          isNull,
          reason: 'sesi mati dibersihkan',
        );
        expect(auth.signOutCalls, 0, reason: 'tak ada sesi aktif dicabut');
      },
    );

    test(
      'error jaringan non-401 saat restore sesi → tetap masuk (offline)',
      () async {
        SharedPreferences.setMockInitialValues({savedKey: savedJson()});
        final prefs = await SharedPreferences.getInstance();
        final client = _OfflineClient();
        final auth = _FakeAuth();
        final session = UserSession(
          repo: ApiUserRepo(client),
          prefs: prefs,
          auth: auth,
          isWeb: true,
          getCategories: () async => ['n5'],
        );

        await session.restore();

        expect(
          session.value?.uid,
          'u1',
          reason: 'progres lokal masih ada → tetap masuk',
        );
        expect(
          auth.restoreCalls,
          0,
          reason: 'bukan sesi mati, jangan panggil Google',
        );
        expect(client.idToken, 'sess-1');
      },
    );

    test('native mengabaikan sesi web tersimpan', () async {
      SharedPreferences.setMockInitialValues({savedKey: savedJson()});
      final prefs = await SharedPreferences.getInstance();
      final client = _FakeClient();
      final auth = _FakeAuth();
      final session = UserSession(
        repo: ApiUserRepo(client),
        prefs: prefs,
        auth: auth,
        isWeb: false,
      );

      await session.restore();

      expect(session.value, isNull, reason: 'native tetap alur Google');
      expect(auth.restoreCalls, 1, reason: 'pakai restore() native');
      expect(
        prefs.getString(savedKey),
        isNotNull,
        reason: 'sesi web dibiarkan, bukan milik native',
      );
      expect(client.idToken, isNull);
    });

    test('logout (web) menghapus sesi tersimpan', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = _FakeClient()
        ..postResponses['/me/profile'] = {
          'firstTime': false,
          'serverNow': 1,
          'sessionToken': 'sess-1',
        };
      final auth = _FakeAuth();
      final session = UserSession(
        repo: ApiUserRepo(client),
        prefs: prefs,
        auth: auth,
        isWeb: true,
      );

      await session.adopt(const AppUser(uid: 'u1', email: 'ana@x.com'));
      expect(prefs.getString(savedKey), contains('sess-1'));
      expect(
        client.idToken,
        'sess-1',
        reason: 'Bearer web pindah ke session token',
      );

      await session.logout();

      expect(prefs.getString(savedKey), isNull);
      expect(client.idToken, isNull);
      expect(auth.signOutCalls, 1);
      expect(session.value, isNull);
    });

    test('native adopt tidak menyimpan / memakai session token', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = _FakeClient()
        ..postResponses['/me/profile'] = {
          'firstTime': false,
          'serverNow': 1,
          'sessionToken': 'sess-1',
        };
      final session = UserSession(
        repo: ApiUserRepo(client),
        prefs: prefs,
        auth: _FakeAuth(),
        isWeb: false,
      );

      await session.adopt(
        const AppUser(uid: 'u1', email: 'ana@x.com', idToken: 'google-token'),
      );

      expect(
        client.idToken,
        'google-token',
        reason: 'native tetap pakai idToken Google',
      );
      expect(prefs.getString(savedKey), isNull);
    });
  });

  group('sesi native (cache profil, home instan)', () {
    const nativeKey = 'session.native.v1';

    String nativeCache({String uid = 'u1'}) => jsonEncode({
      'uid': uid,
      'email': 'ana@x.com',
      'displayName': 'Ana',
      'photoUrl': '',
      'savedAt': 0,
    });

    test('restore dari cache → home seketika, token senyap menyusul', () async {
      SharedPreferences.setMockInitialValues({nativeKey: nativeCache()});
      final prefs = await SharedPreferences.getInstance();
      final client = _FakeClient();
      final auth = _FakeAuth()
        ..stored = AppUser(
          uid: 'u1',
          email: 'ana@x.com',
          idToken: _jwtWithExp(
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
          ),
        );
      final session = UserSession(
        repo: ApiUserRepo(client),
        prefs: prefs,
        auth: auth,
        isWeb: false,
        getCategories: () async => ['n5'],
      );

      final restoreFuture = session.restore(); // sengaja belum di-await

      expect(
        session.value?.uid,
        'u1',
        reason: 'home langsung tanpa menunggu Google/Play Services',
      );

      await restoreFuture;
      await pumpEventQueue();

      expect(
        auth.restoreCalls,
        1,
        reason: 'refresh senyap jalan di background',
      );
      expect(
        client.idToken,
        isNotNull,
        reason: 'token senyap mengisi Bearer setelahnya',
      );
      expect(auth.signInCalls, 0, reason: 'tanpa interaksi sama sekali');
      expect(session.value?.uid, 'u1');
    });

    test(
      'cache ada + silent restore gagal → tetap home, tanpa dialog signIn',
      () async {
        SharedPreferences.setMockInitialValues({nativeKey: nativeCache()});
        final prefs = await SharedPreferences.getInstance();
        final client = _FakeClient();
        final auth = _FakeAuth(); // stored = null → silent restore gagal
        final session = UserSession(
          repo: ApiUserRepo(client),
          prefs: prefs,
          auth: auth,
          isWeb: false,
          getCategories: () async => ['n5'],
        );

        await session.restore();
        await pumpEventQueue();

        expect(
          session.value?.uid,
          'u1',
          reason: 'kegagalan Google tidak boleh mengembalikan LoginPage',
        );
        expect(auth.restoreCalls, 1);
        expect(auth.signInCalls, 0, reason: 'restore tidak minta interaksi');
        expect(client.idToken, isNull);
      },
    );

    test('restore native tanpa cache → tetap alur Google lama', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = _FakeClient();
      final auth = _FakeAuth()
        ..stored = AppUser(uid: 'u1', email: 'ana@x.com', idToken: 'google');
      final session = UserSession(
        repo: ApiUserRepo(client),
        prefs: prefs,
        auth: auth,
        isWeb: false,
      );

      await session.restore();
      await pumpEventQueue();

      expect(auth.restoreCalls, 1, reason: 'silent restore dipanggil sekali');
      expect(session.value?.uid, 'u1');
      expect(
        prefs.getString(nativeKey),
        contains('"uid":"u1"'),
        reason: 'profil disimpan untuk restore berikutnya',
      );
    });

    test(
      'adopt native menyimpan profil tanpa token; logout menghapusnya',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final client = _FakeClient()
          ..postResponses['/me/profile'] = {'firstTime': false, 'serverNow': 1};
        final auth = _FakeAuth();
        final session = UserSession(
          repo: ApiUserRepo(client),
          prefs: prefs,
          auth: auth,
          isWeb: false,
        );

        await session.adopt(
          const AppUser(
            uid: 'u1',
            email: 'ana@x.com',
            displayName: 'Ana',
            idToken: 'google-token',
          ),
        );

        final cached = prefs.getString(nativeKey);
        expect(cached, contains('"uid":"u1"'));
        expect(
          cached,
          isNot(contains('idToken')),
          reason: 'token tidak disimpan',
        );
        expect(
          cached,
          isNot(contains('sessionToken')),
          reason: 'session token web bukan urusan native',
        );
        expect(client.idToken, 'google-token');

        await session.logout();

        expect(prefs.getString(nativeKey), isNull);
        expect(auth.signOutCalls, 1);
        expect(session.value, isNull);
      },
    );

    test('web tidak membaca cache profil native', () async {
      SharedPreferences.setMockInitialValues({nativeKey: nativeCache()});
      final prefs = await SharedPreferences.getInstance();
      final client = _FakeClient();
      final auth = _FakeAuth(); // prompt web balik null
      final session = UserSession(
        repo: ApiUserRepo(client),
        prefs: prefs,
        auth: auth,
        isWeb: true,
      );

      await session.restore();

      expect(
        auth.restoreCalls,
        1,
        reason: 'web tetap alur credential (One Tap), bukan cache native',
      );
      expect(session.value, isNull);
      expect(
        prefs.getString(nativeKey),
        isNotNull,
        reason: 'key native dibiarkan',
      );
    });
  });
}
