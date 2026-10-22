import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/day.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/page_transition.dart';
import '../../../core/widgets/soft_background.dart';
import '../../progress/services/xp_store.dart';
import '../../settings/services/settings_store.dart';
import '../../tts/services/tts_service.dart';
import '../../users/services/progress_sync.dart';
import '../../videos/services/video_progress_store.dart';
import '../../videos/services/videos_service.dart';
import '../../videos/widgets/video_mode_toggle.dart';
import '../../videos/widgets/video_playlist_view.dart';
import '../../videos/widgets/video_split_view.dart';
import '../../vocab/models/word.dart';
import '../../vocab/pages/study_page.dart';
import '../../vocab/pages/vocab_list_page.dart';
import '../../vocab/services/srs_scheduler.dart';
import '../../vocab/services/srs_store.dart';
import '../../vocab/services/vocab_service.dart';
import '../models/category_detail.dart';

class CategoryDetailPage extends StatefulWidget {
  const CategoryDetailPage({
    super.key,
    required this.category,
    required this.vocabService,
    required this.srsStore,
    required this.xpStore,
    required this.videosService,
    required this.videoProgressStore,
    this.sync,
    this.settings,
    this.tts,
  });

  final CategoryDetail category;
  final VocabService vocabService;
  final SrsStore srsStore;
  final XpStore xpStore;
  final VideosService videosService;
  final VideoProgressStore videoProgressStore;
  final ProgressSync? sync;
  final SettingsStore? settings;
  final TtsService? tts;

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<CategoryDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late Future<List<Word>> _wordsFuture;
  Future<void> _statesFuture = Future.value();
  Set<String> _mastered = {};
  Map<String, SrsCard> _states = {};
  String _flashcardLabel = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _load() {
    _wordsFuture = widget.vocabService.getWords(widget.category.name);
    final today = epochDay(DateTime.now());
    _statesFuture = widget.srsStore.migrateLegacy(widget.category.name).then((
      _,
    ) async {
      final states = await widget.srsStore.loadAll(widget.category.name);
      if (!mounted) return;
      final matureDays = widget.settings?.value.matureDays ?? kMatureInterval;
      setState(() {
        _states = states;
        _mastered = states.entries
            .where((e) => isMature(e.value, matureDays: matureDays))
            .map((e) => e.key)
            .toSet();
      });
    });
    _wordsFuture.then((words) async {
      if (!mounted) return;
      final settings = widget.settings;
      final newCap = settings?.value.newPerSession ?? kNewCap;
      final sessionCap = settings?.value.sessionCap ?? kSessionCap;
      final freshCap = await settings?.freshCapToday();
      if (!mounted) return;
      _statesFuture.then((_) {
        final queue = buildQueue(
          words: words,
          states: _states,
          today: today,
          newCap: newCap,
          sessionCap: sessionCap,
          freshCap: freshCap,
        );
        final reviews = queue.where((w) => _states.containsKey(w.masteryKey));
        if (reviews.isNotEmpty) {
          final fresh = queue.length - reviews.length;
          _flashcardLabel = fresh > 0
              ? 'Mulai Flashcard · Review ${reviews.length} · Baru $fresh'
              : 'Mulai Flashcard · Review ${reviews.length}';
        } else {
          _flashcardLabel = 'Mulai Flashcard · ${words.length} kata';
        }
        if (mounted) setState(() {});
      });
    });
  }

  void _reload() => setState(_load);

  String get _label {
    final title = widget.category.title;
    return title.isEmpty
        ? (widget.category.name.isEmpty
              ? widget.category.name
              : widget.category.name[0].toUpperCase() +
                    widget.category.name.substring(1))
        : title;
  }

