import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/day.dart';
import '../../../core/widgets/card_surface.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/soft_background.dart';
import '../../../core/widgets/speak_button.dart';
import '../../progress/services/xp_store.dart';
import '../../settings/services/settings_store.dart';
import '../../tts/services/tts_service.dart';
import '../../users/services/progress_sync.dart';
import '../models/word.dart';
import '../services/srs_scheduler.dart';
import '../services/srs_store.dart';

class StudyPage extends StatefulWidget {
  const StudyPage({
    super.key,
    required this.words,
    required this.category,
    required this.srsStore,
    required this.xpStore,
    this.sync,
    this.settings,
    this.tts,
  });

  final List<Word> words;
  final String category;
  final SrsStore srsStore;
  final XpStore xpStore;
  final ProgressSync? sync;
  final SettingsStore? settings;
  final TtsService? tts;

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage>
    with SingleTickerProviderStateMixin {
  late final List<Word> _queue = List.of(widget.words);
  late final AnimationController _fxCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  int _pos = 0;
  int _good = 0;
  int _sessionXp = 0;
  int? _startLevel;
  final Set<String> _requeued = {};
  final Set<String> _introduced = {};
  bool _flipped = false;
  bool? _lastGood;
  bool _levelUpShown = false;

  Word get _current => _queue[_pos];

  bool get _finished => _pos >= _queue.length;

  Future<void> _flip() async {
    setState(() => _flipped = !_flipped);
    if (!_flipped) return;
    final settings = widget.settings;
    if (settings?.value.autoSpeak != true) return;
    final tts = widget.tts;
    final read = _current.read;
    if (tts != null && read.isNotEmpty) tts.speak(read);
  }

  @override
  void initState() {
    super.initState();
    widget.xpStore.load().then((info) {
      if (mounted) _startLevel = info.level;
    });
  }

  @override
  void dispose() {
    _fxCtrl.dispose();
    super.dispose();
  }

  Future<void> _verdict(bool good) async {
    final w = _current;
    final key = w.masteryKey;
    final today = epochDay(DateTime.now());
    final card = await widget.srsStore.get(widget.category, key);
    final isNew = card == null;
    final sd = widget.settings?.value;
    final nextCard = good
        ? srsGood(
            card,
            today,
            firstInterval: sd?.firstReviewDays ?? 1,
            maxInterval: sd?.maxIntervalDays ?? kMaxInterval,
            defaultEase: sd?.intervalFactor ?? kDefaultEase,
          )
        : srsBad(card, today);
    await widget.srsStore.update(widget.category, key, nextCard);
    await widget.xpStore.addXp(good ? 5 : 1);

    if (isNew && !_introduced.contains(key)) {
      _introduced.add(key);
      widget.settings?.recordIntroduced(1);
    }

    if (good) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    widget.sync?.srsChanged(widget.category, key, nextCard);
    widget.sync?.statsChanged(await widget.xpStore.snapshot());
    try {
      await widget.sync?.flush();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _lastGood = good;
      _fxCtrl.forward(from: 0);
      if (good) _good++;
      _sessionXp += good ? 5 : 1;
      _pos++;
      if (!good && !_requeued.contains(key)) {
        _requeued.add(key);
        _queue.add(w);
      }
      _flipped = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SoftBackground(
        child: SafeArea(child: _finished ? _buildSummary() : _buildSession()),
      ),
    );
  }

  Widget _buildSession() {
    final session = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Stack(
        children: [
          Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${_pos + 1} / ${_queue.length}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 14,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 4),
                        AnimatedCounter(
                          value: _sessionXp,
                          duration: const Duration(milliseconds: 320),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final maxH = constraints.maxHeight - 16;
                      final cardH = math.min(maxH, 440.0);
                      return SizedBox(
                        height: cardH,
                        child: AnimatedBuilder(
                          animation: _fxCtrl,
                          builder: (context, child) {
                            final v = _fxCtrl.value;
                            final bad =
                                _lastGood == false && _fxCtrl.isAnimating;
                            final dx = bad
                                ? math.sin(v * math.pi * 6) * (1 - v) * 12
                                : 0.0;
                            final border = bad
                                ? Color.lerp(
                                    AppColors.belum,
                                    Colors.transparent,
                                    v.clamp(0.0, 1.0),
                                  )
                                : Colors.transparent;
                            return Transform.translate(
                              offset: Offset(dx, 0),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: border!, width: 2),
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: SizedBox(
                            height: cardH,
                            child: _FlipCard(
                              key: ValueKey(_current.masteryKey),
                              word: _current,
                              flipped: _flipped,
                              onFlip: _flip,
                              tts: widget.tts,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 50,
                child: _flipped ? _buildActions() : const SizedBox.shrink(),
              ),
            ],
          ),
          if (_lastGood != null && _fxCtrl.isAnimating) ...[
            if (_lastGood!)
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: const Alignment(0, -0.15),
                    child: _VerdictPop(v: _fxCtrl.value),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 78,
              child: IgnorePointer(
                child: Align(
                  child: _FloatChip(v: _fxCtrl.value, good: _lastGood!),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (AdaptiveLayout.isWide(context)) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: session,
        ),
      );
    }
    return session;
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: _VerdictButton(
            label: 'Belum hafal',
            good: false,
            onTap: () => _verdict(false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _VerdictButton(
            label: 'Sudah hafal',
            good: true,
            onTap: () => _verdict(true),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return Stack(
      children: [
        const Positioned.fill(child: ConfettiBurst()),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_rounded,
                  size: 44,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 12),
                _PopTitle(
                  key: ValueKey('summary-$_sessionXp'),
                  text: 'Sesi selesai!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_queue.length} kartu · $_good hafal',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _sessionXp.toDouble()),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text(
                    '+${v.round()} XP',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<XpInfo>(
                  future: widget.xpStore.load(),
                  builder: (context, snapshot) {
                    final info = snapshot.data;
                    if (info == null) return const SizedBox(height: 8);
                    if (!_levelUpShown &&
                        _startLevel != null &&
                        info.level > _startLevel!) {
                      _levelUpShown = true;
                    }
                    return Column(
                      children: [
                        PulseOnChange(
                          pulse: info.streak,
                          child: Text(
                            'Streak 🔥 ${info.streak} hari · Lv ${info.level}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_levelUpShown)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Lv ${info.level} tercapai!',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Selesai'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VerdictPop extends StatelessWidget {
  const _VerdictPop({required this.v});

  final double v;

  @override
  Widget build(BuildContext context) {
    final scale = Curves.easeOutBack.transform(math.min(1.0, v * 3.5));
    final opacity = 1 - ((v - 0.45) / 0.55).clamp(0.0, 1.0);
    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.hafal.withValues(alpha: 0.16),
            border: Border.all(color: AppColors.hafal, width: 2),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.check_rounded,
            color: AppColors.hafal,
            size: 34,
          ),
        ),
      ),
    );
  }
}

class _FloatChip extends StatelessWidget {
  const _FloatChip({required this.v, required this.good});

  final double v;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final opacity = (1 - v).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(0, -42 * v),
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: (good ? AppColors.hafal : AppColors.belum).withValues(
                alpha: 0.4,
              ),
            ),
          ),
          child: Text(
            good ? '+5 XP' : '+1 XP',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: good ? AppColors.hafal : AppColors.belum,
            ),
          ),
        ),
      ),
    );
  }
}

class _PopTitle extends StatelessWidget {
  const _PopTitle({super.key, required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(
        scale: 0.7 + 0.3 * v,
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: Text(text, style: style),
    );
  }
}

class _VerdictButton extends StatelessWidget {
  const _VerdictButton({
    required this.label,
    required this.good,
    required this.onTap,
  });

  final String label;
  final bool good;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: good ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: good ? null : Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: good ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({
    super.key,
    required this.word,
    required this.flipped,
    required this.onFlip,
    this.tts,
  });

  final Word word;
  final bool flipped;
  final VoidCallback onFlip;
  final TtsService? tts;

  @override
  Widget build(BuildContext context) {
    return _Flip3D(
      flipped: flipped,
      front: _CardFront(word: word, tts: tts),
      back: _CardBack(word: word, tts: tts),
      onTap: onFlip,
    );
  }
}

class _Flip3D extends StatefulWidget {
  const _Flip3D({
    required this.flipped,
    required this.front,
    required this.back,
    required this.onTap,
  });

  final bool flipped;
  final Widget front;
  final Widget back;
  final VoidCallback onTap;

  @override
  State<_Flip3D> createState() => _Flip3DState();
}

class _Flip3DState extends State<_Flip3D> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  @override
  void didUpdateWidget(_Flip3D old) {
    super.didUpdateWidget(old);
    if (old.flipped != widget.flipped) {
      if (widget.flipped) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final angle = Curves.easeInOutCubic.transform(_ctrl.value) * math.pi;
          final showFront = angle < math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(angle),
            child: showFront
                ? widget.front
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: widget.back,
                  ),
          );
        },
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.word, this.tts});

  final Word word;
  final TtsService? tts;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              word.word,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            if (word.read.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    word.read,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.accentSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (tts != null) ...[
                    const SizedBox(width: 10),
                    SpeakButton(text: word.read, tts: tts!),
                  ],
                ],
              ),
            ],
            const Spacer(),
            const Icon(
              Icons.touch_app_rounded,
              size: 20,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 4),
            const Text(
              'Ketuk untuk membalik',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.word, this.tts});

  final Word word;
  final TtsService? tts;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              children: [
                if (word.word.isNotEmpty)
                  Text(
                    word.word,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                if (word.read.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        word.read,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.accentSoft,
                        ),
                      ),
                      if (tts != null) ...[
                        const SizedBox(width: 8),
                        SpeakButton(text: word.read, tts: tts!),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                if (word.meaning.isNotEmpty)
                  Text(
                    word.meaning,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      height: 1.3,
                    ),
                  ),
                if (word.exampleJp.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word.exampleJp,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.text,
                            height: 1.45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (word.exampleRomaji.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            word.exampleRomaji,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        if (word.exampleMeaning.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            word.exampleMeaning,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                const Icon(
                  Icons.touch_app_rounded,
                  size: 20,
                  color: AppColors.textHint,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ketuk untuk kembali',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
