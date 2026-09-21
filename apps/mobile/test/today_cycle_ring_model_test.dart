import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/cycle_prediction.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/today/today_cycle_ring_model.dart';

PeriodRecord _period(int day, {int duration = 5, bool open = false}) =>
    PeriodRecord(
      id: 'p$day',
      startDate: const LocalDate(2026, 1, 1).addDays(day),
      endDate: open
          ? null
          : const LocalDate(2026, 1, 1).addDays(day + duration - 1),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  test('regular 28-day history produces the familiar four-part ring', () {
    final model = TodayCycleRingModel.fromRecords(
      records: [_period(0), _period(28), _period(56), _period(84)],
      today: const LocalDate(2026, 1, 1).addDays(101),
    );

    expect(model.displayCycleDays, 28);
    expect(model.currentDay, 18);
    expect(model.estimatedOvulationCenterDay, 14);
    expect(
      model.segments.map((segment) => segment.phase),
      CycleRingPhase.values,
    );
    expect(model.segmentFor(CycleRingPhase.period)!.startDay, 1);
    expect(model.segmentFor(CycleRingPhase.period)!.endDay, 5);
    expect(model.segmentFor(CycleRingPhase.follicular)!.startDay, 6);
    expect(model.segmentFor(CycleRingPhase.estimatedOvulation)!.startDay, 13);
    expect(model.segmentFor(CycleRingPhase.estimatedOvulation)!.endDay, 15);
    expect(model.currentPhase, CycleRingPhase.luteal);
  });

  test('observed period is distinct from estimated segments', () {
    final model = TodayCycleRingModel.fromRecords(
      records: [_period(0), _period(30), _period(60), _period(90)],
      today: const LocalDate(2026, 1, 1).addDays(92),
    );

    expect(model.currentPhase, CycleRingPhase.period);
    expect(
      model.segmentFor(CycleRingPhase.period)!.certainty,
      CycleRingCertainty.observed,
    );
    expect(
      model.segments
          .where((segment) => segment.phase != CycleRingPhase.period)
          .every(
            (segment) => segment.certainty == CycleRingCertainty.estimated,
          ),
      isTrue,
    );
  });

  test('irregular history keeps the ring but exposes limited confidence', () {
    final model = TodayCycleRingModel.fromRecords(
      records: [
        _period(0),
        _period(28),
        _period(56),
        _period(80),
        _period(118),
      ],
      today: const LocalDate(2026, 1, 1).addDays(125),
    );

    expect(model.predictionConfidence, PredictionConfidence.low);
    expect(model.hasLimitedEstimate, isTrue);
    expect(model.segments, hasLength(4));
  });

  test('one observed interval supplies a clearly limited early ring', () {
    final model = TodayCycleRingModel.fromRecords(
      records: [_period(0), _period(28)],
      today: const LocalDate(2026, 1, 1).addDays(32),
    );

    expect(model.currentDay, 5);
    expect(model.hasLimitedEstimate, isTrue);
    expect(model.segments, hasLength(4));
  });

  test('late cycle extends the display instead of losing Today marker', () {
    final model = TodayCycleRingModel.fromRecords(
      records: [_period(0), _period(28), _period(56), _period(84)],
      today: const LocalDate(2026, 1, 1).addDays(115),
    );

    expect(model.currentDay, 32);
    expect(model.displayCycleDays, 32);
    expect(model.currentPhase, CycleRingPhase.luteal);
  });

  test('an open period remains observed through today, even when long', () {
    final model = TodayCycleRingModel.fromRecords(
      records: [_period(0), _period(28), _period(56), _period(84, open: true)],
      today: const LocalDate(2026, 1, 1).addDays(99),
    );

    expect(model.currentDay, 16);
    expect(model.segmentFor(CycleRingPhase.period)!.endDay, 16);
    expect(model.currentPhase, CycleRingPhase.period);
    expect(
      model.segmentFor(CycleRingPhase.period)!.certainty,
      CycleRingCertainty.observed,
    );
  });

  test('short cycles and long bleeding still produce four valid segments', () {
    final model = TodayCycleRingModel.fromRecords(
      records: [
        _period(0, duration: 14),
        _period(15, duration: 14),
        _period(30, duration: 14),
        _period(45, duration: 14),
      ],
      today: const LocalDate(2026, 1, 1).addDays(58),
    );

    expect(
      model.segments.map((segment) => segment.phase),
      CycleRingPhase.values,
    );
    expect(model.segments.every((segment) => segment.dayCount > 0), isTrue);
    expect(model.displayCycleDays, greaterThanOrEqualTo(19));
  });
}