  Future<void> _startFlashcard(List<Word> words) async {
    final settings = widget.settings;
    final newCap = settings?.value.newPerSession ?? kNewCap;
    final sessionCap = settings?.value.sessionCap ?? kSessionCap;
    final freshCap = await settings?.freshCapToday();
    if (!mounted) return;
    final queue = buildQueue(
      words: words,
      states: _states,
      today: epochDay(DateTime.now()),
      newCap: newCap,
      sessionCap: sessionCap,
      freshCap: freshCap,
    );
    if (queue.isEmpty) return;
    Navigator.of(context)
        .push(
          fadeSlideRoute(
            StudyPage(
              words: queue,
              category: widget.category.name,
              srsStore: widget.srsStore,
              xpStore: widget.xpStore,
              sync: widget.sync,
              settings: widget.settings,
              tts: widget.tts,
            ),
          ),
        )
        .then((_) => _reload());
  }

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${widget.category.total} kata · ${_mastered.length} hafal',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TabBar(
          controller: _tab,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Kosakata'),
            Tab(text: 'Video'),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _KosakataBody(
                future: _wordsFuture,
                mastered: _mastered,
                flashcardLabel: _flashcardLabel,
                onRetry: _reload,
                onStart: _startFlashcard,
                tts: widget.tts,
              ),
              _VideoTab(
                category: widget.category.name,
                videosService: widget.videosService,
                videoProgressStore: widget.videoProgressStore,
                sync: widget.sync,
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      body: SoftBackground(
        child: SafeArea(
          bottom: false,
          child: AdaptiveLayout.isWide(context)
              ? CenteredPane(child: column)
              : column,
        ),
      ),
    );
  }
}

class _KosakataBody extends StatelessWidget {
  const _KosakataBody({
    required this.future,
    required this.mastered,
    required this.flashcardLabel,
    required this.onRetry,
    required this.onStart,
    this.tts,
  });

  final Future<List<Word>> future;
  final Set<String> mastered;
  final String flashcardLabel;
  final VoidCallback onRetry;
  final ValueChanged<List<Word>> onStart;
  final TtsService? tts;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Word>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator();
        }
        if (snapshot.hasError) {
          return ErrorView(message: '${snapshot.error}', onRetry: onRetry);
        }
        final words = snapshot.data ?? const <Word>[];
        if (words.isEmpty) {
          return const ErrorView(
            message: 'Belum ada kosakata.',
            onRetry: _noop,
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => onStart(words),
                  icon: const Icon(Icons.style_rounded, size: 20),
                  label: Text(
                    flashcardLabel.isEmpty
                        ? 'Mulai Flashcard · ${words.length} kata'
                        : flashcardLabel,
                  ),
                ),
              ),
            ),
            Expanded(
              child: VocabListPage(
                words: words,
                mastered: mastered,
                tts: tts,
                grid: AdaptiveLayout.isWide(context),
              ),
            ),
          ],
        );
      },
    );
  }

  static void _noop() {}
}

/// Tab Video. Web wide (>=900px): split view [VideoSplitView] — daftar video
/// + filter di kiri, player di kanan. Sisanya: segmented control
/// Gabung/Bunpou/Kosakata di atas daftar; ganti mode me-reset playlist
/// lewat `ValueKey`; tap video push [VideoPlayerPage].
class _VideoTab extends StatefulWidget {
  const _VideoTab({
    required this.category,
    required this.videosService,
    required this.videoProgressStore,
    this.sync,
  });

  final String category;
  final VideosService videosService;
  final VideoProgressStore videoProgressStore;
  final ProgressSync? sync;

  @override
  State<_VideoTab> createState() => _VideoTabState();
}

class _VideoTabState extends State<_VideoTab> {
  String? _type;

  @override
  Widget build(BuildContext context) {
    // Web (kIsWeb) dengan lebar >=900px: split view sidebar + player.
    // Mobile/desktop app tetap flow lama (daftar → push halaman player).
    if (kIsWeb && AdaptiveLayout.isWide(context)) {
      return VideoSplitView(
        category: widget.category,
        videosService: widget.videosService,
        videoProgressStore: widget.videoProgressStore,
        sync: widget.sync,
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: VideoModeToggle(
            selected: _type,
            onChanged: (type) => setState(() => _type = type),
          ),
        ),
        Expanded(
          child: VideoPlaylistView(
            key: ValueKey(_type),
            category: widget.category,
            videosService: widget.videosService,
            videoProgressStore: widget.videoProgressStore,
            sync: widget.sync,
            type: _type,
            showType: _type == null,
          ),
        ),
      ],
    );
  }
}
