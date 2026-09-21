import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/cycle_prediction.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';

PeriodRecord period(String id, int startDay, {bool open = false}) {
  return PeriodRecord(
    id: id,
    startDate: LocalDate(2026, 1, 1).addDays(startDay),
    endDate: open ? null : LocalDate(2026, 1, 1).addDays(startDay + 4),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

PeriodRecord datedPeriod(String id, LocalDate start, LocalDate end) {
  return PeriodRecord(
    id: id,
    startDate: start,
    endDate: end,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

void main() {
  test('requires two complete start-to-start intervals', () {
    expect(CyclePredictionEngine.calculate([period('one', 0)]), isNull);
    expect(
      CyclePredictionEngine.calculate([period('one', 0), period('two', 28)]),
      isNull,
    );

    final prediction = CyclePredictionEngine.calculate([
      period('one', 0),
      period('two', 28),
      period('three', 58),
    ]);
    expect(prediction, isNotNull);
    expect(prediction!.intervalCount, 2);
  });

  test('one valid interval can supply only a broad early visual estimate', () {
    final records = [period('one', 0), period('two', 36)];

    expect(CyclePredictionEngine.calculate(records), isNull);

    final early = CyclePredictionEngine.calculateEarlyEstimate(records)!;
    expect(early.isEarlyEstimate, isTrue);
    expect(early.confidence, PredictionConfidence.low);
    expect(early.intervalCount, 1);
    expect(early.medianCycleDays, 36);
    expect(early.rangeEnd.epochDay - early.rangeStart.epochDay, 14);
  });

  test('two intervals use rounded median and four-day minimum margin', () {
    final prediction = CyclePredictionEngine.calculate([
      period('one', 0),
      period('two', 27),
      period('three', 58),
    ])!;

    expect(prediction.medianCycleDays, 29);
    expect(prediction.midpoint, const LocalDate(2026, 3, 29));
    expect(prediction.rangeStart, const LocalDate(2026, 3, 25));
    expect(prediction.rangeEnd, const LocalDate(2026, 4, 2));
    expect(prediction.confidence, PredictionConfidence.low);
  });

  test('observed variation widens the range and keeps confidence low', () {
    final prediction = CyclePredictionEngine.calculate([
      period('one', 0),
      period('two', 24),
      period('three', 60),
      period('four', 88),
    ])!;

    expect(prediction.medianCycleDays, 28);
    expect(prediction.minimumCycleDays, 24);
    expect(prediction.maximumCycleDays, 36);
    expect(prediction.observedSpreadDays, 12);
    expect(prediction.rangeEnd.epochDay - prediction.rangeStart.epochDay, 12);
    expect(prediction.hasWideVariation, isTrue);
    expect(prediction.confidence, PredictionConfidence.low);
  });

  test('four stable intervals can produce higher confidence', () {
    final prediction = CyclePredictionEngine.calculate([
      period('one', 0),
      period('two', 28),
      period('three', 57),
      period('four', 85),
      period('five', 115, open: true),
    ])!;

    expect(prediction.intervalCount, 4);
    expect(prediction.minimumCycleDays, 28);
    expect(prediction.maximumCycleDays, 30);
    expect(prediction.confidence, PredictionConfidence.higher);
    expect(prediction.rangeEnd.epochDay - prediction.rangeStart.epochDay, 4);
  });

  test('three stable intervals remain medium confidence', () {
    final prediction = CyclePredictionEngine.calculate([
      period('one', 0),
      period('two', 28),
      period('three', 57),
      period('four', 85),
    ])!;

    expect(prediction.intervalCount, 3);
    expect(prediction.confidence, PredictionConfidence.medium);
    expect(prediction.rangeEnd.epochDay - prediction.rangeStart.epochDay, 6);
  });

  test('uses only the six most recent intervals', () {
    final records = <PeriodRecord>[];
    var start = 0;
    for (var index = 0; index < 9; index += 1) {
      records.add(period('period-$index', start));
      start += index < 2 ? 45 : 28;
    }

    final prediction = CyclePredictionEngine.calculate(records)!;

    expect(prediction.intervalCount, 6);
    expect(prediction.minimumCycleDays, 28);
    expect(prediction.maximumCycleDays, 28);
    expect(prediction.medianCycleDays, 28);
    expect(prediction.confidence, PredictionConfidence.higher);
  });

  test('current open period can anchor a prediction', () {
    final prediction = CyclePredictionEngine.calculate([
      period('one', 0),
      period('two', 28),
      period('current', 57, open: true),
    ])!;

    expect(prediction.midpoint, const LocalDate(2026, 3, 28));
    expect(prediction.intervalCount, 2);
  });

  test('keeps the approved skipped-history estimate fixture unchanged', () {
    final prediction = CyclePredictionEngine.calculate([
      datedPeriod(
        'march',
        const LocalDate(2026, 3, 2),
        const LocalDate(2026, 3, 9),
      ),
      datedPeriod(
        'may',
        const LocalDate(2026, 5, 10),
        const LocalDate(2026, 5, 16),
      ),
      datedPeriod(
        'june',
        const LocalDate(2026, 6, 13),
        const LocalDate(2026, 6, 17),
      ),
      datedPeriod(
        'july',
        const LocalDate(2026, 7, 14),
        const LocalDate(2026, 7, 18),
      ),
    ])!;

    expect(prediction.intervalCount, 2);
    expect(prediction.minimumCycleDays, 31);
    expect(prediction.maximumCycleDays, 34);
    expect(prediction.medianCycleDays, 33);
    expect(prediction.midpoint, const LocalDate(2026, 8, 16));
    expect(prediction.rangeStart, const LocalDate(2026, 8, 12));
    expect(prediction.rangeEnd, const LocalDate(2026, 8, 20));
    expect(prediction.confidence, PredictionConfidence.low);
  });

  test('timing distinguishes upcoming, current, and later states', () {
    final prediction = CyclePredictionEngine.calculate([
      period('one', 0),
      period('two', 28),
      period('three', 56),
    ])!;

    expect(
      prediction.timingFor(prediction.rangeStart.addDays(-1)),
      PredictionTiming.upcoming,
    );
    expect(
      prediction.timingFor(prediction.midpoint),
      PredictionTiming.currentWindow,
    );
    expect(
      prediction.timingFor(prediction.rangeEnd.addDays(1)),
      PredictionTiming.laterThanEstimate,
    );
  });

  test('observed interval progress is capped at the model maximum', () {
    expect(CyclePredictionEngine.observedIntervalCount([]), 0);
    expect(
      CyclePredictionEngine.observedIntervalCount([
        period('one', 0),
        period('two', 28),
      ]),
      1,
    );
    expect(
      CyclePredictionEngine.observedIntervalCount([
        for (var index = 0; index < 10; index += 1)
          period('$index', index * 28),
      ]),
      6,
    );
  });

  // ── Outlier filtering & luteal detection tests ──

  test('drops a short interval that differs from the user baseline', () {
    final prediction = CyclePredictionEngine.calculate([
      period('one', 0),
      period('two', 28),
      period('three', 38), // 10-day exceptional interval
      period('four', 66), // 28-day interval (normal)
    ])!;

    // The 10-day outlier should be excluded; 2 normal intervals remain.
    expect(prediction.intervalCount, 2);
    expect(prediction.medianCycleDays, 28);
  });

  test('drops a long interval that differs from the user baseline', () {
    final prediction = CyclePredictionEngine.calculate([
      period('one', 0),
      period('two', 28),
      period('three', 80), // 52-day exceptional interval
      period('four', 108), // 28-day interval (normal)
    ])!;

    expect(prediction.intervalCount, 2);
    expect(prediction.medianCycleDays, 28);
  });

  test('drops intervals exceeding 1.5× the baseline median', () {
    // Baseline median ~28. 45 days > 28*1.5=42 → excluded.
    final prediction = CyclePredictionEngine.calculate([
      period('one', 0),
      period('two', 28),
      period('three', 56),
      period('four', 101), // 45-day outlier
      period('five', 129), // 28-day normal
    ])!;

    expect(prediction.intervalCount, 3);
  });

  test(
    'estimated pre-period window ends before the earliest predicted menses',
    () {
      final prediction = CyclePredictionEngine.calculate([
        period('one', 0),
        period('two', 28),
        period('three', 56),
        period('four', 84),
      ])!;

      // Menses predicted ~ day 112 (84 + 28). Midpoint ~112, halfWidth 2.
      // Start = earliest predicted menses - 16 days.
      // End = the day before earliest predicted menses, so the two ranges
      // never overlap.
      final luteal = prediction.lutealWindow;
      expect(
        luteal.rangeStart.epochDay,
        prediction.predictedMensesStart.epochDay - 16,
      );
      expect(
        luteal.rangeEnd.epochDay,
        prediction.predictedMensesStart.epochDay - 1,
      );
    },
  );

  test('excluded exceptional interval cannot retain higher confidence', () {
    final prediction = CyclePredictionEngine.calculate([
      period('one', 0),
      period('two', 28),
      period('three', 56),
      period('exceptional', 116),
      period('four', 144),
      period('five', 172),
    ])!;

    expect(prediction.medianCycleDays, 28);
    expect(prediction.excludedIntervalCount, 1);
    expect(prediction.confidence, PredictionConfidence.medium);
  });

  test('invalid short gaps cannot define the baseline for valid intervals', () {
    final prediction = CyclePredictionEngine.calculate([
      period('one', 0),
      period('two', 10),
      period('three', 20),
      period('four', 30),
      period('five', 58),
      period('six', 86),
    ])!;

    expect(prediction.medianCycleDays, 28);
    expect(prediction.intervalCount, 2);
    expect(prediction.excludedIntervalCount, 3);
    expect(prediction.confidence, PredictionConfidence.low);
  });

  test('luteal window contains dates within the predicted luteal phase', () {
    final prediction = CyclePredictionEngine.calculate([
      period('one', 0),
      period('two', 28),
      period('three', 56),
      period('four', 84),
    ])!;

    final luteal = prediction.lutealWindow;
    // A date in the middle of the luteal window should be contained.
    final midLuteal = luteal.midpoint;
    expect(luteal.contains(midLuteal), isTrue);
    // A date well before luteal start should not be contained.
    expect(luteal.contains(luteal.rangeStart.addDays(-10)), isFalse);
    // A date well after luteal end should not be contained.
    expect(luteal.contains(luteal.rangeEnd.addDays(10)), isFalse);
  });

  test('prediction evidence exposes the exact early-estimate interval', () {
    final evidence = CyclePredictionEngine.predictionEvidence([
      period('one', 0),
      period('two', 28),
    ]);

    expect(evidence.kind, PredictionEstimateKind.early);
    expect(evidence.candidateStartsNewestFirst, [
      const LocalDate(2026, 1, 29),
      const LocalDate(2026, 1, 1),
    ]);
    expect(evidence.intervalsNewestFirst, hasLength(1));
    expect(
      evidence.intervalsNewestFirst.single.status,
      PredictionIntervalStatus.used,
    );
  });

  test(
    'prediction evidence marks an excluded interval instead of hiding it',
    () {
      final evidence = CyclePredictionEngine.predictionEvidence([
        period('one', 0),
        period('two', 28),
        period('three', 56),
        period('outlier', 101),
        period('four', 129),
      ]);

      expect(evidence.kind, PredictionEstimateKind.formal);
      expect(
        evidence.intervalsNewestFirst
            .singleWhere((interval) => interval.days == 45)
            .status,
        PredictionIntervalStatus.outlier,
      );
    },
  );
}
