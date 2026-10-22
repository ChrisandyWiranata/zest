import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/models/app_user.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/services/id_token.dart';
import '../../../core/network/api_client.dart';
import 'api_user_repo.dart';
import 'progress_sync.dart';

/// Kegagalan alur login (Google, backend, atau sinkron) dengan tahap yang
/// dilabelkan agar UI bisa menampilkan pesan yang tepat dan jujur.
class LoginException implements Exception {
  const LoginException(this.stage, this.cause);

  /// `auth` = Google menolak | `profile` = backend tidak menerima user
  /// | `hydrate` = tarik data progres gagal | `sync` = kirim progres gagal
  final String stage;
  final Object cause;

  @override
  String toString() => 'LoginException($stage): $cause';
}

/// Isi `session.web.v1`: profil + session token yang pernah diterbitkan server.
class _SavedSession {
  const _SavedSession({required this.user, required this.sessionToken});

  final AppUser user;
  final String sessionToken;
}

/// Sesi user aktif. null = belum login (aplikasi menampilkan LoginPage).
/// Menangani restore otomatis, login (dengan migrasi legacy + hydrate dari
/// backend), dan logout.
///
/// **Web**: sesi diperpanjang lewat session token server (TTL 1 hari sejak
/// login Google terakhir) yang disimpan di SharedPreferences — reload cukup
/// membaca token itu tanpa prompt One Tap (`session.web.v1`).
/// **Native**: profil terakhir disimpan tanpa token (`session.native.v1`) →
/// home tampil seketika walau `signInSilently()` null/timeout; token Google
/// menyusul via refresh senyap di background.
class UserSession extends ValueNotifier<AppUser?> {
  UserSession({
    required this.repo,
    required this.prefs,
    required this.auth,
    this.getCategories,
    this.isWeb = kIsWeb,
    this.restoreTimeout = const Duration(seconds: 4),
  }) : super(null);

  /// Kunci penyimpanan session token web (localStorage via SharedPreferences).
  static const String _savedSessionKey = 'session.web.v1';

  /// Kunci profil native: home tampil seketika tanpa menunggu
  /// `signInSilently()` (yang bisa null/timeout di cold start).
  static const String _nativeProfileKey = 'session.native.v1';

  final ApiUserRepo repo;
  final SharedPreferences prefs;
  final AuthService auth;

  /// Platform web punya perilaku refresh berbeda (credential GIS hanya dari
  /// interaksi user). Diinject agar test bisa menguji kedua jalur.
  final bool isWeb;

  /// Batas waktu [auth.restore] (prompt One Tap web bisa tidak pernah
  /// menjawab; tanpa batas ini `restore()` menggantung dan home tak pernah
  /// tampil). Lewat batas = dianggap belum login, tetap di LoginPage.
  final Duration restoreTimeout;

  /// Penyedia daftar nama kategori untuk hydrate data SRS/watched.
  final Future<Iterable<String>> Function()? getCategories;

  bool _restored = false;
  bool _reauthenticating = false;

  /// `true` selama restore membaca sesi tersimpan dari prefs. Selama flag ini,
  /// `reauthenticate` diam supaya 401 merambat ke `restore()` — fallback
  /// credential Google cukup satu kali prompt, tidak dobel.
  bool _restoringFromSaved = false;

