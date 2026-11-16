import 'package:flutter/material.dart';

import 'zest_colors.dart';

/// Tema Zest dibangun dari token [ZestColors] — satu definisi untuk mode terang
/// dan gelap. Widget membaca warnanya lewat `context.colors`, bukan konstanta
/// hardcoded, sehingga tema bisa diganti saat runtime.
abstract final class AppTheme {
  static ThemeData dark() => _build(ZestColors.dark, Brightness.dark);

  static ThemeData light() => _build(ZestColors.light, Brightness.light);

  static ThemeData _build(ZestColors c, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        (isDark ? const ColorScheme.dark() : const ColorScheme.light())
            .copyWith(
              primary: c.accent,
              onPrimary: Colors.white,
              secondary: c.accentSoft,
              onSecondary: Colors.white,
              surface: c.card,
              onSurface: c.text,
              surfaceContainerHighest: c.card,
              onSurfaceVariant: c.textMuted,
              outline: c.border,
              error: c.belum,
              onError: Colors.white,
            );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.bgBase,
      colorScheme: scheme,
      extensions: [c],
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: c.bgBase,
        foregroundColor: c.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        labelColor: c.text,
        unselectedLabelColor: c.textMuted,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.card,
        contentTextStyle: TextStyle(color: c.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: c.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.bg,
        indicatorColor: c.accent.withValues(alpha: 0.16),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: c.textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? c.accent
                : c.textMuted,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
