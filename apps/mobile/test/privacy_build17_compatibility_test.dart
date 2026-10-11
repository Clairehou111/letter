import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/privacy/data/secure_privacy_preferences_repository.dart';
import 'package:letter_mobile/features/privacy/domain/privacy_preferences.dart';

void main() {
  test(
    'Build17 v4 preserves companion and screen cover without granting new reminder consent',
    () {
      final preferences = PrivacyPreferencesCodec.decode(
        jsonEncode({
          'version': 4,
          'screen_cover': false,
          'care_companion_name': 'Miso',
          'cycle_check_in': true,
          'notification_permission_requested': true,
          'analytics_consent': 'opted_out',
        }),
      );
      expect(preferences.careCompanionName, 'Miso');
      expect(preferences.screenCoverEnabled, isFalse);
      expect(preferences.comfortWindowReminderEnabled, isFalse);
      expect(preferences.comfortWindowReminderLeadDays, 2);
      expect(
        PrivacyPreferencesCodec.decode(
          PrivacyPreferencesCodec.encode(preferences),
        ),
        preferences,
      );
      expect(
        jsonDecode(PrivacyPreferencesCodec.encode(preferences))['version'],
        5,
      );
    },
  );
  test(
    'RH v4 reminder and app lock consent remain explicit across schema 5',
    () {
      final preferences = PrivacyPreferencesCodec.decode(
        jsonEncode({
          'version': 4,
          'screen_cover': true,
          'app_lock': true,
          'comfort_window_reminder': true,
          'comfort_window_lead_days': 1,
          'comfort_window_invitation_dismissed': true,
          'analytics_consent': 'not_set',
        }),
      );
      expect(preferences.appLockEnabled, isTrue);
      expect(preferences.comfortWindowReminderEnabled, isTrue);
      expect(preferences.comfortWindowReminderLeadDays, 1);
      expect(preferences.careCompanionName, isNull);
      expect(
        PrivacyPreferencesCodec.decode(
          PrivacyPreferencesCodec.encode(preferences),
        ),
        preferences,
      );
    },
  );
  test(
    'schema 5 persists both histories and rejects malformed reminder timing',
    () {
      const preferences = PrivacyPreferences(
        careCompanionName: 'Pepper',
        appLockEnabled: true,
        comfortWindowReminderEnabled: true,
        comfortWindowReminderLeadDays: 0,
      );
      expect(
        PrivacyPreferencesCodec.decode(
          PrivacyPreferencesCodec.encode(preferences),
        ),
        preferences,
      );
      expect(
        () => PrivacyPreferencesCodec.decode(
          '{"version":5,"comfort_window_lead_days":9}',
        ),
        throwsFormatException,
      );
    },
  );
}
