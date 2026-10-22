import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zest/core/network/api_client.dart';
import 'package:zest/core/utils/animations.dart';
import 'package:zest/features/auth/models/app_user.dart';
import 'package:zest/features/categories/models/category_detail.dart';
import 'package:zest/features/categories/services/categories_service.dart';
import 'package:zest/features/progress/services/xp_store.dart';
import 'package:zest/features/profile/pages/profile_page.dart';
import 'package:zest/features/settings/services/settings_store.dart';
import 'package:zest/features/users/services/progress_sync.dart';
import 'package:zest/features/users/services/api_user_repo.dart';
import 'package:zest/features/videos/models/video_item.dart';
import 'package:zest/features/videos/services/video_progress_store.dart';
import 'package:zest/features/videos/services/videos_service.dart';
import 'package:zest/features/vocab/models/word.dart';
import 'package:zest/features/vocab/services/srs_scheduler.dart';
import 'package:zest/features/vocab/services/srs_store.dart';
import 'package:zest/features/vocab/services/vocab_service.dart';
import 'package:zest/main.dart';

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

class _FakeCategoriesService implements CategoriesService {
  @override
  Future<List<CategoryDetail>> getCategories() async => const [
    CategoryDetail(name: 'n5', title: 'N5', total: 1, level: 'n5'),
    CategoryDetail(name: 'hiragana', title: 'Hiragana', total: 2),
  ];
}

class _FakeVocabService implements VocabService {
  @override
  Future<List<Word>> getWords(String category) async => [
    Word(
      category: category,
      word: category == 'n5' ? '私' : 'あ',
      read: category == 'n5' ? 'わたし' : 'a',
      meaning: 'saya',
    ),
  ];
}

class _FakeSrsStore implements SrsStore {
  final _cards = <String, SrsCard>{};

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
  int _total = 0;
  int _streak = 0;

  XpInfo _info() =>
      XpInfo(total: _total, streak: _streak, todayXp: _total, level: 1);

  @override
  String get uid => 'u1';

  @override
  Future<XpSnapshot> snapshot() async =>
      XpSnapshot(total: _total, streak: _streak, todayXp: _total);

  @override
  Future<XpInfo> addXp(int points) async {
    _total += points;
    if (_streak == 0) _streak = 1;
    return _info();
  }

  @override
  Future<XpInfo> load() async => _info();
}

