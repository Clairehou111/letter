import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/insights/presentation/hormonal_spectrum_strip.dart';
import 'package:letter_mobile/features/patterns/domain/personal_pattern.dart';
import 'package:letter_mobile/features/patterns/presentation/personal_patterns_screen.dart';

const _symptom = ObservedSymptomPattern(
  id: 'symptom:cramps',
  symptom: SymptomType.cramps,
  count: 2,
  firstDate: LocalDate(2026, 7, 10),
  lastDate: LocalDate(2026, 7, 14),
  coveredDates: [LocalDate(2026, 7, 10), LocalDate(2026, 7, 14)],
  severityCounts: {SymptomSeverity.moderate: 1, SymptomSeverity.severe: 1},
  functionalImpactCounts: {},
  sources: [
    PatternSourceReference(
      id: 'health-one',
      kind: PatternSourceKind.healthRecord,
      date: LocalDate(2026, 7, 10),
    ),
    PatternSourceReference(
      id: 'health-two',
      kind: PatternSourceKind.healthRecord,
      date: LocalDate(2026, 7, 14),
    ),
  ],
  cycleDayObservations: [],
);

const _action = SupportActionPattern(
  id: 'action:physical:lower-input',
  actionId: 'lower-input',
  actionLabel: 'Lower the input',
  mode: CareMode.physical,
  count: 3,
  firstDate: LocalDate(2026, 7, 1),
  lastDate: LocalDate(2026, 7, 7),
  coveredDates: [
    LocalDate(2026, 7, 1),
    LocalDate(2026, 7, 4),
    LocalDate(2026, 7, 7),
  ],
  betterCount: 1,
  sameCount: 1,
  worseCount: 1,
  sources: [
    PatternSourceReference(
      id: 'care-one',
      kind: PatternSourceKind.careRecord,
      date: LocalDate(2026, 7, 1),
    ),
  ],
  pinned: true,
  reflections: [
    AuthoredReflectionEvidence(
      careRecordId: 'care-one',
      text: 'The room felt less demanding.',
    ),
  ],
);

Future<void> pumpPatterns(
  WidgetTester tester, {
  PersonalPatternAnalysis analysis = const PersonalPatternAnalysis(
    symptomPatterns: [_symptom],
    supportActions: [_action],
    selectedCareMode: null,
  ),
  ValueChanged<String>? onDismiss,
  ValueChanged<String>? onUnpin,
  ValueChanged<String>? onEdit,
  ValueChanged<String>? onDelete,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: LetterTheme.light,
      home: PersonalPatternsScreen(
        analysis: analysis,
        onDismissPattern: onDismiss,
        onUnpinAction: onUnpin,
        onEditSource: onEdit,
        onDeleteSource: onDelete,
      ),
    ),
  );
  await tester.pump();
}

Finder _verticalPatternsScrollable() {
  return find
      .descendant(
        of: find.byKey(const Key('personal-patterns-scroll')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      )
      .first;
}

Future<void> revealPatternContent(
  WidgetTester tester,
  Finder content, {
  double coarseDelta = -600,
}) async {
  final scrollable = _verticalPatternsScrollable();
  for (var index = 0; index < 6 && content.evaluate().isEmpty; index++) {
    await tester.drag(scrollable, Offset(0, coarseDelta), warnIfMissed: false);
    await tester.pump();
  }
  if (content.evaluate().isEmpty) return;
  await tester.scrollUntilVisible(content, 260, scrollable: scrollable);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows evidence dates, outcomes, and authored reflection', (
    tester,
  ) async {
    await pumpPatterns(tester);

    expect(find.text('Two views of the same records'), findsOneWidget);
    await revealPatternContent(tester, find.text('Nothing to show yet'));
    expect(find.text('Spectrum Log'), findsOneWidget);
    expect(find.byType(HormonalSpectrumStrip), findsOneWidget);
    expect(find.text('Nothing to show yet'), findsOneWidget);
    final evidenceToggle = find.byKey(
      const Key('symptom-evidence-toggle-symptom:cramps'),
    );
    await revealPatternContent(tester, evidenceToggle);
    expect(find.text('DATES YOU RECORDED IT'), findsNothing);
    await tester.tap(evidenceToggle);
    await tester.pumpAndSettle();
    expect(find.text('DATES YOU RECORDED IT'), findsOneWidget);
    expect(find.text('2026-07-10'), findsOneWidget);
    expect(find.text('2026-07-14'), findsOneWidget);
    final careToggle = find.byKey(const Key('personal-patterns-care-toggle'));
    await revealPatternContent(tester, careToggle);
    await tester.tap(careToggle);
    await tester.pumpAndSettle();
    await revealPatternContent(
      tester,
      find.text('Better in 1 of 3 check-backs'),
    );
    expect(find.text('Better in 1 of 3 check-backs'), findsOneWidget);
    expect(find.text('Same 1 · Worse 1'), findsOneWidget);
    expect(
      find.text('Your words: “The room felt less demanding.”'),
      findsOneWidget,
    );
    expect(find.textContaining('does not diagnose'), findsNothing);
    expect(find.textContaining('hormone'), findsNothing);
  });

  testWidgets('management menu emits source and action identifiers', (
    tester,
  ) async {
    final dismissed = <String>[];
    final unpinned = <String>[];
    final edited = <String>[];
    final deleted = <String>[];
    await pumpPatterns(
      tester,
      onDismiss: dismissed.add,
      onUnpin: unpinned.add,
      onEdit: edited.add,
      onDelete: deleted.add,
    );

    await revealPatternContent(
      tester,
      find.byKey(const Key('pattern-menu-symptom:cramps')),
    );
    await tester.tap(find.byKey(const Key('pattern-menu-symptom:cramps')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit source record'));
    expect(edited, ['health-one']);

    final careToggle = find.byKey(const Key('personal-patterns-care-toggle'));
    await revealPatternContent(tester, careToggle);
    await tester.tap(careToggle);
    await tester.pumpAndSettle();
    await revealPatternContent(
      tester,
      find.byKey(const Key('pattern-menu-action:physical:lower-input')),
    );
    await tester.tap(
      find.byKey(const Key('pattern-menu-action:physical:lower-input')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unpin this action'));
    expect(unpinned, ['care-one']);

    await revealPatternContent(
      tester,
      find.byKey(const Key('pattern-menu-symptom:cramps')),
      coarseDelta: 600,
    );
    await tester.tap(find.byKey(const Key('pattern-menu-symptom:cramps')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide this view'));
    expect(dismissed, ['symptom:cramps']);

    await revealPatternContent(
      tester,
      find.byKey(const Key('pattern-menu-action:physical:lower-input')),
    );
    await tester.tap(
      find.byKey(const Key('pattern-menu-action:physical:lower-input')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete source record'));
    expect(deleted, ['care-one']);
  });

  testWidgets('insufficient history is explicit and avoids diagnosis', (
    tester,
  ) async {
    await pumpPatterns(
      tester,
      analysis: PersonalPatternAnalysis(
        symptomPatterns: const [],
        supportActions: const [],
        selectedCareMode: null,
      ),
    );
    await revealPatternContent(
      tester,
      find.text('Not enough repeated records yet'),
    );
    expect(find.text('Not enough repeated records yet'), findsOneWidget);
    expect(find.textContaining('does not diagnose'), findsNothing);
  });
}
