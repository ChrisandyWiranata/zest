import 'dart:convert';

/// Apakah idToken Google masih layak dikirim ke backend?
///
/// Hanya membaca klaim `exp` dari payload JWT (tanpa verifikasi tanda tangan —
/// verifikasi sebenarnya tetap di backend). Dipakai untuk memutuskan perlu
/// refresh sesi atau tidak saat backend membalas 401. Token yang tidak bisa
/// diparse dianggap tidak segar supaya aman.
bool isIdTokenFresh(
  String? token, {
  DateTime? now,
  Duration margin = const Duration(seconds: 60),
}) {
  final parts = (token ?? '').split('.');
  if (parts.length != 3 || parts[1].isEmpty) return false;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map) return false;
    final exp = payload['exp'];
    if (exp is! num) return false;
    final secondsNow = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    return exp > secondsNow + margin.inSeconds;
  } catch (_) {
    return false;
  }
}
