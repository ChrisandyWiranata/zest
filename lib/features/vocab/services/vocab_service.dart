import '../../../core/network/api_client.dart';
import '../models/word.dart';

class VocabService {
  VocabService(this._client);

  final ApiClient _client;

  Future<List<Word>> getWords(String category) async {
    final json = await _client.get('/vocab', query: {'category': category});
    final rows = (json['words'] as List<dynamic>? ?? const []);
    return rows.whereType<Map<String, dynamic>>().map(Word.fromMap).toList();
  }
}
