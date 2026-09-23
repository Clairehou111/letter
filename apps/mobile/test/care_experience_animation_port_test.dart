import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/care/care_animation_port.dart';
import 'package:letter_mobile/experience/care/care_experience.dart';
import 'package:letter_mobile/experience/care/original_care_animation_port.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/patterns/domain/personal_pattern.dart';

final class _ProbeAnimationPort implements CareAnimationPort {
  CareMode? lastMode;

  @override
  Widget buildScene(
    BuildContext context, {
    required CareMode mode,
    required CareSceneMotionPreference motionPreference,
    required ValueChanged<CareSceneSignal> onSignal,
  }) {
    lastMode = mode;
    return ColoredBox(
      key: const Key('probe-animation-port'),
      color: Colors.black,
      child: Column(
        children: <Widget>[
          Text(mode.label),
          TextButton(
            key: const Key('probe-complete'),
            onPressed: () => onSignal(CareSceneSignal.sceneCompleted),
            child: const Text('Complete'),
          ),
          TextButton(
            key: const Key('probe-dismiss'),
            onPressed: () => onSignal(CareSceneSignal.sceneDismissed),
            child: const Text('Dismiss'),
          ),
          TextButton(
            key: const Key('probe-exit'),
            onPressed: () => onSignal(CareSceneSignal.requestedExit),
            child: const Text('Exit'),
          ),
          TextButton(
            key: const Key('probe-safety'),
            onPressed: () => onSignal(CareSceneSignal.requestedSafety),
            child: const Text('Safety'),
          ),
        ],
      ),
    );
  }
}

