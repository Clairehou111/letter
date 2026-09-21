import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:letter_mobile/features/analytics/data/posthog_analytics_service.dart';
import 'package:letter_mobile/features/analytics/domain/analytics_service.dart';
import 'package:letter_mobile/features/onboarding/domain/onboarding_profile.dart';
import 'package:letter_mobile/features/onboarding/presentation/privacy_protection_screen.dart';
import 'package:letter_mobile/features/notifications/domain/local_notification_port.dart';
import 'package:letter_mobile/features/privacy/data/secure_privacy_preferences_repository.dart';
import 'package:letter_mobile/features/privacy/domain/device_authenticator.dart';
import 'package:letter_mobile/features/privacy/domain/privacy_preferences.dart';

void main() {
  test(
    'PostHog adapter starts opted out and captures only after consent',
    () async {
      final client = FakePosthogClient();
      final service = PosthogAnalyticsService(
        projectToken: 'project-token',
        host: 'https://example.test',
        client: client,
      );

      await service.track(
        AnalyticsPayload(
          event: const OnboardingCompletedEvent(),
          timestamp: DateTime.utc(2026),
        ),
      );
      expect(client.captured, isEmpty);
      expect(client.configured, isFalse);

      await service.enable();
      expect(client.configured, isTrue);
      expect(client.config!.optOut, isTrue);
      expect(client.config!.captureApplicationLifecycleEvents, isFalse);
      expect(client.config!.sessionReplay, isFalse);
      expect(client.config!.preloadFeatureFlags, isFalse);
      expect(client.config!.sendFeatureFlagEvents, isFalse);
      expect(client.config!.capturePushNotificationSubscriptions, isFalse);
      expect(client.config!.capturePushNotificationOpened, isFalse);
      expect(client.config!.personProfiles, PostHogPersonProfiles.never);

      await service.track(
        AnalyticsPayload(
          event: const ExportCompletedEvent(),
          timestamp: DateTime.utc(2026),
        ),
      );
      await service.identifyAuthenticatedUser(
        '550e8400-e29b-41d4-a716-446655440000',
      );
      await service.identifyAuthenticatedUser('not-an-email-or-uuid');
      await service.clearAuthenticatedUser();

      expect(client.captured.single.eventName, 'export_completed');
      expect(client.identifiers, ['550e8400-e29b-41d4-a716-446655440000']);
      expect(client.resetCount, 1);
    },
  );

  test('privacy preferences migrate version 1 to unset analytics consent', () {
    final preferences = PrivacyPreferencesCodec.decode('''
      {"version":1,"app_lock":true,"cycle_check_in":false,
       "notification_permission_requested":true}
    ''');

    expect(preferences.appLockEnabled, isTrue);
    expect(preferences.screenCoverEnabled, isTrue);
    expect(preferences.cycleCheckInEnabled, isFalse);
    expect(preferences.analyticsConsent, AnalyticsConsent.notSet);
  });

  test('privacy preferences encode and decode analytics consent', () {
    const preferences = PrivacyPreferences(
      screenCoverEnabled: false,
      analyticsConsent: AnalyticsConsent.granted,
    );
    final decoded = PrivacyPreferencesCodec.decode(
      PrivacyPreferencesCodec.encode(preferences),
    );

    expect(decoded, preferences);
  });

  testWidgets('current release exposes only supported privacy controls', (
    tester,
  ) async {
    PrivacyPreferences? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyProtectionScreen(
          profile: OnboardingProfile(
            cloudToolsPreference: CloudToolsPreference.off,
            selectedGoals: const {},
          ),
          onProfileChanged: (_) async {},
          privacyPreferences: const PrivacyPreferences(),
          notificationAuthorization: NotificationAuthorization.granted,
          deviceAuthenticator: const AllowingDeviceAuthenticator(),
          onPrivacyPreferencesChanged: (value) async => saved = value,
        ),
      ),
    );

    expect(find.byKey(const Key('screen-cover-toggle')), findsOneWidget);
    expect(find.text('Screen cover'), findsOneWidget);
    final screenCoverToggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('screen-cover-toggle')),
    );
    expect(screenCoverToggle.value, isTrue);
    screenCoverToggle.onChanged!(false);
    await tester.pumpAndSettle();
    expect(saved?.screenCoverEnabled, isFalse);

    expect(find.byKey(const Key('analytics-consent-toggle')), findsNothing);
    expect(find.text('Optional product analytics'), findsNothing);
    expect(find.byKey(const Key('cycle-check-in-toggle')), findsOneWidget);
  });
}

final class FakePosthogClient implements PosthogClient {
  PostHogConfig? config;
  bool configured = false;
  final captured = <({String eventName, Map<String, Object> properties})>[];
  final identifiers = <String>[];
  int resetCount = 0;

  @override
  Future<void> setup(PostHogConfig config) async {
    this.config = config;
    configured = true;
  }

  @override
  Future<void> capture({
    required String eventName,
    required Map<String, Object> properties,
  }) async {
    captured.add((eventName: eventName, properties: properties));
  }

  @override
  Future<void> identify({required String userId}) async {
    identifiers.add(userId);
  }

  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}

  @override
  Future<void> reset() async {
    resetCount++;
  }
}
