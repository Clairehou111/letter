import 'cycle_prediction.dart';
import 'local_date.dart';
import 'period_record.dart';

/// The factual state of bleeding inside the cycle started by [period].
///
/// This is derived from the dates; it is not persisted separately. In
/// particular, a one-day period can be both [startedToday] and [endedToday].
enum BleedingState { open, endedToday, ended }

/// The most recent recorded start remains the current start-to-start cycle
/// until another start is recorded. Bleeding ending does not complete it.
final class CurrentCycle {
  const CurrentCycle({required this.period, required this.today});

  final PeriodRecord period;
  final LocalDate today;

  int get cycleDay => today.epochDay - period.startDate.epochDay + 1;
  bool get startedToday => period.startDate == today;
  bool get endedToday => period.endDate == today;
  bool get bleedingOpen => period.isOpen;
  BleedingState get bleedingState => bleedingOpen
      ? BleedingState.open
      : endedToday
      ? BleedingState.endedToday
      : BleedingState.ended;
}

/// A cycle whose length is observable because a later period start exists.
final class HistoricalCompletedCycle {
  const HistoricalCompletedCycle({
    required this.period,
    required this.nextPeriodStart,
  });

  final PeriodRecord period;
  final LocalDate nextPeriodStart;

  int get cycleLengthDays =>
      nextPeriodStart.epochDay - period.startDate.epochDay;
}

/// One source-of-truth read model for all Cycle-facing surfaces.
///
/// Raw archive records remain available, but all current-cycle and prediction
/// facts are derived from starts on or before [today]. This prevents a future
/// import from changing Today, the ring, or Recent cycles.
final class CycleReadSnapshot {
  const CycleReadSnapshot._({
    required this.today,
    required this.archivePeriodsNewestFirst,
    required this.eligiblePeriodsNewestFirst,
    required this.currentCycle,
    required this.completedCyclesNewestFirst,
    required this.formalPrediction,
    required this.visiblePrediction,
    required this.predictionEvidence,
  });

  factory CycleReadSnapshot.fromRecords({
    required Iterable<PeriodRecord> records,
    required LocalDate today,
  }) {
    final archive = List<PeriodRecord>.of(records)
      ..sort((left, right) => right.startDate.compareTo(left.startDate));
    final eligible = CyclePredictionEngine.recordsThrough(archive, today);
    final current = eligible.isEmpty
        ? null
        : CurrentCycle(period: eligible.first, today: today);
    final completed = <HistoricalCompletedCycle>[
      for (var index = 1; index < eligible.length; index += 1)
        HistoricalCompletedCycle(
          period: eligible[index],
          nextPeriodStart: eligible[index - 1].startDate,
        ),
    ];
    final formal = CyclePredictionEngine.calculate(eligible);
    final evidence = CyclePredictionEngine.predictionEvidence(eligible);
    return CycleReadSnapshot._(
      today: today,
      archivePeriodsNewestFirst: List.unmodifiable(archive),
      eligiblePeriodsNewestFirst: eligible,
      currentCycle: current,
      completedCyclesNewestFirst: List.unmodifiable(completed),
      formalPrediction: formal,
      visiblePrediction: evidence.prediction,
      predictionEvidence: evidence,
    );
  }

  final LocalDate today;

  /// All saved records, including future-dated imports. Archive only.
  final List<PeriodRecord> archivePeriodsNewestFirst;

  /// The only records permitted to affect today's cycle or estimates.
  final List<PeriodRecord> eligiblePeriodsNewestFirst;
  final CurrentCycle? currentCycle;
  final List<HistoricalCompletedCycle> completedCyclesNewestFirst;

  /// Used by insights, preparation, reports, and notifications.
  final CyclePrediction? formalPrediction;

  /// Used only for the Today/Cycle orientation layer. May be a one-interval
  /// early estimate.
  final CyclePrediction? visiblePrediction;
  final PredictionEvidence predictionEvidence;
}
