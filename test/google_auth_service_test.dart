import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zest/features/auth/services/google_auth_service.dart';

const _webId = 'web.apps.googleusercontent.com';
const _iosId = 'ios.apps.googleusercontent.com';

void main() {
  group('AuthConfig.resolve', () {
    test('web → clientId pakai web client id, tanpa serverClientId', () {
      final cfg = AuthConfig.resolve(
        isWeb: true,
        platform: TargetPlatform.android,
        webId: _webId,
        iosId: _iosId,
      );
      expect(
        cfg.clientId,
        _webId,
        reason: 'GIS web menolak serverClientId dan butuh clientId',
      );
      expect(
        cfg.serverClientId,
        isNull,
        reason: 'google_sign_in_web: serverClientId tidak didukung',
      );
    });

    test('android → serverClientId pakai web client id, tanpa clientId', () {
      final cfg = AuthConfig.resolve(
        isWeb: false,
        platform: TargetPlatform.android,
        webId: _webId,
        iosId: _iosId,
      );
      expect(
        cfg.clientId,
        isNull,
        reason: 'clientId Android ditafsirkan native sebagai server id',
      );
      expect(
        cfg.serverClientId,
        _webId,
        reason: 'requestIdToken hanya valid untuk web client',
      );
    });

    test('iOS → clientId pakai ios client id', () {
      final cfg = AuthConfig.resolve(
        isWeb: false,
        platform: TargetPlatform.iOS,
        webId: _webId,
        iosId: _iosId,
      );
      expect(cfg.clientId, _iosId);
      expect(cfg.serverClientId, isNull);
    });

    test('macOS/desktop → serverClientId pakai web client id', () {
      final cfg = AuthConfig.resolve(
        isWeb: false,
        platform: TargetPlatform.macOS,
        webId: _webId,
        iosId: _iosId,
      );
      expect(cfg.clientId, isNull);
      expect(cfg.serverClientId, _webId);
    });
  });

  test('forPlatform meneruskan nilai .env dan mengosongkan string kosong', () {
    dotenv.loadFromString(
      envString:
          'GOOGLE_WEB_CLIENT_ID=\n'
          'GOOGLE_ANDROID_CLIENT_ID=\n'
          'GOOGLE_IOS_CLIENT_ID=\n',
    );
    final cfg = AuthConfig.forPlatform(
      isWeb: false,
      platform: TargetPlatform.android,
    );
    expect(cfg.clientId, isNull);
    expect(cfg.serverClientId, isNull, reason: 'nilai kosong → null');
  });
}
