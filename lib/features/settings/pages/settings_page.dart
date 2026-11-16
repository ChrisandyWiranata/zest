import 'package:flutter/material.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/zest_colors.dart';
import '../../../core/widgets/card_surface.dart';
import '../../tts/services/tts_service.dart';
import '../services/settings_store.dart';

/// Halaman Pengaturan: batas flashcard, jatah kata baru per hari, dan suara.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings, this.tts});

  final SettingsStore settings;
  final TtsService? tts;

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeScope.maybeOf(context);
    final content = ValueListenableBuilder<SettingsData>(
      valueListenable: settings,
      builder: (context, data, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
          children: [
            Text(
              'Pengaturan',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Flashcard'),
            const SizedBox(height: 8),
            CardSurface(
              padding: EdgeInsets.zero,
              radius: 18,
              child: Column(
                children: [
                  _StepperRow(
                    stepperKey: 'new',
                    title: 'Kata baru per sesi',
                    subtitle: 'Kata asing baru boleh masuk satu sesi.',
                    value: data.newPerSession,
                    min: kMinNewPerSession,
                    max: kMaxNewPerSession,
                    onChanged: settings.setNewPerSession,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _StepperRow(
                    stepperKey: 'session',
                    title: 'Maks kartu per sesi',
                    subtitle: 'Batas total kartu (ulangan + baru) per sesi.',
                    value: data.sessionCap,
                    min: kMinSessionCap,
                    max: kMaxSessionCap,
                    onChanged: settings.setSessionCap,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _StepperRow(
                    stepperKey: 'budget',
                    title: 'Jatah kata baru per hari',
                    subtitle: 'Berlaku lintas kategori; 0 = tanpa batas.',
                    value: data.dailyNewBudget,
                    min: 0,
                    max: kMaxDailyNewBudget,
                    step: kMinDailyNewBudget,
                    unlimited: true,
                    onChanged: settings.setDailyNewBudget,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Pola ulangan'),
            const SizedBox(height: 8),
            CardSurface(
              padding: EdgeInsets.zero,
              radius: 18,
              child: Column(
                children: [
                  _StepperRow(
                    stepperKey: 'srs-first',
                    title: 'Ulang pertama',
                    subtitle: 'Hari sebelum kartu baru muncul lagi.',
                    value: data.firstReviewDays,
                    min: kMinFirstReview,
                    max: kMaxFirstReview,
                    onChanged: settings.setFirstReviewDays,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _FactorRow(
                    title: 'Faktor naik interval',
                    subtitle: 'Seberapa cepat jeda ulangan bertambah.',
                    value: data.intervalFactor,
                    onChanged: settings.setIntervalFactor,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _StepperRow(
                    stepperKey: 'srs-max',
                    title: 'Batas interval maks',
                    subtitle: 'Jeda ulangan tidak melebihi ini (hari).',
                    value: data.maxIntervalDays,
                    min: kMinMaxInterval,
                    max: kMaxMaxInterval,
                    step: 7,
                    onChanged: settings.setMaxIntervalDays,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _StepperRow(
                    stepperKey: 'srs-mature',
                    title: 'Ambang hafal',
                    subtitle: 'Jeda ulangan agar dihitung hafal (hari).',
                    value: data.matureDays,
                    min: kMinMatureDays,
                    max: kMaxMatureDays,
                    onChanged: settings.setMatureDays,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Suara'),
            const SizedBox(height: 8),
            Material(
              color: context.colors.card,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: context.colors.border),
              ),
              child: SwitchListTile(
                value: data.autoSpeak,
                onChanged: tts == null ? null : settings.setAutoSpeak,
                secondary: Icon(
                  Icons.volume_up_rounded,
                  size: 20,
                  color: tts == null
                      ? context.colors.textHint
                      : context.colors.textMuted,
                ),
                title: const Text(
                  'Putar pengucapan otomatis',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  tts == null
                      ? 'Fitur suara belum aktif.'
                      : 'Saat kartu dibalik ke jawaban.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.colors.textMuted,
                  ),
                ),
                activeThumbColor: context.colors.accent,
                inactiveThumbColor: context.colors.textHint,
              ),
            ),
            if (themeController != null) ...[
              const SizedBox(height: 20),
              const _SectionLabel('Tampilan'),
              const SizedBox(height: 8),
              _ThemeSelector(controller: themeController),
            ],
          ],
        );
      },
    );

    return SafeArea(
      bottom: false,
      child: AdaptiveLayout.isWide(context)
          ? CenteredPane(child: content)
          : content,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.4,
        color: context.colors.textMuted,
      ),
    );
  }
}

/// Pemilih mode tampilan (Sistem/Terang/Gelap). Hanya tampil bila ada
/// [ThemeScope] di atas (produksi); test tanpa scope menyembunyikannya.
class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: controller,
      builder: (context, mode, _) => CardSurface(
        padding: EdgeInsets.zero,
        radius: 18,
        child: Column(
          children: [
            _ThemeOption(
              optionKey: 'theme-system',
              icon: Icons.brightness_auto_rounded,
              label: 'Sistem',
              subtitle: 'Ikut pengaturan perangkat.',
              selected: mode == ThemeMode.system,
              onTap: () => controller.setMode(ThemeMode.system),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _ThemeOption(
              optionKey: 'theme-light',
              icon: Icons.light_mode_rounded,
              label: 'Terang',
              subtitle: 'Latar terang sepanjang waktu.',
              selected: mode == ThemeMode.light,
              onTap: () => controller.setMode(ThemeMode.light),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _ThemeOption(
              optionKey: 'theme-dark',
              icon: Icons.dark_mode_rounded,
              label: 'Gelap',
              subtitle: 'Latar gelap sepanjang waktu.',
              selected: mode == ThemeMode.dark,
              onTap: () => controller.setMode(ThemeMode.dark),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.optionKey,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String optionKey;
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      key: Key(optionKey),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? colors.accent : colors.textMuted,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: selected ? colors.accent : colors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.stepperKey,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.unlimited = false,
  });

  final String stepperKey;
  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final int step;
  final bool unlimited;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canMinus = unlimited ? value >= step : value > min;
    final canPlus = value < max;
    final display = unlimited && value == 0 ? 'Tak terbatas' : '$value';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StepButton(
            key: Key('step-$stepperKey-minus'),
            icon: Icons.remove_rounded,
            onTap: canMinus
                ? () => onChanged(unlimited && value <= step ? 0 : value - step)
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              display,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: context.colors.text,
              ),
            ),
          ),
          _StepButton(
            key: Key('step-$stepperKey-plus'),
            icon: Icons.add_rounded,
            onTap: canPlus
                ? () => onChanged(unlimited && value == 0 ? step : value + step)
                : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({super.key, required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: context.colors.card,
      shape: CircleBorder(
        side: BorderSide(
          color: enabled
              ? context.colors.border
              : context.colors.border.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? context.colors.accent : context.colors.textHint,
          ),
        ),
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = '×${value.toStringAsFixed(1)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: context.colors.accent,
                ),
              ),
            ],
          ),
          Slider(
            key: const Key('srs-factor'),
            value: value,
            min: kMinIntervalFactor,
            max: kMaxIntervalFactor,
            divisions: 15,
            label: label,
            activeColor: context.colors.accent,
            inactiveColor: context.colors.border,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
