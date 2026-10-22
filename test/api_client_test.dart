import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/core/network/api_client.dart';

/// Adapter Dio buatan: memutar status sesuai [statuses] dan mencatat header
/// `Authorization` tiap request.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.statuses);

  final List<int> statuses;
  final List<String?> authHeaders = [];
  int _calls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    authHeaders.add(options.headers['Authorization'] as String?);
    final index = _calls < statuses.length ? _calls : statuses.length - 1;
    _calls += 1;
    final status = statuses[index];
    final body = status == 200
        ? '{"ok":true}'
        : '{"error":"idToken ditolak: token basi."}';
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

(ApiClient, _ScriptedAdapter, _Refresher) _client(List<int> statuses) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api'));
  final adapter = _ScriptedAdapter(statuses);
  dio.httpClientAdapter = adapter;
  final client = ApiClient(dio: dio);
  client.idToken = 'token-lama';
  final refresher = _Refresher();
  client.onUnauthorized = () async {
    refresher.calls += 1;
    client.idToken = refresher.nextToken;
  };
  return (client, adapter, refresher);
}

class _Refresher {
  int calls = 0;
  String? nextToken = 'token-baru';
}

void main() {
  test('401 → refresh sekali, request diulang dengan token baru', () async {
    final (client, adapter, refresher) = _client([401, 200]);

    final out = await client.get('/categories');

    expect(out['ok'], isTrue);
    expect(refresher.calls, 1);
    expect(adapter.authHeaders, ['Bearer token-lama', 'Bearer token-baru']);
  });

  test('401 → refresh tapi masih 401 → lempar, tanpa loop', () async {
    final (client, adapter, refresher) = _client([401, 401]);

    await expectLater(
      client.get('/categories'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', contains('idToken ditolak')),
      ),
    );
    expect(refresher.calls, 1);
    expect(adapter.authHeaders.length, 2, reason: 'tepat satu retry');
  });

  test('401 → refresh gagal (token hilang) → lempar tanpa retry', () async {
    final (client, adapter, refresher) = _client([401, 200]);
    refresher.nextToken = null;

    await expectLater(
      client.get('/categories'),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
      ),
    );
    expect(refresher.calls, 1);
    expect(
      adapter.authHeaders,
      hasLength(1),
      reason: 'token tak berubah = tak diulang',
    );
  });

  test('tanpa onUnauthorized → 401 langsung lempar, satu request', () async {
    final adapter = _ScriptedAdapter([401]);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api'));
    dio.httpClientAdapter = adapter;
    final client = ApiClient(dio: dio)..idToken = 'token-lama';

    await expectLater(
      client.get('/categories'),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
      ),
    );
    expect(adapter.authHeaders, hasLength(1));
  });

  test('error bukan 401 → tidak memanggil refresh', () async {
    final (client, adapter, refresher) = _client([403]);

    await expectLater(
      client.get('/categories'),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
      ),
    );
    expect(refresher.calls, 0);
    expect(adapter.authHeaders, hasLength(1));
  });

  test('post juga ikut jalur refresh yang sama', () async {
    final (client, adapter, refresher) = _client([401, 200]);

    final out = await client.post('/me/sync', {'srs': <dynamic>[]});

    expect(out['ok'], isTrue);
    expect(refresher.calls, 1);
    expect(adapter.authHeaders, ['Bearer token-lama', 'Bearer token-baru']);
  });
}
