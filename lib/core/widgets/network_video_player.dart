import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Pemutar video jaringan (Chewie) yang mendukung:
/// - [initialPosition]: lanjut dari posisi menonton tersimpan.
/// - [onPositionChanged]: umpan posisi saat video diputar/dicari.
/// - [onFinished]: dipanggil sekali saat video mencapai akhir.
class NetworkVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final Duration? initialPosition;
  final ValueChanged<Duration>? onPositionChanged;
  final VoidCallback? onFinished;

  const NetworkVideoPlayer({
    super.key,
    required this.videoUrl,
    this.initialPosition,
    this.onPositionChanged,
    this.onFinished,
  });

  @override
  State<NetworkVideoPlayer> createState() => _NetworkVideoPlayerState();
}

class _NetworkVideoPlayerState extends State<NetworkVideoPlayer> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _finishedNotified = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    // 1. Inisialisasi controller dengan Network URL
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );

    await _videoPlayerController.initialize();

    // 2. Lanjut dari posisi tersimpan bila masih masuk akal.
    final init = widget.initialPosition;
    final duration = _videoPlayerController.value.duration;
    if (init != null &&
        init > Duration.zero &&
        (duration <= Duration.zero ||
            init < duration - const Duration(milliseconds: 1000))) {
      await _videoPlayerController.seekTo(init);
    }

    _videoPlayerController.addListener(_onPlayerTick);

    // 3. Buat ChewieController untuk kontrol UI
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoPlayerController.value.aspectRatio,
      placeholder: const Center(child: CircularProgressIndicator()),
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            errorMessage,
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );

    setState(() {});
  }

  void _onPlayerTick() {
    final position = _videoPlayerController.value.position;
    widget.onPositionChanged?.call(position);
    final duration = _videoPlayerController.value.duration;
    if (widget.onFinished == null || _finishedNotified) return;
    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 800)) {
      _finishedNotified = true;
      widget.onFinished!();
    }
  }

  @override
  void dispose() {
    _videoPlayerController.removeListener(_onPlayerTick);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _chewieController != null &&
            _chewieController!.videoPlayerController.value.isInitialized
        ? AspectRatio(
            aspectRatio: _videoPlayerController.value.aspectRatio,
            child: Chewie(controller: _chewieController!),
          )
        : const AspectRatio(
            aspectRatio: 16 / 9,
            child: Center(child: CircularProgressIndicator()),
          );
  }
}
