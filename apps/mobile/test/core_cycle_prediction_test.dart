import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/cycle_prediction.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';

LocalDate _date(int offset) =>
    const LocalDate(2026, 1, 1).addDays(offset);

PeriodRecord _p(int start, {bool open = false}) => PeriodRecord(
  id: 'p$start',
  startDate: _date(start),
  endDate: open ? null : _date(start).addDays(4),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  group('CORE: regular 28-day cycle', () {
    test('5 periods → high confidence, midpoint at last+median', () {
      final p = CyclePredictionEngine.calculate([
        _p(0), _p(28), _p(56), _p(84), _p(112),
      ])!;
      expect(p.intervalCount, 4);
      expect(p.medianCycleDays, 28);
      expect(p.observedSpreadDays, 0);
      expect(p.confidence, PredictionConfidence.higher);
      expect(p.midpoint, _date(140));
    });
  });

  group('CORE: irregular cycles', () {
    test('24-38 day spread → low confidence', () {
      final p = CyclePredictionEngine.calculate([
        _p(0), _p(28), _p(56), _p(80), _p(118),
      ])!;
      expect(p.minimumCycleDays, 24);
      expect(p.maximumCycleDays, 38);
      expect(p.hasWideVariation, isTrue);
      expect(p.confidence, PredictionConfidence.low);
    });
  });

  group('CORE: outlier filtering', () {
    test('15-day stress cycle excluded', () {
      final p = CyclePredictionEngine.calculate([
        _p(0), _p(28), _p(56), _p(71), _p(99), _p(127),
      ])!;
      expect(p.intervalCount, 4);
      expect(p.medianCycleDays, 28);
      expect(p.confidence, PredictionConfidence.higher);
    });

    test('all intervals below 21 days → returns null (no usable data)', () {
      final p = CyclePredictionEngine.calculate([
        _p(0), _p(19), _p(38), _p(57),
      ]);
      // Intervals: 19, 19, 19 — all below 21 → all filtered out.
      // filtered < minimumIntervals AND filtered < raw → guard triggers.
      expect(p, isNull);
    });

    test('only one valid interval after filtering → null', () {
      final p = CyclePredictionEngine.calculate([
        _p(0), _p(19), _p(39),
      ]);
      // Intervals: 19 (< 21 dropped), 20 (< 21 dropped).
      // filtered=0, raw=2 → guard triggers → null.
      expect(p, isNull);
    });

    test('two valid intervals survive filtering → still produces prediction', () {
      final p = CyclePredictionEngine.calculate([
        _p(0), _p(19), _p(41), _p(64),
      ]);
      // Intervals: 19 (< 21 dropped), 22 (valid), 23 (valid).
      // filtered=2 ≥ minimumIntervals=2 → prediction produced.
      expect(p, isNotNull);
      expect(p!.intervalCount, 2);
    });

    test('60-day missed cycle excluded', () {
      final p = CyclePredictionEngine.calculate([
        _p(0), _p(28), _p(56), _p(116), _p(144), _p(172),
      ])!;
      expect(p.intervalCount, 4);
    });

    test('20-day excluded (<21), 42-day kept (≤45, ≤1.5×median)', () {
      final p = CyclePredictionEngine.calculate([
        _p(0), _p(20), _p(48), _p(76), _p(118),
      ])!;
      expect(p.intervalCount, 3);
      expect(p.maximumCycleDays, 42);
    });
  });

  group('CORE: luteal window invariant', () {
    test('luteal = mensesStart-16 to mensesEnd-1', () {
      final p = CyclePredictionEngine.calculate([
        _p(0), _p(28), _p(56), _p(84),
      ])!;
      final luteal = p.lutealWindow;
      expect(luteal.rangeStart.epochDay,
          p.predictedMensesStart.epochDay - 16);
      expect(luteal.rangeEnd.epochDay,
          p.predictedMensesEnd.epochDay - 1);
      expect(luteal.contains(luteal.midpoint), isTrue);
      expect(luteal.contains(luteal.rangeStart.addDays(-1)), isFalse);
    });
  });

  group('CORE: confidence progression', () {
    test('3 intervals → medium, 4 tight → higher', () {
      final med = CyclePredictionEngine.calculate([
        _p(0), _p(28), _p(56), _p(84),
      ])!;
      expect(med.confidence, PredictionConfidence.medium);
      final hi = CyclePredictionEngine.calculate([
        _p(0), _p(28), _p(57), _p(85), _p(113),
      ])!;
      expect(hi.confidence, PredictionConfidence.higher);
    });
  });

  group('CORE: edge cases', () {
    test('empty → null', () =>
        expect(CyclePredictionEngine.calculate([]), isNull));
    test('one period → null', () =>
        expect(CyclePredictionEngine.calculate([_p(0)]), isNull));
    test('two periods → null', () =>
        expect(CyclePredictionEngine.calculate([_p(0), _p(28)]), isNull));
    test('open period anchors from its start', () {
      final p = CyclePredictionEngine.calculate([
        _p(0), _p(28), _p(56), _p(84, open: true),
      ])!;
      expect(p.intervalCount, 3);
      expect(p.midpoint.epochDay, greaterThan(_date(84).epochDay));
    });
  });

  group('CORE: timing', () {
    test('upcoming / current / later', () {
      final p = CyclePredictionEngine.calculate([
        _p(0), _p(28), _p(56), _p(84),
      ])!;
      expect(p.timingFor(p.predictedMensesStart.addDays(-10)),
          PredictionTiming.upcoming);
      expect(p.timingFor(p.midpoint),
          PredictionTiming.currentWindow);
      expect(p.timingFor(p.predictedMensesEnd.addDays(10)),
          PredictionTiming.laterThanEstimate);
    });
  });
}
