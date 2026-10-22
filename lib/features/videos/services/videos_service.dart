import '../../../core/network/api_client.dart';
import '../models/video_item.dart';

class VideosService {
  VideosService(this._client);

  final ApiClient _client;

  /// Semua video kategori, dikelompokkan per bab lalu `order_index`.
  /// Saat [type] diberikan (mis. [VideoItem.typeGrammar] atau
  /// [VideoItem.typeVocab]), hanya video bertipe tersebut yang diambil.
  /// Diurutkan di Dart agar "Bab 10" tidak mendahului "Bab 2".
  Future<List<VideoItem>> getVideos(String category, {String? type}) async {
    final json = await _client.get(
      '/videos',
      query: {'category': category, 'type': ?type},
    );
    final rows = (json['videos'] as List<dynamic>? ?? const []);
    final videos = rows
        .whereType<Map<String, dynamic>>()
        .map(VideoItem.fromMap)
        .toList();
    videos.sort((a, b) {
      final byBab = _babNumber(a.bab).compareTo(_babNumber(b.bab));
      if (byBab != 0) return byBab;
      return a.orderIndex.compareTo(b.orderIndex);
    });
    return videos;
  }

  int _babNumber(String bab) {
    final match = RegExp(r'\d+').firstMatch(bab);
    if (match == null) return 0;
    return int.tryParse(match.group(0)!) ?? 0;
  }
}
