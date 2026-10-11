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
    'comfort_window_reminder': preferences.comfortWindowReminderEnabled,
    'comfort_window_lead_days': preferences.comfortWindowReminderLeadDays,
    'comfort_window_invitation_dismissed':
        preferences.comfortWindowInvitationDismissed,
    'analytics_consent': _encodeConsent(preferences.analyticsConsent),
    'care_companion_name': preferences.careCompanionName,
  });

  static PrivacyPreferences decode(String encoded) {
    final value = jsonDecode(encoded);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Unsupported privacy preferences');
    }
    final version = value['version'];
    if (version != 1 &&
        version != 2 &&
        version != 3 &&
        version != 4 &&
        version != PrivacyPreferences.schemaVersion) {
      throw const FormatException('Unsupported privacy preferences');
    }
    final hasReminderTiming =
        version >= 4 && value.containsKey('comfort_window_lead_days');
    final lead = value['comfort_window_lead_days'];
    if ((hasReminderTiming || version == 5) &&
        (lead is! int || lead < 0 || lead > 2)) {
      throw const FormatException('Unsupported reminder timing');
    }
    return PrivacyPreferences(
      appLockEnabled: value['app_lock'] == true,
      screenCoverEnabled: (version >= 3)
          ? value['screen_cover'] != false
          : true,
      cycleCheckInEnabled: value['cycle_check_in'] != false,
      // A legacy default-on check-in is never consent for this new reminder.
      comfortWindowReminderEnabled:
          hasReminderTiming && value['comfort_window_reminder'] == true,
      comfortWindowReminderLeadDays: hasReminderTiming ? lead as int : 2,
      comfortWindowInvitationDismissed:
          hasReminderTiming &&
          value['comfort_window_invitation_dismissed'] == true,
      notificationPermissionRequested:
          value['notification_permission_requested'] == true,
      analyticsConsent: version == 1
          ? AnalyticsConsent.notSet
          : _decodeConsent(value['analytics_consent']),
      careCompanionName: version >= 4
          ? PrivacyPreferences.normalizeCareCompanionName(
              value['care_companion_name'] is String
                  ? value['care_companion_name'] as String
                  : null,
            )
          : null,
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
