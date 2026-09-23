import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/app/letter_app.dart';
import 'package:letter_mobile/experience/letter_experience_shell.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:letter_mobile/features/onboarding/domain/onboarding_profile.dart';
import 'package:letter_mobile/features/onboarding/presentation/onboarding_flow.dart';

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
  PeriodRepository? periodRepository,
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
        periodRepository: periodRepository ?? InMemoryPeriodRepository(),
        now: () => DateTime(2026, 7, 28, 12),
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
  test('profile codec ignores legacy cloud preference fields', () {
    const legacyProfile = '''
      {"version":1,"cloud_tools":"ask_each_time","goals":[
        "understand_cycle","energy_and_sleep"
      ]}
    ''';
    final decoded = OnboardingProfileCodec.decode(legacyProfile);
    final encoded = OnboardingProfileCodec.encode(decoded);
    final roundTrip = OnboardingProfileCodec.decode(encoded);

    expect(encoded, contains('"version":1'));
    expect(encoded, isNot(contains('cloud_tools')));
    expect(decoded.selectedGoals, roundTrip.selectedGoals);
    expect(decoded.selectedGoals, {
      OnboardingGoal.understandCycle,
      OnboardingGoal.energyAndSleep,
    });
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

  testWidgets('completes first use with local records by default', (
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
    expect(repository.profile!.selectedGoals, {
      OnboardingGoal.understandCycle,
      OnboardingGoal.emotionalChanges,
    });
    expect(find.byType(LetterExperienceShell), findsOneWidget);
  });

  testWidgets('permits skipping all goals', (tester) async {
    final repository = FakeOnboardingRepository();
    await pumpLetter(tester, repository);

    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();

    expect(repository.profile!.selectedGoals, isEmpty);
  });

  testWidgets('privacy explanation is factual and preserves the step choice', (
    tester,
  ) async {
    final repository = FakeOnboardingRepository();
    await pumpLetter(tester, repository);

    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(
      find.text('Account details stay separate from your health records.'),
      findsOneWidget,
    );
    expect(find.textContaining('records stay on this device'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-see-privacy')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('privacy-explainer-sheet')), findsOneWidget);
    expect(find.text('How privacy works'), findsOneWidget);
    expect(find.text('Your account is separate'), findsOneWidget);
    expect(find.text('Your records stay here, encrypted'), findsOneWidget);
    expect(find.text('You choose when records move'), findsOneWidget);
    expect(
      find.textContaining('does not upload them to our servers'),
      findsOneWidget,
    );
    expect(find.textContaining('send them to AI services'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('privacy-explainer-close')),
      240,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('privacy-explainer-sheet')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('privacy-explainer-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('privacy-explainer-sheet')), findsNothing);
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
  });

  testWidgets('failed save stays in onboarding and can retry', (tester) async {
    final repository = FakeOnboardingRepository()..failSave = true;
    await pumpLetter(tester, repository);
    await reachGoalsStep(tester);

    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-save-error')), findsOneWidget);
    expect(find.byType(LetterExperienceShell), findsNothing);
    expect(repository.profile, isNull);

    repository.failSave = false;
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(LetterExperienceShell), findsOneWidget);
  });

  testWidgets('load failure is explicit and retryable', (tester) async {
    final repository = FakeOnboardingRepository()..failNextLoad = true;
    await pumpLetter(tester, repository);

    expect(
      find.text('Letter Within could not open secure storage.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('retry-onboarding-load')));
    await tester.pumpAndSettle();
    expect(find.text("Read your body's letter."), findsOneWidget);
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
    await tester.scrollUntilVisible(
      find.byKey(const Key('onboarding-see-privacy')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('onboarding-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const Key('onboarding-see-privacy')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('privacy-explainer-sheet')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('privacy-explainer-close')),
      240,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('privacy-explainer-sheet')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('privacy-explainer-close')));
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

  testWidgets('privacy explanation matches the visual baseline', (
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
    await tester.tap(find.byKey(const Key('onboarding-see-privacy')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/onboarding_privacy_explainer_390x844.png'),
    );
  });
}
