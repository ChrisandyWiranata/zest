import 'app_config.dart';

/// Konfigurasi TTS (VOICEVOX). Getter (bukan static const) supaya perubahan
/// env terbaca saat runtime tanpa rebuild-ulang class/service.
class TtsConfig {
  TtsConfig._();

  /// Base URL server VOICEVOX, mis. `http://localhost:50021`.
  /// Kosong = fitur TTS nonaktif (tombol speaker disembunyikan).
  static String get baseUrl => AppConfig.read('VOICEVOX_BASE_URL');

  /// Id suara VOICEVOX (default 2 = 四国めたん normal).
  static int get speakerId => AppConfig.integer('VOICEVOX_SPEAKER_ID', 2);

  static bool get enabled => baseUrl.isNotEmpty;
}
