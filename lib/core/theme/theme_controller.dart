import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferensi tampilan per-perangkat (bukan per-akun): mode tema yang dipilih
/// user. Disimpan di kunci lintas-user `app.theme.v1` supaya pilihan tetap
/// berlaku di layar login dan saat ganti akun.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController(this._prefs) : super(_read(_prefs));

  static const String storageKey = 'app.theme.v1';

  final SharedPreferences _prefs;

  static ThemeMode _read(SharedPreferences prefs) {
    switch (prefs.getString(storageKey)) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        // Default gelap: identitas asli Zest tetap terjaga sampai user memilih.
        return ThemeMode.dark;
    }
  }

  static String encode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.system => 'system',
    ThemeMode.dark => 'dark',
  };

  /// Mengubah mode tema dan menyimpannya.
  Future<void> setMode(ThemeMode mode) async {
    if (mode == value) return;
    value = mode;
    await _prefs.setString(storageKey, encode(mode));
  }
}

/// Menyediakan [ThemeController] ke subtree (mis. halaman Pengaturan) tanpa
/// harus menurunkan parameter lewat setiap lapisan widget.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;
}
