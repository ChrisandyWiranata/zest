import 'package:flutter/material.dart';

/// Layout adaptif: di atas [wideBreakpoint] app memakai wajah lebar
/// (sidebar kiri + konten multi-kolom); di bawahnya wajah mobile
/// (bottom-nav + kanal satu kolom). Berbasis lebar sehingga web/desktop
/// ikut bereaksi saat jendela di-resize, dan HP tetap seperti semula.
abstract final class AdaptiveLayout {
  static const double wideBreakpoint = 900;
  static const double contentMaxWidth = 1180;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint;
}

/// Panel konten terpusat dengan lebar maksimal untuk layout lebar.
class CenteredPane extends StatelessWidget {
  const CenteredPane({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? AdaptiveLayout.contentMaxWidth,
        ),
        child: child,
      ),
    );
  }
}
