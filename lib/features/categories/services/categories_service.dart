import '../../../core/network/api_client.dart';
import '../models/category_detail.dart';

class CategoriesService {
  CategoriesService(this._client);

  final ApiClient _client;

  Future<List<CategoryDetail>> getCategories() async {
    final json = await _client.get('/categories');
    final rows = (json['categories'] as List<dynamic>? ?? const []);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(CategoryDetail.fromMap)
        .toList();
  }
}
