import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/cycle_prediction.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';

LocalDate _date(int offset) => const LocalDate(2026, 1, 1).addDays(offset);

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
        _p(0),
        _p(28),
        _p(56),
        _p(84),
        _p(112),
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
        _p(0),
        _p(28),
        _p(56),
        _p(80),
        _p(118),
      ])!;
      expect(p.minimumCycleDays, 24);
      expect(p.maximumCycleDays, 38);
      expect(p.hasWideVariation, isTrue);
      expect(p.confidence, PredictionConfidence.low);
    });
  });

  group('CORE: outlier filtering', () {
    test(
      '15-day interval is excluded when it differs from a 28-day baseline',
      () {
        final p = CyclePredictionEngine.calculate([
          _p(0),
          _p(28),
          _p(56),
          _p(71),
          _p(99),
          _p(127),
        ])!;
        expect(p.intervalCount, 4);
        expect(p.medianCycleDays, 28);
        expect(p.excludedIntervalCount, 1);
        expect(p.confidence, PredictionConfidence.medium);
      },
    );

    test('stable 19-day history uses the user baseline', () {
      final p = CyclePredictionEngine.calculate([
        _p(0),
        _p(19),
        _p(38),
        _p(57),
      ]);
      expect(p, isNotNull);
      expect(p!.medianCycleDays, 19);
      expect(p.intervalCount, 3);
    });

    test('intervals below the broad data-quality floor return null', () {
      final p = CyclePredictionEngine.calculate([_p(0), _p(14), _p(28)]);
      expect(p, isNull);
    });

    test(
      'two valid intervals survive filtering → still produces prediction',
      () {
        final p = CyclePredictionEngine.calculate([
          _p(0),
          _p(10),
          _p(32),
          _p(55),
        ]);
        // Intervals: 10 (invalid), 22 and 23 (consistent).
        // filtered=2 ≥ minimumIntervals=2 → prediction produced.
        expect(p, isNotNull);
        expect(p!.intervalCount, 2);
      },
    );

    test('60-day missed cycle excluded', () {
      final p = CyclePredictionEngine.calculate([
        _p(0),
        _p(28),
        _p(56),
        _p(116),
        _p(144),
        _p(172),
      ])!;
      expect(p.intervalCount, 4);
    });

    test('stable 60-day history remains predictable', () {
      final p = CyclePredictionEngine.calculate([
        _p(0),
        _p(60),
        _p(120),
        _p(180),
      ]);
      expect(p, isNotNull);
      expect(p!.medianCycleDays, 60);
      expect(p.intervalCount, 3);
    });

    test('20-day and 42-day intervals can remain around a 28-day baseline', () {
      final p = CyclePredictionEngine.calculate([
        _p(0),
        _p(20),
        _p(48),
        _p(76),
        _p(118),
      ])!;
      expect(p.intervalCount, 4);
      expect(p.maximumCycleDays, 42);
    });
  });

  group('CORE: luteal window invariant', () {
    test('pre-period range = mensesStart-16 to mensesStart-1', () {
      final p = CyclePredictionEngine.calculate([
        _p(0),
        _p(28),
        _p(56),
        _p(84),
      ])!;
      final luteal = p.lutealWindow;
      expect(luteal.rangeStart.epochDay, p.predictedMensesStart.epochDay - 16);
      expect(luteal.rangeEnd.epochDay, p.predictedMensesStart.epochDay - 1);
      expect(luteal.contains(luteal.midpoint), isTrue);
      expect(luteal.contains(luteal.rangeStart.addDays(-1)), isFalse);
    });
  });

  group('CORE: confidence progression', () {
    test('3 intervals → medium, 4 tight → higher', () {
      final med = CyclePredictionEngine.calculate([
        _p(0),
        _p(28),
        _p(56),
        _p(84),
      ])!;
      expect(med.confidence, PredictionConfidence.medium);
      final hi = CyclePredictionEngine.calculate([
        _p(0),
        _p(28),
        _p(57),
        _p(85),
        _p(113),
      ])!;
      expect(hi.confidence, PredictionConfidence.higher);
    });
  });

  group('CORE: edge cases', () {
    test(
      'empty → null',
      () => expect(CyclePredictionEngine.calculate([]), isNull),
    );
    test(
      'one period → null',
      () => expect(CyclePredictionEngine.calculate([_p(0)]), isNull),
    );
    test(
      'two periods → null',
      () => expect(CyclePredictionEngine.calculate([_p(0), _p(28)]), isNull),
    );
    test('open period anchors from its start', () {
      final p = CyclePredictionEngine.calculate([
        _p(0),
        _p(28),
        _p(56),
        _p(84, open: true),
      ])!;
      expect(p.intervalCount, 3);
      expect(p.midpoint.epochDay, greaterThan(_date(84).epochDay));
    });
  });

  group('CORE: timing', () {
    test('upcoming / current / later', () {
      final p = CyclePredictionEngine.calculate([
        _p(0),
        _p(28),
        _p(56),
        _p(84),
      ])!;
      expect(
        p.timingFor(p.predictedMensesStart.addDays(-10)),
        PredictionTiming.upcoming,
      );
      expect(p.timingFor(p.midpoint), PredictionTiming.currentWindow);
      expect(
        p.timingFor(p.predictedMensesEnd.addDays(10)),
        PredictionTiming.laterThanEstimate,
      );
    });
  });
}
