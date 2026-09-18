import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/design_system/lovable/letter_kit.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/domain/cycle_prediction.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/patterns/domain/personal_pattern.dart';
import 'package:letter_mobile/features/preparation/data/in_memory_preparation_repository.dart';
import 'package:letter_mobile/features/preparation/domain/preparation_loop_state.dart';
import 'package:letter_mobile/features/preparation/domain/preparation_plan.dart';
import 'package:letter_mobile/features/preparation/domain/preparation_snapshot.dart';
import 'package:letter_mobile/features/preparation/presentation/next_window_card.dart';

final _snapshot = PreparationSnapshot(
  timing: const PreparationTimingEvidence(
    rangeStart: LocalDate(2026, 3, 16),
    rangeEnd: LocalDate(2026, 4, 4),
    periodRangeStart: LocalDate(2026, 3, 29),
    periodRangeEnd: LocalDate(2026, 4, 4),
    confidence: PredictionConfidence.medium,
    observedIntervalCount: 3,
    observedSpreadDays: 2,
  ),
  observation: const PreparationObservationEvidence(
    symptom: SymptomType.cramps,
    recordCount: 3,
    distinctCompletedCycles: 2,
    totalCompletedCycles: 3,
    supportingCycleStarts: [LocalDate(2026, 1, 1), LocalDate(2026, 1, 29)],
    sources: [
      PatternSourceReference(
        id: 'health-1',
        kind: PatternSourceKind.healthRecord,
        date: LocalDate(2026, 1, 10),
      ),
      PatternSourceReference(
        id: 'health-2',
        kind: PatternSourceKind.healthRecord,
        date: LocalDate(2026, 2, 8),
      ),
    ],
    strength: PreparationPatternStrength.early,
  ),
  care: const PreparationCareEvidence(
    actionId: 'heavy.presence',
    actionLabel: 'Quiet presence',
    mode: CareMode.heavy,
    recordCount: 4,
    betterCount: 2,
    sameCount: 1,
    worseCount: 1,
    pinned: true,
    lastRecordedDate: LocalDate(2026, 3, 20),
    sources: [],
  ),
  futureNote: const PreparationFutureNoteEvidence(
    text: 'Put the phone face down and make one small response.',
    mode: CareMode.heavy,
    careRecordId: 'care-1',
  ),
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1,
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
        ),
        child: child,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpCard(
  WidgetTester tester, {
  PreparationSnapshot? snapshot,
  VoidCallback? onOpenDetails,
  double textScale = 1,
}) => _pump(
  tester,
  Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        child: NextWindowCard(
          snapshot: snapshot ?? _snapshot,
          onOpenDetails: onOpenDetails ?? () {},
        ),
      ),
    ),
  ),
  textScale: textScale,
);

