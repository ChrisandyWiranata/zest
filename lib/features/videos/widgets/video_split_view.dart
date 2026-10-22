import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../users/services/progress_sync.dart';
import '../models/video_item.dart';
import '../pages/video_player_page.dart';
import '../services/video_progress_store.dart';
import '../services/videos_service.dart';
import 'video_mode_toggle.dart';

/// Builder untuk panel player — dipakai test supaya tidak membangun
/// Chewie/video_player (plugin tidak tersedia di VM test).
typedef VideoPlayerBuilder =
    Widget Function(VideoItem video, int? initialPositionMs);

/// Split view tab Video (web wide): daftar video + filter per bab di kiri,
/// player di kanan. Video belum dipilih → placeholder; tap video di sidebar
/// langsung diputar di panel kanan (tanpa push halaman).
class VideoSplitView extends StatefulWidget {
  const VideoSplitView({
    super.key,
    required this.category,
    required this.videosService,
    required this.videoProgressStore,
    this.sync,
    this.playerBuilder,
  });

  final String category;
  final VideosService videosService;
  final VideoProgressStore videoProgressStore;
  final ProgressSync? sync;
  final VideoPlayerBuilder? playerBuilder;

  @override
  State<VideoSplitView> createState() => _VideoSplitViewState();
}

class _VideoSplitViewState extends State<VideoSplitView> {
  static const double _sidebarWidth = 360;

  String? _type;
  late Future<_SplitData> _future;
  VideoItem? _selected;
  int? _selectedResumeMs;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SplitData> _load() async {
    final videos = await widget.videosService.getVideos(
      widget.category,
      type: _type,
    );
    final watched = <String>{};
    final resume = <String, int>{};
    for (final v in videos) {
      if (await widget.videoProgressStore.isWatched(
        widget.category,
        v.progressKey,
      )) {
        watched.add(v.progressKey);
      } else {
        final ms = await widget.videoProgressStore.getResume(
          widget.category,
          v.progressKey,
        );
        if (ms != null && ms > 0) resume[v.progressKey] = ms;
      }
    }
    return _SplitData(videos: videos, watched: watched, resume: resume);
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
    try {
      await _future;
    } catch (_) {}
  }

  void _onTypeChanged(String? type) {
    setState(() {
      _type = type;
      _future = _load();
      // Video terpilih tidak lolos filter baru → kembali ke placeholder.
      if (_selected != null && type != null && _selected!.type != type) {
        _selected = null;
        _selectedResumeMs = null;
      }
    });
  }

  Future<void> _select(VideoItem video) async {
    if (_selected?.progressKey == video.progressKey) return;
    final ms = await widget.videoProgressStore.getResume(
      widget.category,
      video.progressKey,
    );
    if (!mounted) return;
    setState(() {
      _selected = video;
      _selectedResumeMs = (ms == null || ms <= 0) ? null : ms;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: _sidebarWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: VideoModeToggle(
                  selected: _type,
                  onChanged: _onTypeChanged,
                ),
              ),
              Expanded(child: _buildSidebarList()),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(child: _buildPlayerPanel()),
      ],
    );
  }

  Widget _buildSidebarList() {
    return FutureBuilder<_SplitData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator();
        }
        if (snapshot.hasError) {
          return ErrorView(message: '${snapshot.error}', onRetry: _reload);
        }
        final data = snapshot.data ?? _SplitData.empty();
        if (data.videos.isEmpty) {
          return ErrorView(
            message: _type == null
                ? 'Belum ada video.'
                : _type == VideoItem.typeGrammar
                ? 'Belum ada video bunpou.'
                : 'Belum ada video kosakata.',
            onRetry: _noop,
          );
        }
        final sections = _groupByBab(data.videos);
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          itemCount: sections.length,
          itemBuilder: (_, i) {
            final section = sections[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (i > 0) const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    section.bab,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                for (final video in section.videos)
                  _SidebarVideoTile(
                    video: video,
                    watched: data.watched.contains(video.progressKey),
                    resumed: data.resume.containsKey(video.progressKey),
                    selected: _selected?.progressKey == video.progressKey,
                    showType: _type == null,
                    onTap: () => _select(video),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPlayerPanel() {
    final selected = _selected;
    if (selected == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.play_circle_outline_rounded,
              size: 56,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              'Pilih video untuk mulai menonton',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    final player =
        widget.playerBuilder?.call(selected, _selectedResumeMs) ??
        VideoPlayerView(
          video: selected,
          videoProgressStore: widget.videoProgressStore,
          initialPositionMs: _selectedResumeMs,
          sync: widget.sync,
          showBackButton: false,
          onProgressChanged: _reload,
        );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        // Key memaksa State player dibuat ulang saat ganti video
        // (controller lama di-dispose, resume flush jalan).
        child: KeyedSubtree(
          key: ValueKey('video-player-${selected.progressKey}'),
          child: player,
        ),
      ),
    );
  }

  static void _noop() {}

  static List<_SplitSection> _groupByBab(List<VideoItem> videos) {
    final sections = <_SplitSection>[];
    final byBab = <String, List<VideoItem>>{};
    for (final v in videos) {
      final key = v.bab.isEmpty ? 'Video' : v.bab;
      (byBab[key] ??= []).add(v);
    }
    byBab.forEach((bab, items) {
      sections.add(_SplitSection(bab: bab, videos: items));
    });
    return sections;
  }
}

class _SplitSection {
  const _SplitSection({required this.bab, required this.videos});

  final String bab;
  final List<VideoItem> videos;
}

class _SplitData {
  const _SplitData({
    required this.videos,
    required this.watched,
    this.resume = const {},
  });

  final List<VideoItem> videos;
  final Set<String> watched;
  final Map<String, int> resume;

  static _SplitData empty() =>
      const _SplitData(videos: [], watched: <String>{});
}

class _SidebarVideoTile extends StatelessWidget {
  const _SidebarVideoTile({
    required this.video,
    required this.watched,
    required this.resumed,
    required this.selected,
    required this.showType,
    required this.onTap,
  });

  final VideoItem video;
  final bool watched;
  final bool resumed;
  final bool selected;
  final bool showType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = selected ? AppColors.accent : AppColors.text;
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: selected
              ? BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      width: 3,
                      color: AppColors.accent.withValues(alpha: 0.8),
                    ),
                  ),
                )
              : null,
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.14),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.35),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: titleColor,
                      ),
                    ),
                    if (showType) ...[
                      const SizedBox(height: 4),
                      _SidebarTypeBadge(
                        label: video.typeBadge,
                        grammar: video.isGrammar,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (watched)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 17,
                  color: AppColors.hafal,
                )
              else if (resumed)
                const Tooltip(
                  message: 'Lanjut menonton',
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    size: 17,
                    color: AppColors.accent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarTypeBadge extends StatelessWidget {
  const _SidebarTypeBadge({required this.label, required this.grammar});

  final String label;
  final bool grammar;

  @override
  Widget build(BuildContext context) {
    final color = grammar ? AppColors.accent : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