  Future<void> restore() async {
    if (_restored) return;
    _restored = true;

    // Web: session token tersimpan dulu (tanpa prompt Google sama sekali).
    // Bila token sudah ditolak server (401) `_restoreFromSaved` sudah
    // membersihkan penyimpanan, lalu jatuh ke credential Google di bawah.
    if (isWeb) {
      final saved = _readSavedSession();
      if (saved != null && await _restoreFromSaved(saved)) return;
      if (value != null) return; // adopt menang selama restore sesi tersimpan
    } else {
      // Native: profil tersimpan → home SEKETIKA (sebelum `runApp` pun sudah
      // ter-set), token Google menyusul sebagai refresh di background. Ini
      // yang menjamin mobile tidak pernah disuruh login ulang cuma karena
      // `signInSilently()` null/timeout di cold start.
      final cached = _readNativeProfile();
      if (cached != null) {
        value = cached;
        unawaited(_refreshNativeBackground(cached));
        return;
      }
    }

    AppUser? user;
    try {
      user = await auth.restore().timeout(restoreTimeout);
    } on TimeoutException {
      debugPrint(
        'restore(): prompt Google tidak menjawab dalam $restoreTimeout '
        '→ anggap belum login',
      );
      user = null;
    } catch (e) {
      debugPrint('restore(): gagal memulihkan sesi -> $e');
      user = null;
    }
    // One Tap/credential web (adopt) bisa menang duluan — jangan timpa sesi
    // yang sudah ada, apalagi menimpanya dengan null.
    if (value != null) return;
    if (user == null) {
      value = null;
      return;
    }
    repo.setIdToken(user.idToken);
    String? sessionToken;
    try {
      sessionToken = await _hydrate(user);
    } catch (e) {
      // Backend tidak terjangkau tidak berarti user kehilangan sesi: seluruh
      // progres sudah ada di prefs, jadi tetap masuk dan coba sinkron nanti.
      debugPrint('restore(): hydrate gagal, lanjut offline -> $e');
    }
    if (value != null) return;
    value = user;
    await _keepSession(user, sessionToken);
  }

  Future<void> login() async {
    final AppUser user;
    try {
      user = await auth.signIn();
    } on SignInCancelled {
      rethrow;
    } catch (e) {
      throw LoginException('auth', e);
    }
    await adopt(user);
  }

  /// Selesaikan login untuk [user] yang sudah diverifikasi di sisi klien —
  /// dipakai [login] maupun jalur credential web (tombol GIS / One Tap) yang
  /// sudah membawa idToken. Di web, session token hasil server disimpan ke
  /// prefs dan dipakai sebagai Bearer berikutnya.
  Future<void> adopt(AppUser user) async {
    repo.setIdToken(user.idToken);
    final sessionToken = await _hydrate(user);
    value = user;
    await _keepSession(user, sessionToken);
  }

  Future<void> logout() async {
    try {
      await auth.signOut();
    } catch (e) {
      debugPrint('logout(): gagal mencabut sesi Google -> $e');
    }
    repo.setIdToken(null);
    await _clearSavedSession();
    await _clearNativeProfile();
    value = null;
  }

  /// Dipanggil saat backend membalas 401 (idToken/session token kedaluwarsa).
  ///
  /// Native: refresh senyap (`restore`) dan bila token hasilnya masih basi coba
  /// `signIn` sekali — user tetap login tanpa diminta masuk ulang.
  /// Web: coba One Tap (`auth.restore`) sekali untuk credential baru; bila
  /// Google tidak memberi credential (atau uid berbeda) → sesi diakhiri ke
  /// LoginPage. Kalau refresh gagal, sesi diakhiri supaya aplikasi tidak
  /// stuck dengan token mati.
  Future<void> reauthenticate() async {
    if (_reauthenticating || _restoringFromSaved) return;
    _reauthenticating = true;
    try {
      if (isWeb) {
        await _reauthenticateWeb();
        return;
      }

      final refreshed = await _refreshNative();
      final uid = value?.uid;
      if (refreshed == null ||
          uid == null ||
          refreshed.uid != uid ||
          !isIdTokenFresh(refreshed.idToken)) {
        await logout();
        return;
      }
      repo.setIdToken(refreshed.idToken);
      debugPrint('reauthenticate(): idToken di-refresh untuk $uid');
    } catch (e) {
      debugPrint('reauthenticate(): gagal refresh sesi -> $e');
      await logout();
    } finally {
      _reauthenticating = false;
    }
  }