Future<void> _pumpDetails(
  WidgetTester tester, {
  PreparationSnapshot? snapshot,
  ValueChanged<CareMode>? onOpenCare,
  VoidCallback? onReviewRecords,
  PreparationLoopState? loopState,
  PreparationRepository? repository,
  double textScale = 1,
  Size size = const Size(390, 844),
}) => _pump(
  tester,
  YourNextWindowScreen(
    snapshot: snapshot ?? _snapshot,
    onOpenCare: onOpenCare ?? (_) {},
    onReviewRecords: onReviewRecords ?? () {},
    loopState: loopState,
    repository: repository,
  ),
  textScale: textScale,
  size: size,
);

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  final list = find.byType(ListView);
  for (var attempt = 0; attempt < 20 && finder.evaluate().isEmpty; attempt++) {
    await tester.drag(list, const Offset(0, -500));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<PreparationLoopState> _savedLoop(
  InMemoryPreparationRepository repository, {
  String? personalText,
}) async {
  final fingerprint = await PreparationFingerprint.forSelection(
    _snapshot,
    includeCare: true,
    includeNote: true,
  );
  final now = DateTime.utc(2026, 8, 7);
  final care = _snapshot.care!;
  await repository.savePlan(
    PreparationPlan(
      id: PreparationPlan.activeId,
      status: PreparationPlanStatus.current,
      evidenceFingerprint: fingerprint,
      sourceRecordIds: PreparationFingerprint.selectionSourceIds(
        _snapshot,
        includeCare: true,
        includeNote: true,
      ),
      includeCare: true,
      careActionId: care.actionId,
      careActionLabel: care.actionLabel,
      careMode: care.mode,
      betterCount: care.betterCount,
      sameCount: care.sameCount,
      worseCount: care.worseCount,
      noteText: _snapshot.futureNote!.text,
      personalText: personalText,
      createdAt: now,
      updatedAt: now,
    ),
  );
  return PreparationLoopState.load(
    snapshot: _snapshot,
    repository: repository,
    currentSourceIds: const {'care-1'},
  );
}

void main() {
  testWidgets(
    'renders Lovable compact card and makes the whole card tappable',
    (tester) async {
      var opened = 0;
      await _pumpCard(tester, onOpenDetails: () => opened += 1);

      expect(find.text('YOUR NEXT WINDOW · PLUS'), findsOneWidget);
      expect(find.byKey(const Key('next-window-headline')), findsOneWidget);
      expect(find.textContaining('You recorded cramps'), findsOneWidget);
      expect(
        find.text('You have marked Quiet presence Better twice.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('next-window-open-care')), findsNothing);

      await tester.tap(find.byKey(const Key('next-window-card')));
      await tester.pump();
      expect(opened, 1);
    },
  );

  testWidgets('detail page shows honest evidence and Care mode decision', (
    tester,
  ) async {
    CareMode? openedMode;
    await _pumpDetails(tester, onOpenCare: (mode) => openedMode = mode);

    expect(find.text('Your next window'), findsOneWidget);
    expect(find.text('ESTIMATED NEXT PERIOD'), findsOneWidget);
    expect(find.textContaining('Mar 29'), findsWidgets);
    await _scrollTo(
      tester,
      find.text('Early pattern based on 2 completed cycles.'),
    );
    expect(
      find.text('Early pattern based on 2 completed cycles.'),
      findsOneWidget,
    );
    expect(find.textContaining('missing evidence, not proof'), findsOneWidget);
    await _scrollTo(tester, find.text('You left yourself a note'));
    expect(find.text('You left yourself a note'), findsOneWidget);

    await _scrollTo(tester, find.byKey(const Key('next-window-open-care')));
    await tester.tap(find.byKey(const Key('next-window-open-care')));
    await tester.pump();
    expect(openedMode, CareMode.heavy);
  });

  testWidgets('review records is a separate detail-page action', (
    tester,
  ) async {
    var reviews = 0;
    await _pumpDetails(tester, onReviewRecords: () => reviews += 1);

    await _scrollTo(
      tester,
      find.byKey(const Key('next-window-review-records')),
    );
    await tester.tap(find.byKey(const Key('next-window-review-records')));
    await tester.pump();
    expect(reviews, 1);
  });

  testWidgets('null Care omits Care, note, and mode-specific CTA', (
    tester,
  ) async {
    final snapshot = PreparationSnapshot(
      timing: _snapshot.timing,
      observation: _snapshot.observation,
      care: null,
      futureNote: null,
    );
    await _pumpDetails(tester, snapshot: snapshot);

    await _scrollTo(
      tester,
      find.byKey(const Key('next-window-review-records')),
    );

    expect(find.text('WHAT YOU HAVE REACHED FOR BEFORE'), findsNothing);
    expect(find.text('YOUR NOTE TO YOURSELF'), findsNothing);
    expect(find.byKey(const Key('next-window-open-care')), findsNothing);
    expect(find.byKey(const Key('next-window-review-records')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timing and independent Care remain available without pattern', (
    tester,
  ) async {
    final snapshot = PreparationSnapshot(
      timing: _snapshot.timing,
      observation: null,
      care: _snapshot.care,
      futureNote: _snapshot.futureNote,
    );
    await _pumpCard(tester, snapshot: snapshot);

    expect(find.byKey(const Key('next-window-headline')), findsOneWidget);
    expect(
      find.text('You have marked Quiet presence Better twice.'),
      findsOneWidget,
    );

    await _pumpDetails(tester, snapshot: snapshot);
    expect(find.text('WHAT YOU RECORDED BEFORE'), findsNothing);
    await _scrollTo(
      tester,
      find.byKey(const Key('next-window-review-records')),
    );
    expect(find.byKey(const Key('next-window-open-care')), findsOneWidget);
    expect(find.byKey(const Key('next-window-review-records')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long note remains usable at 200 percent text', (tester) async {
    final snapshot = PreparationSnapshot(
      timing: _snapshot.timing,
      observation: _snapshot.observation,
      care: _snapshot.care,
      futureNote: PreparationFutureNoteEvidence(
        text: 'A careful note about making room. ' * 40,
        mode: CareMode.heavy,
        careRecordId: 'care-1',
      ),
    );
    await _pumpDetails(tester, snapshot: snapshot, textScale: 2);

    await _scrollTo(tester, find.text('You left yourself a note'));
    await tester.tap(find.text('You left yourself a note'));
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      find.byKey(const Key('next-window-review-records')),
    );
    expect(find.byKey(const Key('next-window-open-care')), findsOneWidget);
    expect(find.byKey(const Key('next-window-review-records')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit confirmation saves only selected existing evidence', (
    tester,
  ) async {
    final repository = InMemoryPreparationRepository();
    final loop = await PreparationLoopState.load(
      snapshot: _snapshot,
      repository: repository,
      currentSourceIds: const {'care-1'},
    );
    await _pumpDetails(tester, loopState: loop, repository: repository);

    await _scrollTo(tester, find.byKey(const Key('prep_primary')));
    await tester.tap(find.byKey(const Key('prep_primary')));
    await tester.pumpAndSettle();
    expect(find.text('Save this preparation'), findsOneWidget);

    await tester.tap(find.byKey(const Key('prep_confirm_care_row')));
    await tester.tap(find.byKey(const Key('prep_confirm_note_row')));
    await tester.pump();
    await _scrollTo(tester, find.byKey(const Key('prep_confirm_save')));
    final disabled = tester.widget<PrimaryButton>(
      find.byKey(const Key('prep_confirm_save')),
    );
    expect(disabled.onPressed, isNull);
    expect(
      find.text('Write a preparation or include at least one item to save.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('prep_confirm_care_row')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('prep_confirm_save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('prep_confirm_save')));
    await tester.pumpAndSettle();

    final saved = await repository.getActivePlan();
    expect(saved, isNotNull);
    expect(saved!.includeCare, isTrue);
    expect(saved.noteText, isNull);
    expect(find.text('Saved for next time'), findsOneWidget);
  });

  testWidgets('Not for me hides only the exact proposal and Undo restores it', (
    tester,
  ) async {
    final repository = InMemoryPreparationRepository();
    final loop = await PreparationLoopState.load(
      snapshot: _snapshot,
      repository: repository,
      currentSourceIds: const {'care-1'},
    );
    await _pumpDetails(tester, loopState: loop, repository: repository);

    await _scrollTo(tester, find.byKey(const Key('prep_not_for_me')));
    await tester.tap(find.byKey(const Key('prep_not_for_me')));
    await tester.pumpAndSettle();
    expect(find.text('This suggestion is hidden.'), findsOneWidget);
    expect(await repository.getDismissals(), hasLength(1));

    await tester.tap(find.byKey(const Key('prep_undo')));
    await tester.pumpAndSettle();
    expect(find.text('Remember this for next time?'), findsOneWidget);
    expect(
      find.text('Restored. Nothing was saved while it was hidden.'),
      findsOneWidget,
    );
    expect(await repository.getDismissals(), isEmpty);
  });

  testWidgets('confirmation remains usable at 320px and 200 percent text', (
    tester,
  ) async {
    final repository = InMemoryPreparationRepository();
    final loop = await PreparationLoopState.load(
      snapshot: _snapshot,
      repository: repository,
      currentSourceIds: const {'care-1'},
    );
    await _pumpDetails(
      tester,
      loopState: loop,
      repository: repository,
      size: const Size(320, 844),
      textScale: 2,
    );

    await _scrollTo(tester, find.byKey(const Key('prep_primary')));
    await tester.tap(find.byKey(const Key('prep_primary')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const Key('prep_confirm_save')));

    expect(find.byKey(const Key('prep_confirm_save')), findsOneWidget);
    expect(find.textContaining('Nothing here is a reminder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'saved preparation is user-editable and does not repeat history evidence',
    (tester) async {
      final repository = InMemoryPreparationRepository();
      final loop = await _savedLoop(
        repository,
        personalText: 'Put a heat pack beside the bed.',
      );
      await _pumpDetails(tester, loopState: loop, repository: repository);

      await _scrollTo(tester, find.byKey(const Key('prep_edit_open')));
      expect(find.text('Return with Care: I feel heavy'), findsOneWidget);
      expect(find.text('Your earlier note is included.'), findsOneWidget);
      expect(find.text('“Put a heat pack beside the bed.”'), findsOneWidget);
      await tester.tap(find.byKey(const Key('prep_edit_open')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('prep_personal_text')),
        'Keep tomorrow evening clear.',
      );
      await tester.ensureVisible(find.byKey(const Key('prep_confirm_save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('prep_confirm_save')));
      await tester.pumpAndSettle();

      expect(
        (await repository.getActivePlan())!.personalText,
        'Keep tomorrow evening clear.',
      );
      expect(find.text('“Keep tomorrow evening clear.”'), findsOneWidget);
    },
  );

  testWidgets('withdraw immediately restores Remember on the same page', (
    tester,
  ) async {
    final repository = InMemoryPreparationRepository();
    final loop = await _savedLoop(
      repository,
      personalText: 'Keep things quiet.',
    );
    await _pumpDetails(tester, loopState: loop, repository: repository);

    await _scrollTo(tester, find.byKey(const Key('prep_withdraw')));
    await tester.tap(find.byKey(const Key('prep_withdraw')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Withdraw'));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.byKey(const Key('prep_primary')));
    expect(find.byKey(const Key('prep_primary')), findsOneWidget);
    expect(await repository.getActivePlan(), isNull);
  });
}
