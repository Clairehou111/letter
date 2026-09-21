import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/domain/cycle_prediction.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/patterns/domain/pattern_source.dart';
import 'package:letter_mobile/features/patterns/domain/personal_pattern_engine.dart';
import 'package:letter_mobile/features/preparation/domain/preparation_snapshot.dart';
import 'package:letter_mobile/features/preparation/domain/preparation_snapshot_composer.dart';

HealthRecord _health(String id, LocalDate date) {
  final timestamp = DateTime.utc(date.year, date.month, date.day, 12);
  return HealthRecord(
    id: id,
    symptom: SymptomType.cramps,
    severity: SymptomSeverity.moderate,
    functionalImpacts: const {},
    experiencedDate: date,
    recordedAt: timestamp,
    updatedAt: timestamp,
    provenance: HealthRecordProvenance.sameDay,
    userConfirmed: true,
    vocabularyVersion: healthRecordVocabularyVersion,
  );
}

PeriodRecord _period(String id, LocalDate start) {
  final timestamp = DateTime.utc(start.year, start.month, start.day);
  return PeriodRecord(
    id: id,
    startDate: start,
    endDate: start.addDays(4),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

CareRecord _care(
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
    actionLabel: actionId,
    outcome: outcome,
    occurredAt: occurredAt,
    createdAt: occurredAt,
    updatedAt: occurredAt,
    pinned: pinned,
  );
}

CareReflection _note(
  String id,
  String careRecordId,
  String text, {
  CareMode mode = CareMode.physical,
  DateTime? updatedAt,
}) {
  final timestamp = updatedAt ?? DateTime.utc(2026, 4, 1);
  return CareReflection(
    id: id,
    careRecordId: careRecordId,
    mode: mode,
    observation: null,
    need: null,
    whatHelped: null,
    futureSelfNote: text,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

CyclePrediction _prediction() => const CyclePrediction(
  predictedMensesStart: LocalDate(2026, 4, 1),
  predictedMensesEnd: LocalDate(2026, 4, 5),
  midpoint: LocalDate(2026, 4, 3),
  medianCycleDays: 28,
  minimumCycleDays: 27,
  maximumCycleDays: 29,
  intervalCount: 3,
  confidence: PredictionConfidence.medium,
  predictedLutealStart: LocalDate(2026, 3, 16),
  predictedLutealEnd: LocalDate(2026, 4, 4),
);

final _periods = [
  _period('period-1', const LocalDate(2026, 1, 1)),
  _period('period-2', const LocalDate(2026, 1, 29)),
  _period('period-3', const LocalDate(2026, 2, 26)),
  _period('period-4', const LocalDate(2026, 3, 26)),
];

PatternSourceSnapshot _source({
  List<HealthRecord> healthRecords = const [],
  List<CareRecord> careRecords = const [],
  List<CareReflection> careReflections = const [],
  List<PeriodRecord>? periods,
}) => PatternSourceSnapshot(
  healthRecords: healthRecords,
  careRecords: careRecords,
  careReflections: careReflections,
  periods: periods ?? _periods,
);

PreparationComposition _compose(
  PatternSourceSnapshot source, {
  required CyclePrediction? prediction,
  LocalDate today = const LocalDate(2026, 3, 20),
}) {
  final patterns = const PersonalPatternEngine().analyze(source);
  return const PreparationSnapshotComposer().compose(
    source: source,
    patterns: patterns,
    prediction: prediction,
    today: today,
  );
}

void main() {
  test('is unavailable with fewer than two completed cycles', () {
    final source = _source(
      periods: [
        _period('period-1', const LocalDate(2026, 1, 1)),
        _period('period-2', const LocalDate(2026, 1, 29)),
      ],
      healthRecords: [_health('symptom-1', const LocalDate(2026, 1, 10))],
    );

    final result = _compose(source, prediction: _prediction());

    expect(result.isAvailable, isFalse);
    expect(
      result.availability,
      PreparationAvailability.insufficientCycleHistory,
    );
  });

  test('timing remains available when symptoms do not recur', () {
    final source = _source(
      healthRecords: [
        _health('symptom-1', const LocalDate(2026, 1, 10)),
        _health('symptom-2', const LocalDate(2026, 1, 11)),
        _health('symptom-3', const LocalDate(2026, 1, 12)),
      ],
    );

    final result = _compose(source, prediction: _prediction());

    expect(result.isAvailable, isTrue);
    expect(result.snapshot!.observation, isNull);
  });

  test('two distinct completed cycles produce an early pattern', () {
    final source = _source(
      periods: _periods.sublist(0, 3),
      healthRecords: [
        _health('symptom-1', const LocalDate(2026, 1, 10)),
        _health('symptom-2', const LocalDate(2026, 2, 8)),
      ],
    );

    final result = _compose(source, prediction: _prediction());

    expect(result.isAvailable, isTrue);
    expect(
      result.snapshot!.observation!.strength,
      PreparationPatternStrength.early,
    );
    expect(result.snapshot!.observation!.distinctCompletedCycles, 2);
    expect(result.snapshot!.observation!.recordCount, 2);
  });

  test('three distinct completed cycles produce a repeated pattern', () {
    final source = _source(
      healthRecords: [
        _health('symptom-1', const LocalDate(2026, 1, 10)),
        _health('symptom-2', const LocalDate(2026, 2, 8)),
        _health('symptom-3', const LocalDate(2026, 3, 7)),
      ],
    );

    final result = _compose(source, prediction: _prediction());

    expect(result.isAvailable, isTrue);
    expect(
      result.snapshot!.observation!.strength,
      PreparationPatternStrength.repeated,
    );
    expect(result.snapshot!.observation!.distinctCompletedCycles, 3);
  });

  test('is unavailable when prediction is null or its estimate has passed', () {
    final source = _source(
      healthRecords: [
        _health('symptom-1', const LocalDate(2026, 1, 10)),
        _health('symptom-2', const LocalDate(2026, 2, 8)),
      ],
    );

    final noEstimate = _compose(source, prediction: null);
    expect(
      noEstimate.availability,
      PreparationAvailability.estimateUnavailable,
    );

    final passed = _compose(
      source,
      prediction: _prediction(),
      today: const LocalDate(2026, 4, 6),
    );
    expect(passed.availability, PreparationAvailability.estimateHasPassed);
  });

  test('ranks pinned actions before outcome and recency', () {
    final source = _source(
      healthRecords: [
        _health('symptom-1', const LocalDate(2026, 1, 10)),
        _health('symptom-2', const LocalDate(2026, 2, 8)),
      ],
      careRecords: [
        _care(
          'pinned-worse',
          'pinned-worse',
          DateTime.utc(2026, 3, 10),
          CareOutcome.worse,
          pinned: true,
        ),
        _care(
          'better',
          'better',
          DateTime.utc(2026, 3, 20),
          CareOutcome.better,
        ),
      ],
    );

    final result = _compose(source, prediction: _prediction());

    expect(result.snapshot!.care!.actionId, 'pinned-worse');
    expect(result.snapshot!.care!.pinned, isTrue);
  });

  test(
    'ranks Better before same or unknown, then evidence count and recency',
    () {
      final source = _source(
        healthRecords: [
          _health('symptom-1', const LocalDate(2026, 1, 10)),
          _health('symptom-2', const LocalDate(2026, 2, 8)),
        ],
        careRecords: [
          _care(
            'same-1',
            'same-action',
            DateTime.utc(2026, 3, 25),
            CareOutcome.same,
          ),
          _care(
            'same-2',
            'same-action',
            DateTime.utc(2026, 3, 26),
            CareOutcome.same,
          ),
          _care(
            'better-1',
            'better-action',
            DateTime.utc(2026, 3, 1),
            CareOutcome.better,
          ),
        ],
      );

      final betterResult = _compose(source, prediction: _prediction());
      expect(betterResult.snapshot!.care!.actionId, 'better-action');

      final tiedEvidence = _source(
        healthRecords: [
          _health('symptom-1', const LocalDate(2026, 1, 10)),
          _health('symptom-2', const LocalDate(2026, 2, 8)),
        ],
        careRecords: [
          _care(
            'older-1',
            'older-action',
            DateTime.utc(2026, 3, 1),
            CareOutcome.better,
          ),
          _care(
            'older-2',
            'older-action',
            DateTime.utc(2026, 3, 2),
            CareOutcome.better,
          ),
          _care(
            'newer-1',
            'newer-action',
            DateTime.utc(2026, 3, 10),
            CareOutcome.better,
          ),
          _care(
            'newer-2',
            'newer-action',
            DateTime.utc(2026, 3, 20),
            CareOutcome.better,
          ),
        ],
      );

      final tiedResult = _compose(tiedEvidence, prediction: _prediction());
      expect(tiedResult.snapshot!.care!.actionId, 'newer-action');
    },
  );

  test('future note must match the chosen action and Care mode', () {
    final source = _source(
      healthRecords: [
        _health('symptom-1', const LocalDate(2026, 1, 10)),
        _health('symptom-2', const LocalDate(2026, 2, 8)),
      ],
      careRecords: [
        _care(
          'chosen',
          'chosen-action',
          DateTime.utc(2026, 3, 20),
          CareOutcome.better,
          mode: CareMode.heavy,
          pinned: true,
        ),
        _care(
          'other',
          'other-action',
          DateTime.utc(2026, 3, 21),
          CareOutcome.better,
          mode: CareMode.physical,
        ),
      ],
      careReflections: [
        _note('wrong-record', 'other', 'Wrong action.'),
        _note('wrong-mode', 'chosen', 'Wrong mode.', mode: CareMode.physical),
        _note(
          'matching',
          'chosen',
          'Return to one small response.',
          mode: CareMode.heavy,
        ),
      ],
    );

    final result = _compose(source, prediction: _prediction());

    expect(result.snapshot!.care!.actionId, 'chosen-action');
    expect(result.snapshot!.care!.mode, CareMode.heavy);
    expect(result.snapshot!.futureNote!.text, 'Return to one small response.');
    expect(result.snapshot!.futureNote!.mode, CareMode.heavy);
    expect(result.snapshot!.futureNote!.careRecordId, 'chosen');
  });

  test('allows no action and no future note when Care evidence is absent', () {
    final source = _source(
      healthRecords: [
        _health('symptom-1', const LocalDate(2026, 1, 10)),
        _health('symptom-2', const LocalDate(2026, 2, 8)),
      ],
    );

    final result = _compose(source, prediction: _prediction());

    expect(result.isAvailable, isTrue);
    expect(result.snapshot!.care, isNull);
    expect(result.snapshot!.futureNote, isNull);
  });
}
