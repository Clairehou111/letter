import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/summary_export/domain/cycle_care_summary.dart';
import 'package:letter_mobile/features/summary_export/domain/local_file_share_adapter.dart';

HealthRecord _healthRecord({required bool confirmed}) {
  return HealthRecord(
    id: confirmed ? 'confirmed' : 'unconfirmed',
    symptom: confirmed ? SymptomType.cramps : SymptomType.anxiety,
    severity: SymptomSeverity.severe,
    painRating: confirmed ? 8 : null,
    painLocations: confirmed ? const {PainLocation.lowerAbdomen} : const {},
    functionalImpacts: const {FunctionalImpact.workOrSchool},
    experiencedDate: const LocalDate(2026, 7, 18),
    recordedAt: DateTime.utc(2026, 7, 18),
    updatedAt: DateTime.utc(2026, 7, 18),
    provenance: HealthRecordProvenance.sameDay,
    userConfirmed: confirmed,
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
}
