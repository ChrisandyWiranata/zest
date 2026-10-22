import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/network_video_player.dart';
import '../../users/services/progress_sync.dart';
import '../models/video_item.dart';
import '../services/video_progress_store.dart';

/// Halaman player untuk mobile/compact: Scaffold + header back button.
class VideoPlayerPage extends StatelessWidget {
  const VideoPlayerPage({
    super.key,
    required this.video,
    required this.videoProgressStore,
    this.initialPositionMs,
    this.sync,
  });

  final VideoItem video;
  final VideoProgressStore videoProgressStore;
  final int? initialPositionMs;
  final ProgressSync? sync;

  @override
  Widget build(BuildContext context) {
    final view = VideoPlayerView(
      video: video,
      videoProgressStore: videoProgressStore,
      initialPositionMs: initialPositionMs,
      sync: sync,
    );
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: AdaptiveLayout.isWide(context)
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: view,
                ),
              )
            : view,
      ),
    );
  }
}

/// Seam untuk test: ganti permukaan player (Chewie/video_player) dengan
/// widget lain — `player` yang diterima belum pernah di-mount, aman diabaikan.
typedef VideoPlayerSurfaceBuilder = Widget Function(NetworkVideoPlayer player);

/// Isi halaman player (header judul, video, meta, toggle watched) tanpa
/// Scaffold — dipakai [VideoPlayerPage] maupun panel kanan split view.
/// Resume di-flush saat widget di-dispose (ganti video / tutup halaman).
class VideoPlayerView extends StatefulWidget {
  const VideoPlayerView({
    super.key,
    required this.video,
    required this.videoProgressStore,
    this.initialPositionMs,
    this.sync,
    this.showBackButton = true,
    this.onProgressChanged,
    this.playerBuilder,
  });

  final VideoItem video;
  final VideoProgressStore videoProgressStore;
  final int? initialPositionMs;
  final ProgressSync? sync;
  final bool showBackButton;

  /// Dipanggil setelah watched ditoggle/di-set otomatis, supaya panel daftar
  /// di sebelahnya bisa refresh centang watched.
  final VoidCallback? onProgressChanged;

  /// Hanya untuk test (lihat [VideoPlayerSurfaceBuilder]).
  final VideoPlayerSurfaceBuilder? playerBuilder;

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  /// Status watched sinkron; null = masih dimuat dari store.
  bool? _watchedNow;
  Timer? _resumeDebounce;
  Duration? _lastResume;
  bool _finishedSaved = false;

  @override
  void initState() {
    super.initState();
    _loadWatched();
  }

  Future<void> _loadWatched() async {
    final watched = await widget.videoProgressStore.isWatched(
      widget.video.category,
      widget.video.progressKey,
    );
    if (!mounted) return;
    setState(() => _watchedNow = watched);
  }

  Future<void> _toggle() async {
    final next = !(_watchedNow ?? false);
    // Repaint dulu — sync ke backend tidak boleh menahan UI.
    setState(() => _watchedNow = next);
    await widget.videoProgressStore.setWatched(
      widget.video.category,
      widget.video.progressKey,
      next,
    );
    widget.onProgressChanged?.call();
    widget.sync?.videoChanged(widget.video.category, widget.video.progressKey);
    try {
      await widget.sync?.flush();
    } catch (_) {}
  }

  void _onPositionChanged(Duration position) {
    if (_finishedSaved) return;
    _lastResume = position;
    _resumeDebounce?.cancel();
    _resumeDebounce = Timer(
      const Duration(seconds: 3),
      () => widget.videoProgressStore.setResume(
        widget.video.category,
        widget.video.progressKey,
        position.inMilliseconds,
      ),
    );
  }

  Future<void> _onFinished() async {
    if (_finishedSaved) return;
    _finishedSaved = true;
    _resumeDebounce?.cancel();
    _lastResume = null;
    // Repaint dulu, lalu persist + sync (lihat _toggle).
    setState(() => _watchedNow = true);
    await widget.videoProgressStore.setWatched(
      widget.video.category,
      widget.video.progressKey,
      true,
    );
    await widget.videoProgressStore.setResume(
      widget.video.category,
      widget.video.progressKey,
      0,
    );
    widget.onProgressChanged?.call();
    widget.sync?.videoChanged(widget.video.category, widget.video.progressKey);
    try {
      await widget.sync?.flush();
    } catch (_) {}
  }

  @override
  void dispose() {
    _resumeDebounce?.cancel();
    final last = _lastResume;
    if (last != null) {
      widget.videoProgressStore.setResume(
        widget.video.category,
        widget.video.progressKey,
        last.inMilliseconds,
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final watched = _watchedNow ?? false;
    final player = NetworkVideoPlayer(
      key: ValueKey(widget.video.progressKey),
      videoUrl: widget.video.videoUrl,
      initialPosition: widget.initialPositionMs == null
          ? null
          : Duration(milliseconds: widget.initialPositionMs!),
      onPositionChanged: _onPositionChanged,
      onFinished: _onFinished,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              if (widget.showBackButton)
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              Expanded(
                child: Text(
                  widget.video.bab.isEmpty
                      ? widget.video.displayTitle
                      : '${widget.video.bab} · ${widget.video.displayTitle}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: widget.playerBuilder?.call(player) ?? player,
                ),
                const SizedBox(height: 20),
                Text(
                  widget.video.displayTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _MetaChip(
                      icon: Icons.label_outline_rounded,
                      label: widget.video.typeBadge,
                      color: widget.video.isGrammar
                          ? AppColors.accent
                          : AppColors.textMuted,
                    ),
                    if (widget.video.bab.isNotEmpty)
                      _MetaChip(
                        icon: Icons.article_outlined,
                        label: widget.video.bab,
                        color: AppColors.textMuted,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: _toggle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: watched
                          ? AppColors.hafal.withValues(alpha: 0.14)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: watched
                            ? AppColors.hafal.withValues(alpha: 0.5)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          watched
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: watched
                              ? AppColors.hafal
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          watched ? 'Sudah ditonton' : 'Tandai sudah ditonton',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: watched ? AppColors.hafal : AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
