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

Finder _tab(int index, {bool skipOffstage = true}) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.label == ['Today', 'Cycle', 'Care', 'Patterns'][index],
  skipOffstage: skipOffstage,
);

Finder get _recordAction => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.label == 'Record today or another date',
);

Future<void> pumpUntilTabSelected(
  WidgetTester tester,
  int selectedIndex,
) async {
  for (var index = 0; index < 50; index += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    final tab = _tab(selectedIndex);
    if (tab.evaluate().isNotEmpty &&
        tester.widget<Semantics>(tab).properties.selected == true) {
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
    await pumpUntilFound(tester, _tab(0));

    for (var index = 0; index < 4; index++) {
      final tab = _tab(index);
      expect(tab, findsOneWidget);
      expect(tester.widget<Semantics>(tab).properties.button, isTrue);
      expect(tester.widget<Semantics>(tab).properties.selected, index == 0);
      final icon = find.descendant(of: tab, matching: find.byType(Icon));
      expect(icon, findsOneWidget);
      expect(tester.getSize(icon).width, greaterThanOrEqualTo(20));
      expect(tester.getSize(icon).height, greaterThanOrEqualTo(20));
    }
    expect(_recordAction, findsOneWidget);
    expect(tester.widget<Semantics>(_recordAction).properties.button, isTrue);
    expect(tester.widget<Semantics>(_recordAction).properties.selected, isNull);

    notifications.onTap?.call('letter:cycle-check-in');
    await pumpUntilTabSelected(tester, 1);
    expect(tester.widget<Semantics>(_tab(1)).properties.selected, isTrue);

    notifications.onTap?.call('letter:comfort-window');
    await pumpUntilTabSelected(tester, 2);
    expect(tester.widget<Semantics>(_tab(2)).properties.selected, isTrue);
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
      await pumpUntilFound(tester, _tab(0));

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
      expect(tester.widget<Semantics>(_tab(1)).properties.selected, isTrue);
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
      await pumpUntilFound(tester, _tab(0));

      unawaited(
        showModalBottomSheet<void>(
          context: tester.element(_tab(0)),
          builder: (_) => const Text('Open test sheet'),
        ),
      );
      await pumpUntilFound(tester, find.text('Open test sheet'));

      notifications.onTap?.call('letter:comfort-window');
      await pumpUntilTabSelected(tester, 2);

      expect(find.text('Open test sheet'), findsNothing);
      expect(tester.widget<Semantics>(_tab(2)).properties.selected, isTrue);
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
    await pumpUntilFound(tester, _tab(0));

    unawaited(
      Navigator.of(tester.element(_tab(0))).push<void>(
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
          .widget<Semantics>(_tab(0, skipOffstage: false))
          .properties
          .selected,
      isTrue,
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
    await pumpUntilFound(tester, _tab(0));

    await tester.tap(find.byTooltip('Settings').first);
    await pumpUntilFound(tester, find.byTooltip('Back'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const Key('privacy-cover')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await pumpUntilFound(tester, _tab(0));

    unawaited(
      showModalBottomSheet<void>(
        context: tester.element(_tab(0)),
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
