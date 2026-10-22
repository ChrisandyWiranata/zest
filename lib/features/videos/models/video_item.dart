class VideoItem {
  static const typeGrammar = 'grammar';
  static const typeVocab = 'kosakata';

  const VideoItem({
    this.id,
    required this.category,
    this.bab = '',
    this.type = typeGrammar,
    required this.title,
    required this.videoUrl,
    this.orderIndex = 0,
  });

  final dynamic id;
  final String category;
  final String bab;
  final String type;
  final String title;
  final String videoUrl;
  final int orderIndex;

  bool get isGrammar => type == typeGrammar;

  String get typeLabel => isGrammar ? 'Tata Bahasa' : 'Kosakata';

  /// Label pendek untuk badge di baris daftar video.
  String get typeBadge => isGrammar ? 'Grammar' : 'Kosakata';

  /// Judul tampil; bila kosong memakai judul cadangan dari bab + urutan.
  String get displayTitle {
    if (title.trim().isNotEmpty) return title;
    final babPart = bab.isEmpty ? '' : ' · $bab';
    final idxPart = orderIndex > 0 ? ' #$orderIndex' : '';
    return 'Video $typeLabel ${category.toUpperCase()}$babPart$idxPart';
  }

  String get progressKey => id?.toString() ?? videoUrl;

  factory VideoItem.fromMap(Map<String, dynamic> map) {
    final rawOrder = map['order_index'];
    return VideoItem(
      id: map['id'],
      category: (map['category'] ?? '').toString(),
      bab: (map['bab'] ?? '').toString(),
      type: (map['type'] ?? typeGrammar).toString().trim().toLowerCase(),
      title: (map['title'] ?? '').toString(),
      videoUrl: (map['video_url'] ?? '').toString().trim(),
      orderIndex: rawOrder is num
          ? rawOrder.toInt()
          : int.tryParse(rawOrder?.toString() ?? '') ?? 0,
    );
  }
}
