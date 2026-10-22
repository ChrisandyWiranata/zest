import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/auth/services/id_token.dart';

String _segment(Object data) =>
    base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');

String _jwt(Object payload) =>
    '${_segment({'alg': 'none'})}.${_segment(payload)}.sig';

void main() {
  final now = DateTime.utc(2026, 1, 1, 12);
  final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

  test('token segar (exp jauh di depan) → true', () {
    expect(isIdTokenFresh(_jwt({'exp': nowSeconds + 3600}), now: now), isTrue);
  });

  test('token kedaluwarsa → false', () {
    expect(
      isIdTokenFresh(
        _jwt({'exp': nowSeconds - 1}),
        now: now,
        margin: Duration.zero,
      ),
      isFalse,
    );
  });

  test('exp masih dalam margin → dianggap basi', () {
    expect(
      isIdTokenFresh(_jwt({'exp': nowSeconds + 30}), now: now),
      isFalse,
      reason: 'margin default 60 detik menutup ping-pong basi/segar',
    );
  });

  test('margin nol → detik terakhir masih segar', () {
    expect(
      isIdTokenFresh(
        _jwt({'exp': nowSeconds + 30}),
        now: now,
        margin: Duration.zero,
      ),
      isTrue,
    );
  });

  test('input tidak valid → false', () {
    expect(isIdTokenFresh(null), isFalse);
    expect(isIdTokenFresh(''), isFalse);
    expect(isIdTokenFresh('bukan-jwt'), isFalse);
    expect(isIdTokenFresh('a.b'), isFalse, reason: 'cuma 2 segmen');
    expect(isIdTokenFresh('a..c'), isFalse, reason: 'payload kosong');
    expect(
      isIdTokenFresh('a.${base64Url.encode(utf8.encode('bukan-json'))}.c'),
      isFalse,
    );
    expect(
      isIdTokenFresh('a.${_segment([])}.c'),
      isFalse,
      reason: 'bukan objek',
    );
    expect(
      isIdTokenFresh(_jwt({'exp': 'besok'})),
      isFalse,
      reason: 'exp non-num',
    );
    expect(isIdTokenFresh(_jwt({'foo': 1})), isFalse, reason: 'exp hilang');
  });
}
