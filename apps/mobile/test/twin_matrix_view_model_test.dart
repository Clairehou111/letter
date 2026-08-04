import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/clinical/presentation/twin_matrix_view_model.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';

TwinMatrixObservation _observation({
  required String id,
  required SymptomType symptom,
  required int severity,
  required LocalDate date,
  required String cycleKey,
  required int? daysBeforeMenses,
  required int? cycleDay,
  bool confirmed = true,
  HealthRecordProvenance provenance = HealthRecordProvenance.sameDay,
}) {
  return TwinMatrixObservation(
    recordId: id,
    experiencedDate: date,
    symptom: symptom,
    severity: SymptomSeverity.values[severity - 1],
    daysBeforeMenses: daysBeforeMenses,
    cycleDay: cycleDay,
    cycleKey: cycleKey,
    provenance: provenance,
    userConfirmed: confirmed,
    functionalImpacts: const {FunctionalImpact.workOrSchool},
  );
}

TwinMatrixCluster _cluster(TwinMatrixViewModel model, String label) =>
    model.clusters.singleWhere((cluster) => cluster.label == label);

void main() {
  test('keeps missing cells distinct from observed cells', () {
    final model = TwinMatrixViewModel.fromObservations(
      observations: [
        _observation(
          id: 'cramps-1',
          symptom: SymptomType.cramps,
          severity: 4,
          date: const LocalDate(2026, 7, 10),
          cycleKey: 'cycle-a',
          daysBeforeMenses: -3,
          cycleDay: null,
        ),
      ],
      cycleLabel: 'July',
      exportTimestamp: '2026-08-01',
    );

    final physical = _cluster(model, 'physical symptoms');
    expect(physical.lutealCells[11].severity, 4);
    expect(physical.lutealCells[11].observationCount, 1);
    expect(physical.lutealCells[10].severity, isNull);
    expect(physical.lutealCells[10].evidence, isEmpty);
  });

  test('averages each cycle before averaging across cycles', () {
    final model = TwinMatrixViewModel.fromObservations(
      observations: [
        _observation(
          id: 'a-cramps',
          symptom: SymptomType.cramps,
          severity: 6,
          date: const LocalDate(2026, 7, 10),
          cycleKey: 'cycle-a',
          daysBeforeMenses: -3,
          cycleDay: null,
        ),
        _observation(
          id: 'a-nausea',
          symptom: SymptomType.nausea,
          severity: 2,
          date: const LocalDate(2026, 7, 10),
          cycleKey: 'cycle-a',
          daysBeforeMenses: -3,
          cycleDay: null,
        ),
        _observation(
          id: 'b-cramps',
          symptom: SymptomType.cramps,
          severity: 2,
          date: const LocalDate(2026, 8, 10),
          cycleKey: 'cycle-b',
          daysBeforeMenses: -3,
          cycleDay: null,
        ),
      ],
      cycleLabel: 'Two cycles',
      exportTimestamp: '2026-08-01',
    );

    final cell = _cluster(model, 'physical symptoms').lutealCells[11];
    expect(cell.severity, 3); // mean(6, 2) = 4; mean(4, 2) = 3
    expect(cell.observationCount, 3);
    expect(cell.cycleCount, 2);
  });

  test('retains all reviewed symptom domains and evidence provenance', () {
    final model = TwinMatrixViewModel.fromObservations(
      observations: [
        _observation(
          id: 'brain-fog-1',
          symptom: SymptomType.brainFog,
          severity: 5,
          date: const LocalDate(2026, 7, 10),
          cycleKey: 'cycle-a',
          daysBeforeMenses: -2,
          cycleDay: null,
          provenance: HealthRecordProvenance.laterRecall,
        ),
        _observation(
          id: 'sleep-1',
          symptom: SymptomType.insomnia,
          severity: 3,
          date: const LocalDate(2026, 7, 11),
          cycleKey: 'cycle-a',
          daysBeforeMenses: -1,
          cycleDay: null,
        ),
        _observation(
          id: 'nausea-1',
          symptom: SymptomType.nausea,
          severity: 4,
          date: const LocalDate(2026, 7, 12),
          cycleKey: 'cycle-a',
          daysBeforeMenses: null,
          cycleDay: 2,
        ),
        _observation(
          id: 'draft',
          symptom: SymptomType.cramps,
          severity: 6,
          date: const LocalDate(2026, 7, 12),
          cycleKey: 'cycle-a',
          daysBeforeMenses: -1,
          cycleDay: 2,
          confirmed: false,
        ),
      ],
      cycleLabel: 'One cycle',
      exportTimestamp: '2026-08-01',
    );

    expect(model.totalObservations, 3);
    expect(model.clusters, hasLength(5));
    final cognition = _cluster(model, 'anxiety/cognition');
    expect(cognition.lutealCells[12].evidence.single.recordId, 'brain-fog-1');
    expect(
      cognition.lutealCells[12].evidence.single.provenance,
      HealthRecordProvenance.laterRecall,
    );
    expect(
      _cluster(model, 'energy/sleep').lutealCells[13].evidence.single.symptom,
      SymptomType.insomnia,
    );
    expect(
      _cluster(
        model,
        'physical symptoms',
      ).cycleCells[1].evidence.single.symptom,
      SymptomType.nausea,
    );
  });
}
