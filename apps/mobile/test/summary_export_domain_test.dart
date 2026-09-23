import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/summary_export/domain/cycle_care_pdf.dart';
import 'package:letter_mobile/features/summary_export/domain/cycle_care_summary.dart';
import 'package:letter_mobile/features/summary_export/domain/local_file_share_adapter.dart';
import 'package:letter_mobile/features/summary_export/presentation/twin_matrix_summary_adapter.dart';

HealthRecord _healthRecord({required bool confirmed}) {
  return HealthRecord(
    id: confirmed ? 'confirmed' : 'unconfirmed',
    symptom: confirmed ? SymptomType.cramps : SymptomType.anxiety,
    severity: SymptomSeverity.severe,
    functionalImpacts: const {FunctionalImpact.workOrSchool},
    experiencedDate: const LocalDate(2026, 7, 18),
    recordedAt: DateTime.utc(2026, 7, 18),
    updatedAt: DateTime.utc(2026, 7, 18),
    provenance: HealthRecordProvenance.sameDay,
    userConfirmed: confirmed,
    vocabularyVersion: healthRecordVocabularyVersion,
  );
}

HealthRecord _datedHealthRecord({
  required String id,
  required SymptomType symptom,
  required SymptomSeverity severity,
  required LocalDate date,
  required DateTime updatedAt,
}) {
  return HealthRecord(
    id: id,
    symptom: symptom,
    severity: severity,
    functionalImpacts: const {},
    experiencedDate: date,
    recordedAt: DateTime.utc(date.year, date.month, date.day, 8),
    updatedAt: updatedAt,
    provenance: HealthRecordProvenance.sameDay,
    userConfirmed: true,
    vocabularyVersion: healthRecordVocabularyVersion,
  );
}

CareRecord _careRecord() {
  return CareRecord(
    id: 'care-1',
    mode: CareMode.physical,
    actionId: 'warmth',
    actionLabel: 'Warmth and quiet',
    outcome: CareOutcome.better,
    occurredAt: DateTime.utc(2026, 7, 18, 10),
    createdAt: DateTime.utc(2026, 7, 18, 10),
    updatedAt: DateTime.utc(2026, 7, 18, 10),
    pinned: false,
  );
}

SummaryExportInput summaryExportInput() {
  return SummaryExportInput(
    periodDays: const [
      SummaryPeriodDay(LocalDate(2026, 7, 1)),
      SummaryPeriodDay(LocalDate(2026, 7, 2)),
    ],
    predictions: const [
      SummaryPredictionRange(
        start: LocalDate(2026, 7, 29),
        end: LocalDate(2026, 8, 2),
        sourceLabel: 'Local cycle estimate',
      ),
    ],
    healthRecords: [
      _healthRecord(confirmed: true),
      _healthRecord(confirmed: false),
    ],
    checkIns: const [],
    careRecords: [_careRecord()],
    notes: const [
      SummarySelectableNote(
        id: 'note-1',
        date: LocalDate(2026, 7, 18),
        label: 'Your reflection',
        text: 'A quiet room helped.',
        sourceLabel: 'Saved Care reflection · local only',
      ),
    ],
  );
}

