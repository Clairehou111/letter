import '../../comfort_window/domain/comfort_window.dart' as presentation;
import 'comfort_window.dart';

/// Adapts factual evidence to the existing Build17 Kit and reminder surface.
/// Classification stays entirely in the explicit-zero engine.
presentation.ComfortWindowPrediction? projectComfortWindow(
  ComfortWindowResult? result,
) {
  if (result == null || result.prediction == null) return null;
  final prediction = result.prediction!;
  return presentation.ComfortWindowPrediction(
    algorithmVersion: 2,
    sourceAlgorithmId: ComfortWindowResult.algorithmVersion,
    sourceEvidence: Map.unmodifiable(result.canonicalEvidence),
    candidate: presentation.ComfortWindowCandidate(
      offsetStart: result.startOffset,
      offsetEnd: result.endOffset,
      votingCycleCount: result.votes.length,
      supportingCycleCount: result.supportCount,
      averageLift: result.averageLift,
      harderInsideDays: result.insideHarderCount,
      confidence: result.strength == ComfortWindowStrength.clearer
          ? presentation.ComfortWindowConfidence.clearer
          : presentation.ComfortWindowConfidence.emerging,
      cycles: List.unmodifiable([
        for (final vote in result.votes)
          presentation.ComfortWindowCycleEvidence(
            cycleId: vote.evidence.cycleId,
            cycleStart: vote.evidence.cycleStart,
            anchorMensesStart: vote.evidence.anchor,
            observedInsideDays: vote.insideObserved,
            observedOutsideDays: vote.outsideObserved,
            harderInsideDays: vote.insideHarder,
            harderOutsideDays: vote.outsideHarder,
            insideRate: vote.insideRate,
            outsideRate: vote.outsideRate,
            lift: vote.lift,
            supports: vote.supports,
          ),
      ]),
    ),
    forecastStart: result.rangeStart!,
    forecastEnd: result.rangeEnd!,
    periodPrediction: prediction,
  );
}
