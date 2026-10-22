import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zest/features/vocab/services/srs_scheduler.dart';
import 'package:zest/features/vocab/services/srs_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'srs.u1.n5.valid': '{"n":2,"i":8,"e":2.5,"d":12345}',
      'srs.u1.n5.legacy': '{"other":1,"x":true}',
      'srs.u1.n5.corrupt': 'garbage',
      'srs.u1.n5.null': 'null',
      'mastery.n5.legacykey': true,
      'mastery.n5.valid': true,
    });
  });

  test('loadAll melewatkan record rusak & format lama', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = SrsStore(prefs, 'u1');
    final all = await store.loadAll('n5');
    expect(all.keys, ['valid']);
    expect(all['valid']!.interval, 8);
  });

  test('get mengembalikan null untuk record rusak', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = SrsStore(prefs, 'u1');
    expect(await store.get('n5', 'corrupt'), isNull);
    expect(await store.get('n5', 'legacy'), isNull);
    expect(await store.get('n5', 'valid'), isNotNull);
  });

  test('migrateLegacy men-seed bool lama tanpa menimpa kartu valid', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = SrsStore(prefs, 'u1');
    await store.migrateLegacy('n5');

    final migrated = await store.get('n5', 'legacykey');
    expect(migrated, isNotNull);
    expect(migrated!.interval, 1);

    final untouched = await store.get('n5', 'valid');
    expect(untouched!.interval, 8, reason: 'record valid tidak ditimpa');
  });

  test('data terisolasi antar user (namespacing uid)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final userA = SrsStore(prefs, 'a');
    await userA.update('n5', 'k', srsGood(null, 100));
    final userB = SrsStore(prefs, 'b');
    expect(
      await userB.get('n5', 'k'),
      isNull,
      reason: 'user B tidak melihat data A',
    );
    expect(await userA.get('n5', 'k'), isNotNull);
    expect((await userA.get('n5', 'k'))!.interval, 1);
  });
}
