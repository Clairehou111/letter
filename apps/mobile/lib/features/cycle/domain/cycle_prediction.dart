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

enum PredictionEstimateKind { none, early, formal }

enum PredictionIntervalStatus { used, outsideQualityBounds, outlier, pending }

/// A concrete start-to-start interval inspected for a visible estimate.
final class PredictionIntervalEvidence {
  const PredictionIntervalEvidence({
    required this.earlierStart,
    required this.laterStart,
    required this.days,
    required this.status,
  });

  final LocalDate earlierStart;
  final LocalDate laterStart;
  final int days;
  final PredictionIntervalStatus status;
}

/// The exact records and intervals that informed a Cycle/Today estimate.
/// The list is presentation-ready (newest start first) and never includes a
/// future-dated import.
final class PredictionEvidence {
  const PredictionEvidence({
    required this.kind,
    required this.candidateStartsNewestFirst,
    required this.intervalsNewestFirst,
    required this.prediction,
  });

  final PredictionEstimateKind kind;
  final List<LocalDate> candidateStartsNewestFirst;
  final List<PredictionIntervalEvidence> intervalsNewestFirst;
  final CyclePrediction? prediction;
}

/// Estimated pre-period timing window counted backwards from the predicted
/// period range. It is a calendar estimate, not a detected biological phase.
final class LutealWindow {
  const LutealWindow({required this.rangeStart, required this.rangeEnd});

  /// Earliest possible start of the estimated pre-period window.
  final LocalDate rangeStart;

  /// Latest possible end of the estimated pre-period window.
  final LocalDate rangeEnd;

  /// The midpoint of the luteal window.
  LocalDate get midpoint =>
      rangeStart.addDays((rangeEnd.epochDay - rangeStart.epochDay) ~/ 2);

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
    this.excludedIntervalCount = 0,
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

  /// Recent start-to-start intervals left out of the estimate because they
  /// failed basic quality bounds or differed sharply from the recent baseline.
  /// They remain part of the user's record; excluding one lowers certainty.
  final int excludedIntervalCount;

  bool get hasExcludedIntervals => excludedIntervalCount > 0;

  /// A calendar-only estimate from a single observed start-to-start interval.
  /// It is suitable for the early Cycle/Today visual, but not for clinical
  /// reports, Gravity, Spectrum, care preparation, or notifications.
  bool get isEarlyEstimate => intervalCount == 1;

  /// The central estimated pre-period onset used by Gravity's curve.
  LocalDate get estimatedPremenstrualStart =>
      midpoint.addDays(-CyclePredictionEngine.lutealPhaseDays);

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

  /// Product timing assumption: the estimated pre-period window is centered
  /// 14 days before the predicted period, with two days of timing allowance.
  static const lutealPhaseDays = 14;
  static const lutealPhaseVariance = 2;

  /// Broad data-quality bounds catch duplicate starts and likely missed
  /// records without treating a stable short or long cycle as invalid. The
  /// relative filter below decides outliers against this user's own baseline.
  static const minimumValidCycleDays = 15;
  static const maximumValidCycleDays = 90;

  /// Intervals outside this familiar display band deserve a visible review
  /// cue because they can represent a missed entry. They are not automatically
  /// excluded: repeated long or short intervals may be this user's baseline.
  static const minimumTypicalCycleDays = 21;
  static const maximumTypicalCycleDays = 45;

  /// Outlier deviation multiplier: intervals exceeding 1.5× the baseline
  /// median in either direction are dropped.
  static const outlierDeviationMultiplier = 1.5;

  /// Shared calendar eligibility rule for presentation contracts. A stale
  /// future-dated import must not alter today's day number or estimate.
  static List<PeriodRecord> recordsThrough(
    Iterable<PeriodRecord> records,
    LocalDate today,
  ) {
    final eligible =
        records.where((record) => !record.startDate.isAfter(today)).toList()
          ..sort((left, right) => right.startDate.compareTo(left.startDate));
    return List.unmodifiable(eligible);
  }

  /// The formal prediction contract used by analysis, reports, preparation,
  /// and notifications. It needs two valid observed intervals.
  static CyclePrediction? calculate(Iterable<PeriodRecord> records) =>
      _calculate(records, minimumIntervals: minimumIntervals);

  /// A deliberately broad visual estimate after one valid interval. This is
  /// only for the early Today/Cycle orientation layer; callers that can
  /// influence health insights must use [calculate] instead.
  static CyclePrediction? calculateEarlyEstimate(
    Iterable<PeriodRecord> records,
  ) => _calculate(records, minimumIntervals: 1);

  /// Returns the source membership for the same prediction contract used by
  /// Cycle and Today. A formal estimate wins; otherwise a one-interval early
  /// estimate is returned when valid. Insights must still call [calculate].
  static PredictionEvidence predictionEvidence(Iterable<PeriodRecord> records) {
    final formal = _evidence(records, minimumIntervals: minimumIntervals);
    if (formal.prediction != null) {
      return PredictionEvidence(
        kind: PredictionEstimateKind.formal,
        candidateStartsNewestFirst: formal.startsNewestFirst,
        intervalsNewestFirst: formal.intervalsNewestFirst,
        prediction: formal.prediction,
      );
    }
    final early = _evidence(records, minimumIntervals: 1);
    return PredictionEvidence(
      kind: early.prediction == null
          ? PredictionEstimateKind.none
          : PredictionEstimateKind.early,
      candidateStartsNewestFirst: early.startsNewestFirst,
      intervalsNewestFirst: early.intervalsNewestFirst,
      prediction: early.prediction,
    );
  }

