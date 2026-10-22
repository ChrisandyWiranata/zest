import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zest/features/progress/services/xp_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DateTime day(int n) => DateTime.utc(1970).add(Duration(days: n));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('XP bertambah dan level naik tiap 100 XP', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = XpStore(prefs, 'u1', clock: () => day(0));
    for (var i = 0; i < 22; i++) {
      await store.addXp(5);
    }
    final info = await store.load();
    expect(info.total, 110);
    expect(info.todayXp, 110);
    expect(info.level, 2);
  });

  test('streak naik sekali per hari saja', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = XpStore(prefs, 'u1', clock: () => day(0));
    await store.addXp(5);
    await store.addXp(5);
    var info = await store.load();
    expect(info.streak, 1);
    expect(info.todayXp, 10);

    final store2 = XpStore(prefs, 'u1', clock: () => day(1));
    await store2.addXp(5);
    info = await store2.load();
    expect(info.streak, 2);
    expect(info.todayXp, 5);
  });

  test('celah hari mereset streak ke 1', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = XpStore(prefs, 'u1', clock: () => day(0));
    await store.addXp(5);

    final store3 = XpStore(prefs, 'u1', clock: () => day(4));
    await store3.addXp(5);
    final info = await store3.load();
    expect(info.streak, 1);
  });
}
