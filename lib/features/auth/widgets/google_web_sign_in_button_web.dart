import 'package:flutter/material.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart'
    show
        GSIButtonConfiguration,
        GSIButtonShape,
        GSIButtonSize,
        GSIButtonText,
        GSIButtonTheme;
import 'package:google_sign_in_web/web_only.dart' show renderButton;

/// Tombol "Masuk dengan Google" resmi Google Identity Services (web).
///
/// Ini jalur credential: klik tombol → GIS mengembalikan id_token langsung,
/// tanpa People API dan tanpa `signIn()` deprecated yang tidak pernah
/// menghasilkan idToken. Hasil credential dibaca lewat
/// `AuthService.accountChanges`.
class GoogleWebSignInButton extends StatelessWidget {
  const GoogleWebSignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: renderButton(
        configuration: GSIButtonConfiguration(
          theme: GSIButtonTheme.outline,
          size: GSIButtonSize.large,
          text: GSIButtonText.signinWith,
          shape: GSIButtonShape.rectangular,
          locale: 'id',
        ),
      ),
    );
  }
}
