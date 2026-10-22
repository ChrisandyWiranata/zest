/// Service text-to-speech untuk mengucapkan teks Jepang (bacaan kata).
///
/// Implementasi bisa menunjuk ke mesin VOICEVOX lokal/remote atau fake
/// untuk pengujian. UI hanya perlu [speak] — semuanya fire-and-forget.
abstract class TtsService {
  /// Mengucapkan [text]. Tidak melempar error; kegagalan jaringan/engine
  /// diabaikan agar alur belajar tidak terganggu.
  Future<void> speak(String text);

  /// Apakah [text] tersedia untuk diucapkan. Dipakai UI untuk menyembunyikan
  /// tombol speaker bila bacaan tidak ada di set audio.
  Future<bool> has(String text);
}
