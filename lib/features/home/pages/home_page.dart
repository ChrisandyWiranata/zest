import 'package:flutter/material.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/day.dart';
import '../../../core/widgets/ambient_particles.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/page_transition.dart';
import '../../auth/models/app_user.dart';
import '../../categories/models/category_detail.dart';
import '../../categories/pages/category_detail_page.dart';
import '../../categories/services/categories_service.dart';
import '../../progress/services/xp_store.dart';
import '../../settings/services/settings_store.dart';
import '../../tts/services/tts_service.dart';
import '../../users/services/progress_sync.dart';
import '../../videos/services/video_progress_store.dart';
import '../../videos/services/videos_service.dart';
import '../../vocab/services/srs_scheduler.dart';
import '../../vocab/services/srs_store.dart';
import '../../vocab/services/vocab_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.categoriesService,
    required this.vocabService,
    required this.srsStore,
    required this.xpStore,
    required this.videosService,
    required this.videoProgressStore,
    this.user,
    this.sync,
    this.settings,
    this.onOpenProfile,
    this.tts,
  });

  final CategoriesService categoriesService;
  final VocabService vocabService;
  final SrsStore srsStore;
  final XpStore xpStore;
  final VideosService videosService;
  final VideoProgressStore videoProgressStore;
  final AppUser? user;
  final ProgressSync? sync;
  final SettingsStore? settings;
  final VoidCallback? onOpenProfile;
  final TtsService? tts;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _reload() {
    setState(() {
      _future = _load();
    });
    return _future.then((_) {}).catchError((_) {});
  }

  Future<HomeData> _load() async {
    final xp = await widget.xpStore.load();
    final categories = await widget.categoriesService.getCategories();
    final today = epochDay(DateTime.now());
    final progress = await Future.wait(
      categories.map((c) async {
        await widget.srsStore.migrateLegacy(c.name);
        final words = await widget.vocabService.getWords(c.name);
        final states = await widget.srsStore.loadAll(c.name);
        var mastered = 0;
        var due = 0;
        final matureDays = widget.settings?.value.matureDays ?? kMatureInterval;
        for (final s in states.entries) {
          if (isMature(s.value, matureDays: matureDays)) mastered++;
          if (s.value.due <= today) due++;
        }
        return CategoryProgress(
          category: c,
          mastered: mastered,
          due: due,
          fresh: words.length - states.length,
        );
      }),
    );
    final watched = await widget.videoProgressStore.countWatched();
    return HomeData(xp: xp, progress: progress, watched: watched);
  }

  void _open(CategoryProgress item) {
    Navigator.of(context)
        .push(
          fadeSlideRoute(
            CategoryDetailPage(
              category: item.category,
              vocabService: widget.vocabService,
              srsStore: widget.srsStore,
              xpStore: widget.xpStore,
              videosService: widget.videosService,
              videoProgressStore: widget.videoProgressStore,
              sync: widget.sync,
              settings: widget.settings,
              tts: widget.tts,
            ),
          ),
        )
        .then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AdaptiveLayout.isWide(context)
              ? const _WideDashboardSkeleton()
              : const _DashboardSkeleton();
        }
        if (snapshot.hasError) {
          return ErrorView(message: '${snapshot.error}', onRetry: _reload);
        }
        final data = snapshot.data ?? HomeData.empty();
        final callbacks = _HomeCallbacks(
          onRefresh: _reload,
          onOpen: _open,
          onStart: _openSession,
        );
        return AdaptiveLayout.isWide(context)
            ? _HomeWideBody(
                user: widget.user,
                data: data,
                onOpenProfile: widget.onOpenProfile,
                callbacks: callbacks,
              )
            : _HomeBody(
                user: widget.user,
                data: data,
                onOpenProfile: widget.onOpenProfile,
                callbacks: callbacks,
              );
      },
    );
  }

  void _openSession(HomeData data) {
    CategoryProgress? best;
    for (final p in data.progress) {
      if (p.due <= 0 && p.fresh <= 0) continue;
      if (best == null || (p.due + p.fresh) > (best.due + best.fresh)) {
        best = p;
      }
    }
    if (best != null) _open(best);
  }
}

