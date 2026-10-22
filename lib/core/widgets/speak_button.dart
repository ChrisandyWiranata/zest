import 'package:flutter/material.dart';

import '../../features/tts/services/tts_service.dart';
import '../theme/app_colors.dart';
import 'motion.dart';

/// Tombol speaker kecil untuk memutar pengucapan Jepang via [TtsService].
/// Hanya muncul bila [TtsService.has] menjawab true (bacaan ada di set audio);
/// menonaktifkan diri selama memutar. Error TTS diabaikan oleh service.
class SpeakButton extends StatefulWidget {
  const SpeakButton({super.key, required this.text, required this.tts});

  final String text;
  final TtsService tts;

  @override
  State<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<SpeakButton> {
  late Future<bool> _available;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _available = widget.tts.has(widget.text);
  }

  @override
  void didUpdateWidget(SpeakButton old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _available = widget.tts.has(widget.text);
    }
  }

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.tts.speak(widget.text);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _available,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return PressScale(
          scale: 0.9,
          onTap: _tap,
          child: Tooltip(
            message: 'Dengar pengucapan',
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: _busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : const Icon(
                      Icons.volume_up_rounded,
                      size: 17,
                      color: AppColors.textMuted,
                    ),
            ),
          ),
        );
      },
    );
  }
}
