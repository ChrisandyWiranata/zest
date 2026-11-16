import 'package:flutter/material.dart';

/// Token warna Zest sebagai [ThemeExtension] — satu sumber warna untuk mode
/// terang & gelap. Widget membacanya lewat `context.colors`, sehingga tema
/// bisa diganti saat runtime tanpa warna hardcoded.
///
/// Palet gelap = identitas asli (dark-minimalis, aksen merah torii).
/// Palet terang = keluarga yang sama di atas kertas hangat, aksen torii
/// digelapkan agar tetap lolos kontras WCAG AA di latar putih.
@immutable
class ZestColors extends ThemeExtension<ZestColors> {
  const ZestColors({
    required this.bgBase,
    required this.bg,
    required this.card,
    required this.border,
    required this.accent,
    required this.accentSoft,
    required this.text,
    required this.textMuted,
    required this.textHint,
    required this.hafal,
    required this.belum,
  });

  /// Latar paling luar (scaffold).
  final Color bgBase;

  /// Bidang/groove sekunder di dalam elemen.
  final Color bg;

  /// Permukaan kartu, input, chip.
  final Color card;

  /// Garis/border/pemisah.
  final Color border;

  /// Aksen utama (merah torii).
  final Color accent;

  /// Aksen lembut (furigana, aksen kecil).
  final Color accentSoft;

  /// Teks utama.
  final Color text;

  /// Teks sekunder (label, keterangan).
  final Color textMuted;

  /// Teks petunjuk/placeholder.
  final Color textHint;

  /// Semantik benar/hafal/selesai.
  final Color hafal;

  /// Semantik salah/belum/destruktif/error.
  final Color belum;

  /// Palet gelap (default aplikasi).
  static const ZestColors dark = ZestColors(
    bgBase: Color(0xFF0A0A0B),
    bg: Color(0xFF121214),
    card: Color(0xFF1B1B1E),
    border: Color(0xFF2C2C30),
    accent: Color(0xFFE0574A),
    accentSoft: Color(0xFFF08A7A),
    text: Color(0xFFF1F1EF),
    textMuted: Color(0xFFA6A6AC),
    textHint: Color(0xFF86868E),
    hafal: Color(0xFF6FCF97),
    belum: Color(0xFFEB8D8B),
  );

  /// Palet terang (kertas hangat, tinta gelap, aksen torii digelapkan).
  static const ZestColors light = ZestColors(
    bgBase: Color(0xFFFAFAF9),
    bg: Color(0xFFF0F0EE),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE4E4E0),
    accent: Color(0xFFC4422F),
    accentSoft: Color(0xFFA85A4A),
    text: Color(0xFF1A1A1C),
    textMuted: Color(0xFF5B5B62),
    textHint: Color(0xFF74747B),
    hafal: Color(0xFF0F7F4C),
    belum: Color(0xFFC0392B),
  );

  @override
  ZestColors copyWith({
    Color? bgBase,
    Color? bg,
    Color? card,
    Color? border,
    Color? accent,
    Color? accentSoft,
    Color? text,
    Color? textMuted,
    Color? textHint,
    Color? hafal,
    Color? belum,
  }) {
    return ZestColors(
      bgBase: bgBase ?? this.bgBase,
      bg: bg ?? this.bg,
      card: card ?? this.card,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textHint: textHint ?? this.textHint,
      hafal: hafal ?? this.hafal,
      belum: belum ?? this.belum,
    );
  }

  @override
  ZestColors lerp(covariant ZestColors? other, double t) {
    if (other == null) return this;
    return ZestColors(
      bgBase: Color.lerp(bgBase, other.bgBase, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      hafal: Color.lerp(hafal, other.hafal, t)!,
      belum: Color.lerp(belum, other.belum, t)!,
    );
  }
}

/// Akses token warna aktif: `context.colors.accent`.
extension ZestColorsX on BuildContext {
  ZestColors get colors =>
      Theme.of(this).extension<ZestColors>() ?? ZestColors.dark;
}
