import 'package:flutter_test/flutter_test.dart';

import 'package:zest/features/tts/services/asset_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssetTtsService (index di-inject)', () {
    late Map<String, String> index;
    late List<String> played;
    late AssetTtsService service;

    setUp(() {
      index = {'ねこ': 'abc.mp3', 'わたし': 'def.mp3'};
      played = [];
      service = AssetTtsService(
        index: index,
        playAsset: (path) async => played.add(path),
      );
    });

    test('speak memutar aset yang tepat dan me-trim teks', () async {
      await service.speak(' ねこ ');
      expect(played, ['assets/audio/abc.mp3']);
    });

    test('speak bacaan tak dikenal / kosong = no-op', () async {
      await service.speak('いぬ');
      await service.speak('   ');
      expect(played, isEmpty);
    });

    test('has() benar untuk yang ada & yang tidak', () async {
      expect(await service.has('わたし'), isTrue);
      expect(await service.has('いぬ'), isFalse);
      expect(await service.has(' ねこ '), isTrue); // pakai trim
    });

    test('beberapa speak juga memakai file yang sama berulang', () async {
      await service.speak('ねこ');
      await service.speak('ねこ');
      expect(played, hasLength(2));
    });
  });

  group('AssetTtsService (rootBundle nyata)', () {
    test(
      'memuat assets/audio/index.json dan memutar file yang benar',
      () async {
        final played = <String>[];
        final service = AssetTtsService(
          playAsset: (path) async => played.add(path),
        );

        expect(await service.has('わたし'), isTrue); // bacaan asli dari DB
        expect(await service.has('bacaan-tak-ada-x'), isFalse);

        await service.speak('わたし');
        expect(played, hasLength(1));
        expect(played.single, startsWith('assets/audio/'));
        expect(played.single, endsWith('.mp3'));
      },
    );
  });
}
