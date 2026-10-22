import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ambient_particles.dart';
import '../../../core/widgets/card_surface.dart';
import '../../../core/widgets/motion.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../widgets/google_web_sign_in_button.dart';
import '../../users/services/user_session.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});

  final UserSession session;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _busy = false;
  String? _error;
  StreamSubscription<AppUser>? _accountChanges;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Web memakai tombol credential GIS; hasilnya diumumkan lewat stream
      // ini (bukan lewat future seperti signIn() native).
      _accountChanges = widget.session.auth.accountChanges.listen(
        _adoptCredential,
        onError: (Object e) {
          debugPrint('accountChanges error: $e');
          if (mounted) setState(() => _error = 'Gagal masuk. Coba lagi.');
        },
      );
    }
  }

  @override
  void dispose() {
    _accountChanges?.cancel();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();
    try {
      await widget.session.login();
    } on SignInCancelled {
      // User membatalkan dialog Google; bukan error.
    } catch (e) {
      debugPrint('Login gagal: $e');
      if (!mounted) return;
      setState(() {
        _error = _messageFor(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Credential Google sudah sampai (klik tombol GIS / One Tap) → tinggal
  /// hubungkan ke backend lewat jalur yang sama dengan login native.
  Future<void> _adoptCredential(AppUser user) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();
    try {
      await widget.session.adopt(user);
    } catch (e) {
      debugPrint('Login gagal: $e');
      if (!mounted) return;
      setState(() {
        _error = _messageFor(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Kontrol masuk sesuai platform: web = tombol credential GIS (saat loading
  /// hydrate, ganti dengan spinner supaya ada umpan balik), selain itu tombol
  /// custom lama.
  Widget _signInControl() {
    if (!kIsWeb) {
      return PressScale(
        onTap: _signIn,
        child: _GoogleButton(busy: _busy),
      );
    }
    if (_busy) return const _GoogleButton(busy: true);
    return const GoogleWebSignInButton();
  }

  String _messageFor(Object e) {
    if (e is LoginException) {
      switch (e.stage) {
        case 'auth':
          if (e.cause is PlatformException &&
              (e.cause as PlatformException).code == 'access_denied') {
            return 'Izin Google ditolak. Coba lagi.';
          }
          return 'Gagal masuk lewat Google. Periksa konfigurasi OAuth.';
        case 'profile':
          return 'Gagal menyiapkan akun di server. Coba lagi.';
        case 'hydrate':
        case 'sync':
          return 'Gagal menyinkronkan progres. Coba lagi.';
        default:
          return 'Gagal masuk. Coba lagi.';
      }
    }
    return 'Gagal masuk. Coba lagi.';
  }

  @override
  Widget build(BuildContext context) {
    if (AdaptiveLayout.isWide(context)) {
      return Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: AmbientParticles()),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AdaptiveLayout.contentMaxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 32,
                    ),
                    child: Row(
                      children: [
                        const Expanded(child: _LoginHero()),
                        const SizedBox(width: 56),
                        SizedBox(
                          width: 400,
                          child: _LoginCard(
                            signInControl: _signInControl(),
                            error: _error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientParticles()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  _BrandHeader(),
                  const Spacer(),
                  _FeatureRow(),
                  const SizedBox(height: 28),
                  _signInControl(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.belum,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Masuk untuk menyinkronkan progres ke akunmu.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel kiri halaman login lebar: brand besar + fitur (landing-style).
class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [_BrandHeader(), const SizedBox(height: 40), _FeatureRow()],
    );
  }
}

/// Kartu masuk untuk layout lebar: judul + kontrol masuk + status.
class _LoginCard extends StatelessWidget {
  const _LoginCard({required this.signInControl, required this.error});

  /// Kontrol masuk yang sudah dipilih platform ([LoginPage._signInControl]).
  final Widget signInControl;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(10),
              child: Image.asset('assets/icon/logo-zest.png'),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Masuk ke Zest',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Sinkronkan progres dan lanjutkan belajar di perangkat mana pun.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          signInControl,
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.belum),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Masuk untuk menyinkronkan progres ke akunmu.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(
        scale: 0.7 + 0.3 * v,
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  blurRadius: 36,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(10),
            child: Image.asset('assets/icon/logo-zest.png'),
          ),
          const SizedBox(height: 22),
          Text(
            'Zest',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'すっきり · Belajar bahasa Jepang,\ntiap hari.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.style_rounded, 'Flashcard SRS'),
      (Icons.videocam_rounded, 'Video terstruktur'),
      (Icons.local_fire_department_rounded, 'Streak & XP'),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in items) _FeaturePill(icon: item.$1, label: item.$2),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: busy
          ? const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.textMuted,
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _GoogleG(),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Masuk dengan Google',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1F1F1F),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.save();
    canvas.scale(scale);
    final blue = _decode(
      'M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z',
    );
    final green = _decode(
      'M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z',
    );
    final yellow = _decode(
      'M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z',
    );
    final red = _decode(
      'M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z',
    );
    canvas.drawPath(blue, Paint()..color = _blue);
    canvas.drawPath(green, Paint()..color = _green);
    canvas.drawPath(yellow, Paint()..color = _yellow);
    canvas.drawPath(red, Paint()..color = _red);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoogleGPainter oldDelegate) => false;

  static Path _decode(String d) {
    final path = Path();
    var i = 0;
    var cx = 0.0;
    var cy = 0.0;
    var c2x = 0.0;
    var c2y = 0.0;
    var prevWasCurve = false;

    double readNum() {
      while (i < d.length && (d[i] == ' ' || d[i] == ',')) {
        i++;
      }
      final start = i;
      if (i < d.length && (d[i] == '-' || d[i] == '+')) {
        i++;
      }
      var seenDot = false;
      while (i < d.length) {
        final c = d[i];
        if (c == '.') {
          if (seenDot) {
            break;
          }
          seenDot = true;
        } else if (c.codeUnitAt(0) < 48 || c.codeUnitAt(0) > 57) {
          break;
        }
        i++;
      }
      return double.parse(d.substring(start, i));
    }

    bool hasMoreCoords() {
      var j = i;
      while (j < d.length && (d[j] == ' ' || d[j] == ',')) {
        j++;
      }
      if (j >= d.length) {
        return false;
      }
      final c = d[j];
      return c == '-' ||
          c == '+' ||
          c == '.' ||
          (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57);
    }

    String? readCmd() {
      while (i < d.length && (d[i] == ' ' || d[i] == ',')) {
        i++;
      }
      if (i >= d.length) {
        return null;
      }
      final c = d[i];
      if (c == '-' ||
          c == '+' ||
          c == '.' ||
          (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57)) {
        return null;
      }
      i++;
      return c;
    }

    String? cmd = readCmd();
    while (cmd != null) {
      final base = cmd;
      final lower = base.toLowerCase();
      final rel = base == lower;
      if (lower == 'z') {
        path.close();
        prevWasCurve = false;
        cmd = readCmd();
        continue;
      }
      var eff = lower;
      while (true) {
        switch (eff) {
          case 'm':
            cx = rel ? cx + readNum() : readNum();
            cy = rel ? cy + readNum() : readNum();
            path.moveTo(cx, cy);
            prevWasCurve = false;
            eff = 'l';
          case 'l':
            cx = rel ? cx + readNum() : readNum();
            cy = rel ? cy + readNum() : readNum();
            path.lineTo(cx, cy);
            prevWasCurve = false;
          case 'h':
            cx = rel ? cx + readNum() : readNum();
            path.lineTo(cx, cy);
            prevWasCurve = false;
          case 'v':
            cy = rel ? cy + readNum() : readNum();
            path.lineTo(cx, cy);
            prevWasCurve = false;
          case 'c':
            final x1 = readNum();
            final y1 = readNum();
            final x2 = readNum();
            final y2 = readNum();
            final x = readNum();
            final y = readNum();
            final c1x = rel ? cx + x1 : x1;
            final c1y = rel ? cy + y1 : y1;
            c2x = rel ? cx + x2 : x2;
            c2y = rel ? cy + y2 : y2;
            final ex = rel ? cx + x : x;
            final ey = rel ? cy + y : y;
            path.cubicTo(c1x, c1y, c2x, c2y, ex, ey);
            cx = ex;
            cy = ey;
            prevWasCurve = true;
          case 's':
            final c1x = prevWasCurve ? cx * 2 - c2x : cx;
            final c1y = prevWasCurve ? cy * 2 - c2y : cy;
            final x2 = readNum();
            final y2 = readNum();
            final x = readNum();
            final y = readNum();
            c2x = rel ? c1x + x2 : x2;
            c2y = rel ? c1y + y2 : y2;
            final ex = rel ? cx + x : x;
            final ey = rel ? cy + y : y;
            path.cubicTo(c1x, c1y, c2x, c2y, ex, ey);
            cx = ex;
            cy = ey;
            prevWasCurve = true;
          case 'z':
            path.close();
            prevWasCurve = false;
          default:
            break;
        }
        if (!hasMoreCoords()) {
          break;
        }
      }
      cmd = readCmd();
    }
    return path;
  }
}
