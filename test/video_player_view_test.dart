import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zest/core/network/api_client.dart';
import 'package:zest/core/widgets/network_video_player.dart';
import 'package:zest/features/users/services/api_user_repo.dart';
import 'package:zest/features/users/services/progress_sync.dart';
import 'package:zest/features/videos/models/video_item.dart';
import 'package:zest/features/videos/pages/video_player_page.dart';
import 'package:zest/features/videos/services/video_progress_store.dart';

const _video = VideoItem(
  id: 1,
  category: 'n5',
  bab: 'Bab 1',
  type: VideoItem.typeGrammar,
  title: 'Pola kalimat frasa',
  videoUrl: 'https://example.com/v1',
);

class _FakeVideoProgressStore implements VideoProgressStore {
  _FakeVideoProgressStore({Set<String>? watched})
    : watched = watched ?? <String>{};

  final Set<String> watched;
  final watchedWrites = <String>[];
  final resumeWrites = <int>[];

  @override
  String get uid => 'u1';

  @override
  Future<bool> isWatched(String category, String id) async =>
      watched.contains(id);

  @override
  Future<void> setWatched(String category, String id, bool value) async {
    watchedWrites.add('$id=$value');
    if (value) {
      watched.add(id);
    } else {
      watched.remove(id);
    }
  }

  @override
  Future<int?> getResume(String category, String id) async => null;

  @override
  Future<void> setResume(String category, String id, int milliseconds) async {
    resumeWrites.add(milliseconds);
  }

  @override
  Future<int> countWatched() async => watched.length;

  @override
  Future<Set<String>> watchedKeys(String category) async => watched;
}

/// ApiClient dengan `post` yang digantungkan pada [release] — meniru backend
/// lambat/tidak terjangkau supaya bisa dibuktikan UI tidak menunggu flush.
class _GateApiClient implements ApiClient {
  final _gate = Completer<Map<String, dynamic>>();
  final posts = <(String, Map<String, dynamic>)>[];

  @override
  String? idToken;

  @override
  Future<void> Function()? onUnauthorized;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async => const {};

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) {
    posts.add((path, body));
    return _gate.future;
  }

  void release() => _gate.complete(const {'updatedAt': 123});
}

Widget _view({
  required VideoProgressStore store,
  ProgressSync? sync,
  VoidCallback? onProgressChanged,
  void Function(NetworkVideoPlayer player)? capturePlayer,
}) => MaterialApp(
  home: Scaffold(
    body: VideoPlayerView(
      video: _video,
      videoProgressStore: store,
      sync: sync,
      onProgressChanged: onProgressChanged,
      playerBuilder: (player) {
        capturePlayer?.call(player);
        return const SizedBox(key: Key('stub-player'), height: 100);
      },
    ),
  ),
);

void main() {
  testWidgets('toggle watched: tombol & sidebar update sebelum flush selesai', (
    tester,
  ) async {
    final store = _FakeVideoProgressStore();
    final client = _GateApiClient();
    final sync = ProgressSync('u1', ApiUserRepo(client));
    var notified = 0;

    await tester.pumpWidget(
      _view(store: store, sync: sync, onProgressChanged: () => notified++),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tandai sudah ditonton'), findsOneWidget);

    await tester.tap(find.text('Tandai sudah ditonton'));
    await tester.pumpAndSettle();

    // POST /me/sync masih digantung gate, tapi UI sudah konsisten.
    expect(find.text('Sudah ditonton'), findsOneWidget);
    expect(notified, 1);
    expect(store.watchedWrites, ['1=true']);
    expect(store.watched, {'1'});
    expect(sync.status.value, SyncStatus.syncing);
    expect(client.posts, hasLength(1));

    client.release();
    await tester.pumpAndSettle();

    expect(sync.status.value, SyncStatus.synced);
    expect(find.text('Sudah ditonton'), findsOneWidget);
  });

  testWidgets(
    'watched dari store tampil sejak awal; toggle kedua membatalkan',
    (tester) async {
      final store = _FakeVideoProgressStore(watched: {'1'});

      await tester.pumpWidget(_view(store: store));
      await tester.pumpAndSettle();
      expect(find.text('Sudah ditonton'), findsOneWidget);

      await tester.tap(find.text('Sudah ditonton'));
      await tester.pumpAndSettle();

      expect(find.text('Tandai sudah ditonton'), findsOneWidget);
      expect(store.watchedWrites, ['1=false']);
      expect(store.watched, isEmpty);
    },
  );

  testWidgets('video selesai: auto watched + resume 0, dispose tak menimpa', (
    tester,
  ) async {
    final store = _FakeVideoProgressStore();
    NetworkVideoPlayer? player;

    await tester.pumpWidget(
      _view(store: store, capturePlayer: (p) => player = p),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tandai sudah ditonton'), findsOneWidget);

    player!.onFinished!();
    await tester.pumpAndSettle();

    expect(find.text('Sudah ditonton'), findsOneWidget);
    expect(store.watchedWrites, ['1=true']);
    expect(store.resumeWrites, [0]);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(store.resumeWrites, [0]);
  });
}
