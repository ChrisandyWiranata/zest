import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zest/features/tts/services/voicevox_tts_service.dart';

void main() {
  setUpAll(() {
    dotenv.loadFromString(
      envString: 'VOICEVOX_BASE_URL=\nVOICEVOX_SPEAKER_ID=\n',
    );
  });

  group('VoicevoxTtsService.speak', () {
    test('no-op saat baseUrl kosong (TTS nonaktif)', () async {
      final service = VoicevoxTtsService(
        baseUrl: '',
        playFn: RecordingPlayback.failIfCalled,
      );
      await service.speak('ねこ');
    });

    test('no-op saat teks kosong / spasi', () async {
      final adapter = _StubAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final service = VoicevoxTtsService(
        dio: dio,
        baseUrl: 'http://x.test',
        playFn: RecordingPlayback.failIfCalled,
      );
      await service.speak('   ');
      await service.speak('');
      expect(adapter.queryCalls, 0);
      expect(adapter.synthesisCalls, 0);
    });

    test('audio_query + synthesis dipanggil, lalu di-cache (memori)', () async {
      final adapter = _StubAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final playback = RecordingPlayback();
      final service = VoicevoxTtsService(
        dio: dio,
        baseUrl: 'http://localhost:50021',
        speakerId: 2,
        playFn: playback.call,
      );

      await service.speak('ねこ');
      await service.speak('ねこ');
      await service.speak('ねこ');

      expect(adapter.queryCalls, 1);
      expect(adapter.synthesisCalls, 1);
      expect(adapter.lastQueryPath, endsWith('/audio_query'));
      expect(adapter.lastQueryParams['text'], 'ねこ');
      expect(adapter.lastQueryParams['speaker'], 2);
      expect(adapter.lastSynthesisParams['speaker'], 2);
      // 3x speak → hanya bytes pertama yang "diputar", cache untuk sisanya.
      expect(playback.playedWavs, hasLength(3));
    });

    test('teks berbeda tidak memakai cache lama', () async {
      final adapter = _StubAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final service = VoicevoxTtsService(
        dio: dio,
        baseUrl: 'http://localhost:50021',
        playFn: RecordingPlayback.failIfCalled,
      );

      await service.speak('いぬ');
      await service.speak('ねこ');

      expect(adapter.queryCalls, 2);
      expect(adapter.synthesisCalls, 2);
    });
  });
}

class RecordingPlayback {
  RecordingPlayback();

  final List<Uint8List> playedWavs = [];

  Future<void> call(Uint8List wav) async {
    playedWavs.add(wav);
  }

  /// Fallback untuk jalur yang tidak boleh sampai ke playback.
  static Future<void> failIfCalled(Uint8List wav) async {
    throw StateError('playback tidak boleh dipanggil di jalur ini');
  }
}

class _StubAdapter implements HttpClientAdapter {
  int queryCalls = 0;
  int synthesisCalls = 0;
  String? lastQueryPath;
  Map<String, dynamic> lastQueryParams = {};
  Map<String, dynamic> lastSynthesisParams = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/audio_query')) {
      queryCalls++;
      lastQueryPath = options.path;
      lastQueryParams = options.queryParameters;
      return ResponseBody.fromBytes(
        utf8.encode(jsonEncode({'accent_phrases': []})),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.path.endsWith('/synthesis')) {
      synthesisCalls++;
      lastSynthesisParams = options.queryParameters;
      return ResponseBody.fromBytes(
        const [1, 2, 3],
        200,
        headers: {
          Headers.contentTypeHeader: ['audio/wav'],
        },
      );
    }
    return ResponseBody.fromString('', 404);
  }

  @override
  void close({bool force = false}) {}
}
