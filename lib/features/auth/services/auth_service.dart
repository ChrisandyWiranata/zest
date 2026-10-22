import '../models/app_user.dart';

/// Kontrak auth agar bisa di-fake di test.
abstract class AuthService {
  /// Pulihkan sesi yang sudah pernah login (auto-login saat aplikasi start).
  Future<AppUser?> restore();

  /// Buka alur sign-in; lempar [SignInCancelled] bila dibatalkan user.
  Future<AppUser> signIn();

  /// Cabut sesi Google beserta data terkait.
  Future<void> signOut();

  /// Perubahan user aktif dari provider — jalur credential (tombol GIS /
  /// One Tap di web) yang men-deliver [AppUser] ber-idToken. Default kosong;
  /// implementasi tanpa jalur credential cukup memakai bawaan ini.
  Stream<AppUser> get accountChanges => const Stream.empty();
}

class SignInCancelled implements Exception {
  const SignInCancelled();
}