  /// Web: credential GIS hanya didapat lewat interaksi, jadi dicoba prompt One
  /// Tap senyap sekali (user pernah mengizinkan → Google bisa menjawab tanpa
  /// UI). Bila Google tidak mengembalikan credential segar milik user yang
  /// sama, sesi diakhiri — jangan biarkan stuck dengan token 401.
  Future<void> _reauthenticateWeb() async {
    try {
      final fresh = await auth.restore().timeout(restoreTimeout);
      final uid = value?.uid;
      if (fresh != null &&
          fresh.idToken.isNotEmpty &&
          isIdTokenFresh(fresh.idToken) &&
          uid != null &&
          fresh.uid == uid) {
        await adopt(fresh);
        debugPrint('reauthenticate(): sesi web diperbarui lewat One Tap');
        return;
      }
    } catch (e) {
      debugPrint('reauthenticate(): One Tap web gagal -> $e');
    }
    await logout();
  }

  /// Refresh sesi native: senyap dulu, baru minta interaksi sekali.
  Future<AppUser?> _refreshNative() async {
    final silent = await auth.restore();
    if (silent != null && isIdTokenFresh(silent.idToken)) return silent;
    try {
      return await auth.signIn();
    } on SignInCancelled {
      return null;
    }
  }

  /// Tarik profile (+migrate) dan progres paralel. Mengembalikan
  /// `sessionToken` bila server menerbitkannya (hanya saat autentikasi memakai
  /// Google idToken asli; session token tidak diperpanjang oleh reload).
  Future<String?> _hydrate(AppUser user) async {
    final profile = _hydrateProfile(user);
    final progress = _hydrateProgress(user);
    await Future.wait([profile, progress]);
    return (await profile).sessionToken;
  }

  Future<ProfileSync> _hydrateProfile(AppUser user) async {
    final ProfileSync profile;
    try {
      profile = await repo.syncProfile(user);
    } catch (e) {
      throw LoginException('profile', e);
    }
    if (profile.firstTime) {
      try {
        await migrateLegacyUserData(prefs, repo, user.uid);
      } catch (e) {
        throw LoginException('sync', e);
      }
    }
    return profile;
  }

  Future<void> _hydrateProgress(AppUser user) async {
    try {
      await hydrateUserData(
        prefs,
        repo,
        user.uid,
        getCategories: getCategories,
      );
    } catch (e) {
      throw LoginException('hydrate', e);
    }
  }

  // ── Sesi web tersimpan (session token 1 hari) ────────────────────────────

  /// Lanjutkan sesi web dari penyimpanan lokal. `true` = sesi terpakai (masuk,
  /// walau offline); `false` = token ditolak server (401) — sudah dibersihkan,
  /// pemanggil lanjut ke fallback credential Google.
  Future<bool> _restoreFromSaved(_SavedSession saved) async {
    _restoringFromSaved = true;
    repo.setIdToken(saved.sessionToken);
    try {
      final sessionToken = await _hydrate(saved.user);
      if (value != null) return true; // adopt menang duluan
      value = saved.user;
      await _keepSession(saved.user, sessionToken);
      return true;
    } on LoginException catch (e) {
      if (_isUnauthorized(e)) {
        debugPrint('restore(): session token kedaluwarsa (401) → bersihkan');
        await _clearSavedSession();
        return false;
      }
      // Error jaringan ≠ sesi hilang: progres lokal masih ada, tetap masuk.
      debugPrint('restore(): hydrate sesi tersimpan gagal, offline -> $e');
      if (value == null) value = saved.user;
      return true;
    } catch (e) {
      debugPrint('restore(): sesi tersimpan rusak, lanjut fallback -> $e');
      if (value == null) value = saved.user;
      return true;
    } finally {
      _restoringFromSaved = false;
    }
  }

  bool _isUnauthorized(LoginException e) =>
      e.cause is ApiException && (e.cause as ApiException).statusCode == 401;

  _SavedSession? _readSavedSession() {
    try {
      final raw = prefs.getString(_savedSessionKey);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final uid = json['uid'];
      final sessionToken = json['sessionToken'];
      if (uid is! String ||
          uid.isEmpty ||
          sessionToken is! String ||
          sessionToken.isEmpty) {
        return null;
      }
      return _SavedSession(
        user: AppUser(
          uid: uid,
          email: json['email'] is String ? json['email'] as String : '',
          displayName: json['displayName'] is String
              ? json['displayName'] as String
              : '',
          photoUrl: json['photoUrl'] is String
              ? json['photoUrl'] as String
              : '',
          idToken: sessionToken,
        ),
        sessionToken: sessionToken,
      );
    } catch (e) {
      debugPrint('_readSavedSession(): sesi tersimpan rusak -> $e');
      return null;
    }
  }

