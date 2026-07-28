import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/app/letter_app.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:letter_mobile/features/onboarding/domain/onboarding_profile.dart';
import 'package:letter_mobile/features/onboarding/presentation/onboarding_flow.dart';
import 'package:letter_mobile/features/today/today_screen.dart';

final class FakeOnboardingRepository implements OnboardingRepository {
  FakeOnboardingRepository({this.profile});

  OnboardingProfile? profile;
  bool failNextLoad = false;
  bool failSave = false;
  bool failClear = false;
  Completer<OnboardingProfile?>? pendingLoad;
  int saveCount = 0;

  @override
  Future<OnboardingProfile?> load() async {
    if (pendingLoad case final pending?) {
      return pending.future;
    }
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('synthetic load failure');
    }
    return profile;
  }

  @override
  Future<void> save(OnboardingProfile value) async {
    if (failSave) {
      throw StateError('synthetic save failure');
    }
    saveCount += 1;
    profile = value;
  }

  @override
  Future<void> clear() async {
    if (failClear) {
      throw StateError('synthetic clear failure');
    }
    profile = null;
  }
}

Future<void> pumpLetter(
  WidgetTester tester,
  FakeOnboardingRepository repository, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: LetterApp(
        onboardingRepository: repository,
        periodRepository: InMemoryPeriodRepository(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reachGoalsStep(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('onboarding-continue')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('onboarding-continue')));
  await tester.pumpAndSettle();
}

void main() {
  test('profile codec is versioned and preserves synthetic choices', () {
    final profile = OnboardingProfile(
      cloudToolsPreference: CloudToolsPreference.askEachTime,
      selectedGoals: const {
        OnboardingGoal.understandCycle,
        OnboardingGoal.energyAndSleep,
      },
    );

    final encoded = OnboardingProfileCodec.encode(profile);
    final decoded = OnboardingProfileCodec.decode(encoded);

    expect(encoded, contains('"version":1'));
    expect(decoded.cloudToolsPreference, CloudToolsPreference.askEachTime);
    expect(decoded.selectedGoals, profile.selectedGoals);
  });

  testWidgets('does not flash onboarding while secure state is loading', (
    tester,
  ) async {
    final repository = FakeOnboardingRepository();
    repository.pendingLoad = Completer<OnboardingProfile?>();

    await tester.pumpWidget(LetterApp(onboardingRepository: repository));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text("Read your body's letter."), findsNothing);

    repository.pendingLoad!.complete(null);
    await tester.pumpAndSettle();

    expect(find.text("Read your body's letter."), findsOneWidget);
  });

  testWidgets('completes first use with cloud tools off by default', (
    tester,
  ) async {
    final repository = FakeOnboardingRepository();
    await pumpLetter(tester, repository);

    expect(find.text("Read your body's letter."), findsOneWidget);
    await reachGoalsStep(tester);
    await tester.tap(find.byKey(const Key('goal-understand_cycle')));
    await tester.tap(find.byKey(const Key('goal-emotional_changes')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();

    expect(repository.saveCount, 1);
    expect(repository.profile!.cloudToolsPreference, CloudToolsPreference.off);
    expect(repository.profile!.selectedGoals, {
      OnboardingGoal.understandCycle,
      OnboardingGoal.emotionalChanges,
    });
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  testWidgets('allows ask-each-time and permits skipping all goals', (
    tester,
  ) async {
    final repository = FakeOnboardingRepository();
    await pumpLetter(tester, repository);

    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cloud-tools-ask')));
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();

    expect(
      repository.profile!.cloudToolsPreference,
      CloudToolsPreference.askEachTime,
    );
    expect(repository.profile!.selectedGoals, isEmpty);
  });

  testWidgets('failed save stays in onboarding and can retry', (tester) async {
    final repository = FakeOnboardingRepository()..failSave = true;
    await pumpLetter(tester, repository);
    await reachGoalsStep(tester);

    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-save-error')), findsOneWidget);
    expect(find.byType(TodayScreen), findsNothing);
    expect(repository.profile, isNull);

    repository.failSave = false;
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  testWidgets('load failure is explicit and retryable', (tester) async {
    final repository = FakeOnboardingRepository()..failNextLoad = true;
    await pumpLetter(tester, repository);

    expect(find.text('Letter could not open secure storage.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('retry-onboarding-load')));
    await tester.pumpAndSettle();
    expect(find.text("Read your body's letter."), findsOneWidget);
  });

  testWidgets('returning user can update privacy mode and reset choices', (
    tester,
  ) async {
    final repository = FakeOnboardingRepository(
      profile: OnboardingProfile(
        cloudToolsPreference: CloudToolsPreference.askEachTime,
        selectedGoals: const {OnboardingGoal.energyAndSleep},
      ),
    );
    await pumpLetter(tester, repository);

    expect(find.text("Read your body's letter."), findsNothing);
    await tester.tap(find.byKey(const Key('navigation-you')));
    await tester.pumpAndSettle();
    expect(find.text('You decide what leaves your phone.'), findsOneWidget);
    expect(find.text('Energy and sleep'), findsOneWidget);

    await tester.tap(find.byKey(const Key('privacy-center-off')));
    await tester.pumpAndSettle();
    expect(repository.profile!.cloudToolsPreference, CloudToolsPreference.off);

    await tester.scrollUntilVisible(
      find.byKey(const Key('reset-onboarding')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reset-onboarding')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-reset-onboarding')));
    await tester.pumpAndSettle();

    expect(repository.profile, isNull);
    expect(find.text("Read your body's letter."), findsOneWidget);
  });

  testWidgets('returning user can open the Cycle destination', (tester) async {
    final repository = FakeOnboardingRepository(
      profile: OnboardingProfile(
        cloudToolsPreference: CloudToolsPreference.off,
        selectedGoals: const {},
      ),
    );
    await pumpLetter(tester, repository);

    await tester.tap(find.byKey(const Key('navigation-cycle')));
    await tester.pumpAndSettle();

    expect(find.text('Your cycle record'), findsOneWidget);
    expect(find.byKey(const Key('start-period-today')), findsOneWidget);
  });

  testWidgets('all steps fit at 320 width and 200 percent text scale', (
    tester,
  ) async {
    final repository = FakeOnboardingRepository();
    await pumpLetter(
      tester,
      repository,
      size: const Size(320, 700),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('privacy step matches the onboarding visual baseline', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: LetterTheme.light,
        home: OnboardingFlow(onComplete: (_) async {}),
      ),
    );
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(OnboardingFlow),
      matchesGoldenFile('goldens/onboarding_privacy_390x844.png'),
    );
  });
}
