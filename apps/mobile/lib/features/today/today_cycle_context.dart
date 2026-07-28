import '../cycle/domain/cycle_prediction.dart';
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
    final ordered = records.toList()
      ..sort((left, right) => right.startDate.compareTo(left.startDate));
    if (ordered.isEmpty) {
      return TodayCycleContext(
        kind: TodayCycleKind.noHistory,
        today: today,
        latestStart: null,
        dayNumber: null,
        prediction: null,
      );
    }

    final latest = ordered.first;
    final dayNumber = today.epochDay - latest.startDate.epochDay + 1;
    return TodayCycleContext(
      kind: latest.isOpen
          ? TodayCycleKind.periodInProgress
          : TodayCycleKind.betweenPeriods,
      today: today,
      latestStart: latest.startDate,
      dayNumber: dayNumber < 1 ? 1 : dayNumber,
      prediction: CyclePredictionEngine.calculate(ordered),
    );
  }

  final TodayCycleKind kind;
  final LocalDate today;
  final LocalDate? latestStart;
  final int? dayNumber;
  final CyclePrediction? prediction;
}