  Future<void> _persistSession(AppUser user, String? sessionToken) async {
    if (!isWeb) return; // native tidak memakai session token web
    if (sessionToken == null || sessionToken.isEmpty) return;
    try {
      await prefs.setString(
        _savedSessionKey,
        jsonEncode({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoUrl': user.photoUrl,
          'sessionToken': sessionToken,
          'savedAt': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (e) {
      debugPrint('_persistSession(): gagal simpan sesi web -> $e');
    }
  }

  /// Web: simpan session token ke prefs dan jadikan Bearer sesudahnya — sesi
  /// lanjut memakai token TTL 1 hari (menempel login Google), bukan idToken
  /// Google yang cuma berlaku ±1 jam. Saat autentikasi memakai session token,
  /// server tidak menerbitkan token baru dan `_persistSession` jadi no-op —
  /// TTL tidak pernah diperpanjang oleh reload.
  ///
  /// Native: simpan profil saja (TANPA token — idToken Google kedaluwarsa ±1
  /// jam); restore berikutnya masuk home dari profil ini sambil refresh token
  /// senyap di background.
  Future<void> _keepSession(AppUser user, String? sessionToken) async {
    if (isWeb) {
      await _persistSession(user, sessionToken);
      if (sessionToken != null && sessionToken.isNotEmpty) {
        repo.setIdToken(sessionToken);
      }
    } else {
      await _persistNativeProfile(user);
    }
  }

  // ── Profil native tersimpan (home instan di mobile) ──────────────────────

  /// Refresh token native di belakang layar sesudah masuk dari profil
  /// tersimpan. Diam bila gagal — sesi tidak boleh digusur dari sini; jalur
  /// 401 → `reauthenticate` yang menangani (bisa memunculkan dialog `signIn`
  /// sekali kalau silent restore memang rusak di device).
  Future<void> _refreshNativeBackground(AppUser user) async {
    try {
      final fresh = await auth.restore().timeout(restoreTimeout);
      if (fresh == null ||
          fresh.uid != user.uid ||
          !isIdTokenFresh(fresh.idToken)) {
        debugPrint(
          'restore(): refresh token senyap nihil → lanjut tanpa token',
        );
        return;
      }
      repo.setIdToken(fresh.idToken);
      final sessionToken = await _hydrate(fresh);
      await _keepSession(fresh, sessionToken);
      debugPrint('restore(): token senyap diperbarui untuk ${fresh.uid}');
    } catch (e) {
      debugPrint('restore(): refresh token senyap gagal -> $e');
    }
  }

  Future<void> _persistNativeProfile(AppUser user) async {
    if (isWeb) return;
    try {
      await prefs.setString(
        _nativeProfileKey,
        jsonEncode({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoUrl': user.photoUrl,
          'savedAt': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (e) {
      debugPrint('_persistNativeProfile(): gagal -> $e');
    }
  }

  AppUser? _readNativeProfile() {
    try {
      final raw = prefs.getString(_nativeProfileKey);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final uid = json['uid'];
      if (uid is! String || uid.isEmpty) return null;
      return AppUser(
        uid: uid,
        email: json['email'] is String ? json['email'] as String : '',
        displayName: json['displayName'] is String
            ? json['displayName'] as String
            : '',
        photoUrl: json['photoUrl'] is String ? json['photoUrl'] as String : '',
      );
    } catch (e) {
      debugPrint('_readNativeProfile(): profil tersimpan rusak -> $e');
      return null;
    }
  }

  Future<void> _clearNativeProfile() async {
    try {
      await prefs.remove(_nativeProfileKey);
    } catch (e) {
      debugPrint('_clearNativeProfile(): gagal -> $e');
    }
  }

  Future<void> _clearSavedSession() async {
    try {
      await prefs.remove(_savedSessionKey);
    } catch (e) {
      debugPrint('_clearSavedSession(): gagal -> $e');
    }
  }
}
