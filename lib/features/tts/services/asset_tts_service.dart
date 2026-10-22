import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

import 'tts_service.dart';

/// TTS offline dari aset MP3 yang digenerate lebih dulu
/// (`tool/generate_tts.py`). Peta bacaan → nama file dibaca dari
/// `assets/audio/index.json`. Tidak ada jaringan saat runtime.
class AssetTtsService implements TtsService {
  AssetTtsService({
    this._manifestAsset = kDefaultManifest,
    this.index,
    this.playAsset,
  });

  static const kDefaultManifest = 'assets/audio/index.json';

  final String _manifestAsset;

  /// Peta bacaan → nama file. Bila diisi, manifest aset tidak dibaca
  /// (dipakai pengujian / sumber data alternatif).
  final Map<String, String>? index;

  /// Hook playback (di-inject untuk pengujian). Default: [audioplayers]
  /// dengan [AssetSource].
  final Future<void> Function(String assetPath)? playAsset;

  AudioPlayer? _player;
  Future<Map<String, String>>? _loading;

  Future<Map<String, String>> _load() {
    final idx = index;
    if (idx != null) return Future.value(idx);
    return _loading ??= _loadManifest();
  }

  Future<Map<String, String>> _loadManifest() async {
    final raw = await rootBundle.loadString(_manifestAsset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as String));
  }

  @override
  Future<void> speak(String text) async {
    final key = text.trim();
    final map = await _load();
    final file = map[key];
    if (file == null || file.isEmpty) return;
    await _play(file);
  }

  @override
  Future<bool> has(String text) async {
    final idx = index;
    if (idx != null) return idx.containsKey(text.trim());
    final map = await _load();
    return map.containsKey(text.trim());
  }

  Future<void> _play(String file) async {
    final fn = playAsset ?? _audioPlay;
    await fn('assets/audio/$file');
  }

  Future<void> _audioPlay(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final player = _player ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  void dispose() {
    _player?.dispose();
  }
}
