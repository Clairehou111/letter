import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/presentation/racing_thoughts_flow.dart';

const _protectiveCopy = 'Your mind opened every tab at once. We only need one.';
const _unnamedCopy =
    'You do not have to name it for it to stop owning this minute.';
const _namedCopy =
    'It is set down for now. Letter will not bring it back tomorrow.';
const _nothingNowCopy = 'Nothing else is required from this screen.';
const _syntheticThought = 'Synthetic thought about an unfinished errand.';

Future<void> pumpRacingThoughts(
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
        child: RacingThoughtsFlow(
          onReturnToGate: onReturnToGate ?? () {},
          onExitCare: onExitCare ?? () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> converge(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('racing-convergence-surface')));
  await tester.pump();
}

Future<void> openNaming(WidgetTester tester) async {
  await converge(tester);
  await tester.tap(find.byKey(const Key('racing-name-one')));
  await tester.pump();
}

Future<void> enterSyntheticThought(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('racing-thought-field')),
    _syntheticThought,
  );
  await tester.pump();
}

void expectPersistentControls() {
  expect(find.byKey(const Key('racing-back-to-care')), findsOneWidget);
  expect(find.byKey(const Key('racing-exit-care')), findsOneWidget);
  expect(find.byKey(const Key('racing-safety')), findsOneWidget);
}

void expectMinimumTouchTarget(WidgetTester tester, String key) {
  final size = tester.getSize(find.byKey(Key(key)));
  expect(size.width, greaterThanOrEqualTo(44), reason: '$key width');
  expect(size.height, greaterThanOrEqualTo(44), reason: '$key height');
}

