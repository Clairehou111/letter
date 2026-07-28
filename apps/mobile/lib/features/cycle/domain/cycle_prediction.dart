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

final class CyclePrediction {
  const CyclePrediction({
    required this.rangeStart,
    required this.rangeEnd,
    required this.midpoint,
    required this.medianCycleDays,
    required this.minimumCycleDays,
    required this.maximumCycleDays,
    required this.intervalCount,
    required this.confidence,
  });

  final LocalDate rangeStart;
  final LocalDate rangeEnd;
  final LocalDate midpoint;
  final int medianCycleDays;
  final int minimumCycleDays;
  final int maximumCycleDays;
  final int intervalCount;
  final PredictionConfidence confidence;

  int get observedSpreadDays => maximumCycleDays - minimumCycleDays;

  bool get hasWideVariation => observedSpreadDays > 7;

  PredictionTiming timingFor(LocalDate today) {
    if (today.isBefore(rangeStart)) {
      return PredictionTiming.upcoming;
    }
    if (today.isAfter(rangeEnd)) {
      return PredictionTiming.laterThanEstimate;
    }
    return PredictionTiming.currentWindow;
  }
}

abstract final class CyclePredictionEngine {
  static const minimumIntervals = 2;
  static const maximumIntervals = 6;

  static CyclePrediction? calculate(Iterable<PeriodRecord> records) {
    final starts = records.map((record) => record.startDate).toList()..sort();
    final recentStarts = starts.length > maximumIntervals + 1
        ? starts.sublist(starts.length - maximumIntervals - 1)
        : starts;
    final intervals = <int>[
      for (var index = 1; index < recentStarts.length; index += 1)
        recentStarts[index].epochDay - recentStarts[index - 1].epochDay,
    ]..removeWhere((days) => days <= 0);

    if (intervals.length < minimumIntervals) {
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
    final midpoint = recentStarts.last.addDays(median);
    final spread = maximum - minimum;

    final confidence = intervals.length == 2 || spread > 7
        ? PredictionConfidence.low
        : intervals.length >= 4 && spread <= 4
        ? PredictionConfidence.higher
        : PredictionConfidence.medium;

    return CyclePrediction(
      rangeStart: midpoint.addDays(-halfWidth),
      rangeEnd: midpoint.addDays(halfWidth),
      midpoint: midpoint,
      medianCycleDays: median,
      minimumCycleDays: minimum,
      maximumCycleDays: maximum,
      intervalCount: intervals.length,
      confidence: confidence,
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
