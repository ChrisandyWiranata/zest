import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/animations.dart';

/// Partikel ambient yang melayang pelan di latar (bokeh redup). Mengisi parent
/// dan diam saat `MediaQuery.disableAnimations`.
class AmbientParticles extends StatefulWidget {
  const AmbientParticles({
    super.key,
    this.color = AppColors.accent,
    this.count = 18,
  });

  final Color color;
  final int count;

  @override
  State<AmbientParticles> createState() => _AmbientParticlesState();
}

class _AmbientParticlesState extends State<AmbientParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );
  bool _static = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final static =
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
        !ambientEnabled;
    if (static != _static) {
      _static = static;
      if (static) {
        _ctrl.stop();
        _ctrl.value = 0;
      } else if (!_ctrl.isAnimating) {
        _ctrl.repeat();
      }
    } else if (!static && !_ctrl.isAnimating) {
      _ctrl.repeat();
    }
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
          painter: _ParticlesPainter(
            t: _ctrl.value,
            static: _static,
            color: widget.color,
            count: widget.count,
          ),
        ),
      ),
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  _ParticlesPainter({
    required this.t,
    required this.static,
    required this.color,
    required this.count,
  });

  final double t;
  final bool static;
  final Color color;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final now = static ? 0.25 : t;
    for (var i = 0; i < count; i++) {
      final seed = i * 0.173;
      final fx = (((seed * 37.0) % 1.0) + 1.0) % 1.0;
      final fy = (((seed * 53.0) % 1.0) + 1.0) % 1.0;
      final xBase = size.width * (0.08 + 0.84 * fx);
      final yBase = size.height * (0.0 + 1.1 * fy);
      final drift = (now + seed) % 1.0;
      final x =
          xBase +
          math.sin((now * 6.0 + seed) * 2 * math.pi) * size.width * 0.04;
      final y = yBase - drift * size.height * 1.2;
      final fade = drift < 0.12
          ? drift / 0.12
          : (1 - (drift - 0.88) / 0.12).clamp(0.0, 1.0);
      final r = 1.4 + fx * 3.0;
      final alpha =
          (fade * (0.10 + 0.14 * math.sin((now + seed) * math.pi * 3).abs()))
              .clamp(0.0, 1.0);
      final paint = Paint()..color = color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter old) =>
      old.t != t || old.static != static || old.count != count;
}
