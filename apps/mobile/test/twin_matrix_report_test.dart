import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/clinical/presentation/twin_matrix_report.dart';
import 'package:letter_mobile/features/clinical/presentation/twin_matrix_view_model.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';

TwinMatrixObservation _observation({
  required String id,
  required SymptomType symptom,
  required SymptomSeverity severity,
  required int? daysBeforeMenses,
  required int? cycleDay,
  required String cycleKey,
  HealthRecordProvenance provenance = HealthRecordProvenance.sameDay,
}) {
  return TwinMatrixObservation(
    recordId: id,
    experiencedDate: const LocalDate(2026, 8, 1),
    symptom: symptom,
    severity: severity,
    daysBeforeMenses: daysBeforeMenses,
    cycleDay: cycleDay,
    cycleKey: cycleKey,
    provenance: provenance,
    userConfirmed: true,
  );
}

void main() {
  testWidgets('phone report stacks readable halves and exposes cell sources', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final model = TwinMatrixViewModel.fromObservations(
      observations: [
        _observation(
          id: 'mood-before',
          symptom: SymptomType.irritability,
          severity: SymptomSeverity.severe,
          daysBeforeMenses: -3,
          cycleDay: null,
          cycleKey: 'cycle-a',
        ),
        _observation(
          id: 'physical-before',
          symptom: SymptomType.cramps,
          severity: SymptomSeverity.moderate,
          daysBeforeMenses: -1,
          cycleDay: null,
          cycleKey: 'cycle-a',
          provenance: HealthRecordProvenance.laterRecall,
        ),
        _observation(
          id: 'sleep-after',
          symptom: SymptomType.insomnia,
          severity: SymptomSeverity.mild,
          daysBeforeMenses: null,
          cycleDay: 4,
          cycleKey: 'cycle-b',
        ),
      ],
      cycleLabel: 'Jul 1 to Aug 1',
      exportTimestamp: 'Aug 6, 2026',
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: LetterTheme.light,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: TwinMatrixReport(viewModel: model),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('twin-matrix-mobile')), findsOneWidget);
    expect(
      find.byKey(const Key('twin-matrix-horizontal-scroll')),
      findsNothing,
    );
    expect(find.text('Before period'), findsOneWidget);
    expect(find.text('Cycle days'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(TwinMatrixReport)).label,
      contains('3 of 3 confirmed records map'),
    );
    expect(
      tester.getSemantics(find.byType(TwinMatrixReport)).label,
      contains('later-recall'),
    );
    final beforeDay3 = find.byKey(const Key('twin-before--3'));
    expect(beforeDay3, findsWidgets);
    await tester.tap(beforeDay3.first);
    await tester.pumpAndSettle();
    expect(find.text('3 days before period'), findsOneWidget);
    expect(find.textContaining('Irritability · Severe'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/twin_matrix_report_390x844.png'),
    );
  });
}
