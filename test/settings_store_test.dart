import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zest/features/settings/services/settings_store.dart';
import 'package:zest/features/vocab/models/word.dart';
import 'package:zest/features/vocab/services/srs_scheduler.dart';

Word _word(int i) =>
    Word(category: 'n5', word: 'w$i', read: 'r$i', meaning: 'm$i');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SettingsStore: nilai default tanpa pengaturan tersimpan', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore(prefs, 'u1');
    await store.load();

    expect(store.value.newPerSession, 10);
    expect(store.value.sessionCap, 20);
    expect(store.value.dailyNewBudget, 0);
    expect(store.value.autoSpeak, isFalse);
    expect(store.value.firstReviewDays, 1);
    expect(store.value.intervalFactor, 2.5);
    expect(store.value.maxIntervalDays, 60);
    expect(store.value.matureDays, 21);
  });

  test('SettingsStore: perubahan tersimpan & terbaca ulang', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore(prefs, 'u1');
    await store.load();

    await store.setNewPerSession(15);
    await store.setSessionCap(30);
    await store.setDailyNewBudget(25);
    await store.setAutoSpeak(true);
    await store.setFirstReviewDays(3);
    await store.setIntervalFactor(3.0);
    await store.setMaxIntervalDays(90);
    await store.setMatureDays(14);

    final reloaded = SettingsStore(prefs, 'u1');
    await reloaded.load();
    expect(reloaded.value.newPerSession, 15);
    expect(reloaded.value.sessionCap, 30);
    expect(reloaded.value.dailyNewBudget, 25);
    expect(reloaded.value.autoSpeak, isTrue);
    expect(reloaded.value.firstReviewDays, 3);
    expect(reloaded.value.intervalFactor, 3.0);
    expect(reloaded.value.maxIntervalDays, 90);
    expect(reloaded.value.matureDays, 14);
  });

  test('SettingsStore: nilai di-clamp ke rentang yang diizinkan', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore(prefs, 'u1');
    await store.load();

    await store.setNewPerSession(999);
    expect(store.value.newPerSession, kMaxNewPerSession);
    await store.setSessionCap(0);
    expect(store.value.sessionCap, kMinSessionCap);
    await store.setDailyNewBudget(-5);
    expect(store.value.dailyNewBudget, 0);
    await store.setFirstReviewDays(99);
    expect(store.value.firstReviewDays, kMaxFirstReview);
    await store.setFirstReviewDays(0);
    expect(store.value.firstReviewDays, kMinFirstReview);
    await store.setIntervalFactor(9);
    expect(store.value.intervalFactor, kMaxIntervalFactor);
    await store.setIntervalFactor(1);
    expect(store.value.intervalFactor, kMinIntervalFactor);
    await store.setMaxIntervalDays(9999);
    expect(store.value.maxIntervalDays, kMaxMaxInterval);
    await store.setMaxIntervalDays(2);
    expect(store.value.maxIntervalDays, kMinMaxInterval);
    await store.setMatureDays(500);
    expect(store.value.matureDays, kMaxMatureDays);
    await store.setMatureDays(1);
    expect(store.value.matureDays, kMinMatureDays);
  });

  test('SettingsStore: counter kata baru per hari lintas tanggal', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore(prefs, 'u1');
    await store.load();

    expect(await store.introducedToday(), 0);
    await store.recordIntroduced(3);
    await store.recordIntroduced(2);
    expect(await store.introducedToday(), 5);
  });

  test('SettingsStore: tanpa budget, freshCap = kata baru per sesi', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore(prefs, 'u1');
    await store.load();
    await store.setNewPerSession(12);

    expect(await store.freshCapToday(), 12);
  });

  test('SettingsStore: budget harian membatasi kata baru hari ini', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore(prefs, 'u1');
    await store.load();
    await store.setNewPerSession(30);
    await store.setDailyNewBudget(10);

    expect(await store.freshCapToday(), 10);
    await store.recordIntroduced(7);
    expect(await store.freshCapToday(), 3);
    await store.recordIntroduced(5);
    expect(await store.freshCapToday(), 0);
  });

  test('buildQueue: freshCap & sessionCap dari pengaturan dipatuhi', () {
    final words = [for (var i = 0; i < 20; i++) _word(i)];
    final today = 1790331313;

    final capped = buildQueue(
      words: words,
      states: const {},
      today: today,
      freshCap: 2,
    );
    expect(capped.length, 2);

    final tight = buildQueue(
      words: words,
      states: const {},
      today: today,
      newCap: 5,
      sessionCap: 3,
    );
    expect(tight.length, 3);
  });
}
