import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/presentation/clearer_day_reflection_flow.dart';

const _record = ClearerDayCareRecordContext(
  recordId: 'synthetic-record-1',
  modeLabel: 'My mind would not stop',
  actionLabel: 'Brought it to one point',
  outcomeLabel: 'A little better',
  occurredLabel: 'July 24',
);

Future<void> pumpFlow(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = false,
  ClearerDayReflectionViewModel? existing,
  SaveClearerDayReflection? onSave,
  VoidCallback? onDiscard,
  VoidCallback? onDone,
  Future<void> Function()? onDelete,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: LetterTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: ClearerDayReflectionFlow(
          careRecord: _record,
          existingReflection: existing,
          onSave: onSave ?? (_) async {},
          onDiscard: onDiscard ?? () {},
          onDone: onDone ?? () {},
          onDelete: onDelete,
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

Future<void> reachReview(WidgetTester tester, {bool withAnswers = true}) async {
  if (withAnswers) {
    await tester.enterText(
      find.byKey(const Key('clearer-day-truth-field')),
      'The deadline still felt too close.',
    );
  }
  final first = find.byKey(const Key('clearer-day-question-1-continue'));
  await reveal(tester, first);
  await tester.tap(first);
  await tester.pump();

  if (withAnswers) {
    final need = find.byKey(const Key('clearer-day-need-boundaries'));
    await reveal(tester, need);
    await tester.tap(need);
  }
  final second = find.byKey(const Key('clearer-day-question-2-continue'));
  await reveal(tester, second);
  await tester.tap(second);
  await tester.pump();

  if (withAnswers) {
    await tester.enterText(
      find.byKey(const Key('clearer-day-helped-field')),
      'Closing the laptop for ten minutes helped.',
    );
    await tester.enterText(
      find.byKey(const Key('clearer-day-note-field')),
      'Pause before answering. You can choose tomorrow.',
    );
  }
  final review = find.byKey(const Key('clearer-day-review-draft'));
  await reveal(tester, review);
  await tester.tap(review);
  await tester.pump();
}

void main() {
  testWidgets(
    'starts only from supplied record context with exact first prompt',
    (tester) async {
      await pumpFlow(tester);

      expect(find.text('JULY 24'), findsOneWidget);
      expect(find.text('My mind would not stop'), findsOneWidget);
      expect(
        find.text('Brought it to one point  ·  A little better'),
        findsOneWidget,
      );
      expect(
        find.text('Does any part of this still feel true?'),
        findsOneWidget,
      );
      expect(find.textContaining('hormone'), findsNothing);
      expect(find.textContaining('cycle'), findsNothing);
      expect(find.textContaining('AI'), findsNothing);
    },
  );

  testWidgets('asks three optional questions with exact need choices', (
    tester,
  ) async {
    await pumpFlow(tester);
    await tester.tap(find.byKey(const Key('clearer-day-question-1-continue')));
    await tester.pump();

    expect(find.text('What did you need, if you know?'), findsOneWidget);
    for (final need in ClearerDayNeed.values) {
      expect(find.text(need.label), findsOneWidget);
    }

    final second = find.byKey(const Key('clearer-day-question-2-continue'));
    await reveal(tester, second);
    await tester.tap(second);
    await tester.pump();
    expect(find.text('What helped, even a little?'), findsOneWidget);
    expect(find.text('OPTIONAL · 3 OF 3'), findsOneWidget);
    expect(find.textContaining('4 of'), findsNothing);
  });

  testWidgets('all text inputs enforce private 280-character settings', (
    tester,
  ) async {
    await pumpFlow(tester);
    void expectPrivateField(Key key) {
      final field = tester.widget<TextField>(
        find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
      );
      expect(field.maxLength, clearerDayTextLimit);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
    }

    expectPrivateField(const Key('clearer-day-truth-field'));
    final first = find.byKey(const Key('clearer-day-question-1-continue'));
    await reveal(tester, first);
    await tester.tap(first);
    await tester.pump();
    final second = find.byKey(const Key('clearer-day-question-2-continue'));
    await reveal(tester, second);
    await tester.tap(second);
    await tester.pump();
    expectPrivateField(const Key('clearer-day-helped-field'));
    expectPrivateField(const Key('clearer-day-note-field'));
  });

  testWidgets('review separates authored content and save is explicit', (
    tester,
  ) async {
    ClearerDayReflectionDraft? saved;
    var done = 0;
    await pumpFlow(
      tester,
      onSave: (draft) async => saved = draft,
      onDone: () => done += 1,
    );
    await reachReview(tester);

    for (final heading in [
      'What happened',
      'What I needed',
      'What helped',
      'Next time',
    ]) {
      expect(find.text(heading.toUpperCase()), findsOneWidget);
    }
    expect(saved, isNull);

    final save = find.byKey(const Key('clearer-day-save'));
    await reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(saved?.need, ClearerDayNeed.boundaries);
    expect(saved?.stillFeelsTrue, 'The deadline still felt too close.');
    expect(
      saved?.futureSelfNote,
      'Pause before answering. You can choose tomorrow.',
    );
    expect(find.text('Your reply is saved.'), findsOneWidget);
    expect(find.byKey(const Key('clearer-day-discard')), findsNothing);
    expect(find.byKey(const Key('clearer-day-header-done')), findsOneWidget);
    expect(
      find.byKey(const Key('clearer-day-completion-done')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('clearer-day-header-done')));
    await tester.pump();
    expect(done, 1);
  });

  testWidgets('questions can be skipped and review shows no invented content', (
    tester,
  ) async {
    await pumpFlow(tester);
    await reachReview(tester, withAnswers: false);

    expect(find.text('Not added'), findsNWidgets(4));
    expect(find.textContaining('probably'), findsNothing);
    expect(find.textContaining('caused'), findsNothing);
  });

  testWidgets('discard clears draft and calls only discard', (tester) async {
    var discarded = 0;
    var saves = 0;
    await pumpFlow(
      tester,
      onDiscard: () => discarded += 1,
      onSave: (_) async => saves += 1,
    );
    await tester.enterText(
      find.byKey(const Key('clearer-day-truth-field')),
      'Synthetic unsaved text',
    );

    await tester.tap(find.byKey(const Key('clearer-day-discard')));
    await tester.pump();

    expect(discarded, 1);
    expect(saves, 0);
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('clearer-day-truth-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('save failure preserves review and shows generic error', (
    tester,
  ) async {
    await pumpFlow(
      tester,
      onSave: (_) async => throw StateError('private synthetic failure'),
    );
    await reachReview(tester);
    final save = find.byKey(const Key('clearer-day-save'));
    await reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(
      find.text('Letter could not save this reflection. Try again.'),
      findsOneWidget,
    );
    expect(find.text('The deadline still felt too close.'), findsOneWidget);
    expect(find.textContaining('private synthetic failure'), findsNothing);
  });

  testWidgets('existing reflection opens in review and remains editable', (
    tester,
  ) async {
    ClearerDayReflectionDraft? saved;
    await pumpFlow(
      tester,
      existing: const ClearerDayReflectionViewModel(
        reflectionId: 'synthetic-reflection-1',
        stillFeelsTrue: 'The pressure felt real.',
        need: ClearerDayNeed.autonomy,
        whatHelped: 'Stepping outside helped.',
        futureSelfNote: 'Take five minutes before deciding.',
      ),
      onSave: (draft) async => saved = draft,
    );

    expect(find.text('Review your changes.'), findsOneWidget);
    expect(find.text('Autonomy'), findsOneWidget);
    await tester.tap(find.byKey(const Key('clearer-day-edit')));
    await tester.pump();
    expect(find.text('Does any part of this still feel true?'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('clearer-day-truth-field')),
      'The pressure eased after lunch.',
    );
    await reachReview(tester, withAnswers: false);
    final save = find.byKey(const Key('clearer-day-save'));
    await reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saved?.stillFeelsTrue, 'The pressure eased after lunch.');
  });

  testWidgets('delete requires confirmation and invokes callback', (
    tester,
  ) async {
    var deletes = 0;
    var done = 0;
    await pumpFlow(
      tester,
      existing: const ClearerDayReflectionViewModel(
        reflectionId: 'synthetic-reflection-1',
        stillFeelsTrue: 'Synthetic saved reflection.',
      ),
      onDelete: () async => deletes += 1,
      onDone: () => done += 1,
    );

    final delete = find.byKey(const Key('clearer-day-delete'));
    await reveal(tester, delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(deletes, 0);
    await tester.tap(find.byKey(const Key('clearer-day-confirm-delete')));
    await tester.pumpAndSettle();

    expect(deletes, 1);
    expect(find.text('Reflection deleted.'), findsOneWidget);
    expect(find.byKey(const Key('clearer-day-discard')), findsNothing);
    expect(find.byKey(const Key('clearer-day-header-done')), findsOneWidget);

    await tester.tap(find.byKey(const Key('clearer-day-completion-done')));
    await tester.pump();
    expect(done, 1);
  });

  testWidgets('delete failure preserves saved reflection', (tester) async {
    await pumpFlow(
      tester,
      existing: const ClearerDayReflectionViewModel(
        reflectionId: 'synthetic-reflection-1',
        stillFeelsTrue: 'Synthetic saved reflection.',
      ),
      onDelete: () async => throw StateError('private delete details'),
    );
    final delete = find.byKey(const Key('clearer-day-delete'));
    await reveal(tester, delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('clearer-day-confirm-delete')));
    await tester.pumpAndSettle();

    expect(find.text('Synthetic saved reflection.'), findsOneWidget);
    expect(
      find.text('Letter could not delete this reflection. Try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('private delete details'), findsNothing);
  });

  testWidgets('320px at 200 percent text completes without overflow', (
    tester,
  ) async {
    await pumpFlow(
      tester,
      size: const Size(320, 700),
      textScale: 2,
      disableAnimations: true,
    );
    expect(
      tester.getSize(find.byKey(const Key('clearer-day-header'))).height,
      88,
    );
    await reachReview(tester, withAnswers: false);
    final save = find.byKey(const Key('clearer-day-save'));
    await reveal(tester, save);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(save).height, greaterThanOrEqualTo(44));
  });

  testWidgets('question screen matches visual baseline', (tester) async {
    await pumpFlow(tester);
    await expectLater(
      find.byType(ClearerDayReflectionFlow),
      matchesGoldenFile('goldens/clearer_day_reflection_question_390x844.png'),
    );
  });

  testWidgets('review screen matches visual baseline', (tester) async {
    await pumpFlow(tester);
    await reachReview(tester);
    await expectLater(
      find.byType(ClearerDayReflectionFlow),
      matchesGoldenFile('goldens/clearer_day_reflection_review_390x844.png'),
    );
  });
}