  static _PredictionEvidenceComputation _evidence(
    Iterable<PeriodRecord> records, {
    required int minimumIntervals,
  }) {
    final starts = records.map((record) => record.startDate).toList()..sort();
    final recentStarts = starts.length > maximumIntervals + 1
        ? starts.sublist(starts.length - maximumIntervals - 1)
        : starts;
    final raw = <_RawInterval>[
      for (var index = 1; index < recentStarts.length; index += 1)
        _RawInterval(recentStarts[index - 1], recentStarts[index]),
    ].where((interval) => interval.days > 0).toList();
    final valid = raw.where((interval) {
      return interval.days >= minimumValidCycleDays &&
          interval.days <= maximumValidCycleDays;
    }).toList();
    final baseline = valid.isEmpty
        ? null
        : _roundedMedian(
            valid.map((interval) => interval.days).toList()..sort(),
          );
    final filtered = baseline == null
        ? const <_RawInterval>[]
        : valid.where((interval) {
            return interval.days <=
                    (baseline * outlierDeviationMultiplier).round() &&
                interval.days >=
                    (baseline / outlierDeviationMultiplier).round();
          }).toList();
    final prediction = _calculate(records, minimumIntervals: minimumIntervals);
    final statuses = <PredictionIntervalEvidence>[
      for (final interval in raw.reversed)
        PredictionIntervalEvidence(
          earlierStart: interval.earlierStart,
          laterStart: interval.laterStart,
          days: interval.days,
          status: !valid.contains(interval)
              ? PredictionIntervalStatus.outsideQualityBounds
              : !filtered.contains(interval)
              ? PredictionIntervalStatus.outlier
              : prediction == null
              ? PredictionIntervalStatus.pending
              : PredictionIntervalStatus.used,
        ),
    ];
    return _PredictionEvidenceComputation(
      startsNewestFirst: List.unmodifiable(recentStarts.reversed),
      intervalsNewestFirst: List.unmodifiable(statuses),
      prediction: prediction,
    );
  }

  static CyclePrediction? _calculate(
    Iterable<PeriodRecord> records, {
    required int minimumIntervals,
  }) {
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

    // Step 2: establish a baseline from basic quality-valid intervals, then
    // apply the personal-relative filter. Invalid gaps must never define the
    // baseline which judges the rest.
    final validIntervals = rawIntervals.where((interval) {
      return interval >= minimumValidCycleDays &&
          interval <= maximumValidCycleDays;
    }).toList();
    if (validIntervals.length < minimumIntervals) return null;

    final baselineMedian = _roundedMedian([...validIntervals]..sort());
    final filteredIntervals = validIntervals.where((interval) {
      if (baselineMedian > 0 &&
          (interval > (baselineMedian * outlierDeviationMultiplier).round() ||
              interval <
                  (baselineMedian / outlierDeviationMultiplier).round())) {
        return false;
      }
      return true;
    }).toList();

    // A model cannot silently fall back to intervals it just rejected.
    if (filteredIntervals.length < minimumIntervals) return null;
    final intervals = filteredIntervals;
    final excludedIntervalCount = rawIntervals.length - intervals.length;

    final sortedIntervals = [...intervals]..sort();
    final median = _roundedMedian(sortedIntervals);
    final minimum = sortedIntervals.first;
    final maximum = sortedIntervals.last;
    final sampleMargin = switch (intervals.length) {
      1 => 7,
      2 => 4,
      3 => 3,
      _ => 2,
    };
    final leftMargin = max(sampleMargin, median - minimum);
    final rightMargin = max(sampleMargin, maximum - median);
    final predictedMensesMidpoint = recentStarts.last.addDays(median);
    final spread = maximum - minimum;

    var confidence = intervals.length <= 2 || spread > 7
        ? PredictionConfidence.low
        : intervals.length >= 4 && spread <= 4
        ? PredictionConfidence.higher
        : PredictionConfidence.medium;
    if (excludedIntervalCount > 0 &&
        confidence == PredictionConfidence.higher) {
      confidence = PredictionConfidence.medium;
    }

    final mensesStart = predictedMensesMidpoint.addDays(-leftMargin);
    final mensesEnd = predictedMensesMidpoint.addDays(rightMargin);

    // Step 3: estimated pre-period window. It is a date-model window, never
    // a detected hormonal phase. Ending before the earliest predicted menses
    // date prevents an impossible overlap with the period range.
    final lutealStart = mensesStart.addDays(
      -(lutealPhaseDays + lutealPhaseVariance),
    );
    final lutealEnd = mensesStart.addDays(-1);

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
      excludedIntervalCount: excludedIntervalCount,
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

final class _RawInterval {
  const _RawInterval(this.earlierStart, this.laterStart);

  final LocalDate earlierStart;
  final LocalDate laterStart;

  int get days => laterStart.epochDay - earlierStart.epochDay;
}

final class _PredictionEvidenceComputation {
  const _PredictionEvidenceComputation({
    required this.startsNewestFirst,
    required this.intervalsNewestFirst,
    required this.prediction,
  });

  final List<LocalDate> startsNewestFirst;
  final List<PredictionIntervalEvidence> intervalsNewestFirst;
  final CyclePrediction? prediction;
}
