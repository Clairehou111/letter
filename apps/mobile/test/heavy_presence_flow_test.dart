import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/presentation/heavy_presence_flow.dart';

const _approvedLines = <String>[
  'You do not have to become okay all at once.',
  'Nothing needs to be solved from this minute.',
  'One small input was enough. You can stop here.',
];

Future<void> pumpHeavyPresence(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = false,
  VoidCallback? onReturnToGate,
  VoidCallback? onExitCare,
  Duration Function()? elapsedNow,
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
        child: HeavyPresenceFlow(
          onReturnToGate: onReturnToGate ?? () {},
          onExitCare: onExitCare ?? () {},
          elapsedNow: elapsedNow,
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> wakeLight(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('heavy-light')));
  await tester.pump();
}

Future<void> reachHandOff(WidgetTester tester) async {
  await wakeLight(tester);
  await tester.tap(find.byKey(const Key('heavy-stop-here')));
  await tester.pump();
}

String lightSemantics(WidgetTester tester) {
  final data = tester
      .getSemantics(find.byKey(const Key('heavy-light')))
      .getSemanticsData();
  return '${data.label}|${data.value}|${data.hint}';
}

int visibleApprovedLineCount() {
  return _approvedLines
      .map((line) => find.text(line).evaluate().length)
      .fold(0, (total, count) => total + count);
}

void expectMinimumTouchTarget(WidgetTester tester, String key) {
  final size = tester.getSize(find.byKey(Key(key)));
  expect(size.width, greaterThanOrEqualTo(44), reason: '$key width');
  expect(size.height, greaterThanOrEqualTo(44), reason: '$key height');
}

