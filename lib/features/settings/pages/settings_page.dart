import 'package:flutter/material.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/app_colors.dart';
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
              color: AppColors.card,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppColors.border),
              ),
              child: SwitchListTile(
                value: data.autoSpeak,
                onChanged: tts == null ? null : settings.setAutoSpeak,
                secondary: Icon(
                  Icons.volume_up_rounded,
                  size: 20,
                  color: tts == null ? AppColors.textHint : AppColors.textMuted,
                ),
                title: const Text(
                  'Putar pengucapan otomatis',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  tts == null
                      ? 'Fitur suara belum aktif.'
                      : 'Saat kartu dibalik ke jawaban.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
                activeThumbColor: AppColors.accent,
                inactiveThumbColor: AppColors.textHint,
              ),
            ),
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
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.4,
        color: AppColors.textMuted,
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.text,
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
      color: AppColors.card,
      shape: CircleBorder(
        side: BorderSide(color: enabled ? AppColors.border : AppColors.border),
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
            color: enabled ? AppColors.accent : AppColors.textHint,
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
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accent,
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
            activeColor: AppColors.accent,
            inactiveColor: AppColors.border,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
