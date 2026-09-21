import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/clinical/presentation/twin_matrix_view_model.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
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
  Set<FunctionalImpact> functionalImpacts = const {
    FunctionalImpact.workOrSchool,
  },
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
    functionalImpacts: functionalImpacts,
  );
}

TwinMatrixCluster _cluster(TwinMatrixViewModel model, String label) =>
    model.clusters.singleWhere((cluster) => cluster.label == label);

void main() {
  test('empty and unconfirmed-only input stays entirely blank', () {
    final model = TwinMatrixViewModel.fromObservations(
      observations: [
        _observation(
          id: 'draft-only',
          symptom: SymptomType.cramps,
          severity: 5,
          date: const LocalDate(2026, 7, 10),
          cycleKey: 'cycle-a',
          daysBeforeMenses: -3,
          cycleDay: 4,
          confirmed: false,
        ),
      ],
      cycleLabel: 'No confirmed records',
      exportTimestamp: '2026-08-01',
    );

    expect(model.totalObservations, 0);
    expect(model.mappedObservations, 0);
    expect(model.observedRelativeDays, 0);
    expect(model.blankRelativeDays, 28);
    expect(
      model.clusters
          .expand(
            (cluster) => [...cluster.beforePeriodCells, ...cluster.cycleCells],
          )
          .every((cell) => cell.severity == null),
      isTrue,
    );
    expect(model.accessibilitySummary, isNot(contains('luteal')));
  });

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
    expect(physical.beforePeriodCells[11].severity, 4);
    expect(physical.beforePeriodCells[11].observationCount, 1);
    expect(physical.beforePeriodCells[10].severity, isNull);
    expect(physical.beforePeriodCells[10].evidence, isEmpty);
  });

  test('averages each cycle before averaging across cycles', () {
    final model = TwinMatrixViewModel.fromObservations(
      observations: [
        _observation(
          id: 'a-cramps',
          symptom: SymptomType.cramps,
          severity: 5,
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

    final cell = _cluster(model, 'physical symptoms').beforePeriodCells[11];
    expect(cell.severity, 2.75); // mean(5, 2) = 3.5; mean(3.5, 2) = 2.75
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
          severity: 5,
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
    expect(
      cognition.beforePeriodCells[12].evidence.single.recordId,
      'brain-fog-1',
    );
    expect(
      cognition.beforePeriodCells[12].evidence.single.provenance,
      HealthRecordProvenance.laterRecall,
    );
    expect(
      _cluster(
        model,
        'energy/sleep',
      ).beforePeriodCells[13].evidence.single.symptom,
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

  test('keeps exact boundaries and reports honest coverage', () {
    final model = TwinMatrixViewModel.fromObservations(
      observations: [
        _observation(
          id: 'first-boundaries',
          symptom: SymptomType.cramps,
          severity: 2,
          date: const LocalDate(2026, 7, 1),
          cycleKey: 'cycle-a',
          daysBeforeMenses: -14,
          cycleDay: 1,
        ),
        _observation(
          id: 'last-boundaries',
          symptom: SymptomType.cramps,
          severity: 5,
          date: const LocalDate(2026, 7, 14),
          cycleKey: 'cycle-a',
          daysBeforeMenses: -1,
          cycleDay: 14,
          provenance: HealthRecordProvenance.laterRecall,
        ),
        _observation(
          id: 'outside-low',
          symptom: SymptomType.cramps,
          severity: 5,
          date: const LocalDate(2026, 6, 30),
          cycleKey: 'cycle-a',
          daysBeforeMenses: -15,
          cycleDay: 0,
        ),
        _observation(
          id: 'outside-high',
          symptom: SymptomType.cramps,
          severity: 5,
          date: const LocalDate(2026, 7, 15),
          cycleKey: 'cycle-a',
          daysBeforeMenses: 0,
          cycleDay: 15,
        ),
        _observation(
          id: 'draft',
          symptom: SymptomType.cramps,
          severity: 5,
          date: const LocalDate(2026, 7, 2),
          cycleKey: 'cycle-a',
          daysBeforeMenses: -13,
          cycleDay: 2,
          confirmed: false,
        ),
      ],
      cycleLabel: 'Boundary cycle',
      exportTimestamp: '2026-08-01',
    );

    final physical = _cluster(model, 'physical symptoms');
    expect(physical.beforePeriodCells.first.severity, 2);
    expect(physical.beforePeriodCells.last.severity, 5);
    expect(physical.cycleCells.first.severity, 2);
    expect(physical.cycleCells.last.severity, 5);
    expect(model.totalObservations, 4);
    expect(model.mappedObservations, 2);
    expect(model.beforePeriodMapped, 2);
    expect(model.cycleMapped, 2);
    expect(model.cyclesCovered, 1);
    expect(model.observedRelativeDays, 4);
    expect(model.blankRelativeDays, 24);
    expect(model.sameDayObservations, 3);
    expect(model.laterRecallObservations, 1);
    expect(model.accessibilitySummary, contains('24 are blank'));
    expect(model.accessibilitySummary, contains('14 days before period'));
    expect(model.accessibilitySummary, contains('cycle day 14'));
  });

  test(
    'maps every symptom exactly once across the five scanability groups',
    () {
      final observations = [
        for (final symptom in SymptomType.values)
          _observation(
            id: symptom.name,
            symptom: symptom,
            severity: 3,
            date: const LocalDate(2026, 7, 19),
            cycleKey: 'cycle-a',
            daysBeforeMenses: -1,
            cycleDay: null,
          ),
      ];
      final model = TwinMatrixViewModel.fromObservations(
        observations: observations,
        cycleLabel: 'All symptoms',
        exportTimestamp: '2026-08-01',
      );

      final evidence = [
        for (final cluster in model.clusters)
          ...cluster.beforePeriodCells.last.evidence,
      ];
      expect(evidence, hasLength(SymptomType.values.length));
      expect(
        evidence.map((item) => item.symptom).toSet(),
        SymptomType.values.toSet(),
      );
    },
  );

  test(
    'retains functional-impact evidence without inventing a severity row',
    () {
      final model = TwinMatrixViewModel.fromObservations(
        observations: [
          _observation(
            id: 'cramps-with-social-impact',
            symptom: SymptomType.cramps,
            severity: 5,
            date: const LocalDate(2026, 7, 18),
            cycleKey: 'cycle-a',
            daysBeforeMenses: -2,
            cycleDay: null,
            functionalImpacts: const {FunctionalImpact.socialActivity},
          ),
        ],
        cycleLabel: 'One cycle',
        exportTimestamp: '2026-08-01',
      );

      final physicalEvidence = _cluster(
        model,
        'physical symptoms',
      ).beforePeriodCells[12].evidence.single;
      expect(
        physicalEvidence.functionalImpacts,
        contains(FunctionalImpact.socialActivity),
      );
      expect(
        _cluster(
          model,
          'social withdrawal',
        ).beforePeriodCells.every((cell) => cell.severity == null),
        isTrue,
      );
    },
  );

  test('one confirmed record is eligible without claiming recurrence', () {
    final model = TwinMatrixViewModel.fromObservations(
      observations: [
        _observation(
          id: 'single',
          symptom: SymptomType.lowMood,
          severity: 4,
          date: const LocalDate(2026, 7, 18),
          cycleKey: 'cycle-a',
          daysBeforeMenses: -2,
          cycleDay: null,
        ),
      ],
      cycleLabel: 'One observation',
      exportTimestamp: '2026-08-01',
    );

    expect(model.totalObservations, 1);
    expect(model.mappedObservations, 1);
    expect(
      _cluster(model, 'mood/irritability').beforePeriodCells[12].severity,
      4,
    );
  });

  test(
    'Care outcomes stay qualitative, explicit, and independently anchored',
    () {
      final model = TwinMatrixViewModel.fromObservations(
        observations: const [],
        careOutcomes: [
          TwinMatrixCareMarker(
            recordId: 'better',
            recordedAt: DateTime(2026, 7, 28, 8),
            actionLabel: 'Apply warmth',
            outcome: CareOutcome.better,
            daysBeforeMenses: -1,
            cycleDay: 28,
            cycleKey: 'cycle-a',
          ),
          TwinMatrixCareMarker(
            recordId: 'same',
            recordedAt: DateTime(2026, 7, 29, 8),
            actionLabel: 'Quiet presence',
            outcome: CareOutcome.same,
            daysBeforeMenses: null,
            cycleDay: 1,
            cycleKey: 'cycle-b',
          ),
          TwinMatrixCareMarker(
            recordId: 'worse',
            recordedAt: DateTime(2026, 7, 30, 8),
            actionLabel: 'Gentle movement',
            outcome: CareOutcome.worse,
            daysBeforeMenses: null,
            cycleDay: 2,
            cycleKey: 'cycle-b',
          ),
          TwinMatrixCareMarker(
            recordId: 'unanchored',
            recordedAt: DateTime(2026, 6, 1, 8),
            actionLabel: 'Breathe with me',
            outcome: CareOutcome.better,
            daysBeforeMenses: null,
            cycleDay: null,
          ),
        ],
        cycleLabel: 'Care only',
        exportTimestamp: '2026-08-01',
      );

      expect(model.totalObservations, 0);
      expect(model.mappedObservations, 0);
      expect(model.careOutcomes.map((item) => item.outcome), [
        CareOutcome.better,
        CareOutcome.same,
        CareOutcome.worse,
        CareOutcome.better,
      ]);
      expect(model.accessibilitySummary, contains('4 saved Care check-backs'));
    },
  );
}
