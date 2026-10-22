import 'package:flutter_test/flutter_test.dart';

import 'package:zest/features/vocab/models/word.dart';
import 'package:zest/features/vocab/services/srs_scheduler.dart';

void main() {
  group('srsGood', () {
    test('kartu baru -> interval 1, jatuh tempo besok', () {
      final c = srsGood(null, 100);
      expect(c.n, 1);
      expect(c.interval, 1);
      expect(c.due, 101);
      expect(c.ease, 2.5);
    });

    test('interval naik bertahap (x ease) dan dibatasi 60 hari', () {
      var c = srsGood(null, 0);
      final intervals = <int>[];
      for (var i = 0; i < 8; i++) {
        c = srsGood(c, c.due);
        intervals.add(c.interval);
      }
      expect(intervals, [3, 8, 20, 50, 60, 60, 60, 60]);
    });

    test('firstInterval dipakai untuk kartu baru (default 1)', () {
      final c = srsGood(null, 100, firstInterval: 3);
      expect(c.n, 1);
      expect(c.interval, 3);
      expect(c.due, 103);
    });

    test('defaultEase menentukan ease awal kartu baru', () {
      final c = srsGood(null, 0, defaultEase: 3.0);
      expect(c.ease, 3.0);
      final d = srsGood(c, c.due);
      expect(d.ease, 3.0);
    });

    test('maxInterval membatasi kenaikan interval', () {
      var c = srsGood(null, 0);
      final intervals = <int>[];
      for (var i = 0; i < 6; i++) {
        c = srsGood(c, c.due, maxInterval: 10);
        intervals.add(c.interval);
      }
      expect(intervals, [3, 8, 10, 10, 10, 10]);
    });
  });

  group('isMature', () {
    test('default: interval >= kMatureInterval (21)', () {
      expect(isMature(SrsCard(n: 1, interval: 20, ease: 2.5, due: 1)), isFalse);
      expect(isMature(SrsCard(n: 1, interval: 21, ease: 2.5, due: 1)), isTrue);
      expect(isMature(null), isFalse);
    });

    test('matureDays menggeser ambang hafal', () {
      final card = SrsCard(n: 1, interval: 7, ease: 2.5, due: 1);
      expect(isMature(card), isFalse);
      expect(isMature(card, matureDays: 7), isTrue);
      expect(isMature(card, matureDays: 14), isFalse);
    });
  });

  group('srsBad', () {
    test('reset n & interval, due hari ini, ease turun (min 1.3)', () {
      var c = srsGood(null, 10);
      c = srsBad(c, 10);
      expect(c.n, 0);
      expect(c.interval, 0);
      expect(c.due, 10);
      expect(c.ease, 2.3);
      for (var i = 0; i < 10; i++) {
        c = srsBad(c, 10);
      }
      expect(c.ease, 1.3);
    });
  });

  group('buildQueue', () {
    Word w(String key) => Word(category: 'n5', word: 'w', read: key);

    test(
      'review diutamakan, kartu baru maksimal kNewCap, belum-due dilewati',
      () {
        final today = 100;
        final words = [for (var i = 0; i < 26; i++) w('n$i')];
        final states = <String, SrsCard>{
          for (var i = 0; i < 5; i++)
            'w|n$i': SrsCard(n: 2, interval: 3, ease: 2.5, due: today),
          'w|n5': SrsCard(n: 2, interval: 3, ease: 2.5, due: today + 5),
        };
        final q = buildQueue(words: words, states: states, today: today);
        expect(q.length, 5 + kNewCap);
        final reviewKeys = {for (var i = 0; i < 5; i++) 'n$i'};
        for (var i = 0; i < 5; i++) {
          expect(
            reviewKeys.contains(q[i].read),
            isTrue,
            reason: '5 kartu review harus diprioritaskan di awal',
          );
        }
        expect(
          q.where((w) => w.read == 'n5'),
          isEmpty,
          reason: 'kartu yang belum jatuh tempo tidak ikut',
        );
      },
    );

    test('total sesi dibatasi kSessionCap', () {
      final words = [for (var i = 0; i < 30; i++) w('n$i')];
      final states = <String, SrsCard>{
        for (var i = 0; i < 30; i++)
          'w|n$i': SrsCard(n: 1, interval: 1, ease: 2.5, due: 1),
      };
      final q = buildQueue(words: words, states: states, today: 5);
      expect(q.length, kSessionCap);
    });

    test('semua kartu baru bila tidak ada review', () {
      final words = [for (var i = 0; i < 3; i++) w('n$i')];
      final q = buildQueue(words: words, states: {}, today: 1);
      expect(q.length, 3);
      expect(q.map((w) => w.read), containsAll(['n0', 'n1', 'n2']));
    });
  });
}
