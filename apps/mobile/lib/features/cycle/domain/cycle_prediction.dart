import 'dart:math';

import 'local_date.dart';
import 'period_record.dart';

enum PredictionConfidence {
  low('Low'),
  medium('Medium'),
  higher('Higher');

  const PredictionConfidence(this.label);

  final String label;
}

enum PredictionTiming { upcoming, currentWindow, laterThanEstimate }

/// Luteal phase window derived from the clinical invariant that the luteal
/// phase (post-ovulation to pre-menses) is ~14 days (±2 days) across adult
/// women. Computed by counting backwards from predicted menses start.
final class LutealWindow {
  const LutealWindow({
    required this.rangeStart,
    required this.rangeEnd,
  });

  /// Earliest predicted luteal onset (14+2 = 16 days before earliest menses).
  final LocalDate rangeStart;

  /// Latest predicted luteal end (day before latest menses start).
  final LocalDate rangeEnd;

  /// The midpoint of the luteal window.
  LocalDate get midpoint => rangeStart.addDays(
    (rangeEnd.epochDay - rangeStart.epochDay) ~/ 2,
  );

  bool contains(LocalDate date) =>
      date.compareTo(rangeStart) >= 0 && date.compareTo(rangeEnd) <= 0;
}

final class CyclePrediction {
  const CyclePrediction({
    required this.predictedMensesStart,
    required this.predictedMensesEnd,
    required this.midpoint,
    required this.medianCycleDays,
    required this.minimumCycleDays,
    required this.maximumCycleDays,
    required this.intervalCount,
    required this.confidence,
    required this.predictedLutealStart,
    required this.predictedLutealEnd,
  });

  final LocalDate predictedMensesStart;
  final LocalDate predictedMensesEnd;
  final LocalDate midpoint;
  final int medianCycleDays;
  final int minimumCycleDays;
  final int maximumCycleDays;
  final int intervalCount;
  final PredictionConfidence confidence;
  final LocalDate predictedLutealStart;
  final LocalDate predictedLutealEnd;

  /// Backward-compatible rangeStart for existing callers.
  LocalDate get rangeStart => predictedMensesStart;
  LocalDate get rangeEnd => predictedMensesEnd;

  int get observedSpreadDays => maximumCycleDays - minimumCycleDays;

  bool get hasWideVariation => observedSpreadDays > 7;

  LutealWindow get lutealWindow => LutealWindow(
    rangeStart: predictedLutealStart,
    rangeEnd: predictedLutealEnd,
  );

  PredictionTiming timingFor(LocalDate today) {
    if (today.isBefore(predictedMensesStart)) {
      return PredictionTiming.upcoming;
    }
    if (today.isAfter(predictedMensesEnd)) {
      return PredictionTiming.laterThanEstimate;
    }
    return PredictionTiming.currentWindow;
  }
}

abstract final class CyclePredictionEngine {
  static const minimumIntervals = 2;
  static const maximumIntervals = 6;

  /// Clinical luteal-phase invariant: 14 days ±2.
  static const lutealPhaseDays = 14;
  static const lutealPhaseVariance = 2;

  /// Outlier bounds: cycles shorter than 21 or longer than 45 days are
  /// considered pathological and excluded from prediction.
  static const minimumValidCycleDays = 21;
  static const maximumValidCycleDays = 45;

  /// Outlier deviation multiplier: intervals exceeding 1.5× the baseline
  /// median are dropped.
  static const outlierDeviationMultiplier = 1.5;

  static CyclePrediction? calculate(Iterable<PeriodRecord> records) {
    final starts = records.map((record) => record.startDate).toList()..sort();
    final recentStarts = starts.length > maximumIntervals + 1
        ? starts.sublist(starts.length - maximumIntervals - 1)
        : starts;

    // Step 1: compute raw intervals.
    final rawIntervals = <int>[
      for (var index = 1; index < recentStarts.length; index += 1)
        recentStarts[index].epochDay - recentStarts[index - 1].epochDay,
    ]..removeWhere((days) => days <= 0);

    if (rawIntervals.length < minimumIntervals) {
      return null;
    }

    // Step 2: outlier filtering.
    final baselineMedian = _roundedMedian([...rawIntervals]..sort());
    final filteredIntervals = rawIntervals.where((interval) {
      if (interval < minimumValidCycleDays || interval > maximumValidCycleDays) {
        return false;
      }
      if (baselineMedian > 0 &&
          interval > (baselineMedian * outlierDeviationMultiplier).round()) {
        return false;
      }
      return true;
    }).toList();

    final intervals = filteredIntervals.length >= minimumIntervals
        ? filteredIntervals
        : rawIntervals;

    // Guard: if filtered intervals exist but fell below minimum, the data is
    // too unreliable for a prediction. Falling back to raw intervals risks
    // predicting a cycle below the 21-day clinical minimum.
    if (filteredIntervals.length < minimumIntervals &&
        filteredIntervals.length < rawIntervals.length) {
      return null;
    }

    final sortedIntervals = [...intervals]..sort();
    final median = _roundedMedian(sortedIntervals);
    final minimum = sortedIntervals.first;
    final maximum = sortedIntervals.last;
    final sampleMargin = switch (intervals.length) {
      2 => 4,
      3 => 3,
      _ => 2,
    };
    final observedMargin = max(
      (median - minimum).abs(),
      (maximum - median).abs(),
    );
    final halfWidth = max(sampleMargin, observedMargin);
    final predictedMensesMidpoint = recentStarts.last.addDays(median);
    final spread = maximum - minimum;

    final confidence = intervals.length == 2 || spread > 7
        ? PredictionConfidence.low
        : intervals.length >= 4 && spread <= 4
        ? PredictionConfidence.higher
        : PredictionConfidence.medium;

    final mensesStart = predictedMensesMidpoint.addDays(-halfWidth);
    final mensesEnd = predictedMensesMidpoint.addDays(halfWidth);

    // Step 3: luteal phase window via clinical-invariant countdown.
    // Luteal onset = predicted menses start minus (14 + 2) days.
    // Luteal end   = day before predicted menses end.
    final lutealStart = mensesStart.addDays(
      -(lutealPhaseDays + lutealPhaseVariance),
    );
    final lutealEnd = mensesEnd.addDays(-1);

    return CyclePrediction(
      predictedMensesStart: mensesStart,
      predictedMensesEnd: mensesEnd,
      midpoint: predictedMensesMidpoint,
      medianCycleDays: median,
      minimumCycleDays: minimum,
      maximumCycleDays: maximum,
      intervalCount: intervals.length,
      confidence: confidence,
      predictedLutealStart: lutealStart,
      predictedLutealEnd: lutealEnd,
    );
  }

  static int observedIntervalCount(Iterable<PeriodRecord> records) {
    final uniqueStarts = records.map((record) => record.startDate).toSet();
    return max(0, min(maximumIntervals, uniqueStarts.length - 1));
  }

  static int _roundedMedian(List<int> sortedValues) {
    final middle = sortedValues.length ~/ 2;
    if (sortedValues.length.isOdd) {
      return sortedValues[middle];
    }
    return ((sortedValues[middle - 1] + sortedValues[middle]) / 2).round();
  }
}
