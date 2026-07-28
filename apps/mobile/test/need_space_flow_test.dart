import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/presentation/need_space_boundary_card.dart';
import 'package:letter_mobile/features/care/presentation/need_space_flow.dart';
import 'package:letter_mobile/features/care/presentation/safe_cocoon_stage.dart';

const _syntheticBoundary = 'Synthetic request for two quiet hours.';

Future<void> pumpNeedSpace(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = false,
  VoidCallback? onReturnToGate,
  VoidCallback? onExitCare,
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
        child: NeedSpaceFlow(
          onReturnToGate: onReturnToGate ?? () {},
          onExitCare: onExitCare ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> closeCurtain(WidgetTester tester) async {
  final close = find.byKey(const Key('safe-cocoon-close'));
  await tester.ensureVisible(close);
  await tester.tap(close);
  await tester.pumpAndSettle();
}

Future<void> openBoundaryCard(WidgetTester tester) async {
  await closeCurtain(tester);
  final prepare = find.byKey(const Key('safe-cocoon-prepare-words'));
  await tester.ensureVisible(prepare);
  await tester.tap(prepare);
  await tester.pumpAndSettle();
}

Future<void> prepareSyntheticBoundary(WidgetTester tester) async {
  final duration = find.byKey(const Key('need-space-duration-2h'));
  await reveal(tester, duration);
  await tester.tap(duration);
  await tester.pump();
  final template = find.byKey(const Key('need-space-template-0'));
  await reveal(tester, template);
  await tester.tap(template);
  await tester.pump();
  final field = find.byKey(const Key('need-space-boundary-field'));
  await reveal(tester, field);
  await tester.enterText(field, _syntheticBoundary);
  await tester.pump();
}

String boundaryText(WidgetTester tester) {
  final field = find.byKey(const Key('need-space-boundary-field'));
  return tester
      .widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      )
      .controller
      .text;
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(
    tester.element(finder),
    alignment: 0.5,
    duration: Duration.zero,
  );
  await tester.pump();
}

void main() {
  testWidgets('one action closes the curtain without hiding persistent exits', (
    tester,
  ) async {
    await pumpNeedSpace(tester);

    expect(find.byType(SafeCocoonStage), findsOneWidget);
    expect(
      find.text(
        'Letter can quiet this screen. It cannot silence calls or other apps.',
      ),
      findsOneWidget,
    );

    await closeCurtain(tester);

    expect(
      find.text('The door is closed. You are allowed to be unavailable.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('safe-cocoon-prepare-words')), findsOneWidget);
    expect(find.byKey(const Key('safe-cocoon-nothing-now')), findsOneWidget);
    expect(find.byKey(const Key('need-space-back-to-care')), findsOneWidget);
    expect(find.byKey(const Key('need-space-exit-care')), findsOneWidget);
    expect(find.byKey(const Key('need-space-safety')), findsOneWidget);
  });

  testWidgets('boundary back returns to the already closed cocoon', (
    tester,
  ) async {
    await pumpNeedSpace(tester);
    await openBoundaryCard(tester);

    expect(find.byType(NeedSpaceBoundaryCard), findsOneWidget);
    await tester.tap(find.byKey(const Key('need-space-boundary-back')));
    await tester.pumpAndSettle();

    expect(find.byType(SafeCocoonStage), findsOneWidget);
    expect(
      find.text('The door is closed. You are allowed to be unavailable.'),
      findsOneWidget,
    );
    final closedControl = find.byKey(const Key('safe-cocoon-close'));
    expect(closedControl, findsOneWidget);
    expect(tester.widget<GestureDetector>(closedControl).onTap, isNull);
  });

  testWidgets('nothing-now reaches the finite handoff without boundary input', (
    tester,
  ) async {
    var returns = 0;
    var exits = 0;
    await pumpNeedSpace(
      tester,
      onReturnToGate: () => returns += 1,
      onExitCare: () => exits += 1,
    );
    await closeCurtain(tester);

    await tester.tap(find.byKey(const Key('safe-cocoon-nothing-now')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('need-space-handoff-content')), findsOneWidget);
    expect(find.text('You can leave without explaining.'), findsOneWidget);
    expect(find.byType(NeedSpaceBoundaryCard), findsNothing);

    await tester.tap(find.byKey(const Key('need-space-handoff-return')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('need-space-handoff-exit')));
    await tester.pump();
    expect(returns, 1);
    expect(exits, 1);
  });

  testWidgets('boundary finish clears text before the handoff', (tester) async {
    await pumpNeedSpace(tester);
    await openBoundaryCard(tester);
    await prepareSyntheticBoundary(tester);

    expect(boundaryText(tester), _syntheticBoundary);
    final continueButton = find.byKey(const Key('need-space-continue'));
    await reveal(tester, continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text(_syntheticBoundary), findsNothing);
    expect(find.byType(NeedSpaceBoundaryCard), findsNothing);
    expect(find.byKey(const Key('need-space-handoff-content')), findsOneWidget);
  });

  testWidgets('safety dismissal preserves text and safety leave clears it', (
    tester,
  ) async {
    var exits = 0;
    await pumpNeedSpace(tester, onExitCare: () => exits += 1);
    await openBoundaryCard(tester);
    await prepareSyntheticBoundary(tester);

    await tester.tap(find.byKey(const Key('need-space-safety')));
    await tester.pumpAndSettle();
    expect(find.text('Immediate safety comes first.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('return-to-care-scene')));
    await tester.pumpAndSettle();

    expect(boundaryText(tester), _syntheticBoundary);

    await tester.tap(find.byKey(const Key('need-space-safety')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leave-care-from-safety')));
    await tester.pump();

    expect(exits, 1);
    expect(boundaryText(tester), isEmpty);
  });

  testWidgets('top-level back and exit clear active boundary text', (
    tester,
  ) async {
    var returns = 0;
    var exits = 0;
    await pumpNeedSpace(
      tester,
      onReturnToGate: () => returns += 1,
      onExitCare: () => exits += 1,
    );
    await openBoundaryCard(tester);
    await prepareSyntheticBoundary(tester);

    final backToCare = find.byKey(const Key('need-space-back-to-care'));
    await reveal(tester, backToCare);
    await tester.tap(backToCare);
    await tester.pump();
    expect(returns, 1);
    expect(boundaryText(tester), isEmpty);

    await prepareSyntheticBoundary(tester);
    final exitCare = find.byKey(const Key('need-space-exit-care'));
    await reveal(tester, exitCare);
    await tester.tap(exitCare);
    await tester.pump();
    expect(exits, 1);
    expect(boundaryText(tester), isEmpty);
  });

  testWidgets('reconstruction starts open without prior user text', (
    tester,
  ) async {
    await pumpNeedSpace(tester);
    await openBoundaryCard(tester);
    await prepareSyntheticBoundary(tester);

    await pumpNeedSpace(tester);

    expect(find.byType(SafeCocoonStage), findsOneWidget);
    expect(find.byKey(const Key('safe-cocoon-close')), findsOneWidget);
    expect(find.text(_syntheticBoundary), findsNothing);
    expect(find.byType(NeedSpaceBoundaryCard), findsNothing);
  });

  testWidgets(
    'does not expose contact, send, share, or system-control actions',
    (tester) async {
      await pumpNeedSpace(tester);
      await openBoundaryCard(tester);

      for (final prohibited in [
        'Recipient',
        'Contact',
        'Send',
        'Share',
        'Focus',
        'Do Not Disturb',
        'Delivered',
      ]) {
        expect(find.textContaining(prohibited), findsNothing);
      }
      expect(find.byIcon(Icons.send), findsNothing);
      expect(find.byIcon(Icons.share), findsNothing);
    },
  );

  testWidgets(
    'reduced motion and 200 percent text fit a complete direct path',
    (tester) async {
      await pumpNeedSpace(
        tester,
        size: const Size(320, 700),
        textScale: 2,
        disableAnimations: true,
      );

      await closeCurtain(tester);
      final nothingNow = find.byKey(const Key('safe-cocoon-nothing-now'));
      await reveal(tester, nothingNow);
      await tester.tap(nothingNow);
      await tester.pump();

      expect(
        find.byKey(const Key('need-space-handoff-content')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('integrated handoff matches the visual baseline', (tester) async {
    await pumpNeedSpace(tester);
    await closeCurtain(tester);
    await tester.tap(find.byKey(const Key('safe-cocoon-nothing-now')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(NeedSpaceFlow),
      matchesGoldenFile('goldens/need_space_handoff_390x844.png'),
    );
  });
}
