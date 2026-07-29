import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/presentation/physical_pain_flow.dart';

Future<void> pumpPhysicalPain(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = false,
  VoidCallback? onReturnToGate,
  VoidCallback? onExitCare,
  ValueChanged<PhysicalPainAction>? onActionCompleted,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: LetterTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: PhysicalPainFlow(
          onReturnToGate: onReturnToGate ?? () {},
          onExitCare: onExitCare ?? () {},
          onActionCompleted: onActionCompleted,
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(
    tester.element(finder),
    alignment: 0.5,
    duration: Duration.zero,
  );
  await tester.pump();
}

Future<void> selectPath(WidgetTester tester, String id) async {
  final choice = find.byKey(Key('physical-path-$id'));
  await reveal(tester, choice);
  await tester.tap(choice);
  await tester.pump();
}

Future<void> reachPractical(WidgetTester tester, String id) async {
  await selectPath(tester, id);
  final auto = find.byKey(const Key('physical-auto-complete'));
  await reveal(tester, auto);
  await tester.tap(auto);
  await tester.pump();
}

void expectPersistentControls() {
  expect(find.byKey(const Key('physical-back-to-care')), findsOneWidget);
  expect(find.byKey(const Key('physical-exit-care')), findsOneWidget);
  expect(find.byKey(const Key('physical-safety')), findsOneWidget);
}

void expectMinimumTouchTarget(WidgetTester tester, String key) {
  final size = tester.getSize(find.byKey(Key(key)));
  expect(size.width, greaterThanOrEqualTo(44), reason: '$key width');
  expect(size.height, greaterThanOrEqualTo(44), reason: '$key height');
}

void main() {
  const paths = {
    'cramps': 'Cramps or back pain',
    'headache': 'Headache or migraine',
    'nausea': 'Nausea or bloating',
    'body': 'Breast, muscle, or joint discomfort',
    'depleted': 'Completely drained',
  };

  testWidgets('starts with all five optional paths and persistent boundaries', (
    tester,
  ) async {
    await pumpPhysicalPain(tester);

    for (final entry in paths.entries) {
      expect(find.byKey(Key('physical-path-${entry.key}')), findsOneWidget);
      expect(find.text(entry.value), findsOneWidget);
    }
    expect(find.text('This is new, unusual, or severe'), findsOneWidget);
    expect(find.textContaining('pain rating or health record'), findsOneWidget);
    expectPersistentControls();
  });

  for (final entry in paths.entries) {
    testWidgets('${entry.key} gives useful feedback after one selection', (
      tester,
    ) async {
      await pumpPhysicalPain(tester);
      await selectPath(tester, entry.key);

      expect(find.byKey(Key('physical-comfort-${entry.key}')), findsOneWidget);
      expect(
        find.byKey(Key('physical-comfort-surface-${entry.key}')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('physical-auto-complete')), findsOneWidget);
      expectPersistentControls();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('every path has a one-tap automatic completion alternative', (
    tester,
  ) async {
    for (final id in paths.keys) {
      await pumpPhysicalPain(tester);
      await reachPractical(tester, id);

      expect(find.byKey(Key('physical-practical-$id')), findsOneWidget);
      expect(find.textContaining('already familiar'), findsOneWidget);
      expect(find.textContaining('not assessing or treating'), findsOneWidget);
      expectPersistentControls();
    }
  });

  testWidgets('gesture can complete a non-headache scene without repetition', (
    tester,
  ) async {
    await pumpPhysicalPain(tester);
    await selectPath(tester, 'cramps');

    await tester.drag(
      find.byKey(const Key('physical-comfort-surface-cramps')),
      const Offset(120, 0),
    );
    await tester.pump();

    expect(find.byKey(const Key('physical-practical-cramps')), findsOneWidget);
  });

  testWidgets(
    'headache is explicitly dark and still with no gesture handlers',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPhysicalPain(tester);
      await selectPath(tester, 'headache');

      expect(find.text('The screen is dark and still.'), findsOneWidget);
      expect(
        find.textContaining('No sound, haptics, flashing, pulsing'),
        findsOneWidget,
      );
      final surface = tester.widget<GestureDetector>(
        find.byKey(const Key('physical-comfort-surface-headache')),
      );
      expect(surface.onPanUpdate, isNull);
      expect(surface.onPanEnd, isNull);

      final semanticsData = tester
          .getSemantics(
            find.byKey(const Key('physical-comfort-surface-headache')),
          )
          .getSemanticsData();
      expect(semanticsData.label, contains('dark still field'));
      expect(semanticsData.label, contains('without animation'));
      semantics.dispose();
    },
  );

  testWidgets('practical actions emit only stable id and label on completion', (
    tester,
  ) async {
    final completed = <PhysicalPainAction>[];
    await pumpPhysicalPain(tester, onActionCompleted: completed.add);

    await reachPractical(tester, 'cramps');
    expect(completed, isEmpty);
    await tester.tap(
      find.byKey(const Key('physical-action-cramps_familiar_warmth')),
    );
    await tester.pump();

    expect(completed, hasLength(1));
    expect(completed.single.actionId, 'cramps_familiar_warmth');
    expect(completed.single.actionLabel, 'Get familiar warmth');
    expect(find.byKey(const Key('physical-handoff')), findsOneWidget);
  });

  testWidgets('entry, selection, scene, and no-action emit no completion', (
    tester,
  ) async {
    final completed = <PhysicalPainAction>[];
    await pumpPhysicalPain(tester, onActionCompleted: completed.add);
    await reachPractical(tester, 'depleted');

    expect(completed, isEmpty);
    await tester.tap(find.byKey(const Key('physical-no-action')));
    await tester.pump();

    expect(completed, isEmpty);
    expect(
      find.text('Letter has not created a symptom or pain record.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'back, leave, and handoff commands call their explicit callbacks',
    (tester) async {
      var returns = 0;
      var exits = 0;
      await pumpPhysicalPain(
        tester,
        onReturnToGate: () => returns += 1,
        onExitCare: () => exits += 1,
      );

      await tester.tap(find.byKey(const Key('physical-back-to-care')));
      await tester.tap(find.byKey(const Key('physical-exit-care')));
      expect(returns, 1);
      expect(exits, 1);

      await reachPractical(tester, 'body');
      await tester.tap(find.byKey(const Key('physical-no-action')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('physical-handoff-return')));
      await tester.tap(find.byKey(const Key('physical-handoff-exit')));
      expect(returns, 2);
      expect(exits, 2);
    },
  );

  testWidgets('medical boundary opens from every major state and can return', (
    tester,
  ) async {
    await pumpPhysicalPain(tester);

    for (final transition in <Future<void> Function()>[
      () async {},
      () => selectPath(tester, 'nausea'),
      () async {
        final auto = find.byKey(const Key('physical-auto-complete'));
        await reveal(tester, auto);
        await tester.tap(auto);
        await tester.pump();
      },
      () async {
        await tester.tap(find.byKey(const Key('physical-no-action')));
        await tester.pump();
      },
    ]) {
      await transition();
      await tester.tap(find.byKey(const Key('physical-safety')));
      await tester.pumpAndSettle();
      expect(
        find.text('This needs medical attention, not more interaction.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Book a medical assessment'),
        findsOneWidget,
      );
      await tester.dragUntilVisible(
        find.byKey(const Key('return-to-care-scene')),
        find.byType(ListView).last,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('return-to-care-scene')));
      await tester.pumpAndSettle();
      expectPersistentControls();
    }
  });

  testWidgets('medical boundary can leave Care directly', (tester) async {
    var exits = 0;
    await pumpPhysicalPain(tester, onExitCare: () => exits += 1);
    await selectPath(tester, 'cramps');

    await tester.tap(find.byKey(const Key('physical-safety')));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('leave-care-from-safety')),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leave-care-from-safety')));
    await tester.pump();

    expect(exits, 1);
  });

  testWidgets(
    'content contains no medication, diagnosis, rating, or timer UI',
    (tester) async {
      for (final id in paths.keys) {
        await pumpPhysicalPain(tester);
        await reachPractical(tester, id);
        for (final prohibited in [
          'Ibuprofen',
          'Acetaminophen',
          'Dose',
          'Supplement',
          'Diagnosed',
          'Severity',
          'Pain score',
          'Start timer',
        ]) {
          expect(find.textContaining(prohibited), findsNothing);
        }
      }
      expect(find.byType(Slider), findsNothing);
    },
  );

  testWidgets('Reduced Motion reaches an equivalent practical state', (
    tester,
  ) async {
    await pumpPhysicalPain(tester, disableAnimations: true);
    await reachPractical(tester, 'nausea');

    expect(find.byKey(const Key('physical-practical-nausea')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '320px at 200 percent supports a complete path without overflow',
    (tester) async {
      await pumpPhysicalPain(
        tester,
        size: const Size(320, 700),
        textScale: 2,
        disableAnimations: true,
      );
      await selectPath(tester, 'body');
      final auto = find.byKey(const Key('physical-auto-complete'));
      await reveal(tester, auto);
      await tester.tap(auto);
      await tester.pump();

      final action = find.byKey(
        const Key('physical-action-body_familiar_support'),
      );
      await reveal(tester, action);
      await tester.tap(action);
      await tester.pump();

      expect(find.byKey(const Key('physical-handoff')), findsOneWidget);
      expectPersistentControls();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('persistent and primary controls meet 44px touch targets', (
    tester,
  ) async {
    await pumpPhysicalPain(tester);
    for (final key in [
      'physical-back-to-care',
      'physical-exit-care',
      'physical-safety',
      'physical-path-cramps',
      'physical-path-headache',
      'physical-path-nausea',
      'physical-path-body',
      'physical-path-depleted',
    ]) {
      final finder = find.byKey(Key(key));
      await reveal(tester, finder);
      expectMinimumTouchTarget(tester, key);
    }
  });

  testWidgets('choice screen matches the visual baseline', (tester) async {
    await pumpPhysicalPain(tester);

    await expectLater(
      find.byType(PhysicalPainFlow),
      matchesGoldenFile('goldens/physical_pain_choices_390x844.png'),
    );
  });

  testWidgets('headache still screen matches the visual baseline', (
    tester,
  ) async {
    await pumpPhysicalPain(tester);
    await selectPath(tester, 'headache');
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PhysicalPainFlow),
      matchesGoldenFile('goldens/physical_pain_headache_390x844.png'),
    );
  });
}
