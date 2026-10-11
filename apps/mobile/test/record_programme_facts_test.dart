import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';
import 'package:letter_mobile/features/record_hub/domain/record_programme.dart';
import 'package:letter_mobile/features/record_hub/domain/record_programme_facts.dart';

void main() {
  final start = const LocalDate(2026, 9, 1);
  final now = DateTime.utc(2026, 10, 9);
  RecordProgramme programme({
    LocalDate? end,
    List<RecordProgrammePause> pauses = const [],
  }) => RecordProgramme(
    id: 'synthetic-programme',
    startDate: start,
    endDate: end,
    createdAt: now,
    updatedAt: now,
    configurations: [
      RecordProgrammeConfig(
        id: 'synthetic-config',
        version: 1,
        effectiveDate: start,
        symptoms: [SymptomType.cramps],
      ),
    ],
    pauses: pauses,
  );
  HealthRecord symptom(
    LocalDate date,
    int score, {
    HealthRecordProvenance provenance = HealthRecordProvenance.sameDay,
  }) => HealthRecord(
    id: 'synthetic-${date.epochDay}',
    symptom: SymptomType.cramps,
    severity: SymptomSeverity.fromScore(score),
    functionalImpacts: {},
    experiencedDate: date,
    recordedAt: now,
    updatedAt: now,
    provenance: provenance,
    userConfirmed: true,
    vocabularyVersion: healthRecordVocabularyVersion,
  );
  RecordHubDateFacts impact(LocalDate date, int score) => RecordHubDateFacts(
    date: date,
    impact: RecordHubFact(
      metadata: RecordFactMetadata(
        id: 'synthetic-impact-${date.epochDay}',
        experiencedDate: date,
        recordedAt: now,
        updatedAt: now,
        originalProvenance: HealthRecordProvenance.sameDay,
        provenance: HealthRecordProvenance.sameDay,
      ),
      value: DailyImpactDraft(experiencedDate: date, overall: score),
    ),
  );
  List<PeriodRecord> getPeriods() => [
    for (final date in [start, const LocalDate(2026, 10, 1)])
      PeriodRecord(
        id: 'synthetic-period-${date.epochDay}',
        startDate: date,
        endDate: date.addDays(4),
        createdAt: now,
        updatedAt: now,
      ),
  ];

  test(
    'every fixed non-paused field must be explicitly same-day; zero is observed',
    () {
      final symptoms = [
        for (var day = 0; day < 30; day++) symptom(start.addDays(day), 0),
      ];
      final impacts = [
        for (var day = 0; day < 30; day++) impact(start.addDays(day), 0),
      ];
      final complete = composeRecordProgrammeFacts(
        programme: programme(),
        today: const LocalDate(2026, 10, 1),
        healthRecords: symptoms,
        datedFacts: impacts,
        periods: getPeriods(),
      );
      expect(complete.elapsedCycles, 1);
      expect(complete.literallyFullyRecordedCycles, 1);
      expect(complete.fields.first.overall.distribution[0], 30);
      symptoms[3] = symptom(
        start.addDays(3),
        0,
        provenance: HealthRecordProvenance.laterRecall,
      );
      final recalled = composeRecordProgrammeFacts(
        programme: programme(),
        today: const LocalDate(2026, 10, 1),
        healthRecords: symptoms,
        datedFacts: impacts,
        periods: getPeriods(),
      );
      expect(recalled.literallyFullyRecordedCycles, 0);
      expect(recalled.fields.first.overall.sourceCount, 30);
      expect(recalled.fields.first.overall.laterRecallCount, 1);
      impacts.removeAt(5);
      final missing = composeRecordProgrammeFacts(
        programme: programme(),
        today: const LocalDate(2026, 10, 1),
        healthRecords: symptoms,
        datedFacts: impacts,
        periods: getPeriods(),
      );
      expect(
        missing.missingFieldCount,
        3,
      ); // One missing impact plus both fields on Oct 1.
    },
  );

  test(
    'persistent or partial evidence always yields free source-traceable facts',
    () {
      final result = composeRecordProgrammeFacts(
        programme: programme(),
        today: const LocalDate(2026, 10, 1),
        healthRecords: [
          symptom(start, 5),
          symptom(
            start.addDays(1),
            5,
            provenance: HealthRecordProvenance.timingUnknown,
          ),
        ],
        datedFacts: [],
        periods: getPeriods(),
      );
      expect(result.fields.first.overall.sourceCount, 2);
      expect(result.fields.first.overall.median, 5);
      expect(result.fields.first.overall.peak, 5);
      expect(result.fields.first.overall.timingUnknownCount, 1);
      expect(
        result.fields.first.overall.sources.first.sourceId,
        'synthetic-${start.epochDay}',
      );
      expect(result.literallyFullyRecordedCycles, 0);
      expect(
        result.fields.last.overall.sourceCount,
        0,
      ); // Independent impact stays missing.
    },
  );

  test(
    'pause skips expected fields and ended history never includes later facts/cycles',
    () {
      final paused = programme(
        end: const LocalDate(2026, 9, 20),
        pauses: [
          RecordProgrammePause(
            id: 'synthetic-pause',
            startDate: const LocalDate(2026, 9, 5),
            resumedDate: const LocalDate(2026, 9, 8),
          ),
        ],
      );
      final result = composeRecordProgrammeFacts(
        programme: paused,
        today: const LocalDate(2026, 10, 9),
        healthRecords: [
          symptom(const LocalDate(2026, 9, 5), 4),
          symptom(const LocalDate(2026, 10, 2), 5),
        ],
        datedFacts: [],
        periods: getPeriods(),
      );
      expect(result.days.length, 20);
      expect(result.expectedFieldCount, 34);
      expect(result.elapsedCycles, 0);
      expect(
        result.fields.first.overall.sourceCount,
        1,
      ); // Paused source stays visible context.
      expect(result.days[4].paused, isTrue);
      expect(result.days[7].paused, isFalse);
    },
  );
}
