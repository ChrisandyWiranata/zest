import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `.env` terdaftar sebagai asset, jadi isinya ikut ter-bundle ke
/// `build/web/assets/.env` — file yang bisa diunduh siapa saja. Menjaga
/// `.env` bebas secret adalah satu-satunya pengaman kita di sini; token
/// Turso bocor lewat jalur ini sebelumnya.
void main() {
  group('.env tidak boleh memuat secret', () {
    test('tidak ada key bernama token/secret/password/private-key', () {
      final file = File('.env');
      if (!file.existsSync()) {
        // Clone baru belum menyalin .env.example — bukan kegagalan test.
        return;
      }
      final offenders = <String>[];
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final key = trimmed.split('=').first.trim().toUpperCase();
        const banned = [
          'TOKEN',
          'SECRET',
          'PASSWORD',
          'PASSWD',
          'PRIVATE',
          'CREDENTIAL',
          'APIKEY',
          'API_KEY',
        ];
        if (banned.any(key.contains)) {
          offenders.add(key);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Key berikut tidak boleh ada di .env karena file-nya publik di '
            'build web. Pindahkan ke backend/.env.local: $offenders',
      );
    });

    test('tidak ada nilai yang tampak seperti JWT', () {
      final file = File('.env');
      if (!file.existsSync()) return;
      final jwt = RegExp(r'eyJ[A-Za-z0-9_-]{10,}');
      final offenders = <String>[];
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        if (jwt.hasMatch(trimmed)) {
          offenders.add(trimmed.split('=').first.trim());
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Nilai JWT (tanpa key token) terdeteksi di .env pada: $offenders',
      );
    });

    test('memuat API_BASE_URL supaya app punya tujuan backend', () {
      final file = File('.env');
      if (!file.existsSync()) return;
      expect(
        file.readAsLinesSync().any(
          (line) => line.trim().startsWith('API_BASE_URL'),
        ),
        isTrue,
        reason: 'API_BASE_URL wajib ada di .env (nilai publik, bukan secret)',
      );
    });
  });

  group('.env.example mendokumentasikan .env', () {
    test('tidak memuat nilai API_BASE_URL yang hardcode ke produksi', () {
      final file = File('.env.example');
      if (!file.existsSync()) return;
      final text = file.readAsStringSync();
      expect(
        RegExp(r'API_BASE_URL\s*=\s*https?://(?!localhost)').hasMatch(text),
        isFalse,
        reason: 'contoh di .env.example sebaiknya localhost, bukan domain asli',
      );
    });
  });
}
