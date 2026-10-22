import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static String read(String key) => (dotenv.maybeGet(key) ?? '').trim();

  static int integer(String key, int fallback) =>
      int.tryParse(read(key)) ?? fallback;
}
