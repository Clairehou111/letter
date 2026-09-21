import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/app/letter_app.dart';
import 'package:letter_mobile/experience/letter_experience_shell.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/notifications/domain/local_notification_port.dart';
import 'package:letter_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:letter_mobile/features/onboarding/domain/onboarding_profile.dart';
import 'package:letter_mobile/features/onboarding/presentation/privacy_protection_screen.dart';
import 'package:letter_mobile/features/privacy/domain/device_authenticator.dart';
import 'package:letter_mobile/features/privacy/domain/privacy_preferences.dart';
import 'package:letter_mobile/features/privacy/domain/privacy_preferences_repository.dart';

final class ExistingProfileRepository implements OnboardingRepository {
  OnboardingProfile? profile = OnboardingProfile(
    cloudToolsPreference: CloudToolsPreference.off,
    selectedGoals: {},
  );

  @override
  Future<void> clear() async => profile = null;

  @override
  Future<OnboardingProfile?> load() async => profile;

  @override
  Future<void> save(OnboardingProfile profile) async {
    this.profile = profile;
  }
}

final class TapNotificationPort implements LocalNotificationPort {
  NotificationTapHandler? onTap;

  @override
  Future<NotificationAuthorization> authorizationStatus() async =>
      NotificationAuthorization.granted;

  @override
  Future<void> cancelCycleCheckIn() async {}

  @override
  Future<void> initialize(NotificationTapHandler onTap) async {
    this.onTap = onTap;
  }

  @override
  Future<NotificationAuthorization> requestAuthorization() async =>
      NotificationAuthorization.granted;

  @override
  Future<void> scheduleCycleCheckIn({
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  }) async {}
}

final class MutableAuthenticator implements DeviceAuthenticator {
  bool result;

  MutableAuthenticator(this.result);

  @override
  Future<bool> authenticate() async => result;

  @override
  Future<bool> canAuthenticate() async => true;
}

void main() {
  testWidgets('legacy app lock is disabled before notification navigation', (
    tester,
  ) async {
    final notifications = TapNotificationPort();
    final authenticator = MutableAuthenticator(false);
    final privacyRepository = InMemoryPrivacyPreferencesRepository(
      const PrivacyPreferences(appLockEnabled: true),
    );
    await tester.pumpWidget(
      LetterApp(
        onboardingRepository: ExistingProfileRepository(),
        periodRepository: InMemoryPeriodRepository(),
        privacyPreferencesRepository: privacyRepository,
        deviceAuthenticator: authenticator,
        notificationPort: notifications,
      ),
    );
    await tester.pumpAndSettle();

    notifications.onTap?.call('letter:cycle-check-in');
    await tester.pump();

    expect(find.byType(LetterExperienceShell), findsOneWidget);
    expect(find.byKey(const Key('privacy-cover')), findsNothing);
    expect(find.byType(LetterExperienceShell), findsOneWidget);
    expect((await privacyRepository.load()).appLockEnabled, isFalse);
  });

  testWidgets('new Cycle Check-in setting is on and fits compact large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 1000),
            textScaler: TextScaler.linear(2),
          ),
          child: PrivacyProtectionScreen(
            profile: OnboardingProfile(
              cloudToolsPreference: CloudToolsPreference.off,
              selectedGoals: const {},
            ),
            onProfileChanged: (_) async {},
            privacyPreferences: const PrivacyPreferences(),
            notificationAuthorization: NotificationAuthorization.granted,
            deviceAuthenticator: const AllowingDeviceAuthenticator(),
            onPrivacyPreferencesChanged: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('cycle-check-in-toggle')),
      find.byType(ListView),
      const Offset(0, -240),
    );

    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('cycle-check-in-toggle')),
    );
    expect(toggle.value, isTrue);
    expect(tester.takeException(), isNull);
  });
}
