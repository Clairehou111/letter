import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/patterns/domain/pattern_source.dart';
import 'package:letter_mobile/features/patterns/domain/personal_pattern.dart';
import 'package:letter_mobile/features/patterns/domain/personal_pattern_engine.dart';

HealthRecord health(
  String id,
  LocalDate date, {
  SymptomType symptom = SymptomType.cramps,
  SymptomSeverity severity = SymptomSeverity.moderate,
  bool confirmed = true,
  Set<PainLocation> painLocations = const {},
  Set<FunctionalImpact> functionalImpacts = const {},
}) {
  final recordedAt = DateTime.utc(date.year, date.month, date.day, 12);
  return HealthRecord(
    id: id,
    symptom: symptom,
    severity: severity,
    painRating: null,
    painLocations: painLocations,
    functionalImpacts: functionalImpacts,
    experiencedDate: date,
    recordedAt: recordedAt,
    updatedAt: recordedAt,
    provenance: HealthRecordProvenance.sameDay,
    userConfirmed: confirmed,
    vocabularyVersion: healthRecordVocabularyVersion,
  );
}

CareRecord care(
  String id,
  String actionId,
  DateTime occurredAt,
  CareOutcome outcome, {
  CareMode mode = CareMode.physical,
  bool pinned = false,
}) {
  return CareRecord(
    id: id,
    mode: mode,
    actionId: actionId,
    actionLabel: 'Lower the input',
    outcome: outcome,
    occurredAt: occurredAt,
    createdAt: occurredAt,
    updatedAt: occurredAt,
    pinned: pinned,
  );
}

PeriodRecord period(String id, LocalDate start) {
  final timestamp = DateTime.utc(start.year, start.month, start.day);
  return PeriodRecord(
    id: id,
    startDate: start,
    endDate: start.addDays(4),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

void main() {
  const engine = PersonalPatternEngine();

  test('requires two confirmed comparable health records', () {
    final one = engine.analyze(
      PatternSourceSnapshot(
        healthRecords: [
          health('one', const LocalDate(2026, 7, 10)),
          health('unconfirmed', const LocalDate(2026, 7, 11), confirmed: false),
        ],
      ),
    );
    expect(one.symptomPatterns, isEmpty);

    final two = engine.analyze(
      PatternSourceSnapshot(
        healthRecords: [
          health('one', const LocalDate(2026, 7, 10)),
          health(
            'two',
            const LocalDate(2026, 7, 14),
            severity: SymptomSeverity.severe,
            painLocations: const {PainLocation.lowerAbdomen},
            functionalImpacts: const {FunctionalImpact.workOrSchool},
          ),
        ],
      ),
    );
    final pattern = two.symptomPatterns.single;
    expect(pattern.count, 2);
    expect(pattern.firstDate, const LocalDate(2026, 7, 10));
    expect(pattern.lastDate, const LocalDate(2026, 7, 14));
    expect(pattern.coveredDates, [
      const LocalDate(2026, 7, 10),
      const LocalDate(2026, 7, 14),
    ]);
    expect(pattern.severityCounts[SymptomSeverity.moderate], 1);
    expect(pattern.severityCounts[SymptomSeverity.severe], 1);
    expect(pattern.painLocationCounts[PainLocation.lowerAbdomen], 1);
    expect(pattern.functionalImpactCounts[FunctionalImpact.workOrSchool], 1);
  });

  test('uses period dates only for observed cycle-day context', () {
    final analysis = engine.analyze(
      PatternSourceSnapshot(
        healthRecords: [
          health('one', const LocalDate(2026, 7, 10)),
          health('two', const LocalDate(2026, 8, 10)),
        ],
        periods: [
          period('july', const LocalDate(2026, 7, 1)),
          period('august', const LocalDate(2026, 8, 1)),
        ],
      ),
    );
    final pattern = analysis.symptomPatterns.single;
    expect(pattern.comparisonBasis, PatternComparisonBasis.observedCycleDays);
    expect(pattern.cycleDayObservations.map((item) => item.cycleDay), [10, 10]);
    expect(pattern.cycleDayObservations, hasLength(2));
  });

  test('legacy duplicate symptom rows count once per experienced day', () {
    final older = health('older', const LocalDate(2026, 7, 10));
    final newer = HealthRecord(
      id: 'newer',
      symptom: older.symptom,
      severity: SymptomSeverity.severe,
      painRating: null,
      painLocations: const {},
      functionalImpacts: const {},
      experiencedDate: older.experiencedDate,
      recordedAt: older.recordedAt,
      updatedAt: older.updatedAt.add(const Duration(hours: 1)),
      provenance: older.provenance,
      userConfirmed: true,
      vocabularyVersion: healthRecordVocabularyVersion,
    );
    final analysis = engine.analyze(
      PatternSourceSnapshot(
        healthRecords: [
          older,
          newer,
          health('second-day', const LocalDate(2026, 7, 11)),
        ],
      ),
    );

    final pattern = analysis.symptomPatterns.single;
    expect(pattern.count, 2);
    expect(pattern.severityCounts[SymptomSeverity.severe], 1);
    expect(pattern.severityCounts[SymptomSeverity.moderate], 1);
  });

  test('keeps Care outcomes distinct and returns prior actions by mode', () {
    final analysis = engine.analyze(
      PatternSourceSnapshot(
        careRecords: [
          care(
            'one',
            'lower-input',
            DateTime.utc(2026, 7, 1),
            CareOutcome.better,
            pinned: true,
          ),
          care(
            'two',
            'lower-input',
            DateTime.utc(2026, 7, 4),
            CareOutcome.same,
          ),
          care(
            'three',
            'lower-input',
            DateTime.utc(2026, 7, 7),
            CareOutcome.worse,
          ),
          care(
            'other',
            'different',
            DateTime.utc(2026, 7, 8),
            CareOutcome.better,
            mode: CareMode.heavy,
          ),
        ],
        careReflections: [
          CareReflection(
            id: 'reflection-one',
            careRecordId: 'one',
            mode: CareMode.physical,
            observation: 'The room felt less demanding.',
            need: null,
            whatHelped: null,
            futureSelfNote: null,
            createdAt: DateTime.utc(2026, 7, 1),
            updatedAt: DateTime.utc(2026, 7, 1),
          ),
        ],
      ),
      selectedCareMode: CareMode.physical,
    );
    final action = analysis.supportActions.single;
    expect(action.count, 3);
    expect(action.betterCount, 1);
    expect(action.sameCount, 1);
    expect(action.worseCount, 1);
    expect(action.factualOutcomeSummary, 'Better in 1 of 3 check-backs');
    expect(action.pinned, isTrue);
    expect(action.reflections.single.text, 'The room felt less demanding.');
    expect(action.coveredDates, [
      const LocalDate(2026, 7, 1),
      const LocalDate(2026, 7, 4),
      const LocalDate(2026, 7, 7),
    ]);
  });

  test('fresh analysis removes derived patterns after source deletion', () {
    final first = PatternSourceSnapshot(
      healthRecords: [
        health('one', const LocalDate(2026, 7, 10)),
        health('two', const LocalDate(2026, 7, 11)),
      ],
    );
    expect(engine.analyze(first).symptomPatterns, hasLength(1));
    final afterDelete = PatternSourceSnapshot(
      healthRecords: [first.healthRecords.first],
    );
    expect(engine.analyze(afterDelete).symptomPatterns, isEmpty);
  });
}
