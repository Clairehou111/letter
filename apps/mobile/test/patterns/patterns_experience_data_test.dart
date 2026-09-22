import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/cycle/domain/bleeding_flow.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/patterns/domain/pattern_source.dart';
import 'package:letter_mobile/features/patterns/domain/patterns_experience_data.dart';
import 'package:letter_mobile/features/patterns/presentation/patterns_experience_screen.dart';

const _today = LocalDate(2026, 8, 16);
const _builder = PatternsExperienceDataBuilder();

PeriodRecord _period(String id, LocalDate start, {LocalDate? end}) {
  final timestamp = DateTime.utc(start.year, start.month, start.day);
  return PeriodRecord(
    id: id,
    startDate: start,
    endDate: end,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

BleedingDayRecord _flow(
  String periodId,
  LocalDate date,
  BleedingFlow flow, {
  BleedingColor? color,
}) {
  final timestamp = DateTime.utc(date.year, date.month, date.day);
  return BleedingDayRecord(
    periodId: periodId,
    date: date,
    flow: flow,
    color: color,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

HealthRecord _symptom(
  String id,
  LocalDate date,
  SymptomType symptom,
  SymptomSeverity severity, {
  bool confirmed = true,
  DateTime? updatedAt,
}) {
  final timestamp = updatedAt ?? DateTime.utc(date.year, date.month, date.day);
  return HealthRecord(
    id: id,
    symptom: symptom,
    severity: severity,
    functionalImpacts: const {},
    experiencedDate: date,
    recordedAt: timestamp,
    updatedAt: timestamp,
    provenance: HealthRecordProvenance.sameDay,
    userConfirmed: confirmed,
    vocabularyVersion: healthRecordVocabularyVersion,
  );
}

CareRecord _care(String id, LocalDate date, CareOutcome outcome) {
  final timestamp = DateTime.utc(date.year, date.month, date.day, 12);
  return CareRecord(
    id: id,
    mode: CareMode.physical,
    actionId: 'warmth',
    actionLabel: 'Warmth (heating pad)',
    outcome: outcome,
    occurredAt: timestamp,
    createdAt: timestamp,
    updatedAt: timestamp,
    pinned: false,
  );
}

void main() {
  test('zero starts stays empty and never invents a report range', () {
    final data = _builder.build(
      PatternSourceSnapshot(
        healthRecords: [
          _symptom(
            'unanchored',
            const LocalDate(2026, 8, 12),
            SymptomType.cramps,
            SymptomSeverity.severe,
          ),
        ],
      ),
      today: _today,
    );

    expect(data.hasAnyPeriodHistory, isFalse);
    expect(data.completedCycles, isEmpty);
    expect(data.currentCycle, isNull);
    expect(data.firstIncludedDate, isNull);
    expect(data.symptoms, isEmpty);
  });

  test('one start has a current cycle but no fabricated completed cycle', () {
    final data = _builder.build(
      PatternSourceSnapshot(
        periods: [_period('aug', const LocalDate(2026, 8, 10))],
        flowDays: [
          _flow(
            'aug',
            const LocalDate(2026, 8, 10),
            BleedingFlow.heavy,
            color: BleedingColor.brightRed,
          ),
        ],
        healthRecords: [
          _symptom(
            'mood',
            const LocalDate(2026, 8, 12),
            SymptomType.lowMood,
            SymptomSeverity.moderate,
          ),
        ],
      ),
      today: _today,
    );

    expect(data.completedCycles, isEmpty);
    expect(data.currentCycle?.periodId, 'aug');
    expect(data.currentCycle?.flowDays, hasLength(1));
    expect(data.symptoms.single.category, PatternsSymptomCategory.emotions);
  });

  test(
    'uses the last six observed intervals and retains an abnormal interval',
    () {
      final starts = [
        const LocalDate(2026, 1, 1),
        const LocalDate(2026, 1, 29),
        const LocalDate(2026, 2, 26),
        const LocalDate(2026, 3, 26),
        const LocalDate(2026, 5, 15), // 50-day interval: intentionally kept.
        const LocalDate(2026, 6, 12),
        const LocalDate(2026, 7, 10),
        const LocalDate(2026, 8, 7),
      ];
      final periods = [
        for (var index = 0; index < starts.length; index++)
          _period('p$index', starts[index]),
      ];
      final data = _builder.build(
        PatternSourceSnapshot(periods: periods),
        today: _today,
      );

      expect(data.completedCycles, hasLength(6));
      expect(
        data.completedCycles.first.startDate,
        const LocalDate(2026, 1, 29),
      );
      expect(data.completedCycles.map((cycle) => cycle.lengthDays), [
        28,
        28,
        50,
        28,
        28,
        28,
      ]);
      expect(data.currentCycle?.startDate, const LocalDate(2026, 8, 7));
      expect(data.firstIncludedDate, const LocalDate(2026, 1, 29));
      expect(data.lastIncludedDate, const LocalDate(2026, 8, 6));
    },
  );

  test('cross-cycle analysis excludes records from the current cycle', () {
    final data = _builder.build(
      PatternSourceSnapshot(
        periods: [
          _period('july', const LocalDate(2026, 7, 1)),
          _period('august', const LocalDate(2026, 7, 29)),
        ],
        healthRecords: [
          _symptom(
            'completed-cycle',
            const LocalDate(2026, 7, 20),
            SymptomType.cramps,
            SymptomSeverity.moderate,
          ),
          _symptom(
            'current-cycle',
            const LocalDate(2026, 8, 10),
            SymptomType.headache,
            SymptomSeverity.severe,
          ),
        ],
        careRecords: [
          _care(
            'current-care',
            const LocalDate(2026, 8, 10),
            CareOutcome.better,
          ),
        ],
      ),
      today: _today,
    );

    expect(data.lastIncludedDate, const LocalDate(2026, 7, 28));
    expect(data.symptoms.map((record) => record.id), ['completed-cycle']);
    expect(data.care, isEmpty);
  });

  test('keeps only explicit flow days and their optional colors', () {
    final data = _builder.build(
      PatternSourceSnapshot(
        periods: [
          _period('july', const LocalDate(2026, 7, 1)),
          _period('august', const LocalDate(2026, 7, 29)),
        ],
        flowDays: [
          _flow('july', const LocalDate(2026, 7, 1), BleedingFlow.light),
          _flow(
            'july',
            const LocalDate(2026, 7, 3),
            BleedingFlow.heavy,
            color: BleedingColor.brown,
          ),
        ],
      ),
      today: _today,
    );

    final flow = data.completedCycles.single.flowDays;
    expect(flow.map((day) => day.date), [
      const LocalDate(2026, 7, 1),
      const LocalDate(2026, 7, 3),
    ]);
    expect(flow.first.color, isNull);
    expect(flow.last.color, BleedingColor.brown);
  });

  test('period dates retain bleeding days when no flow detail was saved', () {
    final data = _builder.build(
      PatternSourceSnapshot(
        periods: [
          _period(
            'june',
            const LocalDate(2026, 6, 2),
            end: const LocalDate(2026, 6, 8),
          ),
          _period('july', const LocalDate(2026, 7, 8)),
        ],
      ),
      today: _today,
    );

    final cycle = data.completedCycles.single;
    expect(cycle.flowDays, isEmpty);
    expect(cycle.bleedingDates, [
      const LocalDate(2026, 6, 2),
      const LocalDate(2026, 6, 3),
      const LocalDate(2026, 6, 4),
      const LocalDate(2026, 6, 5),
      const LocalDate(2026, 6, 6),
      const LocalDate(2026, 6, 7),
      const LocalDate(2026, 6, 8),
    ]);
    expect(cycle.flowFor(const LocalDate(2026, 6, 4)), isNull);
    expect(
      phaseLabel(data, const LocalDate(2026, 6, 4).epochDay),
      'Bleeding day 3 · Cycle 1',
    );
  });

  test('ignores flow entries outside the recorded period range', () {
    final data = _builder.build(
      PatternSourceSnapshot(
        periods: [
          _period(
            'june',
            const LocalDate(2026, 6, 2),
            end: const LocalDate(2026, 6, 8),
          ),
          _period('july', const LocalDate(2026, 7, 8)),
        ],
        flowDays: [
          _flow('june', const LocalDate(2026, 6, 5), BleedingFlow.medium),
          _flow('june', const LocalDate(2026, 6, 9), BleedingFlow.heavy),
        ],
      ),
      today: _today,
    );

    expect(data.completedCycles.single.flowDays.map((entry) => entry.date), [
      const LocalDate(2026, 6, 5),
    ]);
  });

  test(
    'deduplicates same-day symptom revisions and keeps low-severity detail',
    () {
      final data = _builder.build(
        PatternSourceSnapshot(
          periods: [
            _period('july', const LocalDate(2026, 7, 1)),
            _period('august', const LocalDate(2026, 7, 29)),
          ],
          healthRecords: [
            _symptom(
              'old-cramps',
              const LocalDate(2026, 7, 2),
              SymptomType.cramps,
              SymptomSeverity.minimal,
            ),
            _symptom(
              'new-cramps',
              const LocalDate(2026, 7, 2),
              SymptomType.cramps,
              SymptomSeverity.severe,
              updatedAt: DateTime.utc(2026, 7, 3),
            ),
            _symptom(
              'fatigue',
              const LocalDate(2026, 7, 18),
              SymptomType.fatigue,
              SymptomSeverity.mild,
            ),
            _symptom(
              'not-confirmed',
              const LocalDate(2026, 7, 20),
              SymptomType.lowMood,
              SymptomSeverity.severe,
              confirmed: false,
            ),
          ],
        ),
        today: _today,
      );

      expect(data.symptoms, hasLength(2));
      expect(data.symptoms.first.id, 'new-cramps');
      expect(data.symptoms.first.isHeavier, isTrue);
      expect(
        data.symptoms.last.category,
        PatternsSymptomCategory.energyAndSleep,
      );
      expect(data.symptoms.last.isHeavier, isFalse);
    },
  );

  test(
    'uses only Today check-ins for moods and keeps them distinct from symptoms',
    () {
      final timestamp = DateTime.utc(2026, 7, 2, 12);
      final data = _builder.build(
        PatternSourceSnapshot(
          periods: [
            _period('july', const LocalDate(2026, 7, 1)),
            _period('august', const LocalDate(2026, 7, 29)),
          ],
          momentCheckIns: [
            MomentCheckIn(
              id: 'duplicate-good',
              state: MomentCheckInState.good,
              occurredAt: timestamp,
              createdAt: timestamp,
            ),
            MomentCheckIn(
              id: 'calm',
              state: MomentCheckInState.calm,
              occurredAt: DateTime.utc(2026, 7, 3, 12),
              createdAt: DateTime.utc(2026, 7, 3, 12),
            ),
            MomentCheckIn(
              id: 'physical-only',
              state: MomentCheckInState.physical,
              occurredAt: DateTime.utc(2026, 7, 4, 12),
              createdAt: DateTime.utc(2026, 7, 4, 12),
            ),
          ],
        ),
        today: _today,
      );

      expect(data.symptoms, isEmpty);
      expect(data.moods.map((mood) => mood.label), [
        'Good',
        'Calm',
        'Physical',
      ]);
      expect(data.moods.map((mood) => mood.tone), [
        PatternsMoodTone.positive,
        PatternsMoodTone.positive,
        PatternsMoodTone.difficult,
      ]);
      expect(data.moods.last.harderCategory, PatternsSymptomCategory.otherBody);
    },
  );

  test('newest same-day check-in is the one Patterns reads', () {
    final data = _builder.build(
      PatternSourceSnapshot(
        periods: [
          _period('july', const LocalDate(2026, 7, 1)),
          _period('august', const LocalDate(2026, 7, 29)),
        ],
        momentCheckIns: [
          MomentCheckIn(
            id: 'earlier',
            state: MomentCheckInState.low,
            occurredAt: DateTime.utc(2026, 7, 5, 8),
            createdAt: DateTime.utc(2026, 7, 5, 8),
          ),
          MomentCheckIn(
            id: 'latest',
            state: MomentCheckInState.calm,
            occurredAt: DateTime.utc(2026, 7, 5, 12),
            createdAt: DateTime.utc(2026, 7, 5, 12),
          ),
        ],
      ),
      today: _today,
    );

    expect(data.moods, hasLength(1));
    expect(data.moods.single.label, 'Calm');
    expect(data.moods.single.isHarder, isFalse);
  });

  test(
    'all saved symptoms and difficult or physical moods count as harder',
    () {
      final data = _builder.build(
        PatternSourceSnapshot(
          periods: [
            _period('july', const LocalDate(2026, 7, 1)),
            _period('august', const LocalDate(2026, 7, 29)),
          ],
          healthRecords: [
            _symptom(
              'minimal-cramps',
              const LocalDate(2026, 7, 2),
              SymptomType.cramps,
              SymptomSeverity.minimal,
            ),
          ],
          momentCheckIns: [
            MomentCheckIn(
              id: 'low-same-day',
              state: MomentCheckInState.low,
              occurredAt: DateTime.utc(2026, 7, 2, 12),
              createdAt: DateTime.utc(2026, 7, 2, 12),
            ),
            MomentCheckIn(
              id: 'physical',
              state: MomentCheckInState.physical,
              occurredAt: DateTime.utc(2026, 7, 3, 12),
              createdAt: DateTime.utc(2026, 7, 3, 12),
            ),
            MomentCheckIn(
              id: 'good',
              state: MomentCheckInState.good,
              occurredAt: DateTime.utc(2026, 7, 4, 12),
              createdAt: DateTime.utc(2026, 7, 4, 12),
            ),
          ],
        ),
        today: _today,
      );

      final cycle = data.completedCycles.single;
      expect(harderEpochsIn(data, cycle), {
        const LocalDate(2026, 7, 2).epochDay,
        const LocalDate(2026, 7, 3).epochDay,
      });
      expect(categoryDays(data)[PatternsSymptomCategory.pain], {
        const LocalDate(2026, 7, 2).epochDay,
      });
      expect(categoryDays(data)[PatternsSymptomCategory.emotions], {
        const LocalDate(2026, 7, 2).epochDay,
      });
      expect(categoryDays(data)[PatternsSymptomCategory.otherBody], {
        const LocalDate(2026, 7, 3).epochDay,
      });
    },
  );

  test(
    'uses only in-range Care records and joins authored reflection text',
    () {
      final care = _care(
        'care-in',
        const LocalDate(2026, 7, 3),
        CareOutcome.better,
      );
      final data = _builder.build(
        PatternSourceSnapshot(
          periods: [
            _period('july', const LocalDate(2026, 7, 1)),
            _period('august', const LocalDate(2026, 7, 29)),
          ],
          careRecords: [
            _care('care-old', const LocalDate(2026, 6, 20), CareOutcome.same),
            care,
          ],
          careReflections: [
            CareReflection(
              id: 'reflection',
              careRecordId: care.id,
              mode: CareMode.physical,
              observation: 'Twenty quiet minutes.',
              need: null,
              whatHelped: 'The warmth stayed gentle.',
              futureSelfNote: null,
              createdAt: DateTime.utc(2026, 7, 3),
              updatedAt: DateTime.utc(2026, 7, 3),
            ),
          ],
        ),
        today: _today,
      );

      expect(data.care, hasLength(1));
      expect(data.care.single.id, 'care-in');
      expect(
        data.care.single.reflection,
        'Twenty quiet minutes. The warmth stayed gentle.',
      );
    },
  );
}
