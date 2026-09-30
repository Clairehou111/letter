import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:letter_mobile/features/analytics/data/posthog_analytics_service.dart';
import 'package:letter_mobile/features/analytics/domain/analytics_service.dart';
import 'package:letter_mobile/features/onboarding/domain/onboarding_profile.dart';
import 'package:letter_mobile/features/onboarding/presentation/privacy_protection_screen.dart';
import 'package:letter_mobile/features/notifications/domain/local_notification_port.dart';
import 'package:letter_mobile/features/privacy/data/secure_privacy_preferences_repository.dart';
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
      expect(client.config!.rageClickConfig.enabled, isFalse);
      expect(client.config!.surveys, isFalse);
      expect(client.config!.personProfiles, PostHogPersonProfiles.never);

      await service.track(
        AnalyticsPayload(
          event: const CareUsageBucketEvent(CareUsageBucket.twoToFive),
          timestamp: DateTime.utc(2026),
        ),
      );
      await service.disable();

      expect(client.captured.single.eventName, 'care_usage_30d');
      expect(client.captured.single.properties, {
        'event_name': 'care_usage_30d',
        'schema_version': 1,
        'usage_bucket': '2-5',
      });
      expect(client.shutdownOrder, ['disable', 'close', 'clear']);
      expect(client.clearedProjectToken, 'project-token');
    },
  );

  test('ordinary disposal preserves consented queued events', () async {
    final client = FakePosthogClient();
    final service = PosthogAnalyticsService(
      projectToken: 'project-token',
      host: 'https://example.test',
      client: client,
    );

    await service.enable();
    await service.dispose();

    expect(client.shutdownOrder, ['close']);
    expect(client.clearedProjectToken, isNull);
  });

  test('privacy preferences migrate version 1 to unset analytics consent', () {
    final preferences = PrivacyPreferencesCodec.decode('''
      {"version":1,"app_lock":true,"cycle_check_in":false,
       "notification_permission_requested":true}
    ''');

    expect(preferences.screenCoverEnabled, isTrue);
    expect(preferences.cycleCheckInEnabled, isFalse);
    expect(preferences.analyticsConsent, AnalyticsConsent.notSet);
  });

  test('privacy preferences encode and decode analytics consent', () {
    const preferences = PrivacyPreferences(
      screenCoverEnabled: false,
      analyticsConsent: AnalyticsConsent.granted,
      careCompanionName: 'Miso',
    );
    final decoded = PrivacyPreferencesCodec.decode(
      PrivacyPreferencesCodec.encode(preferences),
    );

    expect(decoded, preferences);
  });

  test('Care companion names normalize, enforce the rune limit, and clear', () {
    final maxName = List<String>.filled(24, '🐈').join();
    final tooLongName = List<String>.filled(25, '🐈').join();
    expect(PrivacyPreferences.normalizeCareCompanionName('  Miso  '), 'Miso');
    expect(PrivacyPreferences.normalizeCareCompanionName(maxName), maxName);
    expect(PrivacyPreferences.normalizeCareCompanionName(tooLongName), isNull);

    const named = PrivacyPreferences(careCompanionName: 'Miso');
    expect(named.copyWith().careCompanionName, 'Miso');
    expect(named.copyWith(careCompanionName: null).careCompanionName, isNull);
  });

  testWidgets('current release exposes only supported privacy controls', (
    tester,
  ) async {
    PrivacyPreferences? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyProtectionScreen(
          profile: OnboardingProfile(selectedGoals: const {}),
          onProfileChanged: (_) async {},
          privacyPreferences: const PrivacyPreferences(),
          notificationAuthorization: NotificationAuthorization.granted,
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
  final shutdownOrder = <String>[];
  String? clearedProjectToken;

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
  Future<void> enable() async {}

  @override
  Future<void> disable() async => shutdownOrder.add('disable');

  @override
  Future<void> close() async => shutdownOrder.add('close');

  @override
  Future<void> clearPendingEvents(String projectToken) async {
    shutdownOrder.add('clear');
    clearedProjectToken = projectToken;
  }
}