void main() {
  testWidgets('starts dim and one tap immediately changes light and meaning', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpHeavyPresence(tester);

    final dimSemantics = lightSemantics(tester);
    expect(visibleApprovedLineCount(), 0);
    expect(find.byKey(const Key('heavy-start-presence')), findsNothing);
    expect(find.byKey(const Key('heavy-safety')), findsOneWidget);

    await wakeLight(tester);

    expect(find.bySemanticsLabel('One light is awake'), findsOneWidget);
    expect(find.byKey(const Key('heavy-light')), findsNothing);
    expect(dimSemantics, contains('Wake one light'));
    expect(find.text(_approvedLines.first), findsOneWidget);
    expect(visibleApprovedLineCount(), 1);
    expect(find.byKey(const Key('heavy-start-presence')), findsOneWidget);
    expect(find.byKey(const Key('heavy-safety')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('shows the three approved lines one at a time and then stops', (
    tester,
  ) async {
    await pumpHeavyPresence(tester);
    await wakeLight(tester);

    expect(find.text(_approvedLines[0]), findsOneWidget);
    expect(visibleApprovedLineCount(), 1);

    await tester.tap(find.byKey(const Key('heavy-next-message')));
    await tester.pump();
    expect(find.text(_approvedLines[0]), findsNothing);
    expect(find.text(_approvedLines[1]), findsOneWidget);
    expect(visibleApprovedLineCount(), 1);

    await tester.tap(find.byKey(const Key('heavy-next-message')));
    await tester.pump();
    expect(find.text(_approvedLines[1]), findsNothing);
    expect(find.text(_approvedLines[2]), findsOneWidget);
    expect(visibleApprovedLineCount(), 1);
    expect(find.byKey(const Key('heavy-next-message')), findsNothing);
  });

  testWidgets('can stop after the first line without starting presence', (
    tester,
  ) async {
    await pumpHeavyPresence(tester);
    await wakeLight(tester);

    await tester.tap(find.byKey(const Key('heavy-stop-here')));
    await tester.pump();

    expect(find.text('Put the phone down for a moment.'), findsOneWidget);
    expect(find.byKey(const Key('heavy-presence-remaining')), findsNothing);
    expect(find.byKey(const Key('heavy-handoff-return')), findsOneWidget);
    expect(find.byKey(const Key('heavy-handoff-exit')), findsOneWidget);
    expect(find.byKey(const Key('heavy-safety')), findsOneWidget);
  });

  testWidgets('optional presence completes at exactly two minutes', (
    tester,
  ) async {
    var elapsed = Duration.zero;
    await pumpHeavyPresence(tester, elapsedNow: () => elapsed);
    await wakeLight(tester);

    await tester.tap(find.byKey(const Key('heavy-start-presence')));
    await tester.pump();

    expect(find.byKey(const Key('heavy-presence-remaining')), findsOneWidget);
    expect(find.byKey(const Key('heavy-end-early')), findsOneWidget);
    expect(find.byKey(const Key('heavy-safety')), findsOneWidget);

    elapsed = const Duration(minutes: 1, seconds: 59);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('heavy-presence-remaining')), findsOneWidget);
    expect(find.text('Put the phone down for a moment.'), findsNothing);

    elapsed = const Duration(minutes: 2);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('heavy-presence-remaining')), findsNothing);
    expect(find.text('Put the phone down for a moment.'), findsOneWidget);
    expect(find.byKey(const Key('heavy-handoff-return')), findsOneWidget);
    expect(find.byKey(const Key('heavy-handoff-exit')), findsOneWidget);
  });

  testWidgets('presence can end early at any time', (tester) async {
    await pumpHeavyPresence(tester);
    await wakeLight(tester);
    await tester.tap(find.byKey(const Key('heavy-start-presence')));
    await tester.pump(const Duration(seconds: 17));

    await tester.tap(find.byKey(const Key('heavy-end-early')));
    await tester.pump();

    expect(find.byKey(const Key('heavy-presence-remaining')), findsNothing);
    expect(find.text('Put the phone down for a moment.'), findsOneWidget);
    expect(find.byKey(const Key('heavy-safety')), findsOneWidget);
  });

  testWidgets('safety interrupts the flow and can return to the same state', (
    tester,
  ) async {
    var exits = 0;
    await pumpHeavyPresence(tester, onExitCare: () => exits += 1);
    await wakeLight(tester);
    await tester.tap(find.byKey(const Key('heavy-next-message')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('heavy-safety')));
    await tester.pumpAndSettle();

    expect(find.text('Immediate safety comes first.'), findsOneWidget);
    expect(
      find.textContaining('Letter cannot provide emergency help'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('return-to-care-scene')));
    await tester.pumpAndSettle();
    expect(find.text(_approvedLines[1]), findsOneWidget);
    expect(find.byKey(const Key('heavy-safety')), findsOneWidget);

    await tester.tap(find.byKey(const Key('heavy-safety')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leave-care-from-safety')));
    await tester.pump();
    expect(exits, 1);
  });

  testWidgets('presence counts only foreground time outside the safety sheet', (
    tester,
  ) async {
    var elapsed = Duration.zero;
    await pumpHeavyPresence(tester, elapsedNow: () => elapsed);
    await wakeLight(tester);
    await tester.tap(find.byKey(const Key('heavy-start-presence')));
    await tester.pump();

    elapsed = const Duration(seconds: 30);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('heavy-safety')));
    await tester.pumpAndSettle();

    elapsed = const Duration(minutes: 5);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Immediate safety comes first.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('return-to-care-scene')));
    await tester.pumpAndSettle();
    elapsed = const Duration(minutes: 6, seconds: 29);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('heavy-presence-remaining')), findsOneWidget);

    elapsed = const Duration(minutes: 6, seconds: 30);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Put the phone down for a moment.'), findsOneWidget);
  });

  testWidgets('persistent navigation controls call their callbacks', (
    tester,
  ) async {
    var returns = 0;
    var exits = 0;
    await pumpHeavyPresence(
      tester,
      onReturnToGate: () => returns += 1,
      onExitCare: () => exits += 1,
    );

    await tester.tap(find.byKey(const Key('heavy-back-to-care')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('heavy-exit-care')));
    await tester.pump();

    expect(returns, 1);
    expect(exits, 1);
  });

  testWidgets('hand-off controls return to Care or leave Care', (tester) async {
    var returns = 0;
    var exits = 0;
    await pumpHeavyPresence(
      tester,
      onReturnToGate: () => returns += 1,
      onExitCare: () => exits += 1,
    );
    await reachHandOff(tester);

    await tester.tap(find.byKey(const Key('heavy-handoff-return')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('heavy-handoff-exit')));
    await tester.pump();

    expect(returns, 1);
    expect(exits, 1);
  });

  testWidgets('reconstruction starts again from the dim scene', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpHeavyPresence(tester);
    final initialDimSemantics = lightSemantics(tester);
    await wakeLight(tester);
    expect(find.text(_approvedLines.first), findsOneWidget);

    await pumpHeavyPresence(tester);

    expect(lightSemantics(tester), initialDimSemantics);
    expect(visibleApprovedLineCount(), 0);
    expect(find.byKey(const Key('heavy-start-presence')), findsNothing);
    semantics.dispose();
  });

  testWidgets('does not fabricate personal memory or clinical progress', (
    tester,
  ) async {
    await pumpHeavyPresence(tester);
    await wakeLight(tester);

    for (final text in [
      'Care Kit',
      'My person',
      'Last time',
      'saved action',
      'future-self',
      'symptom',
      'severity',
      'improving',
    ]) {
      expect(find.textContaining(text), findsNothing);
    }
  });

  testWidgets('primary controls remain at least 44 logical pixels', (
    tester,
  ) async {
    await pumpHeavyPresence(tester);
    for (final key in [
      'heavy-light',
      'heavy-back-to-care',
      'heavy-exit-care',
      'heavy-safety',
    ]) {
      expectMinimumTouchTarget(tester, key);
    }

    await wakeLight(tester);
    for (final key in [
      'heavy-next-message',
      'heavy-start-presence',
      'heavy-stop-here',
    ]) {
      expectMinimumTouchTarget(tester, key);
    }

    await tester.tap(find.byKey(const Key('heavy-start-presence')));
    await tester.pump();
    expectMinimumTouchTarget(tester, 'heavy-end-early');

    await tester.tap(find.byKey(const Key('heavy-end-early')));
    await tester.pump();
    expectMinimumTouchTarget(tester, 'heavy-handoff-return');
    expectMinimumTouchTarget(tester, 'heavy-handoff-exit');
  });

  testWidgets('reduced motion and 200 percent text fit at 320 by 700', (
    tester,
  ) async {
    await pumpHeavyPresence(
      tester,
      size: const Size(320, 700),
      textScale: 2,
      disableAnimations: true,
    );
    expect(tester.takeException(), isNull);

    await wakeLight(tester);
    expect(find.text(_approvedLines.first), findsOneWidget);
    expect(tester.takeException(), isNull);

    final startPresence = find.byKey(const Key('heavy-start-presence'));
    await tester.scrollUntilVisible(
      startPresence,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byKey(const Key('heavy-presence-scroll')),
      const Offset(0, -100),
    );
    await tester.pump();
    expect(startPresence.hitTestable(), findsOneWidget);
    await tester.tap(startPresence);
    await tester.pump();
    expect(find.byKey(const Key('heavy-presence-remaining')), findsOneWidget);
    expect(find.byKey(const Key('heavy-safety')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('heavy-end-early')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('heavy-handoff-exit')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Put the phone down for a moment.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dim light matches the visual baseline', (tester) async {
    await pumpHeavyPresence(tester);

    await expectLater(
      find.byType(HeavyPresenceFlow),
      matchesGoldenFile('goldens/heavy_dim_390x844.png'),
    );
  });

  testWidgets('presence interval matches the visual baseline', (tester) async {
    var elapsed = const Duration(seconds: 30);
    await pumpHeavyPresence(tester, elapsedNow: () => elapsed);
    await wakeLight(tester);
    await tester.tap(find.byKey(const Key('heavy-start-presence')));
    await tester.pump();

    elapsed = const Duration(seconds: 60);
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(
      find.byType(HeavyPresenceFlow),
      matchesGoldenFile('goldens/heavy_presence_390x844.png'),
    );
  });
}