void main() {
  testWidgets(
    'starts scattered with actionable semantics and no approved line',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpRacingThoughts(tester);

      final surface = find.byKey(const Key('racing-convergence-surface'));
      final data = tester.getSemantics(surface).getSemanticsData();
      final description = '${data.label} ${data.value} ${data.hint}'
          .toLowerCase();

      expect(surface, findsOneWidget);
      expect(description, contains('gather racing thoughts'));
      expect(description, isNot(contains('gathered')));
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      for (final line in [
        _protectiveCopy,
        _unnamedCopy,
        _namedCopy,
        _nothingNowCopy,
      ]) {
        expect(find.text(line), findsNothing);
      }
      expectPersistentControls();
      semantics.dispose();
    },
  );

  testWidgets('one tap converges and reveals exact protective copy', (
    tester,
  ) async {
    await pumpRacingThoughts(tester);

    await converge(tester);

    expect(find.text(_protectiveCopy), findsOneWidget);
    expect(find.byKey(const Key('racing-name-one')), findsOneWidget);
    expect(find.byKey(const Key('racing-unnamed')), findsOneWidget);
    expect(find.byKey(const Key('racing-nothing-now')), findsOneWidget);
    expectPersistentControls();
  });

  testWidgets('reduced motion converges directly after one tap', (
    tester,
  ) async {
    await pumpRacingThoughts(tester, disableAnimations: true);

    await tester.tap(find.byKey(const Key('racing-convergence-surface')));
    await tester.pump();

    expect(find.text(_protectiveCopy), findsOneWidget);
    expect(find.byKey(const Key('racing-name-one')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers naming, unnamed, and nothing-now paths', (tester) async {
    await pumpRacingThoughts(tester);
    await converge(tester);

    expect(find.byKey(const Key('racing-name-one')), findsOneWidget);
    expect(find.byKey(const Key('racing-unnamed')), findsOneWidget);
    expect(find.byKey(const Key('racing-nothing-now')), findsOneWidget);

    await tester.tap(find.byKey(const Key('racing-unnamed')));
    await tester.pump();
    expect(find.text(_unnamedCopy), findsOneWidget);
    expect(find.byKey(const Key('racing-set-down-continue')), findsOneWidget);
    expectPersistentControls();

    await pumpRacingThoughts(tester);
    await converge(tester);
    await tester.tap(find.byKey(const Key('racing-nothing-now')));
    await tester.pump();
    expect(find.text(_nothingNowCopy), findsOneWidget);
    expect(find.byKey(const Key('racing-handoff-return')), findsOneWidget);
    expect(find.byKey(const Key('racing-handoff-exit')), findsOneWidget);
    expectPersistentControls();
  });

  testWidgets(
    'naming explains ephemerality and rejects whitespace-only input',
    (tester) async {
      await pumpRacingThoughts(tester);
      await openNaming(tester);

      expect(find.textContaining('only on this screen'), findsOneWidget);
      expect(find.textContaining('not save it'), findsOneWidget);
      expect(find.textContaining('bring it back tomorrow'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('racing-thought-field')),
        '   ',
      );
      await tester.tap(find.byKey(const Key('racing-set-down')));
      await tester.pump();

      expect(find.byKey(const Key('racing-operation-error')), findsOneWidget);
      expect(find.byKey(const Key('racing-thought-field')), findsOneWidget);
      expect(find.text(_namedCopy), findsNothing);
    },
  );

  testWidgets('thought entry is private, suggestion-free, and limited to 280', (
    tester,
  ) async {
    await pumpRacingThoughts(tester);
    await openNaming(tester);

    final field = find.byKey(const Key('racing-thought-field'));
    final editable = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(editable.autocorrect, isFalse);
    expect(editable.enableSuggestions, isFalse);

    await tester.enterText(field, List.filled(281, 'a').join());
    await tester.pump();

    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          )
          .controller
          .text,
      hasLength(280),
    );
    for (final prohibited in ['Recipient', 'Deadline', 'Priority', 'Send']) {
      expect(find.textContaining(prohibited), findsNothing);
    }
    expect(find.byIcon(Icons.share), findsNothing);
    expect(find.byIcon(Icons.file_upload_outlined), findsNothing);
  });

  testWidgets('set down clears synthetic text from widgets and semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpRacingThoughts(tester);
    await openNaming(tester);
    await enterSyntheticThought(tester);
    expect(find.semantics.byValue(_syntheticThought).evaluate(), hasLength(1));

    await tester.tap(find.byKey(const Key('racing-set-down')));
    await tester.pump();

    expect(find.text(_namedCopy), findsOneWidget);
    expect(find.text(_syntheticThought), findsNothing);
    expect(find.semantics.byValue(_syntheticThought).evaluate(), isEmpty);
    expect(find.byKey(const Key('racing-thought-field')), findsNothing);
    expectPersistentControls();
    semantics.dispose();
  });

  testWidgets('discard clears synthetic text and reaches finite hand-off', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpRacingThoughts(tester);
    await openNaming(tester);
    await enterSyntheticThought(tester);
    expect(find.semantics.byValue(_syntheticThought).evaluate(), hasLength(1));

    await tester.tap(find.byKey(const Key('racing-discard')));
    await tester.pump();

    expect(find.text(_syntheticThought), findsNothing);
    expect(find.semantics.byValue(_syntheticThought).evaluate(), isEmpty);
    expect(find.byKey(const Key('racing-thought-field')), findsNothing);
    expect(find.byKey(const Key('racing-handoff-return')), findsOneWidget);
    expect(find.byKey(const Key('racing-handoff-exit')), findsOneWidget);
    expect(
      find.text(
        'The words are gone from this screen. Nothing was marked solved.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('completed'), findsNothing);
    semantics.dispose();
  });

  testWidgets('safety can return to the same state or leave Care', (
    tester,
  ) async {
    var exits = 0;
    await pumpRacingThoughts(tester, onExitCare: () => exits += 1);
    await openNaming(tester);
    await enterSyntheticThought(tester);

    await tester.tap(find.byKey(const Key('racing-safety')));
    await tester.pumpAndSettle();
    expect(find.text('Immediate safety comes first.'), findsOneWidget);
    expect(
      find.textContaining('Letter cannot provide emergency help'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('return-to-care-scene')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('racing-thought-field')), findsOneWidget);
    expect(find.text(_syntheticThought), findsOneWidget);

    await tester.tap(find.byKey(const Key('racing-safety')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leave-care-from-safety')));
    await tester.pump();
    expect(exits, 1);
  });

  testWidgets('persistent and hand-off controls call their callbacks', (
    tester,
  ) async {
    var returns = 0;
    var exits = 0;
    await pumpRacingThoughts(
      tester,
      onReturnToGate: () => returns += 1,
      onExitCare: () => exits += 1,
    );

    await tester.tap(find.byKey(const Key('racing-back-to-care')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('racing-exit-care')));
    await tester.pump();
    expect(returns, 1);
    expect(exits, 1);

    await converge(tester);
    await tester.tap(find.byKey(const Key('racing-nothing-now')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('racing-handoff-return')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('racing-handoff-exit')));
    await tester.pump();
    expect(returns, 2);
    expect(exits, 2);
  });

  testWidgets('reconstruction starts empty and scattered', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpRacingThoughts(tester);
    await openNaming(tester);
    await enterSyntheticThought(tester);

    await pumpRacingThoughts(tester);

    final surface = find.byKey(const Key('racing-convergence-surface'));
    final data = tester.getSemantics(surface).getSemanticsData();
    expect(
      '${data.label} ${data.hint}'.toLowerCase(),
      contains('gather racing thoughts'),
    );
    expect(find.text(_syntheticThought), findsNothing);
    expect(find.byKey(const Key('racing-thought-field')), findsNothing);
    expect(find.text(_protectiveCopy), findsNothing);
    semantics.dispose();
  });

  testWidgets(
    'does not promise resurfacing or fabricate personal clinical data',
    (tester) async {
      await pumpRacingThoughts(tester);
      await openNaming(tester);

      for (final prohibited in [
        'Tomorrow Tray',
        'We will remind you',
        'We saved this',
        'Care Kit',
        'My person',
        'Last time',
        'future-self',
        'symptom',
        'severity',
        'diagnosis',
        'clinical report',
      ]) {
        expect(find.textContaining(prohibited), findsNothing);
      }

      await enterSyntheticThought(tester);
      await tester.tap(find.byKey(const Key('racing-set-down')));
      await tester.pump();
      expect(find.textContaining('bring it back'), findsOneWidget);
      expect(find.textContaining('remind'), findsNothing);
      expect(find.textContaining('saved'), findsNothing);
    },
  );

  testWidgets('primary controls remain at least 44 logical pixels', (
    tester,
  ) async {
    await pumpRacingThoughts(tester);
    for (final key in [
      'racing-convergence-surface',
      'racing-back-to-care',
      'racing-exit-care',
      'racing-safety',
    ]) {
      expectMinimumTouchTarget(tester, key);
    }

    final surface = find.byKey(const Key('racing-convergence-surface'));
    await tester.ensureVisible(surface);
    await tester.pump();
    await tester.tap(surface);
    await tester.pump();
    for (final key in [
      'racing-name-one',
      'racing-unnamed',
      'racing-nothing-now',
    ]) {
      expectMinimumTouchTarget(tester, key);
    }

    await tester.tap(find.byKey(const Key('racing-name-one')));
    await tester.pump();
    expectMinimumTouchTarget(tester, 'racing-set-down');
    expectMinimumTouchTarget(tester, 'racing-discard');

    await tester.tap(find.byKey(const Key('racing-discard')));
    await tester.pump();
    expectMinimumTouchTarget(tester, 'racing-handoff-return');
    expectMinimumTouchTarget(tester, 'racing-handoff-exit');
  });

  testWidgets('scattered state matches the visual baseline', (tester) async {
    await pumpRacingThoughts(tester);

    await expectLater(
      find.byType(RacingThoughtsFlow),
      matchesGoldenFile('goldens/racing_scattered_390x844.png'),
    );
  });

  testWidgets('converged state matches the visual baseline', (tester) async {
    await pumpRacingThoughts(tester);
    await converge(tester);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RacingThoughtsFlow),
      matchesGoldenFile('goldens/racing_converged_390x844.png'),
    );
  });

  testWidgets('fits 320 by 700 at 200 percent text through a complete path', (
    tester,
  ) async {
    await pumpRacingThoughts(
      tester,
      size: const Size(320, 700),
      textScale: 2,
      disableAnimations: true,
    );
    expect(tester.takeException(), isNull);

    final surface = find.byKey(const Key('racing-convergence-surface'));
    await tester.ensureVisible(surface);
    await tester.pump();
    await tester.tap(surface);
    await tester.pump();
    expect(find.text(_protectiveCopy), findsOneWidget);
    expect(tester.takeException(), isNull);

    final unnamed = find.byKey(const Key('racing-unnamed'));
    await tester.scrollUntilVisible(
      unnamed,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(unnamed);
    await tester.pump();
    expect(find.text(_unnamedCopy), findsOneWidget);
    expect(tester.takeException(), isNull);

    final continueButton = find.byKey(const Key('racing-set-down-continue'));
    await tester.scrollUntilVisible(
      continueButton,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(continueButton);
    await tester.pump();
    expect(find.byKey(const Key('racing-handoff-return')), findsOneWidget);
    expect(find.byKey(const Key('racing-handoff-exit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
