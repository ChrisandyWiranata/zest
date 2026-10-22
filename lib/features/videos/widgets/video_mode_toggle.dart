import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/video_item.dart';

/// Segmented control gabung/pisah tipe video (Gabung | Bunpou | Kosakata).
/// Dipakai oleh tab Video biasa dan sidebar split view.
class VideoModeToggle extends StatelessWidget {
  const VideoModeToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// null = gabungan Grammar + Kosakata.
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <(String?, String, IconData)>[
      (null, 'Gabung', Icons.playlist_play_rounded),
      (VideoItem.typeGrammar, 'Bunpou', Icons.menu_book_rounded),
      (VideoItem.typeVocab, 'Kosakata', Icons.style_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final (type, label, icon) in options)
            Expanded(
              child: _VideoModePill(
                key: ValueKey('video-mode-${type ?? 'all'}'),
                label: label,
                icon: icon,
                active: selected == type,
                onTap: () => onChanged(type),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoModePill extends StatelessWidget {
  const _VideoModePill({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.text : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        // scaleDown: pill dipakai juga di sidebar split view yang sempit —
        // konten mengecil alih-alih overflow.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
