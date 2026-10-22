import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SoftBackground extends StatelessWidget {
  const SoftBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: AppColors.bgBase, child: child);
  }
}
