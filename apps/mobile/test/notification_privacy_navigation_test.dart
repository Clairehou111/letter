import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/app/letter_app.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/notifications/domain/local_notification_port.dart';
import 'package:letter_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:letter_mobile/features/onboarding/domain/onboarding_profile.dart';
import 'package:letter_mobile/features/onboarding/presentation/privacy_protection_screen.dart';
import 'package:letter_mobile/features/privacy/domain/privacy_preferences.dart';

import 'support/widget_test_pump.dart';

final class ExistingProfileRepository implements OnboardingRepository {
  OnboardingProfile? profile = OnboardingProfile(selectedGoals: {});

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

Future<void> pumpUntilTabSelected(
  WidgetTester tester,
  int selectedIndex,
) async {
  for (var index = 0; index < 50; index += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    final navigationBar = find.byType(NavigationBar);
    if (navigationBar.evaluate().isNotEmpty &&
        tester.widget<NavigationBar>(navigationBar).selectedIndex ==
            selectedIndex) {
      return;
    }
  }
  throw TestFailure('Timed out waiting for tab $selectedIndex.');
}

void main() {
  testWidgets('notification payloads open the intended Release 2.0 tab', (
    tester,
  ) async {
    final notifications = TapNotificationPort();
    await tester.pumpWidget(
      LetterApp(
        onboardingRepository: ExistingProfileRepository(),
        periodRepository: InMemoryPeriodRepository(),
        notificationPort: notifications,
      ),
    );
    // The loaded Today surface intentionally keeps a quiet ambient animation
    // alive, so advancing a bounded frame is the correct readiness contract.
    await pumpUntilFound(tester, find.byType(NavigationBar));

    final destinations = tester
        .widget<NavigationBar>(find.byType(NavigationBar))
        .destinations
        .cast<NavigationDestination>();
    for (final destination in destinations) {
      expect((destination.selectedIcon! as Icon).size, 20);
    }

    notifications.onTap?.call('letter:cycle-check-in');
    await tester.pump();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    notifications.onTap?.call('letter:comfort-window');
    await tester.pump();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
  });

  testWidgets(
    'notification dismisses Reports and Settings before showing target tab',
    (tester) async {
      final notifications = TapNotificationPort();
      await tester.pumpWidget(
        LetterApp(
          onboardingRepository: ExistingProfileRepository(),
          periodRepository: InMemoryPeriodRepository(),
          notificationPort: notifications,
        ),
      );
      await pumpUntilFound(tester, find.byType(NavigationBar));

      await tester.tap(find.byTooltip('Settings').first);
      await pumpUntilFound(tester, find.byTooltip('Back'));
      await tester.dragUntilVisible(
        find.text('Clinician reports'),
        find.byType(ListView).last,
        const Offset(0, -300),
      );
      await tester.tap(find.text('Clinician reports'));
      await pumpUntilFound(tester, find.widgetWithText(AppBar, 'Reports'));

      notifications.onTap?.call('letter:cycle-check-in');
      await pumpUntilTabSelected(tester, 1);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.widgetWithText(AppBar, 'Reports'), findsNothing);
      expect(find.text('Clinician reports'), findsNothing);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
    },
  );

  testWidgets(
    'notification dismisses a modal sheet before showing target tab',
    (tester) async {
      final notifications = TapNotificationPort();
      await tester.pumpWidget(
        LetterApp(
          onboardingRepository: ExistingProfileRepository(),
          periodRepository: InMemoryPeriodRepository(),
          notificationPort: notifications,
        ),
      );
      await pumpUntilFound(tester, find.byType(NavigationBar));

      unawaited(
        showModalBottomSheet<void>(
          context: tester.element(find.byType(NavigationBar)),
          builder: (_) => const Text('Open test sheet'),
        ),
      );
      await pumpUntilFound(tester, find.text('Open test sheet'));

      notifications.onTap?.call('letter:comfort-window');
      await pumpUntilTabSelected(tester, 2);

      expect(find.text('Open test sheet'), findsNothing);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
    },
  );

  testWidgets('notification respects a route PopScope that refuses dismissal', (
    tester,
  ) async {
    final notifications = TapNotificationPort();
    await tester.pumpWidget(
      LetterApp(
        onboardingRepository: ExistingProfileRepository(),
        periodRepository: InMemoryPeriodRepository(),
        notificationPort: notifications,
      ),
    );
    await pumpUntilFound(tester, find.byType(NavigationBar));

    unawaited(
      Navigator.of(tester.element(find.byType(NavigationBar))).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const PopScope(
            canPop: false,
            child: Scaffold(body: Text('Unsaved draft')),
          ),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Unsaved draft'));

    notifications.onTap?.call('letter:cycle-check-in');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Unsaved draft'), findsOneWidget);
    expect(
      tester
          .widget<NavigationBar>(
            find.byType(NavigationBar, skipOffstage: false),
          )
          .selectedIndex,
      0,
    );
  });

  testWidgets('Screen Cover stays above pushed routes and modal sheets', (
    tester,
  ) async {
    await tester.pumpWidget(
      LetterApp(
        onboardingRepository: ExistingProfileRepository(),
        periodRepository: InMemoryPeriodRepository(),
      ),
    );
    await pumpUntilFound(tester, find.byType(NavigationBar));

    await tester.tap(find.byTooltip('Settings').first);
    await pumpUntilFound(tester, find.byTooltip('Back'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const Key('privacy-cover')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await pumpUntilFound(tester, find.byType(NavigationBar));

    unawaited(
      showModalBottomSheet<void>(
        context: tester.element(find.byType(NavigationBar)),
        builder: (_) => const Text('Sensitive modal content'),
      ),
    );
    await pumpUntilFound(tester, find.text('Sensitive modal content'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const Key('privacy-cover')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const Key('privacy-cover')), findsNothing);
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
            profile: OnboardingProfile(selectedGoals: const {}),
            onProfileChanged: (_) async {},
            privacyPreferences: const PrivacyPreferences(),
            notificationAuthorization: NotificationAuthorization.granted,
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
