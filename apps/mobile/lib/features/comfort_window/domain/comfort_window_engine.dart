import '../../cycle/domain/cycle_prediction.dart';
import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_record.dart';
import '../../patterns/domain/pattern_source.dart';
import 'comfort_window.dart';

final class ComfortWindowEngine {
  const ComfortWindowEngine();

  static const minimumOffset = -14;
  static const maximumOffset = 3;
  static const minimumWindowDays = 3;
  static const maximumWindowDays = 7;
  static const maximumCompletedCycles = 6;

  ComfortWindowPrediction? calculate({
    required PatternSourceSnapshot source,
    required CyclePrediction? periodPrediction,
    required LocalDate today,
  }) {
    if (periodPrediction == null || periodPrediction.isEarlyEstimate) {
      return null;
    }
    final eligibleStarts =
        source.periods
            .where((period) => !period.startDate.isAfter(today))
            .map((period) => period.startDate)
            .toList(growable: false)
          ..sort();
    if (eligibleStarts.length < 3) return null;
    final currentCycleStart = eligibleStarts.last;
    final days = Map<LocalDate, ObservedDayClassification>.unmodifiable(
      Map<LocalDate, ObservedDayClassification>.fromEntries(
        classifyObservedDays(
          source.through(today),
        ).entries.where((entry) => entry.key.isBefore(currentCycleStart)),
      ),
    );
    final cycles = _completedCycles(
      source.periods,
      today,
    ).where((cycle) => _isEligibleCycle(cycle, days)).toList(growable: false);
    if (cycles.length < 2) return null;

    final candidates = <ComfortWindowCandidate>[];
    for (
      var length = minimumWindowDays;
      length <= maximumWindowDays;
      length++
    ) {
      for (
        var start = minimumOffset;
        start + length - 1 <= maximumOffset;
        start++
      ) {
        final candidate = _evaluateCandidate(
          cycles: cycles,
          days: days,
          offsetStart: start,
          offsetEnd: start + length - 1,
        );
        if (candidate.confidence != ComfortWindowConfidence.none) {
          candidates.add(candidate);
        }
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort(_compareCandidates);
    final selected = candidates.first;
    return ComfortWindowPrediction(
      algorithmVersion: comfortWindowAlgorithmVersion,
      candidate: selected,
      forecastStart: periodPrediction.predictedMensesStart.addDays(
        selected.offsetStart,
      ),
      forecastEnd: periodPrediction.predictedMensesEnd.addDays(
        selected.offsetEnd,
      ),
      periodPrediction: periodPrediction,
    );
  }

  /// Produces one deterministic daily classification. A symptom or difficult
  /// mood always wins when the same day also contains a positive check-in.
  Map<LocalDate, ObservedDayClassification> classifyObservedDays(
    PatternSourceSnapshot source,
  ) {
    final hasSymptom = <LocalDate>{};
    for (final record in source.healthRecords.where(
      (record) => record.userConfirmed,
    )) {
      hasSymptom.add(record.experiencedDate);
    }

    final hardMood = <LocalDate>{};
    final nonHardMood = <LocalDate>{};
    for (final checkIn in source.momentCheckIns) {
      final date = LocalDate.fromDateTime(checkIn.occurredAt.toLocal());
      if (checkIn.state.isHarderDaySignal) {
        hardMood.add(date);
      } else {
        nonHardMood.add(date);
      }
    }

    final observed = <LocalDate>{...hasSymptom, ...hardMood, ...nonHardMood};
    return Map.unmodifiable({
      for (final date in observed)
        date: hasSymptom.contains(date) || hardMood.contains(date)
            ? ObservedDayClassification.harder
            : ObservedDayClassification.nonHard,
    });
  }

  List<_CompletedCycle> _completedCycles(
    List<PeriodRecord> periods,
    LocalDate today,
  ) {
    final eligible =
        periods
            .where((period) => !period.startDate.isAfter(today))
            .toList(growable: false)
          ..sort((left, right) => left.startDate.compareTo(right.startDate));
    final completed = <_CompletedCycle>[
      for (var index = 0; index < eligible.length - 1; index++)
        _CompletedCycle(
          id: eligible[index].id,
          start: eligible[index].startDate,
          nextStart: eligible[index + 1].startDate,
        ),
    ];
    final recent = completed.length > maximumCompletedCycles
        ? completed.sublist(completed.length - maximumCompletedCycles)
        : completed;
    return List.unmodifiable(recent);
  }

  bool _isEligibleCycle(
    _CompletedCycle cycle,
    Map<LocalDate, ObservedDayClassification> days,
  ) {
    var observed = 0;
    var nonHard = 0;
    for (var offset = minimumOffset; offset <= maximumOffset; offset++) {
      final classification = days[cycle.nextStart.addDays(offset)];
      if (classification == null) continue;
      observed++;
      if (classification == ObservedDayClassification.nonHard) nonHard++;
    }
    return observed >= 9 && nonHard >= 3;
  }

  ComfortWindowCandidate _evaluateCandidate({
    required List<_CompletedCycle> cycles,
    required Map<LocalDate, ObservedDayClassification> days,
    required int offsetStart,
    required int offsetEnd,
  }) {
    final evidence = <ComfortWindowCycleEvidence>[];
    final requiredInside = ((offsetEnd - offsetStart + 1) / 2).ceil();
    for (final cycle in cycles) {
      var observedInside = 0;
      var observedOutside = 0;
      var harderInside = 0;
      var harderOutside = 0;
      for (var offset = minimumOffset; offset <= maximumOffset; offset++) {
        final classification = days[cycle.nextStart.addDays(offset)];
        if (classification == null) continue;
        final inside = offset >= offsetStart && offset <= offsetEnd;
        if (inside) {
          observedInside++;
          if (classification == ObservedDayClassification.harder) {
            harderInside++;
          }
        } else {
          observedOutside++;
          if (classification == ObservedDayClassification.harder) {
            harderOutside++;
          }
        }
      }
      if (observedInside < requiredInside || observedOutside < 5) continue;
      final insideRate = harderInside / observedInside;
      final outsideRate = harderOutside / observedOutside;
      final lift = insideRate - outsideRate;
      evidence.add(
        ComfortWindowCycleEvidence(
          cycleId: cycle.id,
          cycleStart: cycle.start,
          anchorMensesStart: cycle.nextStart,
          observedInsideDays: observedInside,
          observedOutsideDays: observedOutside,
          harderInsideDays: harderInside,
          harderOutsideDays: harderOutside,
          insideRate: insideRate,
          outsideRate: outsideRate,
          lift: lift,
          supports: harderInside >= 2 && insideRate >= 0.50 && lift >= 0.25,
        ),
      );
    }
    final supporting = evidence.where((cycle) => cycle.supports).length;
    final voting = evidence.length;
    final ratio = voting == 0 ? 0.0 : supporting / voting;
    final confidence = voting >= 3 && ratio >= 0.75
        ? ComfortWindowConfidence.clearer
        : voting == 2 && supporting == 2
        ? ComfortWindowConfidence.emerging
        : ComfortWindowConfidence.none;
    final averageLift = voting == 0
        ? 0.0
        : evidence.fold<double>(0, (sum, cycle) => sum + cycle.lift) / voting;
    return ComfortWindowCandidate(
      offsetStart: offsetStart,
      offsetEnd: offsetEnd,
      votingCycleCount: voting,
      supportingCycleCount: supporting,
      averageLift: averageLift,
      harderInsideDays: evidence.fold<int>(
        0,
        (sum, cycle) => sum + cycle.harderInsideDays,
      ),
      confidence: confidence,
      cycles: List.unmodifiable(evidence),
    );
  }

  int _compareCandidates(
    ComfortWindowCandidate left,
    ComfortWindowCandidate right,
  ) {
    var order = right.supportRatio.compareTo(left.supportRatio);
    if (order != 0) return order;
    order = right.averageLift.compareTo(left.averageLift);
    if (order != 0) return order;
    order = right.harderInsideDays.compareTo(left.harderInsideDays);
    if (order != 0) return order;
    order = left.lengthDays.compareTo(right.lengthDays);
    if (order != 0) return order;
    order = right.offsetEnd.compareTo(left.offsetEnd);
    if (order != 0) return order;
    return left.offsetStart.compareTo(right.offsetStart);
  }
}

final class _CompletedCycle {
  const _CompletedCycle({
    required this.id,
    required this.start,
    required this.nextStart,
  });

  final String id;
  final LocalDate start;
  final LocalDate nextStart;
}
