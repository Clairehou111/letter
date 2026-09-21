import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/privacy_preferences.dart';
import '../domain/privacy_preferences_repository.dart';

final class SecurePrivacyPreferencesRepository
    implements PrivacyPreferencesRepository {
  SecurePrivacyPreferencesRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'letter.privacy.preferences';

  final FlutterSecureStorage _storage;

  @override
  Future<PrivacyPreferences> load() async {
    final encoded = await _storage.read(key: _storageKey);
    if (encoded == null) return const PrivacyPreferences();
    return PrivacyPreferencesCodec.decode(encoded);
  }

  @override
  Future<void> save(PrivacyPreferences preferences) {
    return _storage.write(
      key: _storageKey,
      value: PrivacyPreferencesCodec.encode(preferences),
    );
  }
}

abstract final class PrivacyPreferencesCodec {
  static String encode(PrivacyPreferences preferences) => jsonEncode({
    'version': PrivacyPreferences.schemaVersion,
    'app_lock': preferences.appLockEnabled,
    'screen_cover': preferences.screenCoverEnabled,
    'cycle_check_in': preferences.cycleCheckInEnabled,
    'notification_permission_requested':
        preferences.notificationPermissionRequested,
    'analytics_consent': _encodeConsent(preferences.analyticsConsent),
  });

  static PrivacyPreferences decode(String encoded) {
    final value = jsonDecode(encoded);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Unsupported privacy preferences');
    }
    final version = value['version'];
    if (version != 1 &&
        version != 2 &&
        version != PrivacyPreferences.schemaVersion) {
      throw const FormatException('Unsupported privacy preferences');
    }
    return PrivacyPreferences(
      appLockEnabled: value['app_lock'] == true,
      screenCoverEnabled: version == 3 ? value['screen_cover'] != false : true,
      cycleCheckInEnabled: value['cycle_check_in'] != false,
      notificationPermissionRequested:
          value['notification_permission_requested'] == true,
      analyticsConsent: version == 1
          ? AnalyticsConsent.notSet
          : _decodeConsent(value['analytics_consent']),
    );
  }

  static String _encodeConsent(AnalyticsConsent consent) {
    return switch (consent) {
      AnalyticsConsent.notSet => 'not_set',
      AnalyticsConsent.granted => 'granted',
      AnalyticsConsent.optedOut => 'opted_out',
    };
  }

  static AnalyticsConsent _decodeConsent(Object? value) {
    return switch (value) {
      'granted' => AnalyticsConsent.granted,
      'opted_out' => AnalyticsConsent.optedOut,
      'not_set' || null => AnalyticsConsent.notSet,
      _ => throw const FormatException('Unsupported analytics consent'),
    };
  }
}
