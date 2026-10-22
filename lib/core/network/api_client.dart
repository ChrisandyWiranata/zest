import 'package:dio/dio.dart';

import '../../config/api_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Klien HTTP tipis untuk backend `zest-api` (Vercel).
///
/// Token Turso tidak pernah ada di sisi klien: aplikasi hanya butuh
/// `API_BASE_URL` dan Google idToken sebagai bukti identitas.
class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? _buildDio();

  final Dio _dio;

  /// Google idToken milik user aktif; diisi `UserSession` tiap login/restore
  /// dan dikosongkan saat logout. Kosong berarti endpoint `/api/me/*` akan
  /// ditolak server dengan 401.
  String? idToken;

  /// Dipanggil sekali saat backend membalas 401, sebelum request diulang.
  /// Diisi `UserSession.reauthenticate` dari `main.dart` (native: refresh
  /// senyap; web: kembali ke LoginPage). Kosong = tidak ada retry.
  Future<void> Function()? onUnauthorized;

  static Dio _buildDio() {
    final base = ApiConfig.baseUrl;
    if (base.isEmpty) {
      throw StateError(
        'API_BASE_URL belum diset di file .env. Contoh:\n'
        '  API_BASE_URL = http://localhost:3000',
      );
    }
    return Dio(
      BaseOptions(
        baseUrl: '$base/api',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  Options _authOptions({bool json = true}) {
    final token = idToken?.trim() ?? '';
    return Options(
      headers: {
        if (json) 'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) {
    return _send(
      () => _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
        options: _authOptions(json: false),
      ),
    );
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) {
    return _send(
      () => _dio.post<Map<String, dynamic>>(
        path,
        data: body,
        options: _authOptions(),
      ),
    );
  }

  /// Kirim request; pada 401, refresh sesi lewat [onUnauthorized] lalu ulangi
  /// **sekali** — hanya bila token benar-benar berubah. Tanpa itu, 401
  /// dilempar apa adanya supaya user tidak terjebak dalam loop.
  Future<Map<String, dynamic>> _send(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      final res = await request();
      return res.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      if (e.response?.statusCode != 401 || onUnauthorized == null) {
        throw _toApiException(e);
      }

      final before = idToken;
      await onUnauthorized!();
      final after = idToken;
      if (after == null || after == before) {
        throw _toApiException(e);
      }

      try {
        final res = await request();
        return res.data ?? <String, dynamic>{};
      } on DioException catch (retryError) {
        throw _toApiException(retryError);
      }
    }
  }

  /// Pertahankan pesan error server apa adanya supaya UI jujur — dulu semua
  /// kegagalan ikut ditampilkan sebagai "Periksa konfigurasi OAuth" padahal
  /// penyebabnya bisa apa saja.
  ApiException _toApiException(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    if (data is Map && data['error'] != null) {
      return ApiException(data['error'].toString(), statusCode: status);
    }
    if (status == 401) {
      return const ApiException(
        'Sesi kedaluwarsa. Coba masuk lagi.',
        statusCode: 401,
      );
    }
    if (status == 403) {
      return const ApiException(
        'Origin aplikasi tidak diizinkan backend (ALLOWED_ORIGINS).',
        statusCode: 403,
      );
    }
    final detail = e.error ?? e.message ?? e.type.name;
    return ApiException(
      'Gagal menghubungi backend (${e.requestOptions.uri}): $detail',
      statusCode: status,
    );
  }
}
