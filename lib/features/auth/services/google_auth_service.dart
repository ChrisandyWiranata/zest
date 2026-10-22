import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../config/app_config.dart';
import '../models/app_user.dart';
import 'auth_service.dart';

/// Client ID Google OAuth (Android/iOS/Web) dibaca lewat [AppConfig].
abstract final class AuthConfig {
  static String get webClientId => AppConfig.read('GOOGLE_WEB_CLIENT_ID');

  /// Native Android client (package + SHA-1) hanya diverifikasi oleh Google
  /// di sisi device/console; TIDAK boleh diteruskan sebagai `clientId` ke
  /// google_sign_in karena plugin Android menafsirkannya sebagai server id.
  static String get androidClientId =>
      AppConfig.read('GOOGLE_ANDROID_CLIENT_ID');
  static String get iosClientId => AppConfig.read('GOOGLE_IOS_CLIENT_ID');

  /// Resolusi (clientId, serverClientId) per platform, murni agar bisa diuji.
  ///
  /// - Web: plugin GIS (`google_sign_in_web`) TIDAK mendukung `serverClientId`
  ///   (assert menolak) dan butuh `clientId` (atau meta tag) → `clientId = webId`.
  /// - Android: plugin menafsirkan `clientId` sebagai serverClientId, dan
  ///   requestIdToken hanya valid untuk web client → `serverClientId = webId`.
  /// - iOS: GIDSignIn memakai `clientId = iosId`.
  static ({String? clientId, String? serverClientId}) resolve({
    required bool isWeb,
    required TargetPlatform platform,
    required String? webId,
    required String? iosId,
  }) {
    if (isWeb) return (clientId: webId, serverClientId: null);
    switch (platform) {
      case TargetPlatform.iOS:
        return (clientId: iosId, serverClientId: null);
      default:
        return (clientId: null, serverClientId: webId);
    }
  }

  /// Resolusi memakai nilai dari env untuk platform runtime saat ini.
  static ({String? clientId, String? serverClientId}) forPlatform({
    required bool isWeb,
    required TargetPlatform platform,
  }) => resolve(
    isWeb: isWeb,
    platform: platform,
    webId: webClientId.isEmpty ? null : webClientId,
    iosId: iosClientId.isEmpty ? null : iosClientId,
  );
}

/// Implementasi Google Sign-In untuk Android, iOS, dan Web.
class GoogleAuthService implements AuthService {
  GoogleAuthService({GoogleSignIn? googleSignIn})
    : _google = googleSignIn ?? _default();

  final GoogleSignIn _google;

  static GoogleSignIn _default() {
    final cfg = AuthConfig.forPlatform(
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    );
    return GoogleSignIn(
      scopes: const ['email', 'openid'],
      serverClientId: cfg.serverClientId,
      clientId: cfg.clientId,
    );
  }

  @override
  Future<AppUser?> restore() async {
    final account = await _google.signInSilently();
    return account == null ? null : _fromAccount(account);
  }

  @override
  Future<AppUser> signIn() async {
    final account = await _google.signIn();
    if (account == null) throw const SignInCancelled();
    return _fromAccount(account);
  }

  @override
  Future<void> signOut() async {
    await _google.disconnect();
  }

  /// Credential dari tombol GIS / One Tap (khusus web) — hanya user dengan
  /// idToken yang diumumkan, karena tanpa idToken backend pasti menolak.
  @override
  Stream<AppUser> get accountChanges async* {
    await for (final account in _google.onCurrentUserChanged) {
      if (account == null) continue;
      final user = await _fromAccount(account);
      if (user.idToken.isEmpty) {
        debugPrint(
          'accountChanges: credential tanpa idToken diabaikan '
          '(${user.email}) — pakai tombol renderButton/One Tap',
        );
        continue;
      }
      yield user;
    }
  }

  Future<AppUser> _fromAccount(GoogleSignInAccount account) async {
    var idToken = '';
    try {
      final auth = await account.authentication;
      idToken = auth.idToken ?? '';
    } catch (_) {}
    return AppUser(
      uid: account.id,
      email: account.email,
      displayName: account.displayName ?? '',
      photoUrl: account.photoUrl ?? '',
      idToken: idToken,
    );
  }
}
