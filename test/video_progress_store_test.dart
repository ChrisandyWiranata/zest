import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zest/features/videos/services/video_progress_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoProgressStore', () {
    test('resume: null awal, tersimpan setelah set', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = VideoProgressStore(prefs, 'u1');

      expect(await store.getResume('n5', 'v1'), isNull);

      await store.setResume('n5', 'v1', 42000);

      expect(await store.getResume('n5', 'v1'), 42000);
      expect(prefs.getInt('resume_video.u1.n5.v1'), 42000);
    });

    test('countWatched hanya menghitung yang true di namespace uid', () async {
      SharedPreferences.setMockInitialValues({
        'watched_video.u1.n5.v1': true,
        'watched_video.u1.n5.v2': false,
        'watched_video.u2.n5.v3': true,
        'resume_video.u1.n5.v1': 42,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = VideoProgressStore(prefs, 'u1');

      expect(await store.countWatched(), 1);
    });

    test('watched: status per video', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = VideoProgressStore(prefs, 'u1');

      expect(await store.isWatched('n5', 'v1'), isFalse);
      await store.setWatched('n5', 'v1', true);
      expect(await store.isWatched('n5', 'v1'), isTrue);
    });
  });
}
