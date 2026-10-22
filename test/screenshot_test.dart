import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zest/core/network/api_client.dart';
import 'package:zest/core/theme/app_theme.dart';
import 'package:zest/core/utils/animations.dart';
import 'package:zest/features/auth/models/app_user.dart';
import 'package:zest/features/auth/pages/login_page.dart';
import 'package:zest/features/auth/services/auth_service.dart';
import 'package:zest/features/categories/models/category_detail.dart';
import 'package:zest/features/categories/services/categories_service.dart';
import 'package:zest/features/progress/services/xp_store.dart';
import 'package:zest/features/profile/pages/profile_page.dart';
import 'package:zest/features/settings/services/settings_store.dart';
import 'package:zest/features/users/services/api_user_repo.dart';
import 'package:zest/features/users/services/progress_sync.dart';
import 'package:zest/features/users/services/user_session.dart';
import 'package:zest/features/videos/models/video_item.dart';
import 'package:zest/features/videos/services/video_progress_store.dart';
import 'package:zest/features/videos/services/videos_service.dart';
import 'package:zest/features/vocab/models/word.dart';
import 'package:zest/features/vocab/services/srs_scheduler.dart';
import 'package:zest/features/vocab/services/srs_store.dart';
import 'package:zest/features/vocab/services/vocab_service.dart';
import 'package:zest/main.dart';

/// Screenshot docs: render layar nyata dengan data contoh lalu simpan PNG.
///
/// Jalankan: `flutter test test/screenshot_test.dart --update-goldens`
/// Hasil: `test/screenshots/*.png` (lalu di-resize ke lebar 780 px).

const Size _phone = Size(390, 844);
const double _dpr = 2;

class _FakeApiClient implements ApiClient {
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
  ) async => const {};
}

class _FakeAuth implements AuthService {
  @override
  Stream<AppUser> get accountChanges => const Stream.empty();

  @override
  Future<AppUser?> restore() async => null;

  @override
  Future<AppUser> signIn() async =>
      const AppUser(uid: 'u1', email: 'ana@x.com', displayName: 'Ana');

  @override
  Future<void> signOut() async {}
}

class _FakeCategoriesService implements CategoriesService {
  @override
  Future<List<CategoryDetail>> getCategories() async => const [
    CategoryDetail(name: 'n5', title: 'N5', total: 128, level: 'N5'),
    CategoryDetail(name: 'n4', title: 'N4', total: 96, level: 'N4'),
    CategoryDetail(name: 'hiragana', title: 'Hiragana', total: 46),
    CategoryDetail(name: 'katakana', title: 'Katakana', total: 46),
  ];
}

class _FakeVocabService implements VocabService {
  @override
  Future<List<Word>> getWords(String category) async => [
    Word(
      id: 'n5-1',
      category: category,
      word: '私',
      read: 'わたし',
      meaning: 'saya',
      exampleJp: '私は学生です。',
      exampleMeaning: 'Saya seorang pelajar.',
    ),
    Word(
      id: 'n5-2',
      category: category,
      word: '友達',
      read: 'ともだち',
      meaning: 'teman',
      exampleJp: '友達と映画を見ます。',
      exampleMeaning: 'Menonton film bersama teman.',
    ),
    Word(
      id: 'n5-3',
      category: category,
      word: '学生',
      read: 'がくせい',
      meaning: 'pelajar',
      exampleJp: '彼は大学生です。',
      exampleMeaning: 'Dia mahasiswa.',
    ),
    Word(
      id: 'n5-4',
      category: category,
      word: '食べる',
      read: 'たべる',
      meaning: 'makan',
      exampleJp: 'ご飯を食べる。',
      exampleMeaning: 'Makan nasi.',
    ),
    Word(
      id: 'n5-5',
      category: category,
      word: '学校',
      read: 'がっこう',
      meaning: 'sekolah',
      exampleJp: '学校へ行きます。',
      exampleMeaning: 'Pergi ke sekolah.',
    ),
  ];
}

class _FakeSrsStore implements SrsStore {
  final Map<String, SrsCard> _cards = {};

  void seedDue(String key) =>
      _cards[key] = SrsCard(n: 2, interval: 3, ease: 2.5, due: 0);

  void seedMature(String key) =>
      _cards[key] = SrsCard(n: 5, interval: 40, ease: 2.6, due: 99999);

  @override
  String get uid => 'u1';

  @override
  Future<SrsCard?> get(String category, String id) async => _cards[id];

  @override
  Future<Map<String, SrsCard>> loadAll(String category) async => Map.of(_cards);

