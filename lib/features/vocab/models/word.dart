class Word {
  const Word({
    this.id,
    this.category = '',
    this.word = '',
    this.read = '',
    this.readRomaji = '',
    this.meaning = '',
    this.exampleJp = '',
    this.exampleRomaji = '',
    this.exampleMeaning = '',
    this.timestamp = '',
  });

  final dynamic id;
  final String category;
  final String word;
  final String read;
  final String readRomaji;
  final String meaning;
  final String exampleJp;
  final String exampleRomaji;
  final String exampleMeaning;
  final String timestamp;

  String get masteryKey => id?.toString() ?? '$word|$read';

  factory Word.fromMap(Map<String, dynamic> map) => Word(
    id: map['id'],
    category: (map['category'] ?? '').toString(),
    word: (map['word'] ?? '').toString(),
    read: (map['read'] ?? '').toString(),
    readRomaji: (map['read_romaji'] ?? '').toString(),
    meaning: (map['meaning'] ?? '').toString(),
    exampleJp: (map['example_jp'] ?? '').toString(),
    exampleRomaji: (map['example_romaji'] ?? '').toString(),
    exampleMeaning: (map['example_meaning'] ?? '').toString(),
    timestamp: (map['timestamp'] ?? '').toString(),
  );
}
