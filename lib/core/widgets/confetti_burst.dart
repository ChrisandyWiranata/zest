import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Ledakan konfeti satu kali (finite). Diletakkan sebagai overlay (Stack)
/// untuk momen perayaan. Diam (tidak menggambar) saat reduce-motion aktif.
class ConfettiBurst extends StatelessWidget {
  const ConfettiBurst({super.key, this.count = 44});

  final int count;

  @override
  Widget build(BuildContext context) {
    final static = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (static) return const IgnorePointer(child: SizedBox.expand());
    return _Burst(count: count);
  }
}

class _Burst extends StatefulWidget {
  const _Burst({required this.count});

  final int count;

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(t: _ctrl.value, count: widget.count),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.t, required this.count});

  final double t;
  final int count;

  static const _colors = [
    AppColors.accent,
    AppColors.accentSoft,
    AppColors.hafal,
    AppColors.text,
    AppColors.textMuted,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    for (var i = 0; i < count; i++) {
      final s = i * 0.731;
      final fx = (((s * 7.0) % 1.0) + 1.0) % 1.0;
      final fy = (((s * 3.0) % 1.0) + 1.0) % 1.0;
      final fr = (((s * 5.0) % 1.0) + 1.0) % 1.0;
      final fp = (((s * 11.0) % 1.0) + 1.0) % 1.0;
      final x0 = size.width * (0.06 + 0.88 * fx);
      final y0 = size.height * (0.08 + 0.12 * fy);
      final vx = (fp - 0.5) * size.width * 0.85;
      final vy = (0.10 + 0.30 * fr) * size.height * 0.9;
      final g = size.height * 1.7;
      final x = x0 + vx * t;
      final y = y0 + vy * t + 0.5 * g * t * t;
      final alpha = (1 - t * t) * 0.95;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((s * math.pi * 2) + t * (4 + 8 * fr));
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: alpha);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 4 + 5.0 * fr, height: 3),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.t != t || old.count != count;
}
