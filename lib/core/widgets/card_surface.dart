import 'package:flutter/material.dart';

import '../theme/zest_colors.dart';

class CardSurface extends StatelessWidget {
  const CardSurface({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.colors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: context.colors.border),
      ),
      child: child,
    );

    if (onTap == null) return box;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: box,
    );
  }
}