  @override
  Future<void> update(String category, String id, SrsCard card) async {
    _cards[id] = card;
  }

  @override
  Future<Set<String>> masteredKeys(String category) async =>
      _cards.entries.where((e) => isMature(e.value)).map((e) => e.key).toSet();

  @override
  Future<void> migrateLegacy(String category) async {}
}

class _FakeXpStore implements XpStore {
  @override
  String get uid => 'u1';

  @override
  Future<XpSnapshot> snapshot() async =>
      const XpSnapshot(total: 1250, streak: 6, todayXp: 90);

  @override
  Future<XpInfo> addXp(int points) async => load();

  @override
  Future<XpInfo> load() async =>
      const XpInfo(total: 1250, streak: 6, todayXp: 90, level: 5);
}

class _FakeVideosService implements VideosService {
  @override
  Future<List<VideoItem>> getVideos(String category, {String? type}) async {
    const all = [
      VideoItem(
        id: 1,
        category: 'n5',
        bab: 'Bab 1 · Perkenalan',
        type: VideoItem.typeGrammar,
        title: 'Pola kalimat dasar',
        videoUrl: 'https://example.com/v1',
      ),
      VideoItem(
        id: 2,
        category: 'n5',
        bab: 'Bab 1 · Perkenalan',
        type: VideoItem.typeVocab,
        title: 'Kosakata perkenalan',
        videoUrl: 'https://example.com/v2',
      ),
      VideoItem(
        id: 3,
        category: 'n5',
        bab: 'Bab 2 · Sehari-hari',
        type: VideoItem.typeGrammar,
        title: 'Partikel は & を',
        videoUrl: 'https://example.com/v3',
      ),
    ];
    if (category != 'n5') return const <VideoItem>[];
    if (type == null) return all;
    return all.where((v) => v.type == type).toList();
  }
}

class _FakeVideoProgressStore implements VideoProgressStore {
  @override
  String get uid => 'u1';

  @override
  Future<bool> isWatched(String category, String id) async => id == '1';

  @override
  Future<void> setWatched(String category, String id, bool watched) async {}

  @override
  Future<int> countWatched() async => 24;

  @override
  Future<Set<String>> watchedKeys(String category) async => const {'1'};

  @override
  Future<int?> getResume(String category, String id) async => null;

  @override
  Future<void> setResume(String category, String id, int milliseconds) async {}
}

Future<SettingsStore> _settings() async {
  final prefs = await SharedPreferences.getInstance();
  final store = SettingsStore(prefs, 'u1');
  await store.load();
  return store;
}

Widget _app({
  required SrsStore srsStore,
  XpStore? xpStore,
  SettingsStore? settings,
  ProgressSync? sync,
}) => ZestApp(
  categoriesService: _FakeCategoriesService(),
  vocabService: _FakeVocabService(),
  videosService: _FakeVideosService(),
  srsStore: srsStore,
  xpStore: xpStore ?? _FakeXpStore(),
  videoProgressStore: _FakeVideoProgressStore(),
  user: const AppUser(uid: 'u1', email: 'ana@x.com', displayName: 'Ana'),
  onLogout: () {},
  settings: settings,
  sync: sync,
);

/// Rasio piksel 2× menaikkan detail; `matchesGoldenFile` menangkap seluruh
/// permukaan aplikasi (RepaintBoundary akar) SETELAH [drive] selesai — jadi
/// semua navigasi/pump harus ada di dalam [drive], bukan sesudahnya.
Future<void> _shoot(
  WidgetTester tester,
  String name,
  Future<void> Function(WidgetTester tester) drive,
) async {
  tester.view.physicalSize = Size(_phone.width * _dpr, _phone.height * _dpr);
  tester.view.devicePixelRatio = _dpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await drive(tester);
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('screenshots/$name.png'),
  );
}

/// Golden ini artefak dokumentasi (di-resize `sips`, jadi tidak pernah
/// byte-identik dengan render baru). Lewati di `flutter test` biasa; panggil
/// `SCREENSHOTS=1 flutter test test/screenshot_test.dart --update-goldens`
/// untuk regenerate.
final bool _enabled = Platform.environment['SCREENSHOTS'] == '1';

void _shot(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, body, skip: !_enabled);
}

