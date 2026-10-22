class CategoryDetail {
  const CategoryDetail({
    required this.name,
    required this.total,
    this.title = '',
    this.level = '',
    this.description = '',
  });

  final String name;
  final int total;
  final String title;
  final String level;
  final String description;

  factory CategoryDetail.fromMap(Map<String, dynamic> map) {
    final rawTotal = map['total'];
    return CategoryDetail(
      name: (map['category'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      level: (map['level'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      total: rawTotal is num
          ? rawTotal.toInt()
          : int.tryParse(rawTotal?.toString() ?? '') ?? 0,
    );
  }
}
