import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';

import '../../../config/tts_config.dart';
import 'tts_service.dart';

/// TTS via mesin VOICEVOX (protocol HTTP):
///
///   1. `POST {base}/audio_query?text=...&speaker=<id>` → JSON query sintesis;
///   2. `POST {base}/synthesis?speaker=<id>` (body = query) → bytes WAV.
///
/// Hasil disimpan di cache memori per sesi (key `speaker|text`) supaya tap
/// berulang tidak re-sintesis. Error apa pun di-swallow.
class VoicevoxTtsService implements TtsService {
  VoicevoxTtsService({Dio? dio, String? baseUrl, int? speakerId, this.playFn})
    : _dio =
          dio ??
          (Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 10),
            ),
          )),
      _baseUrl = baseUrl ?? TtsConfig.baseUrl,
      _speakerId = speakerId ?? TtsConfig.speakerId;

  final Dio _dio;
  final String _baseUrl;
  final int _speakerId;
  final Map<String, Uint8List> _cache = {};

  /// Hook playback, di-inject untuk pengujian. Default: [audioplayers].
  final Future<void> Function(Uint8List bytes)? playFn;

  AudioPlayer? _player;

  String get _base => _baseUrl.replaceAll(RegExp(r'\/+$'), '');

  bool get _disabled => _base.isEmpty;

  @override
  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (_disabled || trimmed.isEmpty) return;
    final key = '$_speakerId|$trimmed';
    final cached = _cache[key];
    if (cached != null) {
      await _play(cached);
      return;
    }
    try {
      final wav = await _synthesize(trimmed);
      _cache[key] = wav;
      await _play(wav);
    } catch (_) {
      // Jangan pernah mengganggu alur belajar karena TTS error.
    }
  }

  @override
  Future<bool> has(String text) async => !_disabled && text.trim().isNotEmpty;

  Future<Uint8List> _synthesize(String text) async {
    final query = await _dio.post<Map<String, dynamic>>(
      '$_base/audio_query',
      queryParameters: {'text': text, 'speaker': _speakerId},
    );
    final resp = await _dio.post<List<int>>(
      '$_base/synthesis',
      queryParameters: {'speaker': _speakerId},
      data: query.data,
      options: Options(
        headers: {'Content-Type': 'application/json'},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(resp.data ?? const []);
  }

  Future<void> _play(Uint8List wav) async {
    final fn = playFn ?? _audioPlay;
    await fn(wav);
  }

  Future<void> _audioPlay(Uint8List wav) async {
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(BytesSource(wav));
    } catch (_) {}
  }

  void dispose() {
    _player?.dispose();
  }
}
