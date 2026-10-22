import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zest/features/videos/models/video_item.dart';
import 'package:zest/features/videos/services/video_progress_store.dart';
import 'package:zest/features/videos/services/videos_service.dart';
import 'package:zest/features/videos/widgets/video_split_view.dart';

class _FakeVideosService implements VideosService {
  _FakeVideosService({this.videos = _n5Videos});

  final List<VideoItem> videos;

  static const _n5Videos = [
    VideoItem(
      id: 1,
      category: 'n5',
      bab: 'Bab 1',
      type: VideoItem.typeGrammar,
      title: 'Pola kalimat frasa',
      videoUrl: 'https://example.com/v1',
    ),
    VideoItem(
      id: 2,
      category: 'n5',
      bab: 'Bab 1',
      type: VideoItem.typeVocab,
      title: '',
      videoUrl: 'https://example.com/v2',
    ),
  ];

  @override
  Future<List<VideoItem>> getVideos(String category, {String? type}) async {
    if (type == null) return videos;
    return videos.where((v) => v.type == type).toList();
  }
}

class _FakeVideoProgressStore implements VideoProgressStore {
  _FakeVideoProgressStore({this.watched = const {}});

  final Set<String> watched;

  @override
  String get uid => 'u1';

  @override
  Future<bool> isWatched(String category, String id) async =>
      watched.contains(id);

  @override
  Future<void> setWatched(String category, String id, bool watched) async {}

  @override
  Future<int> countWatched() async => watched.length;

  @override
  Future<Set<String>> watchedKeys(String category) async => watched;

  @override
  Future<int?> getResume(String category, String id) async => null;

  @override
  Future<void> setResume(String category, String id, int milliseconds) async {}
}

Widget _host({
  required VideosService videosService,
  required VideoProgressStore progressStore,
  VideoPlayerBuilder? playerBuilder,
}) => MaterialApp(
  home: Scaffold(
    body: VideoSplitView(
      category: 'n5',
      videosService: videosService,
      videoProgressStore: progressStore,
      playerBuilder:
          playerBuilder ??
          (video, resumeMs) => Text('stub-player-${video.progressKey}'),
    ),
  ),
);

void main() {
  testWidgets('sidebar tampil per bab, panel kanan placeholder dulu', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        videosService: _FakeVideosService(),
        progressStore: _FakeVideoProgressStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bab 1'), findsOneWidget);
    expect(find.text('Pola kalimat frasa'), findsOneWidget);
    expect(find.text('Video Kosakata N5 · Bab 1'), findsOneWidget);
    expect(find.text('Grammar'), findsOneWidget);
    expect(find.text('Kosakata'), findsWidgets);
    expect(find.text('Pilih video untuk mulai menonton'), findsOneWidget);
    expect(find.textContaining('stub-player-'), findsNothing);
  });

  testWidgets('tap video di sidebar membuka player di panel kanan', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        videosService: _FakeVideosService(),
        progressStore: _FakeVideoProgressStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pola kalimat frasa'));
    await tester.pumpAndSettle();

    expect(find.text('stub-player-1'), findsOneWidget);
    expect(find.text('Pilih video untuk mulai menonton'), findsNothing);

    // Ganti video → panel kanan ikut berganti.
    await tester.tap(find.text('Video Kosakata N5 · Bab 1'));
    await tester.pumpAndSettle();
    expect(find.text('stub-player-2'), findsOneWidget);
    expect(find.text('stub-player-1'), findsNothing);
  });

  testWidgets('filter tipe menyembunyikan video & clear pilihan tak lolos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        videosService: _FakeVideosService(),
        progressStore: _FakeVideoProgressStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Video Kosakata N5 · Bab 1'));
    await tester.pumpAndSettle();
    expect(find.text('stub-player-2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('video-mode-grammar')));
    await tester.pumpAndSettle();

    expect(find.text('Pola kalimat frasa'), findsOneWidget);
    expect(find.text('Video Kosakata N5 · Bab 1'), findsNothing);
    expect(find.text('Kosakata'), findsOneWidget);
    // Video terpilih tidak lolos filter → kembali ke placeholder.
    expect(find.text('Pilih video untuk mulai menonton'), findsOneWidget);
    expect(find.text('stub-player-2'), findsNothing);
  });

  testWidgets('filter per tipe: kosakata tanpa video → pesan kosong', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        videosService: _FakeVideosService(
          videos: const [
            VideoItem(
              id: 1,
              category: 'n5',
              bab: 'Bab 1',
              type: VideoItem.typeGrammar,
              title: 'Pola kalimat frasa',
              videoUrl: 'https://example.com/v1',
            ),
          ],
        ),
        progressStore: _FakeVideoProgressStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('video-mode-kosakata')));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada video kosakata.'), findsOneWidget);
    expect(find.text('Pilih video untuk mulai menonton'), findsOneWidget);
  });

  testWidgets('tanpa video sama sekali → pesan kosong gabung', (tester) async {
    await tester.pumpWidget(
      _host(
        videosService: _FakeVideosService(videos: const []),
        progressStore: _FakeVideoProgressStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Belum ada video.'), findsOneWidget);
  });

  testWidgets('video ditonton menampilkan centang di sidebar', (tester) async {
    await tester.pumpWidget(
      _host(
        videosService: _FakeVideosService(),
        progressStore: _FakeVideoProgressStore(watched: {'1'}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}
