import '../../features/cycle/domain/cycle_prediction.dart';
import '../../features/cycle/domain/local_date.dart';

/// Short context shared by the Today card and Cycle estimate line.
String cycleEstimateContextLabel(CyclePrediction prediction, LocalDate today) {
  final evidence = prediction.isEarlyEstimate
      ? 'early estimate from one observed interval'
      : prediction.hasWideVariation
      ? 'recorded cycles vary; wider estimate'
      : prediction.confidence == PredictionConfidence.low
      ? 'limited history'
      : null;
  final timing = switch (prediction.timingFor(today)) {
    PredictionTiming.upcoming => 'upcoming',
    PredictionTiming.currentWindow => 'estimate window is current',
    PredictionTiming.laterThanEstimate => 'later than this estimate',
  };
  return evidence == null ? timing : '$evidence · $timing';
}