class _FakeVideosService implements VideosService {
  @override
  Future<List<VideoItem>> getVideos(String category, {String? type}) async {
    const all = [
      VideoItem(
        id: 1,
        category: 'n5',
        bab: 'Bab 1',
        type: VideoItem.typeGrammar,
        title: 'Pola kalimat frasa',
        videoUrl: 'https://example.com/v1',
      ),
      VideoItem(
        id: 2,
        category: 'n5',
        bab: 'Bab 1',
        type: VideoItem.typeVocab,
        title: '',
        videoUrl: 'https://example.com/v2',
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
  Future<bool> isWatched(String category, String id) async => false;

  @override
  Future<void> setWatched(String category, String id, bool watched) async {}

  @override
  Future<int> countWatched() async => 1;

  @override
  Future<Set<String>> watchedKeys(String category) async => const {};

  @override
  Future<int?> getResume(String category, String id) async => null;

  @override
  Future<void> setResume(String category, String id, int milliseconds) async {}
}

Widget _app({
  VoidCallback? onLogout,
  SettingsStore? settings,
  ProgressSync? sync,
}) => ZestApp(
  categoriesService: _FakeCategoriesService(),
  vocabService: _FakeVocabService(),
  videosService: _FakeVideosService(),
  srsStore: _FakeSrsStore(),
  xpStore: _FakeXpStore(),
  videoProgressStore: _FakeVideoProgressStore(),
  user: const AppUser(uid: 'u1', email: 'ana@x.com', displayName: 'Ana'),
  onLogout: onLogout,
  settings: settings,
  sync: sync,
);

void main() {
  setUp(() => ambientEnabled = false);

  testWidgets('Dashboard: sapaan, XP, sesi hari ini', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Hai, Ana!'), findsOneWidget);
    expect(find.text('Lv'), findsOneWidget);
    expect(find.text('Flashcard hari ini'), findsOneWidget);
    expect(find.text('0 ulangan · 2 kata baru'), findsOneWidget);
    expect(find.text('Mulai'), findsOneWidget);
    expect(find.text('1 video'), findsOneWidget);
  });

  testWidgets('Kategori: tap kartu membuka Kosakata & Video', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('N5'));
    await tester.pumpAndSettle();

    expect(find.text('Kosakata'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Mulai Flashcard · 1 kata'), findsOneWidget);
    expect(find.text('私'), findsOneWidget);
    expect(find.text('saya'), findsOneWidget);
  });

  testWidgets('Hari ini: tombol Mulai di beranda membuka kategori', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();

    expect(find.text('Kosakata'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
  });

  testWidgets('Profil: tab menampilkan statistik & akun', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(find.text('Masuk lewat Google'), findsOneWidget);
    expect(find.text('Kata hafal'), findsOneWidget);
    expect(find.text('Video ditonton'), findsOneWidget);

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

    expect(find.text('Akun Google'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);
  });

  testWidgets('Profil: keluar mengonfirmasi lalu memanggil callback', (
    tester,
  ) async {
    var loggedOut = false;
    await tester.pumpWidget(_app(onLogout: () => loggedOut = true));
    await tester.pumpAndSettle();

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

    expect(loggedOut, isTrue);
  });

  testWidgets('Menampilkan grid kategori di beranda', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Kategori'), findsOneWidget);
    expect(find.text('N5'), findsOneWidget);
    expect(find.text('Hiragana'), findsOneWidget);
    expect(find.text('1 kata'), findsOneWidget);
    expect(find.text('2 kata'), findsOneWidget);
  });

  testWidgets('Membuka kategori: tab Kosakata & Video', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('N5'));
    await tester.pumpAndSettle();

    expect(find.text('Kosakata'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Mulai Flashcard · 1 kata'), findsOneWidget);
    expect(find.text('私'), findsOneWidget);
    expect(find.text('saya'), findsOneWidget);
  });

  testWidgets('Alur flashcard sampai selesai', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('N5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mulai Flashcard · 1 kata'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('私'), findsOneWidget);
    expect(find.text('Ketuk untuk membalik'), findsOneWidget);

    await tester.tap(find.text('私'));
    await tester.pumpAndSettle();

    expect(find.text('saya'), findsOneWidget);
    expect(find.text('Sudah hafal'), findsOneWidget);
    expect(find.text('Belum hafal'), findsOneWidget);

    await tester.tap(find.text('Sudah hafal'));
    await tester.pumpAndSettle();

    expect(find.text('Sesi selesai!'), findsOneWidget);
    expect(find.text('+5 XP'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);
  });

  testWidgets('Tab video menampilkan daftar per bab', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('N5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();

    expect(find.text('Bab 1'), findsOneWidget);
    expect(find.text('Pola kalimat frasa'), findsOneWidget);
    expect(find.text('Video Kosakata N5 · Bab 1'), findsOneWidget);
    expect(find.text('Grammar'), findsOneWidget);
  });

  testWidgets('Tab video: gabung & pisah per tipe', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('N5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();

    // Gabung (default): kedua tipe tampil + badge tipe.
    expect(find.text('Pola kalimat frasa'), findsOneWidget);
    expect(find.text('Video Kosakata N5 · Bab 1'), findsOneWidget);
    expect(find.text('Grammar'), findsOneWidget);

    // Pisah Bunpou: hanya grammar.
    await tester.tap(find.byKey(const ValueKey('video-mode-grammar')));
    await tester.pumpAndSettle();
    expect(find.text('Pola kalimat frasa'), findsOneWidget);
    expect(find.text('Video Kosakata N5 · Bab 1'), findsNothing);
    expect(find.text('Grammar'), findsNothing);

    // Pisah Kosakata: hanya kosakata.
    await tester.tap(find.byKey(const ValueKey('video-mode-kosakata')));
    await tester.pumpAndSettle();
    expect(find.text('Pola kalimat frasa'), findsNothing);
    expect(find.text('Video Kosakata N5 · Bab 1'), findsOneWidget);
  });

  testWidgets('Tab video: pesan kosong saat kategori tanpa video', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hiragana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada video.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('video-mode-kosakata')));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada video kosakata.'), findsOneWidget);
  });

  testWidgets('Layout lebar: sidebar kiri muncul, bottom-nav hilang', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('zest-sidebar')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Hai, Ana!'), findsOneWidget);
    expect(find.text('N5'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(find.text('Masuk lewat Google'), findsOneWidget);
    expect(find.text('Kata hafal'), findsOneWidget);
    expect(find.text('XP total'), findsOneWidget);
  });

  testWidgets('Pengaturan: tab muncul & opsi flashcard terlihat', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsStore(prefs, 'u1');
    await settings.load();

    await tester.pumpWidget(_app(settings: settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();

    expect(find.text('FLASHCARD'), findsOneWidget);
    expect(find.text('Kata baru per sesi'), findsOneWidget);
    expect(find.text('Maks kartu per sesi'), findsOneWidget);
    expect(find.text('Jatah kata baru per hari'), findsOneWidget);
    expect(find.text('Tak terbatas'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Putar pengucapan otomatis'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('SUARA'), findsOneWidget);
    expect(find.text('Fitur suara belum aktif.'), findsOneWidget);
    expect(find.text('Putar pengucapan otomatis'), findsOneWidget);
  });

  testWidgets('Pengaturan: stepper mengubah nilai & budget tanpa batas', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsStore(prefs, 'u1');
    await settings.load();

    await tester.pumpWidget(_app(settings: settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();

    expect(find.text('10'), findsOneWidget);
    await tester.tap(find.byKey(const Key('step-new-plus')));
    await tester.pumpAndSettle();
    expect(find.text('11'), findsOneWidget);

    await tester.tap(find.byKey(const Key('step-budget-plus')));
    await tester.pumpAndSettle();
    expect(find.text('5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('step-budget-minus')));
    await tester.pumpAndSettle();
    expect(find.text('Tak terbatas'), findsOneWidget);
    expect(settings.value.dailyNewBudget, 0);
    expect(settings.value.newPerSession, 11);
  });

  testWidgets('Layout lebar: halaman Pengaturan dibuka lewat sidebar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsStore(prefs, 'u1');
    await settings.load();

    await tester.pumpWidget(_app(settings: settings));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('side-nav-pengaturan')), findsOneWidget);
    await tester.tap(find.byKey(const Key('side-nav-pengaturan')));
    await tester.pumpAndSettle();

    expect(find.text('Kata baru per sesi'), findsOneWidget);
    expect(find.text('Putar pengucapan otomatis'), findsOneWidget);
  });

  testWidgets('Pengaturan: section Pola ulangan tampil & stepper berfungsi', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsStore(prefs, 'u1');
    await settings.load();

    await tester.pumpWidget(_app(settings: settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();

    expect(find.text('POLA ULANGAN'), findsOneWidget);
    expect(find.text('Ulang pertama'), findsOneWidget);
    expect(find.text('Faktor naik interval'), findsOneWidget);
    expect(find.byKey(const Key('srs-factor')), findsOneWidget);
    expect(find.text('Batas interval maks'), findsOneWidget);
    expect(find.text('Ambang hafal'), findsOneWidget);

    await tester.tap(find.byKey(const Key('step-srs-first-plus')));
    await tester.pumpAndSettle();
    expect(settings.value.firstReviewDays, 2);

    await tester.ensureVisible(find.byKey(const Key('step-srs-mature-plus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('step-srs-mature-plus')));
    await tester.pumpAndSettle();
    expect(settings.value.matureDays, 22);
    expect(find.text('22'), findsOneWidget);
  });

  testWidgets('Profil: tombol Sinkronkan progres tampil saat sync aktif', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final sync = ProgressSync('u1', ApiUserRepo(_FakeApiClient()), prefs);

    await tester.pumpWidget(_app(sync: sync));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(find.text('Sinkronkan progres'), findsOneWidget);
  });
}
