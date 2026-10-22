import 'app_config.dart';

class ApiConfig {
  ApiConfig._();

  static String get baseUrl {
    final raw = AppConfig.read('API_BASE_URL');
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }
}
