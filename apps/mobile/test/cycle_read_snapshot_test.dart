import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/cycle_prediction.dart';
import 'package:letter_mobile/features/cycle/domain/cycle_read_snapshot.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';

PeriodRecord _period(String id, LocalDate start, {LocalDate? end}) =>
    PeriodRecord(
      id: id,
      startDate: start,
      endDate: end,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  test(
    'latest start remains current after bleeding ends until another start',
    () {
      const today = LocalDate(2026, 8, 15);
      final snapshot = CycleReadSnapshot.fromRecords(
        today: today,
        records: [
          _period(
            'previous',
            const LocalDate(2026, 7, 8),
            end: const LocalDate(2026, 7, 13),
          ),
          _period('current', const LocalDate(2026, 8, 13), end: today),
        ],
      );

      expect(snapshot.currentCycle!.period.id, 'current');
      expect(snapshot.currentCycle!.cycleDay, 3);
      expect(snapshot.currentCycle!.bleedingState, BleedingState.endedToday);
      expect(snapshot.completedCyclesNewestFirst.single.period.id, 'previous');
    },
  );

  test('a later start completes the previous current cycle', () {
    const today = LocalDate(2026, 9, 18);
    final snapshot = CycleReadSnapshot.fromRecords(
      today: today,
      records: [
        _period(
          'july',
          const LocalDate(2026, 7, 8),
          end: const LocalDate(2026, 7, 13),
        ),
        _period(
          'august',
          const LocalDate(2026, 8, 13),
          end: const LocalDate(2026, 8, 15),
        ),
        _period('september', today),
      ],
    );

    expect(snapshot.currentCycle!.period.id, 'september');
    expect(snapshot.completedCyclesNewestFirst.first.period.id, 'august');
    expect(snapshot.completedCyclesNewestFirst.first.cycleLengthDays, 36);
  });

  test('a one-day period can start and end today without a third state', () {
    const today = LocalDate(2026, 8, 15);
    final snapshot = CycleReadSnapshot.fromRecords(
      today: today,
      records: [_period('same-day', today, end: today)],
    );

    final current = snapshot.currentCycle!;
    expect(current.startedToday, isTrue);
    expect(current.endedToday, isTrue);
    expect(current.bleedingState, BleedingState.endedToday);
  });

  test('future archive records never affect today or estimate evidence', () {
    const today = LocalDate(2026, 8, 15);
    final snapshot = CycleReadSnapshot.fromRecords(
      today: today,
      records: [
        _period('july', const LocalDate(2026, 7, 8)),
        _period('august', const LocalDate(2026, 8, 13)),
        _period('future', const LocalDate(2026, 10, 1)),
      ],
    );

    expect(snapshot.archivePeriodsNewestFirst.first.id, 'future');
    expect(snapshot.currentCycle!.period.id, 'august');
    expect(snapshot.predictionEvidence.candidateStartsNewestFirst, [
      const LocalDate(2026, 8, 13),
      const LocalDate(2026, 7, 8),
    ]);
    expect(snapshot.predictionEvidence.kind, PredictionEstimateKind.early);
  });
}
