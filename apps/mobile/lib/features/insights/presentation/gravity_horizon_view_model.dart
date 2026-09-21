import '../../cycle/domain/cycle_prediction.dart';
import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_record.dart';

enum HorizonStateId {
  noHistory,
  insufficientHistory,
  predictionAvailable,
  periodInProgress,
  pastEstimatedRange,
}

/// Presentation adapter for Lovable's Gravity Horizon.
///
/// The production domain remains authoritative: recorded bands come from
/// [PeriodRecord] and every estimate comes from [CyclePredictionEngine].
/// This class contains no persistence and performs no health inference.
final class GravityHorizonViewModel {
  GravityHorizonViewModel._({
    required this.today,
    required this.records,
    required this.prediction,
  });

  factory GravityHorizonViewModel.fromRecords({
    required Iterable<PeriodRecord> records,
    required LocalDate today,
  }) {
    final ordered = CyclePredictionEngine.recordsThrough(records, today);
    return GravityHorizonViewModel._(
      today: today,
      records: List.unmodifiable(ordered),
      prediction: CyclePredictionEngine.calculate(ordered),
    );
  }

  final LocalDate today;
  final List<PeriodRecord> records;
  final CyclePrediction? prediction;

  /// Prediction rendered by the compact Today chart.
  ///
  /// An open period is observed information and takes precedence over a
  /// future estimate on Today. The underlying [prediction] remains available
  /// to detailed Cycle views.
  CyclePrediction? get chartPrediction =>
      openPeriod == null ? prediction : null;

  bool get hasHistory => records.isNotEmpty;

  PeriodRecord? get openPeriod {
    for (final record in records) {
      if (record.isOpen) return record;
    }
    return null;
  }

  PeriodRecord? get latestRecord => records.isEmpty ? null : records.first;

  LocalDate? get lastPeriodStart => latestRecord?.startDate;

  int? get cycleDay {
    final start = lastPeriodStart;
    if (start == null) return null;
    final value = today.epochDay - start.epochDay + 1;
    return value < 1 ? null : value;
  }

  int? get recordedPeriodDay {
    final record = openPeriod;
    if (record == null) return null;
    final value = today.epochDay - record.startDate.epochDay + 1;
    return value < 1 ? null : value;
  }

  LocalDate? get lastObservedDate {
    final latest = latestRecord;
    return latest?.endDate ?? latest?.startDate;
  }

  HorizonStateId get stateId {
    if (!hasHistory) return HorizonStateId.noHistory;
    if (openPeriod != null) return HorizonStateId.periodInProgress;
    final value = prediction;
    if (value == null) return HorizonStateId.insufficientHistory;
    if (value.timingFor(today) == PredictionTiming.laterThanEstimate) {
      return HorizonStateId.pastEstimatedRange;
    }
    return HorizonStateId.predictionAvailable;
  }

  int get estimatedRangeWidthDays {
    final value = prediction;
    if (value == null) return 0;
    return value.predictedMensesEnd.epochDay -
        value.predictedMensesStart.epochDay +
        1;
  }

  bool get isTodayInEstimatedPremenstrualWindow {
    final value = chartPrediction;
    return value != null && value.lutealWindow.contains(today);
  }

  /// Calendar-date position in the visible chart window.
  double dateFraction(LocalDate date) {
    final window = chartWindow;
    final span = window.end.epochDay - window.start.epochDay;
    if (span <= 0) return 0;
    return ((date.epochDay - window.start.epochDay) / span).clamp(0.0, 1.0);
  }

  /// Ordinal estimated cycle-gravity curve driven by cycle dates. One is the
  /// lighter guide and zero is the heavier guide.
  ///
  /// The curve recovers after the recorded period start, stays light through
  /// the middle of the cycle, descends from the central estimated pre-period
  /// start
  /// to the earliest estimated period start, then holds near the heavier guide
  /// through the full estimated range. It is a visual timing metaphor, never a
  /// mood or energy measurement.
  double? estimatedGravityLevel(LocalDate date) {
    final value = chartPrediction;
    final anchor = lastPeriodStart;
    if (value == null || anchor == null) return null;

    if (date.isBefore(anchor)) {
      final leadStart = anchor.addDays(-4);
      if (date.isBefore(leadStart)) return 0.1;
      final progress = (date.epochDay - leadStart.epochDay) / 4;
      return 0.1 + 0.32 * _smoothStep(progress);
    }

    final recoveryCandidate = anchor.addDays(
      (value.medianCycleDays * 0.18).round().clamp(1, 7),
    );
    final estimatedStart = value.estimatedPremenstrualStart;
    final recoveryEnd = recoveryCandidate.isAfter(estimatedStart)
        ? estimatedStart
        : recoveryCandidate;
    if (!date.isAfter(recoveryEnd)) {
      final span = recoveryEnd.epochDay - anchor.epochDay;
      if (span <= 0) return 1;
      final progress = (date.epochDay - anchor.epochDay) / span;
      return 0.42 + 0.58 * _smoothStep(progress);
    }
    if (date.isBefore(estimatedStart)) return 1;
    if (date.isBefore(value.predictedMensesStart)) {
      final span =
          value.predictedMensesStart.epochDay - estimatedStart.epochDay;
      if (span <= 0) return 0.1;
      final progress = (date.epochDay - estimatedStart.epochDay) / span;
      return 1 - 0.9 * _smoothStep(progress);
    }
    return 0.1;
  }

  ({LocalDate start, LocalDate end}) get chartWindow {
    final latest = latestRecord;
    if (latest == null) {
      return (start: today.addDays(-7), end: today.addDays(7));
    }
    final value = chartPrediction;
    var first = latest.startDate;
    final premenstrualStart = value?.predictedLutealStart;
    if (premenstrualStart != null && premenstrualStart.isBefore(first)) {
      first = premenstrualStart;
    }
    if (today.isBefore(first)) first = today;
    var last = today;
    final predictedEnd = value?.predictedMensesEnd;
    if (predictedEnd != null && predictedEnd.isAfter(last)) {
      last = predictedEnd;
    }
    final observedEnd = latest.endDate ?? latest.startDate;
    if (observedEnd.isAfter(last)) {
      last = observedEnd;
    }
    return (start: first.addDays(-4), end: last.addDays(4));
  }

  static double _smoothStep(double value) {
    final t = value.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}