Future<void> _pumpExperience(
  WidgetTester tester,
  CareAnimationPort animationPort, {
  List<SupportActionPattern> memoryEvidence = const [],
  InMemoryCareMemoryRepository? repository,
  VoidCallback? onLeaveCare,
  VoidCallback? onRequestCheckIn,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: CareExperience(
        careMemoryRepository: repository ?? InMemoryCareMemoryRepository(),
        animationPort: animationPort,
        memoryEvidence: memoryEvidence,
        onLeaveCare: onLeaveCare,
        onRequestCheckIn: onRequestCheckIn,
        performanceConstrained: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

SupportActionPattern _memoryPattern({required int betterCount}) {
  const date = LocalDate(2026, 8, 14);
  return SupportActionPattern(
    id: 'warmth',
    actionId: 'care.warmth',
    actionLabel: 'Apply warmth',
    mode: CareMode.physical,
    count: betterCount,
    firstDate: date,
    lastDate: date,
    coveredDates: const [date],
    betterCount: betterCount,
    sameCount: 0,
    worseCount: 0,
    sources: const [],
    pinned: false,
    reflections: const [],
  );
}

Future<void> _openHeavy(WidgetTester tester) async {
  final heavy = find.text('I feel heavy');
  await tester.scrollUntilVisible(
    heavy,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  await tester.tap(heavy);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('CareExperience renders and completes its animation port', (
    tester,
  ) async {
    final port = _ProbeAnimationPort();
    await _pumpExperience(tester, port);

    await _openHeavy(tester);

    expect(port.lastMode, CareMode.heavy);
    expect(find.byKey(const Key('probe-animation-port')), findsOneWidget);

    await tester.tap(find.byKey(const Key('probe-complete')));
    await tester.pumpAndSettle();

    expect(find.text('You stayed with the moment.'), findsOneWidget);
  });

  testWidgets('skipping a completed scene returns to Care without saving', (
    tester,
  ) async {
    final repository = InMemoryCareMemoryRepository();
    var leaveCount = 0;
    await _pumpExperience(
      tester,
      _ProbeAnimationPort(),
      repository: repository,
      onLeaveCare: () => leaveCount += 1,
    );
    await _openHeavy(tester);
    await tester.tap(find.byKey(const Key('probe-complete')));
    await tester.pumpAndSettle();

    expect(find.text('Leave for now'), findsNothing);
    expect(find.text("I'll check back later"), findsNothing);
    await tester.tap(find.text('Skip — nothing needs saving'));
    await tester.pumpAndSettle();

    expect(leaveCount, 0);
    expect(await repository.getRecords(), isEmpty);
    expect(find.byKey(const ValueKey<String>('care-landing')), findsOneWidget);
    expect(find.text('You stayed with the moment.'), findsNothing);
  });

  testWidgets('recovery still offers check-in on Today instead', (
    tester,
  ) async {
    var requestCount = 0;
    await _pumpExperience(
      tester,
      _ProbeAnimationPort(),
      onRequestCheckIn: () => requestCount += 1,
    );
    await _openHeavy(tester);
    await tester.tap(find.byKey(const Key('probe-exit')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check in on Today instead'));
    await tester.pumpAndSettle();

    expect(requestCount, 1);
    expect(find.byKey(const ValueKey<String>('care-landing')), findsOneWidget);
    expect(find.text('You stayed with the moment.'), findsNothing);
  });

  testWidgets('a requested exit remains a recoverable interruption', (
    tester,
  ) async {
    await _pumpExperience(tester, _ProbeAnimationPort());
    await _openHeavy(tester);

    await tester.tap(find.byKey(const Key('probe-exit')));
    await tester.pumpAndSettle();

    expect(find.text('You were in the middle of Heavy.'), findsOneWidget);
    expect(find.textContaining('Nothing was recorded'), findsOneWidget);
  });

  testWidgets('a scene safety request opens support without leaving scene', (
    tester,
  ) async {
    await _pumpExperience(tester, _ProbeAnimationPort());
    await _openHeavy(tester);

    await tester.tap(find.byKey(const Key('probe-safety')));
    await tester.pumpAndSettle();

    expect(find.text('You deserve support right now.'), findsOneWidget);
    Navigator.of(
      tester.element(find.text('You deserve support right now.')),
    ).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('probe-animation-port')), findsOneWidget);
  });

  testWidgets('Care landing hides one attempt and shows repeated help', (
    tester,
  ) async {
    await _pumpExperience(
      tester,
      _ProbeAnimationPort(),
      memoryEvidence: [_memoryPattern(betterCount: 1)],
    );
    expect(find.textContaining('recorded once'), findsNothing);
    expect(find.textContaining('helped once'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpExperience(
      tester,
      _ProbeAnimationPort(),
      memoryEvidence: [_memoryPattern(betterCount: 2)],
    );
    expect(find.textContaining('helped 2 times'), findsOneWidget);
  });

  testWidgets('the original scene back returns directly to Care landing', (
    tester,
  ) async {
    await _pumpExperience(tester, const OriginalCareAnimationPort());
    await _openHeavy(tester);

    await tester.tap(find.byKey(const Key('care-break-back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('care-landing')), findsOneWidget);
    expect(find.textContaining('You were in the middle of'), findsNothing);
  });

  testWidgets('the original native Heavy scene is mounted through the port', (
    tester,
  ) async {
    await _pumpExperience(tester, const OriginalCareAnimationPort());

    final heavy = find.text('I feel heavy');
    await tester.scrollUntilVisible(
      heavy,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(heavy);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('care-break-heavy')), findsOneWidget);
    expect(find.byKey(const Key('care-break-sound')), findsNothing);
  });

  testWidgets('the original guided breathing route remains available', (
    tester,
  ) async {
    await _pumpExperience(tester, const OriginalCareAnimationPort());

    final breathing = find.byKey(const Key('care-breathe-entry'));
    await tester.scrollUntilVisible(
      breathing,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(breathing),
      alignment: 0.45,
      duration: Duration.zero,
    );
    await tester.pump();
    await tester.tap(breathing);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Even breathing'), findsOneWidget);
    expect(find.byKey(const Key('breath-back')), findsOneWidget);
  });
}