void main() {
  setUp(() => ambientEnabled = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openKategori(WidgetTester t) async {
    await t.pumpWidget(_app(srsStore: _FakeSrsStore()));
    await t.pumpAndSettle();
    await t.tap(find.text('N5'));
    await t.pumpAndSettle();
  }

  _shot('01 login', (tester) async {
    final session = UserSession(
      repo: ApiUserRepo(_FakeApiClient()),
      auth: _FakeAuth(),
      prefs: await SharedPreferences.getInstance(),
      isWeb: true,
    );
    await _shoot(tester, '01-login', (t) async {
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: LoginPage(session: session),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Masuk dengan Google'), findsOneWidget);
    });
  });

  _shot('02 beranda', (tester) async {
    final srs = _FakeSrsStore()
      ..seedDue('n5-1')
      ..seedDue('n5-2')
      ..seedMature('n5-3');
    await _shoot(tester, '02-beranda', (t) async {
      await t.pumpWidget(_app(srsStore: srs));
      await t.pumpAndSettle();
      expect(find.text('Hai, Ana!'), findsOneWidget);
      expect(find.text('Flashcard hari ini'), findsOneWidget);
    });
  });

  _shot('03 kategori-kosakata', (tester) async {
    final srs = _FakeSrsStore()..seedDue('n5-1');
    await _shoot(tester, '03-kategori-kosakata', (t) async {
      await t.pumpWidget(_app(srsStore: srs));
      await t.pumpAndSettle();
      await t.tap(find.text('N5'));
      await t.pumpAndSettle();
      expect(find.text('私'), findsOneWidget);
      expect(find.textContaining('Mulai Flashcard'), findsOneWidget);
    });
  });

  _shot('04 flashcard-depan', (tester) async {
    final srs = _FakeSrsStore()..seedDue('n5-1');
    await _shoot(tester, '04-flashcard-depan', (t) async {
      await t.pumpWidget(_app(srsStore: srs));
      await t.pumpAndSettle();
      await t.tap(find.text('N5'));
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Mulai Flashcard'));
      await t.pumpAndSettle();
      expect(find.text('Ketuk untuk membalik'), findsOneWidget);
      expect(find.text('私'), findsOneWidget);
    });
  });

  _shot('05 flashcard-belakang', (tester) async {
    final srs = _FakeSrsStore()..seedDue('n5-1');
    await _shoot(tester, '05-flashcard-belakang', (t) async {
      await t.pumpWidget(_app(srsStore: srs));
      await t.pumpAndSettle();
      await t.tap(find.text('N5'));
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Mulai Flashcard'));
      await t.pumpAndSettle();
      await t.tap(find.text('私'));
      await t.pumpAndSettle();
      expect(find.text('Sudah hafal'), findsOneWidget);
      expect(find.text('Belum hafal'), findsOneWidget);
    });
  });

  _shot('06 kategori-video', (tester) async {
    await _shoot(tester, '06-kategori-video', (t) async {
      await openKategori(t);
      await t.tap(find.text('Video'));
      await t.pumpAndSettle();
      expect(find.textContaining('Bab 1'), findsWidgets);
      expect(find.text('Pola kalimat dasar'), findsOneWidget);
    });
  });

  _shot('07 profil', (tester) async {
    final srs = _FakeSrsStore()..seedMature('n5-1');
    final sync = ProgressSync(
      'u1',
      ApiUserRepo(_FakeApiClient()),
      await SharedPreferences.getInstance(),
    );
    await _shoot(tester, '07-profil', (t) async {
      await t.pumpWidget(_app(srsStore: srs, sync: sync));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Profil'),
        ),
      );
      await t.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byType(ProfilePage),
            matching: find.byType(Scrollable),
          )
          .first;
      await t.drag(scrollable, const Offset(0, -240));
      await t.pumpAndSettle();
      expect(find.text('Kata hafal'), findsOneWidget);
    });
  });

  _shot('08 pengaturan', (tester) async {
    final settings = await _settings();
    await _shoot(tester, '08-pengaturan', (t) async {
      await t.pumpWidget(_app(srsStore: _FakeSrsStore(), settings: settings));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Pengaturan'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('FLASHCARD'), findsOneWidget);
    });
  });

  tearDownAll(_shrinkToWidth);
}

/// GitHub ramah pada gambar < ~1 MB; turunkan ke lebar 780 px memakai sips
/// (macOS). Di OS lain dilewati tanpa gagal.
Future<void> _shrinkToWidth() async {
  final dir = Directory('test/screenshots');
  if (!dir.existsSync() || !Platform.isMacOS) return;
  for (final f in dir.listSync().whereType<File>()) {
    if (f.path.endsWith('.png')) {
      await Process.run('sips', ['-Z', '780', f.path]);
    }
  }
}
