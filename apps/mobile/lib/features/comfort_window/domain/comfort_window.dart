import '../../cycle/domain/cycle_prediction.dart';
import '../../cycle/domain/local_date.dart';

const comfortWindowAlgorithmVersion = 1;

enum ObservedDayClassification { harder, nonHard }

enum ComfortWindowConfidence { none, emerging, clearer }

final class ComfortWindowCycleEvidence {
  const ComfortWindowCycleEvidence({
    required this.cycleId,
    required this.cycleStart,
    required this.anchorMensesStart,
    required this.observedInsideDays,
    required this.observedOutsideDays,
    required this.harderInsideDays,
    required this.harderOutsideDays,
    required this.insideRate,
    required this.outsideRate,
    required this.lift,
    required this.supports,
  });

  final String cycleId;
  final LocalDate cycleStart;
  final LocalDate anchorMensesStart;
  final int observedInsideDays;
  final int observedOutsideDays;
  final int harderInsideDays;
  final int harderOutsideDays;
  final double insideRate;
  final double outsideRate;
  final double lift;
  final bool supports;
}

final class ComfortWindowCandidate {
  const ComfortWindowCandidate({
    required this.offsetStart,
    required this.offsetEnd,
    required this.votingCycleCount,
    required this.supportingCycleCount,
    required this.averageLift,
    required this.harderInsideDays,
    required this.confidence,
    required this.cycles,
  });

  final int offsetStart;
  final int offsetEnd;
  final int votingCycleCount;
  final int supportingCycleCount;
  final double averageLift;
  final int harderInsideDays;
  final ComfortWindowConfidence confidence;
  final List<ComfortWindowCycleEvidence> cycles;

  int get lengthDays => offsetEnd - offsetStart + 1;
  double get supportRatio =>
      votingCycleCount == 0 ? 0 : supportingCycleCount / votingCycleCount;
}

final class ComfortWindowPrediction {
  const ComfortWindowPrediction({
    required this.algorithmVersion,
    required this.candidate,
    required this.forecastStart,
    required this.forecastEnd,
    required this.periodPrediction,
  });

  final int algorithmVersion;
  final ComfortWindowCandidate candidate;
  final LocalDate forecastStart;
  final LocalDate forecastEnd;
  final CyclePrediction periodPrediction;

  ComfortWindowConfidence get confidence => candidate.confidence;
  List<String> get sourceCycleIds =>
      List.unmodifiable(candidate.cycles.map((cycle) => cycle.cycleId));

  int get forecastSpanDays => forecastEnd.epochDay - forecastStart.epochDay + 1;

  bool get canOfferReminder =>
      confidence == ComfortWindowConfidence.clearer &&
      periodPrediction.confidence != PredictionConfidence.low &&
      !periodPrediction.hasWideVariation &&
      forecastSpanDays <= 10;

  bool isPreparationVisibleOn(LocalDate today, {int leadDays = 2}) {
    final visibleFrom = forecastStart.addDays(-leadDays);
    return !today.isBefore(visibleFrom) && !today.isAfter(forecastEnd);
  }
}
