import 'package:flutter/material.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/card_surface.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/page_transition.dart';
import '../../users/services/progress_sync.dart';
import '../models/video_item.dart';
import '../pages/video_player_page.dart';
import '../services/video_progress_store.dart';
import '../services/videos_service.dart';

/// Daftar video per kategori, dikelompokkan per bab.
/// [type] null berarti gabungan Grammar + Kosakata; saat diisi hanya tipe
/// tersebut yang tampil. Memuat video + status watched, handle
/// loading/error/empty, lalu membuka [VideoPlayerPage] saat baris diketuk.
class VideoPlaylistView extends StatefulWidget {
  const VideoPlaylistView({
    super.key,
    required this.category,
    required this.videosService,
    required this.videoProgressStore,
    this.type,
    this.showType = true,
    this.sync,
  });

  final String category;
  final VideosService videosService;
  final VideoProgressStore videoProgressStore;
  final String? type;
  final bool showType;
  final ProgressSync? sync;

  @override
  State<VideoPlaylistView> createState() => _VideoPlaylistViewState();
}

class _VideoPlaylistViewState extends State<VideoPlaylistView> {
  late Future<_PlaylistData> _future;

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

  Future<_PlaylistData> _load() async {
    final videos = await widget.videosService.getVideos(
      widget.category,
      type: widget.type,
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
    return _PlaylistData(videos: videos, watched: watched, resume: resume);
  }

  void _openVideo(VideoItem video, int? resumeMs) {
    Navigator.of(context)
        .push(
          fadeSlideRoute(
            VideoPlayerPage(
              video: video,
              videoProgressStore: widget.videoProgressStore,
              initialPositionMs: resumeMs,
              sync: widget.sync,
            ),
          ),
        )
        .then((_) => _reload());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PlaylistData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator();
        }
        if (snapshot.hasError) {
          return ErrorView(message: '${snapshot.error}', onRetry: _reload);
        }
        final data = snapshot.data ?? _PlaylistData.empty();
        if (data.videos.isEmpty) {
          return ErrorView(
            message: widget.type == null
                ? 'Belum ada video.'
                : widget.type == VideoItem.typeGrammar
                ? 'Belum ada video bunpou.'
                : 'Belum ada video kosakata.',
            onRetry: _noop,
          );
        }
        final sections = _groupByBab(data.videos);
        return AdaptiveLayout.isWide(context)
            ? _wideSections(context, sections, data.watched, data.resume)
            : _compactSections(context, sections, data.watched, data.resume);
      },
    );
  }

  Widget _compactSections(
    BuildContext context,
    List<_PlaylistSection> sections,
    Set<String> watched,
    Map<String, int> resume,
  ) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: sections.length,
      itemBuilder: (_, i) {
        final section = sections[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i > 0) const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                section.bab,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 2),
            for (var j = 0; j < section.videos.length; j++) ...[
              if (j > 0) const Divider(color: AppColors.border, height: 1),
              _VideoRow(
                video: section.videos[j],
                watched: watched.contains(section.videos[j].progressKey),
                resumed: resume.containsKey(section.videos[j].progressKey),
                showType: widget.showType,
                onTap: () => _openVideo(
                  section.videos[j],
                  resume[section.videos[j].progressKey],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Layout lebar: setiap bab jadi grid kartu video 2-4 kolom.
  Widget _wideSections(
    BuildContext context,
    List<_PlaylistSection> sections,
    Set<String> watched,
    Map<String, int> resume,
  ) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: sections.length,
      itemBuilder: (_, i) {
        final section = sections[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i > 0) const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                section.bab,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisExtent: 112,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: section.videos.length,
              itemBuilder: (_, j) => _VideoCard(
                video: section.videos[j],
                watched: watched.contains(section.videos[j].progressKey),
                resumed: resume.containsKey(section.videos[j].progressKey),
                showType: widget.showType,
                onTap: () => _openVideo(
                  section.videos[j],
                  resume[section.videos[j].progressKey],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static void _noop() {}

  List<_PlaylistSection> _groupByBab(List<VideoItem> videos) {
    final sections = <_PlaylistSection>[];
    final byBab = <String, List<VideoItem>>{};
    for (final v in videos) {
      final key = v.bab.isEmpty ? 'Video' : v.bab;
      (byBab[key] ??= []).add(v);
    }
    byBab.forEach((bab, items) {
      sections.add(_PlaylistSection(bab: bab, videos: items));
    });
    return sections;
  }
}

class _PlaylistSection {
  const _PlaylistSection({required this.bab, required this.videos});

  final String bab;
  final List<VideoItem> videos;
}

class _VideoRow extends StatelessWidget {
  const _VideoRow({
    required this.video,
    required this.watched,
    required this.resumed,
    required this.showType,
    required this.onTap,
  });

  final VideoItem video;
  final bool watched;
  final bool resumed;
  final bool showType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
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
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
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
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (showType)
                      _TypeBadge(
                        label: video.typeBadge,
                        grammar: video.isGrammar,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (watched)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: AppColors.hafal,
                )
              else if (resumed)
                const Tooltip(
                  message: 'Lanjut menonton',
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    size: 18,
                    color: AppColors.accent,
                  ),
                ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.grammar});

  final String label;
  final bool grammar;

  @override
  Widget build(BuildContext context) {
    final color = grammar ? AppColors.accent : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Kartu video untuk layout lebar.
class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.video,
    required this.watched,
    required this.resumed,
    required this.showType,
    required this.onTap,
  });

  final VideoItem video;
  final bool watched;
  final bool resumed;
  final bool showType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
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
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                if (showType) ...[
                  const SizedBox(height: 5),
                  _TypeBadge(label: video.typeBadge, grammar: video.isGrammar),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (watched)
            const Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: AppColors.hafal,
            )
          else if (resumed)
            const Icon(
              Icons.play_circle_outline_rounded,
              size: 18,
              color: AppColors.accent,
            ),
        ],
      ),
    );
  }
}

class _PlaylistData {
  const _PlaylistData({
    required this.videos,
    required this.watched,
    this.resume = const {},
  });

  final List<VideoItem> videos;
  final Set<String> watched;
  final Map<String, int> resume;

  static _PlaylistData empty() =>
      const _PlaylistData(videos: [], watched: <String>{});
}
