import 'dart:convert';
import 'dart:math' as math;

import '../models/word.dart';

const int kNewCap = 10;
const int kSessionCap = 20;

/// Ambang "hafal" default: interval ≥ 21 hari.
const int kMatureInterval = 21;

/// Batas interval maks default (hari).
const int kMaxInterval = 60;

/// Ease awal default untuk kartu baru.
const double kDefaultEase = 2.5;

/// Status pengulangan berjarak untuk satu kartu kosakata.
class SrsCard {
  const SrsCard({
    required this.n,
    required this.interval,
    required this.ease,
    required this.due,
  });

  factory SrsCard.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return SrsCard(
      n: (map['n'] as num).toInt(),
      interval: (map['i'] as num).toInt(),
      ease: (map['e'] as num).toDouble(),
      due: (map['d'] as num).toInt(),
    );
  }

  final int n;
  final int interval;
  final double ease;
  final int due;

  String toJson() => jsonEncode({'n': n, 'i': interval, 'e': ease, 'd': due});
}

/// Kartu dianggap "hafal" bila intervalnya sudah melewati ambang matang.
bool isMature(SrsCard? card, {int matureDays = kMatureInterval}) =>
    card != null && card.interval >= matureDays;

/// Jawaban "Sudah hafal": naikkan interval bertahap, jadwalkan ulang di hari
/// ini + interval. Untuk kartu baru dipakai [firstInterval] (hari) dengan ease
/// awal [defaultEase]; interval review dikalikan ease dan di-cap [maxInterval].
SrsCard srsGood(
  SrsCard? card,
  int today, {
  int firstInterval = 1,
  int maxInterval = kMaxInterval,
  double defaultEase = kDefaultEase,
}) {
  final ease = card?.ease ?? defaultEase;
  if (card == null || card.interval <= 0) {
    return SrsCard(
      n: 1,
      interval: firstInterval,
      ease: ease,
      due: today + firstInterval,
    );
  }
  final next = math.max(
    1,
    math.min(maxInterval, (card.interval * ease).ceil()),
  );
  return SrsCard(n: card.n + 1, interval: next, ease: ease, due: today + next);
}

/// Jawaban "Belum hafal": reset ulangan & interval, ease turun (min 1.3),
/// kartu dijadwalkan hari ini (akan diulang di akhir sesi).
SrsCard srsBad(SrsCard? card, int today) {
  final ease = math.max(1.3, (card?.ease ?? 2.5) - 0.2);
  return SrsCard(n: 0, interval: 0, ease: ease, due: today);
}

/// Membangun antrean sesi: kartu jatuh tempo (review) dahulu, lalu kartu baru
/// maksimal [freshCap] (fallback [newCap]). Total sesi dibatasi [sessionCap].
List<Word> buildQueue({
  required List<Word> words,
  required Map<String, SrsCard> states,
  required int today,
  int newCap = kNewCap,
  int sessionCap = kSessionCap,
  int? freshCap,
}) {
  final reviews = <Word>[];
  final fresh = <Word>[];
  for (final w in words) {
    final s = states[w.masteryKey];
    if (s == null) {
      fresh.add(w);
    } else if (s.due <= today) {
      reviews.add(w);
    }
  }
  reviews.shuffle();
  fresh.shuffle();
  final queue = <Word>[];
  for (final w in reviews) {
    if (queue.length >= sessionCap) break;
    queue.add(w);
  }
  final freshLimit = freshCap ?? newCap;
  var addedNew = 0;
  for (final w in fresh) {
    if (addedNew >= freshLimit || queue.length >= sessionCap) break;
    queue.add(w);
    addedNew++;
  }
  return queue;
}