void main() {
  const range = SummaryDateRange(
    start: LocalDate(2026, 7, 1),
    end: LocalDate(2026, 7, 31),
  );

  test(
    'aggregates only confirmed local facts with provenance and missingness',
    () {
      final summary = buildCycleAndCareSummary(
        input: summaryExportInput(),
        range: range,
        selectedNoteIds: const {'note-1'},
      );

      expect(summary.healthRows, hasLength(1));
      expect(summary.healthRows.single.symptom, SymptomType.cramps);
      expect(summary.healthRows.single.cycleDay, 18);
      expect(
        summary.healthRows.single.provenance,
        SummaryRecordProvenance.sameDay,
      );
      expect(
        summary.careRows.single.provenance,
        SummaryRecordProvenance.factualCareEvent,
      );
      expect(summary.careRows.single.id, 'care-1');
      expect(
        summary.careRows.single.cycleStartDate,
        const LocalDate(2026, 7, 1),
      );
      expect(summary.careRows.single.cycleDay, 18);
      expect(summary.notes.single.text, 'A quiet room helped.');
      expect(summary.predictions.single.sourceLabel, 'Local cycle estimate');
      expect(summary.missingness, isEmpty);
      final periodRange = observedPeriodRanges(summary.periodDays).single;
      expect(periodRange.dayCount, 2);
      expect(summaryDateLabel(periodRange.start), '7/1/2026');
      expect(summaryDateLabel(periodRange.end), '7/2/2026');
    },
  );

  test(
    'creates deterministic CSV without unconfirmed data or unselected notes',
    () {
      final summary = buildCycleAndCareSummary(
        input: summaryExportInput(),
        range: range,
        selectedNoteIds: const {},
      );
      final first = buildCycleAndCareCsv(summary);
      final second = buildCycleAndCareCsv(summary);
      final text = utf8.decode(first.bytes);

      expect(
        first.fileName,
        'letter-cycle-care-summary-2026-07-01-2026-07-31.csv',
      );
      expect(first.bytes, second.bytes);
      expect(text, contains('This is a user-recorded summary'));
      expect(text, contains('Observed period dates (2 days)'));
      expect(text, contains('7/1/2026 to 7/2/2026'));
      expect(text, contains('Cramps'));
      expect(text, contains('Same day'));
      expect(text, contains('Factual Care event'));
      expect(text, contains('No user-selected notes included.'));
      expect(text, isNot(contains('Anxiety')));
      expect(text, isNot(contains('A quiet room helped.')));
    },
  );

  test('uses singular day grammar for a one-day observed period', () {
    final summary = buildCycleAndCareSummary(
      input: const SummaryExportInput(
        periodDays: [SummaryPeriodDay(LocalDate(2026, 7, 1))],
        predictions: [],
        healthRecords: [],
        checkIns: [],
        careRecords: [],
        notes: [],
      ),
      range: range,
      selectedNoteIds: const {},
    );
    final text = utf8.decode(buildCycleAndCareCsv(summary).bytes);

    expect(text, contains('Observed period dates (1 day)'));
    expect(text, isNot(contains('1 days')));
  });

  test('uses singular cycle grammar for one mapped cycle', () {
    expect(mappedCycleCountLabel(1), '1 cycle with mapped symptom ratings');
    expect(mappedCycleCountLabel(2), '2 cycles with mapped symptom ratings');
  });

  test('keeps derived matrix cells out of the CSV sidecar', () {
    final summary = buildCycleAndCareSummary(
      input: summaryExportInput(),
      range: range,
      selectedNoteIds: const {},
    );
    final text = utf8.decode(buildCycleAndCareCsv(summary).bytes);

    expect(text, isNot(contains('Matrix cell')));
    expect(text, isNot(contains('Cycle-balanced average')));
    expect(text, contains('Confirmed health record'));
  });

  test('deduplicates edits and maps real period timing into Twin Matrix', () {
    final input = SummaryExportInput(
      periodDays: const [
        SummaryPeriodDay(LocalDate(2026, 7, 1)),
        SummaryPeriodDay(LocalDate(2026, 7, 2)),
        SummaryPeriodDay(LocalDate(2026, 7, 3)),
        SummaryPeriodDay(LocalDate(2026, 7, 4)),
        SummaryPeriodDay(LocalDate(2026, 7, 29)),
        SummaryPeriodDay(LocalDate(2026, 7, 30)),
        SummaryPeriodDay(LocalDate(2026, 7, 31)),
        SummaryPeriodDay(LocalDate(2026, 8, 1)),
        SummaryPeriodDay(LocalDate(2026, 8, 27)),
        SummaryPeriodDay(LocalDate(2026, 8, 28)),
        SummaryPeriodDay(LocalDate(2026, 8, 29)),
        SummaryPeriodDay(LocalDate(2026, 8, 30)),
      ],
      predictions: const [],
      healthRecords: [
        _datedHealthRecord(
          id: 'edited-old',
          symptom: SymptomType.cramps,
          severity: SymptomSeverity.extreme,
          date: const LocalDate(2026, 7, 15),
          updatedAt: DateTime.utc(2026, 7, 15, 9),
        ),
        _datedHealthRecord(
          id: 'edited-new',
          symptom: SymptomType.cramps,
          severity: SymptomSeverity.minimal,
          date: const LocalDate(2026, 7, 15),
          updatedAt: DateTime.utc(2026, 7, 15, 12),
        ),
        _datedHealthRecord(
          id: 'before-one',
          symptom: SymptomType.headache,
          severity: SymptomSeverity.severe,
          date: const LocalDate(2026, 7, 28),
          updatedAt: DateTime.utc(2026, 7, 28, 12),
        ),
        _datedHealthRecord(
          id: 'cycle-one',
          symptom: SymptomType.lowMood,
          severity: SymptomSeverity.mild,
          date: const LocalDate(2026, 7, 29),
          updatedAt: DateTime.utc(2026, 7, 29, 12),
        ),
        _datedHealthRecord(
          id: 'cycle-fourteen',
          symptom: SymptomType.fatigue,
          severity: SymptomSeverity.moderate,
          date: const LocalDate(2026, 8, 11),
          updatedAt: DateTime.utc(2026, 8, 11, 12),
        ),
        _datedHealthRecord(
          id: 'open-cycle',
          symptom: SymptomType.irritability,
          severity: SymptomSeverity.extreme,
          date: const LocalDate(2026, 9, 1),
          updatedAt: DateTime.utc(2026, 9, 1, 12),
        ),
      ],
      checkIns: const [],
      careRecords: const [],
      notes: const [],
    );
    final summary = buildCycleAndCareSummary(
      input: input,
      range: const SummaryDateRange(
        start: LocalDate(2026, 7, 1),
        end: LocalDate(2026, 9, 5),
      ),
      selectedNoteIds: const {},
    );

    expect(summary.healthRows, hasLength(5));
    expect(
      summary.healthRows.map((row) => row.id),
      isNot(contains('edited-old')),
    );
    expect(summary.healthRows.map((row) => row.id), contains('edited-new'));
    final matrix = TwinMatrixSummaryAdapter.fromSummary(
      summary: summary,
      exportTimestamp: '2026-09-05',
    );
    final physical = matrix.clusters.singleWhere(
      (cluster) => cluster.label == 'physical symptoms',
    );

    expect(physical.beforePeriodCells.first.severity, 1);
    expect(physical.beforePeriodCells.last.severity, 4);
    expect(matrix.beforePeriodMapped, 2);
    expect(matrix.cycleMapped, 3);
    expect(matrix.mappedObservations, 5);
    expect(matrix.cyclesCovered, 3);
    expect(matrix.observedRelativeDays, 5);
  });

  test(
    'keeps a difficult Today check-in separate from a same-day symptom rating',
    () {
      final input = SummaryExportInput(
        periodDays: const [
          SummaryPeriodDay(LocalDate(2026, 7, 1)),
          SummaryPeriodDay(LocalDate(2026, 7, 2)),
          SummaryPeriodDay(LocalDate(2026, 7, 3)),
          SummaryPeriodDay(LocalDate(2026, 7, 29)),
        ],
        predictions: const [],
        healthRecords: [
          _datedHealthRecord(
            id: 'same-day-cramps',
            symptom: SymptomType.cramps,
            severity: SymptomSeverity.severe,
            date: const LocalDate(2026, 7, 28),
            updatedAt: DateTime.utc(2026, 7, 28, 12),
          ),
        ],
        checkIns: [
          MomentCheckIn(
            id: 'unanchored-low',
            state: MomentCheckInState.low,
            occurredAt: DateTime(2026, 6, 1, 18),
            createdAt: DateTime(2026, 6, 1, 18),
          ),
          MomentCheckIn(
            id: 'same-day-good',
            state: MomentCheckInState.good,
            occurredAt: DateTime(2026, 7, 28, 12),
            createdAt: DateTime(2026, 7, 28, 12),
          ),
          MomentCheckIn(
            id: 'same-day-anxious',
            state: MomentCheckInState.anxious,
            occurredAt: DateTime(2026, 7, 28, 18),
            createdAt: DateTime(2026, 7, 28, 18),
          ),
        ],
        careRecords: const [],
        notes: const [],
      );
      final summary = buildCycleAndCareSummary(
        input: input,
        range: const SummaryDateRange(
          start: LocalDate(2026, 6, 1),
          end: LocalDate(2026, 7, 31),
        ),
        selectedNoteIds: const {},
      );
      final matrix = TwinMatrixSummaryAdapter.fromSummary(
        summary: summary,
        exportTimestamp: '2026-07-31',
      );

      expect(summary.healthRows, hasLength(1));
      expect(summary.checkInRows, hasLength(3));
      expect(
        summary.checkInRows
            .singleWhere((row) => row.id == 'same-day-anxious')
            .daysBeforeMenses,
        -1,
      );
      expect(matrix.totalObservations, 1);
      expect(matrix.beforePeriodMapped, 1);
      expect(matrix.qualitativeCheckIns, hasLength(2));
      expect(
        matrix.qualitativeCheckIns.map((marker) => marker.state),
        containsAll(<MomentCheckInState>[
          MomentCheckInState.low,
          MomentCheckInState.anxious,
        ]),
      );
      expect(
        matrix.qualitativeCheckIns
            .singleWhere((marker) => marker.recordId == 'unanchored-low')
            .cycleDay,
        isNull,
      );
    },
  );

  test('groups repeated same-day moods for clinician-facing evidence', () {
    final repeated = <MomentCheckIn>[
      for (var index = 0; index < 3; index++)
        MomentCheckIn(
          id: 'irritable-$index',
          state: MomentCheckInState.irritable,
          occurredAt: DateTime(2026, 7, 28, 18, index),
          createdAt: DateTime(2026, 7, 28, 18, index),
        ),
      MomentCheckIn(
        id: 'anxious',
        state: MomentCheckInState.anxious,
        occurredAt: DateTime(2026, 7, 28, 19),
        createdAt: DateTime(2026, 7, 28, 19),
      ),
    ];
    final summary = buildCycleAndCareSummary(
      input: SummaryExportInput(
        periodDays: const [
          SummaryPeriodDay(LocalDate(2026, 7, 1)),
          SummaryPeriodDay(LocalDate(2026, 7, 29)),
        ],
        predictions: const [],
        healthRecords: const [],
        checkIns: repeated,
        careRecords: const [],
        notes: const [],
      ),
      range: const SummaryDateRange(
        start: LocalDate(2026, 7, 1),
        end: LocalDate(2026, 7, 31),
      ),
      selectedNoteIds: const {},
    );
    final matrix = TwinMatrixSummaryAdapter.fromSummary(
      summary: summary,
      exportTimestamp: '2026-07-31',
    );

    expect(summary.checkInRows, hasLength(4));
    expect(matrix.qualitativeCheckIns, hasLength(2));
    final irritable = matrix.qualitativeCheckIns.singleWhere(
      (marker) => marker.state == MomentCheckInState.irritable,
    );
    expect(irritable.occurrenceCount, 3);
    expect(irritable.recordId, 'irritable-2');
    expect(irritable.daysBeforeMenses, -1);
    expect(
      matrix.qualitativeCheckIns
          .singleWhere((marker) => marker.state == MomentCheckInState.anxious)
          .occurrenceCount,
      1,
    );
  });

  test('uses one cycle evidence contract for starts, spans, and timing', () {
    const starts = <LocalDate>[
      LocalDate(2026, 7, 1),
      LocalDate(2026, 7, 29),
      LocalDate(2026, 8, 26),
      LocalDate(2026, 9, 23),
    ];
    final evidence = SummaryCycleEvidence.fromPeriodDays([
      for (final start in starts)
        for (var day = 0; day < 5; day++) SummaryPeriodDay(start.addDays(day)),
    ]);

    expect(evidence.periodStartCount, 4);
    expect(evidence.completedCycleCount, 3);
    expect(evidence.currentCycleStart, starts.last);
    expect(evidence.completedCycles.first.dayCount, 28);
    expect(
      evidence.completedCycleCountIn(
        const SummaryDateRange(
          start: LocalDate(2026, 7, 15),
          end: LocalDate(2026, 8, 15),
        ),
      ),
      2,
    );
    expect(evidence.cycleDayFor(const LocalDate(2026, 7, 28)), 28);
    expect(evidence.daysBeforeNextPeriod(const LocalDate(2026, 7, 28)), -1);
  });

  test('maps Care outcomes to timing without changing symptom averages', () {
    final input = SummaryExportInput(
      periodDays: const [
        SummaryPeriodDay(LocalDate(2026, 7, 1)),
        SummaryPeriodDay(LocalDate(2026, 7, 2)),
        SummaryPeriodDay(LocalDate(2026, 7, 29)),
        SummaryPeriodDay(LocalDate(2026, 7, 30)),
      ],
      predictions: const [],
      healthRecords: [
        _datedHealthRecord(
          id: 'cramps',
          symptom: SymptomType.cramps,
          severity: SymptomSeverity.severe,
          date: const LocalDate(2026, 7, 28),
          updatedAt: DateTime.utc(2026, 7, 28, 9),
        ),
      ],
      checkIns: const [],
      careRecords: [
        CareRecord(
          id: 'care-before-history',
          mode: CareMode.racing,
          actionId: 'breathe',
          actionLabel: 'Breathe with me',
          outcome: CareOutcome.same,
          occurredAt: DateTime(2026, 6, 1, 18),
          createdAt: DateTime(2026, 6, 1, 18),
          updatedAt: DateTime(2026, 6, 1, 18),
          pinned: false,
        ),
        CareRecord(
          id: 'care-before-period',
          mode: CareMode.physical,
          actionId: 'warmth',
          actionLabel: 'Apply warmth',
          outcome: CareOutcome.better,
          occurredAt: DateTime(2026, 7, 28, 18),
          createdAt: DateTime(2026, 7, 28, 18),
          updatedAt: DateTime(2026, 7, 28, 18),
          pinned: false,
        ),
        CareRecord(
          id: 'care-cycle-day-two',
          mode: CareMode.heavy,
          actionId: 'quiet',
          actionLabel: 'Quiet presence',
          outcome: CareOutcome.worse,
          occurredAt: DateTime(2026, 7, 30, 18),
          createdAt: DateTime(2026, 7, 30, 18),
          updatedAt: DateTime(2026, 7, 30, 18),
          pinned: false,
        ),
      ],
      notes: const [],
    );
    final summary = buildCycleAndCareSummary(
      input: input,
      range: const SummaryDateRange(
        start: LocalDate(2026, 6, 1),
        end: LocalDate(2026, 7, 31),
      ),
      selectedNoteIds: const {},
    );
    final matrix = TwinMatrixSummaryAdapter.fromSummary(
      summary: summary,
      exportTimestamp: '2026-07-31',
    );

    expect(matrix.totalObservations, 1);
    expect(matrix.beforePeriodMapped, 1);
    expect(matrix.careOutcomes, hasLength(3));
    final unanchored = matrix.careOutcomes.singleWhere(
      (item) => item.recordId == 'care-before-history',
    );
    expect(unanchored.cycleDay, isNull);
    expect(unanchored.daysBeforeMenses, isNull);
    final beforePeriod = matrix.careOutcomes.singleWhere(
      (item) => item.recordId == 'care-before-period',
    );
    expect(beforePeriod.daysBeforeMenses, -1);
    expect(beforePeriod.cycleDay, 28);
    expect(beforePeriod.outcome, CareOutcome.better);
    final cycleDayTwo = matrix.careOutcomes.singleWhere(
      (item) => item.recordId == 'care-cycle-day-two',
    );
    expect(cycleDayTwo.cycleDay, 2);
    expect(cycleDayTwo.outcome, CareOutcome.worse);
  });
}
