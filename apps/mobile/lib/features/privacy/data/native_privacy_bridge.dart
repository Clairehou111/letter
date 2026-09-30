import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps the native app-switcher cover in sync with the local preference.
///
/// iOS can capture its app-switcher snapshot before Flutter paints another
/// frame, so the cover itself must also be installed by native lifecycle code.
abstract final class NativePrivacyBridge {
  static const MethodChannel _channel = MethodChannel(
    'app.letterwithin/privacy',
  );

  static Future<void> setScreenCoverEnabled(bool enabled) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      // Native privacy protection strengthens the Flutter cover but must
      // never hold the local-data gate closed if an embedder is missing or
      // its platform channel does not answer during startup.
      await _channel
          .invokeMethod<void>('setScreenCoverEnabled', enabled)
          .timeout(const Duration(seconds: 1));
    } on MissingPluginException {
      // Flutter's in-app cover remains as a fallback on unsupported builds.
    } on PlatformException {
      // Retry naturally on the next setting change or app launch.
    } on TimeoutException {
      // The in-app cover remains active; retry on the next preference sync.
    }
  }
}
