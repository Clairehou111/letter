import '../cycle/domain/cycle_prediction.dart';
import '../cycle/domain/cycle_read_snapshot.dart';
import '../cycle/domain/local_date.dart';
import '../cycle/domain/period_record.dart';

enum TodayCycleKind { noHistory, periodInProgress, betweenPeriods }

final class TodayCycleContext {
  const TodayCycleContext({
    required this.kind,
    required this.today,
    required this.latestStart,
    required this.dayNumber,
    required this.prediction,
  });

  factory TodayCycleContext.fromRecords({
    required Iterable<PeriodRecord> records,
    required LocalDate today,
  }) {
    final snapshot = CycleReadSnapshot.fromRecords(
      records: records,
      today: today,
    );
    final current = snapshot.currentCycle;
    if (current == null) {
      return TodayCycleContext(
        kind: TodayCycleKind.noHistory,
        today: today,
        latestStart: null,
        dayNumber: null,
        prediction: null,
      );
    }

    return TodayCycleContext(
      // Closing a period on its final day must not erase that day's factual
      // period context. It becomes between-periods only tomorrow.
      kind:
          current.bleedingState == BleedingState.open ||
              current.bleedingState == BleedingState.endedToday
          ? TodayCycleKind.periodInProgress
          : TodayCycleKind.betweenPeriods,
      today: today,
      latestStart: current.period.startDate,
      dayNumber: current.cycleDay < 1 ? 1 : current.cycleDay,
      prediction: snapshot.visiblePrediction,
    );
  }

  final TodayCycleKind kind;
  final LocalDate today;
  final LocalDate? latestStart;
  final int? dayNumber;
  final CyclePrediction? prediction;
}
