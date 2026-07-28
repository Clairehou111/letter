import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
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
  painLocationCounts: {},
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

Future<void> scrollPatterns(WidgetTester tester, {required bool down}) async {
  final offset = down ? const Offset(0, -620) : const Offset(0, 620);
  for (var index = 0; index < 3; index++) {
    await tester.drag(
      find.byType(Scrollable).first,
      offset,
      warnIfMissed: false,
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('shows evidence dates, outcomes, and authored reflection', (
    tester,
  ) async {
    await pumpPatterns(tester);

    expect(find.text('What has repeated'), findsOneWidget);
    expect(
      find.text('Recorded 2 times from 2026-07-10 to 2026-07-14.'),
      findsOneWidget,
    );
    expect(find.text('Observed dates: 2026-07-10, 2026-07-14'), findsOneWidget);
    await scrollPatterns(tester, down: true);
    expect(find.text('Better in 1 of 3 check-backs'), findsOneWidget);
    expect(find.text('Same 1 · Worse 1'), findsOneWidget);
    expect(
      find.text('Your words: “The room felt less demanding.”'),
      findsOneWidget,
    );
    expect(find.textContaining('diagnos'), findsNothing);
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

    await tester.tap(find.byKey(const Key('pattern-menu-symptom:cramps')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit source record'));
    expect(edited, ['health-one']);

    await scrollPatterns(tester, down: true);
    await tester.tap(
      find.byKey(const Key('pattern-menu-action:physical:lower-input')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unpin this action'));
    expect(unpinned, ['care-one']);

    await scrollPatterns(tester, down: false);
    await tester.tap(find.byKey(const Key('pattern-menu-symptom:cramps')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide this view'));
    expect(dismissed, ['symptom:cramps']);

    await scrollPatterns(tester, down: true);
    await tester.tap(
      find.byKey(const Key('pattern-menu-action:physical:lower-input')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete source record'));
    expect(deleted, ['care-one']);
  });

  testWidgets(
    'insufficient history is explicit and separates generic comfort',
    (tester) async {
      await pumpPatterns(
        tester,
        analysis: PersonalPatternAnalysis(
          symptomPatterns: const [],
          supportActions: const [],
          selectedCareMode: null,
        ),
      );
      expect(find.text('Not enough repeated records yet'), findsOneWidget);
      await scrollPatterns(tester, down: true);
      expect(find.text('General comfort ideas'), findsOneWidget);
      expect(find.textContaining('not personal findings'), findsOneWidget);
    },
  );
}
