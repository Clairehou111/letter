import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/patterns/domain/pattern_source.dart';
import 'package:letter_mobile/features/patterns/domain/personal_pattern_engine.dart';

const engine = PersonalPatternEngine();

LocalDate _d(int offset) =>
    const LocalDate(2026, 7, 1).addDays(offset);

PeriodRecord _period(int start, {bool open = false}) => PeriodRecord(
  id: 'period-$start',
  startDate: _d(start),
  endDate: open ? null : _d(start).addDays(4),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

HealthRecord _health({
  required String id,
  required SymptomType symptom,
  required SymptomSeverity severity,
  required int day,
  Set<PainLocation> pain = const {},
  Set<FunctionalImpact> impacts = const {},
}) => HealthRecord(
  id: id,
  symptom: symptom,
  severity: severity,
  painRating: pain.isNotEmpty ? 4 : null,
  painLocations: pain,
  functionalImpacts: impacts,
  experiencedDate: _d(day),
  recordedAt: DateTime.utc(2026, 7, 1 + day),
  updatedAt: DateTime.utc(2026, 7, 1 + day),
  provenance: HealthRecordProvenance.sameDay,
  userConfirmed: true,
  vocabularyVersion: 1,
);

void main() {
  group('CORE: empty and minimal', () {
    test('empty source → empty analysis', () {
      final a = engine.analyze(const PatternSourceSnapshot());
      expect(a.isEmpty, isTrue);
    });

    test('single symptom occurrence → no pattern (needs ≥2)', () {
      final a = engine.analyze(PatternSourceSnapshot(
        healthRecords: [
          _health(id: 'h1', symptom: SymptomType.cramps,
              severity: SymptomSeverity.moderate, day: 5),
        ],
        periods: [_period(0), _period(28)],
      ));
      expect(a.symptomPatterns, isEmpty);
    });
  });

  group('CORE: days-before-menses', () {
    test('symptom 3 days before next period → -3', () {
      final a = engine.analyze(PatternSourceSnapshot(
        healthRecords: [
          _health(id: 'h1', symptom: SymptomType.cramps,
              severity: SymptomSeverity.severe, day: 25),
          _health(id: 'h2', symptom: SymptomType.cramps,
              severity: SymptomSeverity.moderate, day: 53),
        ],
        periods: [_period(0), _period(28), _period(56)],
      ));
      expect(a.symptomPatterns.single.count, 2);
      final d25 = a.symptomPatterns.single.cycleDayObservations
          .firstWhere((o) => o.date == _d(25));
      expect(d25.daysBeforeMenses, -3);
    });

    test('no subsequent period → null daysBeforeMenses', () {
      final a = engine.analyze(PatternSourceSnapshot(
        healthRecords: [
          _health(id: 'h1', symptom: SymptomType.lowEnergy,
              severity: SymptomSeverity.mild, day: 5),
          _health(id: 'h2', symptom: SymptomType.lowEnergy,
              severity: SymptomSeverity.severe, day: 20),
        ],
        periods: [_period(0)],
      ));
      expect(a.symptomPatterns.single.cycleDayObservations
          .every((o) => o.daysBeforeMenses == null), isTrue);
    });
  });

  group('CORE: severity matrix', () {
    test('aggregates severity by luteal day correctly', () {
      final a = engine.analyze(PatternSourceSnapshot(
        healthRecords: [
          _health(id: 'h1', symptom: SymptomType.cramps,
              severity: SymptomSeverity.severe, day: 26),   // -2
          _health(id: 'h2', symptom: SymptomType.cramps,
              severity: SymptomSeverity.mild, day: 51),     // -5
          _health(id: 'h3', symptom: SymptomType.cramps,
              severity: SymptomSeverity.extreme, day: 81),  // -3
        ],
        periods: [_period(0), _period(28), _period(56), _period(84)],
      ));
      final matrix = a.symptomPatterns.single.severityByDaysBeforeMenses;
      expect(matrix[-2], closeTo(5.0, 0.1));
      expect(matrix[-5], closeTo(3.0, 0.1));
      expect(matrix[-3], closeTo(6.0, 0.1));
    });

    test('excludes days outside luteal window (-14 to -1)', () {
      final a = engine.analyze(PatternSourceSnapshot(
        healthRecords: [
          _health(id: 'h1', symptom: SymptomType.irritability,
              severity: SymptomSeverity.severe, day: 5),   // early
          _health(id: 'h2', symptom: SymptomType.irritability,
              severity: SymptomSeverity.severe, day: 26),  // -2 (luteal)
        ],
        periods: [_period(0), _period(28), _period(56)],
      ));
      final matrix = a.symptomPatterns.single.severityByDaysBeforeMenses;
      // Day 5 from epoch, next period at 28 → -23, excluded.
      expect(matrix.keys, everyElement(greaterThanOrEqualTo(-14)));
      expect(matrix.keys, everyElement(lessThanOrEqualTo(-1)));
    });
  });

  group('CORE: multi-symptom', () {
    test('cramps + irritability across 3 cycles → 2 patterns', () {
      final a = engine.analyze(PatternSourceSnapshot(
        healthRecords: [
          _health(id: 'c1', symptom: SymptomType.cramps,
              severity: SymptomSeverity.severe, day: 2),
          _health(id: 'c2', symptom: SymptomType.cramps,
              severity: SymptomSeverity.extreme, day: 30),
          _health(id: 'c3', symptom: SymptomType.cramps,
              severity: SymptomSeverity.severe, day: 58),
          _health(id: 'i1', symptom: SymptomType.irritability,
              severity: SymptomSeverity.severe, day: 25),
          _health(id: 'i2', symptom: SymptomType.irritability,
              severity: SymptomSeverity.severe, day: 53),
        ],
        periods: [_period(0), _period(28), _period(56), _period(84)],
      ));
      expect(a.symptomPatterns.length, 2);
      final cramps = a.symptomPatterns
          .firstWhere((p) => p.symptom == SymptomType.cramps);
      final irr = a.symptomPatterns
          .firstWhere((p) => p.symptom == SymptomType.irritability);
      expect(cramps.count, 3);
      expect(irr.count, 2);
      expect(cramps.severityCounts[SymptomSeverity.severe], 2);
      expect(cramps.severityCounts[SymptomSeverity.extreme], 1);
    });
  });

  group('CORE: care actions', () {
    test('grouped by mode+action, sorted by count', () {
      final a = engine.analyze(PatternSourceSnapshot(
        careRecords: [
          CareRecord(
            id: 'a1', mode: CareMode.heavy, actionId: 'quiet',
            actionLabel: 'Quiet presence', outcome: CareOutcome.better,
            occurredAt: DateTime.utc(2026, 7, 10),
            createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026),
            pinned: false,
          ),
          CareRecord(
            id: 'a2', mode: CareMode.heavy, actionId: 'quiet',
            actionLabel: 'Quiet presence', outcome: CareOutcome.same,
            occurredAt: DateTime.utc(2026, 8, 7),
            createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026),
            pinned: false,
          ),
          CareRecord(
            id: 'a3', mode: CareMode.explode, actionId: 'shatter',
            actionLabel: 'Shatter draft', outcome: CareOutcome.better,
            occurredAt: DateTime.utc(2026, 8, 24),
            createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026),
            pinned: false,
          ),
        ],
        periods: [_period(0), _period(28), _period(56)],
      ));
      expect(a.supportActions.length, 2);
      final quiet = a.supportActions.first;
      expect(quiet.count, 2);
      expect(quiet.betterCount, 1);
      expect(quiet.sameCount, 1);
      final shatter = a.supportActions.last;
      expect(shatter.count, 1);
    });
  });

  group('CORE: determinism', () {
    test('same input twice → identical output', () {
      final snapshot = PatternSourceSnapshot(
        healthRecords: [
          _health(id: 'h1', symptom: SymptomType.cramps,
              severity: SymptomSeverity.severe, day: 26),
          _health(id: 'h2', symptom: SymptomType.cramps,
              severity: SymptomSeverity.moderate, day: 54),
        ],
        periods: [_period(0), _period(28), _period(56)],
      );
      final a1 = engine.analyze(snapshot);
      final a2 = engine.analyze(snapshot);
      expect(a1.symptomPatterns.single.count,
          a2.symptomPatterns.single.count);
      expect(a1.symptomPatterns.single.severityByDaysBeforeMenses,
          a2.symptomPatterns.single.severityByDaysBeforeMenses);
    });
  });
}