String _greetingName(AppUser? user) {
  final display = user?.displayName.trim() ?? '';
  if (display.isNotEmpty) return display.split(' ').first;
  final email = user?.email ?? '';
  final at = email.indexOf('@');
  if (at > 0) return email.substring(0, at);
  return 'belajar';
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.data, this.onOpenProfile});

  final AppUser? user;
  final HomeData data;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final greeting = _greetingName(user);
    final subtitle = data.totalDue > 0
        ? 'Ada ${data.totalDue} ulangan menunggu hari ini.'
        : data.totalFresh > 0
        ? '${data.totalFresh} kata baru siap dipelajari.'
        : 'Semua beres! Tidak ada ulangan hari ini.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hai, $greeting!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          _Avatar(user: user, onTap: onOpenProfile),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, this.onTap});

  final AppUser? user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: PressScale(
        onTap: onTap,
        child: Tooltip(
          message: 'Profil',
          child: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.accent.withValues(alpha: 0.16),
            backgroundImage: (user?.hasPhoto ?? false)
                ? NetworkImage(user!.photoUrl)
                : null,
            child: user?.hasPhoto == true
                ? null
                : Text(
                    user?.initial ?? '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.accent,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _XpCard extends StatelessWidget {
  const _XpCard({required this.xp});

  final XpInfo xp;

  @override
  Widget build(BuildContext context) {
    const perLevel = XpStore.xpPerLevel;
    final intoLevel = xp.total % perLevel;
    final fraction = intoLevel / perLevel;
    final remaining = perLevel - intoLevel;
    final next = xp.level + 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _LevelRing(level: xp.level, fraction: fraction),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedCounter(
                    value: xp.total,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'XP total · $remaining XP lagi ke level $next',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 10),
                  _Pill(
                    icon: Icons.local_fire_department_rounded,
                    text: '${xp.streak} hari beruntun',
                    highlight: xp.streak > 0,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelRing extends StatelessWidget {
  const _LevelRing({required this.level, required this.fraction});

  final int level;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      height: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 66,
            height: 66,
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              backgroundColor: AppColors.bg,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$level',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                  height: 1,
                ),
              ),
              const Text(
                'Lv',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.data, required this.onStart});

  final HomeData data;
  final ValueChanged<HomeData> onStart;

  @override
  Widget build(BuildContext context) {
    final total = data.totalDue + data.totalFresh;
    final done = total == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: done
              ? AppColors.hafal.withValues(alpha: 0.08)
              : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: done
                ? AppColors.hafal.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: (done ? AppColors.hafal : AppColors.accent).withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                done ? Icons.check_circle_rounded : Icons.style_rounded,
                size: 24,
                color: done ? AppColors.hafal : AppColors.accent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    done ? 'Semua beres!' : 'Flashcard hari ini',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    done
                        ? 'Tidak ada ulangan. Kamu bebas hari ini.'
                        : '${data.totalDue} ulangan · ${data.totalFresh} kata baru',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            if (!done) const SizedBox(width: 8) else const SizedBox.shrink(),
            if (!done)
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                onPressed: () => onStart(data),
                child: const Text('Mulai'),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniStats extends StatelessWidget {
  const _MiniStats({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _Pill(
            icon: Icons.bolt_rounded,
            text: '${data.xp.todayXp} XP hari ini',
          ),
          const SizedBox(width: 8),
          _Pill(
            icon: Icons.style_rounded,
            text: '${data.totalMastered} kata hafal',
          ),
          const SizedBox(width: 8),
          _Pill(icon: Icons.videocam_rounded, text: '${data.watched} video'),
        ],
      ),
    );
  }
}

/// Chip stat kecil (non-interaktif) satu baris.
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, this.highlight = false});

  final IconData icon;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.accent : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.item, required this.onTap});

  final CategoryProgress item;
  final ValueChanged<CategoryProgress> onTap;

  @override
  Widget build(BuildContext context) {
    final category = item.category;
    final label = category.title.isEmpty ? category.name : category.title;
    final total = category.total;
    final ratio = total == 0 ? 0.0 : item.mastered / total;
    final hasDue = item.due > 0;
    return PressScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(item),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total kata',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 4,
                    backgroundColor: AppColors.bg,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      '${item.mastered}/$total hafal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHint,
                      ),
                    ),
                    const Spacer(),
                    if (hasDue)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${item.due} ulangan',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                          ),
                        ),
                      )
                    else
                      Icon(
                        category.level.isNotEmpty
                            ? Icons.flag_rounded
                            : Icons.tag_rounded,
                        size: 15,
                        color: AppColors.accent,
                      ),
                  ],
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton statis saat dashboard dimuat (tanpa animasi agar aman untuk
/// `pumpAndSettle` dan mode reduce-motion).
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const _SkelBox(width: 160, height: 26),
          const SizedBox(height: 6),
          const _SkelBox(width: 220, height: 14),
          const SizedBox(height: 20),
          const _SkelBox(height: 102),
          const SizedBox(height: 12),
          const _SkelBox(height: 78),
          const SizedBox(height: 12),
          const _SkelBox(height: 40),
          const SizedBox(height: 28),
          const _SkelBox(width: 120, height: 24),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(child: _SkelBox(height: 140)),
              SizedBox(width: 12),
              Expanded(child: _SkelBox(height: 140)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: _SkelBox(height: 140)),
              SizedBox(width: 12),
              Expanded(child: _SkelBox(height: 140)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkelBox extends StatelessWidget {
  const _SkelBox({this.width, required this.height});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}

class _HomeCallbacks {
  const _HomeCallbacks({
    required this.onRefresh,
    required this.onOpen,
    required this.onStart,
  });

  final Future<void> Function() onRefresh;
  final ValueChanged<CategoryProgress> onOpen;
  final ValueChanged<HomeData> onStart;
}

/// Body compact (mobile): dashboard satu kolom.
class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.user,
    required this.data,
    required this.onOpenProfile,
    required this.callbacks,
  });

  final AppUser? user;
  final HomeData data;
  final VoidCallback? onOpenProfile;
  final _HomeCallbacks callbacks;

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          const Positioned.fill(child: AmbientParticles()),
          RefreshIndicator(
            onRefresh: callbacks.onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _Header(user: user, data: data, onOpenProfile: onOpenProfile),
                const SizedBox(height: 18),
                _XpCard(xp: data.xp),
                const SizedBox(height: 12),
                _SessionCard(data: data, onStart: callbacks.onStart),
                const SizedBox(height: 12),
                _MiniStats(data: data),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Text(
                    'Kategori',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (data.progress.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 48),
                    child: ErrorView(
                      message: 'Belum ada kategori.',
                      onRetry: _HomeBody._noop,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            mainAxisExtent: 140,
                          ),
                      itemCount: data.progress.length,
                      itemBuilder: (_, i) => CardEntrance(
                        index: i,
                        child: _CategoryCard(
                          item: data.progress[i],
                          onTap: callbacks.onOpen,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Body lebar (web/desktop): hero + dua kolom (XP/stats | kategori).
class _HomeWideBody extends StatelessWidget {
  const _HomeWideBody({
    required this.user,
    required this.data,
    required this.onOpenProfile,
    required this.callbacks,
  });

  final AppUser? user;
  final HomeData data;
  final VoidCallback? onOpenProfile;
  final _HomeCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          const Positioned.fill(child: AmbientParticles()),
          RefreshIndicator(
            onRefresh: callbacks.onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                CenteredPane(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(
                          user: user,
                          data: data,
                          onOpenProfile: onOpenProfile,
                        ),
                        const SizedBox(height: 20),
                        _SessionCard(data: data, onStart: callbacks.onStart),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _XpCard(xp: data.xp),
                                  const SizedBox(height: 12),
                                  _MiniStats(data: data),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 7,
                              child: _WideCategoryGrid(
                                progress: data.progress,
                                onOpen: callbacks.onOpen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WideCategoryGrid extends StatelessWidget {
  const _WideCategoryGrid({required this.progress, required this.onOpen});

  final List<CategoryProgress> progress;
  final ValueChanged<CategoryProgress> onOpen;

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (progress.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: ErrorView(
              message: 'Belum ada kategori.',
              onRetry: _WideCategoryGrid._noop,
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 260).floor().clamp(2, 4);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 140,
                ),
                itemCount: progress.length,
                itemBuilder: (_, i) => CardEntrance(
                  index: i,
                  child: _CategoryCard(item: progress[i], onTap: onOpen),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Skeleton statis untuk layout lebar (aman untuk `pumpAndSettle`).
class _WideDashboardSkeleton extends StatelessWidget {
  const _WideDashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AdaptiveLayout.contentMaxWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SkelBox(width: 200, height: 26),
                SizedBox(height: 8),
                _SkelBox(width: 300, height: 14),
                SizedBox(height: 24),
                _SkelBox(height: 96),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          _SkelBox(height: 150),
                          SizedBox(height: 12),
                          _SkelBox(height: 44),
                        ],
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      flex: 7,
                      child: Column(
                        children: [
                          _SkelBox(width: 120, height: 24),
                          SizedBox(height: 14),
                          _SkelBox(height: 140),
                          SizedBox(height: 12),
                          _SkelBox(height: 140),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CategoryProgress {
  const CategoryProgress({
    required this.category,
    required this.mastered,
    this.due = 0,
    this.fresh = 0,
  });

  final CategoryDetail category;
  final int mastered;
  final int due;
  final int fresh;
}

class HomeData {
  const HomeData({required this.xp, required this.progress, this.watched = 0});

  final XpInfo xp;
  final List<CategoryProgress> progress;
  final int watched;

  int get totalDue => progress.fold(0, (s, p) => s + p.due);
  int get totalFresh => progress.fold(0, (s, p) => s + p.fresh);
  int get totalMastered => progress.fold(0, (s, p) => s + p.mastered);

  static HomeData empty() => const HomeData(
    xp: XpInfo(total: 0, streak: 0, todayXp: 0, level: 1),
    progress: [],
  );
}
