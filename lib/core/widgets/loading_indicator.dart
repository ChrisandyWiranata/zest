import 'package:flutter/material.dart';

import '../theme/zest_colors.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: context.colors.accent,
        ),
      ),
    );
  }
}
