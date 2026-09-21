import 'dart:math' as math;

import '../cycle/domain/cycle_prediction.dart';
import '../cycle/domain/cycle_read_snapshot.dart';
import '../cycle/domain/local_date.dart';
import '../cycle/domain/period_record.dart';

enum CycleRingPhase {
  period('Period'),
  follicular('Follicular'),
  estimatedOvulation('Estimated ovulation'),
  luteal('Luteal');

  const CycleRingPhase(this.label);

  final String label;
}

enum CycleRingCertainty { observed, estimated }

final class CycleRingSegment {
  const CycleRingSegment({
    required this.phase,
    required this.startDay,
    required this.endDay,
    required this.certainty,
  });

  final CycleRingPhase phase;
  final int startDay;
  final int endDay;
  final CycleRingCertainty certainty;

  int get dayCount => endDay - startDay + 1;

  bool containsDay(int day) => day >= startDay && day <= endDay;
}

/// Presentation model for Today's familiar four-part cycle ring.
///
/// It uses the existing period prediction as its only estimate. It never
/// claims that ovulation or a hormonal phase was detected.
final class TodayCycleRingModel {
  const TodayCycleRingModel({
    required this.cycleStart,
    required this.today,
    required this.currentDay,
    required this.displayCycleDays,
    required this.typicalCycleDays,
    required this.segments,
    required this.currentPhase,
    required this.predictionConfidence,
    required this.predictedPeriodStart,
    required this.predictedPeriodEnd,
    required this.estimatedOvulationCenterDay,
  });

  factory TodayCycleRingModel.fromRecords({
    required Iterable<PeriodRecord> records,
    required LocalDate today,
  }) {
    final snapshot = CycleReadSnapshot.fromRecords(
      records: records,
      today: today,
    );
    final ordered = snapshot.eligiblePeriodsNewestFirst;
    if (ordered.isEmpty || today.isBefore(ordered.first.startDate)) {
      throw const TodayCycleRingException(
        TodayCycleRingFailure.insufficientHistory,
      );
    }

    final latest = ordered.first;
    final prediction = snapshot.visiblePrediction;
    if (prediction == null) {
      throw const TodayCycleRingException(
        TodayCycleRingFailure.insufficientHistory,
      );
    }

    final currentDay = today.epochDay - latest.startDate.epochDay + 1;
    final observedPeriodDays = _observedPeriodDays(latest, currentDay);
    // Reserve enough visual days for every one of the four familiar phases,
    // even when a short historical cycle overlaps an unusually long recorded
    // bleed. This only affects the ring canvas; it does not alter prediction.
    final displayCycleDays = math.max(
      math.max(currentDay, prediction.medianCycleDays),
      observedPeriodDays + 5,
    );

    // Calendar estimate only: roughly fourteen days before the predicted
    // period midpoint. A three-day visual range avoids presenting one exact
    // detected ovulation day.
    final estimatedCenter =
        (prediction.medianCycleDays - CyclePredictionEngine.lutealPhaseDays)
            .clamp(observedPeriodDays + 3, displayCycleDays - 2);
    final ovulationStart = (estimatedCenter - 1).clamp(
      observedPeriodDays + 1,
      displayCycleDays,
    );
    final ovulationEnd = (estimatedCenter + 1).clamp(
      ovulationStart,
      displayCycleDays,
    );

    final segments = <CycleRingSegment>[
      CycleRingSegment(
        phase: CycleRingPhase.period,
        startDay: 1,
        endDay: observedPeriodDays,
        certainty: CycleRingCertainty.observed,
      ),
      if (observedPeriodDays + 1 <= ovulationStart - 1)
        CycleRingSegment(
          phase: CycleRingPhase.follicular,
          startDay: observedPeriodDays + 1,
          endDay: ovulationStart - 1,
          certainty: CycleRingCertainty.estimated,
        ),
      CycleRingSegment(
        phase: CycleRingPhase.estimatedOvulation,
        startDay: ovulationStart,
        endDay: ovulationEnd,
        certainty: CycleRingCertainty.estimated,
      ),
      if (ovulationEnd + 1 <= displayCycleDays)
        CycleRingSegment(
          phase: CycleRingPhase.luteal,
          startDay: ovulationEnd + 1,
          endDay: displayCycleDays,
          certainty: CycleRingCertainty.estimated,
        ),
    ];

    final currentPhase = segments
        .where((segment) => segment.containsDay(currentDay))
        .map((segment) => segment.phase)
        .firstOrNull;

    return TodayCycleRingModel(
      cycleStart: latest.startDate,
      today: today,
      currentDay: currentDay,
      displayCycleDays: displayCycleDays,
      typicalCycleDays: prediction.medianCycleDays,
      segments: List.unmodifiable(segments),
      currentPhase: currentPhase,
      predictionConfidence: prediction.confidence,
      predictedPeriodStart: prediction.predictedMensesStart,
      predictedPeriodEnd: prediction.predictedMensesEnd,
      estimatedOvulationCenterDay: estimatedCenter,
    );
  }

  final LocalDate cycleStart;
  final LocalDate today;
  final int currentDay;
  final int displayCycleDays;

  /// Canvas length only. It can expand after a late period to keep today's
  /// marker visible and must never be rendered as the predicted cycle length.
  final int typicalCycleDays;
  final List<CycleRingSegment> segments;
  final CycleRingPhase? currentPhase;
  final PredictionConfidence predictionConfidence;
  final LocalDate predictedPeriodStart;
  final LocalDate predictedPeriodEnd;
  final int estimatedOvulationCenterDay;

  bool get hasLimitedEstimate =>
      predictionConfidence == PredictionConfidence.low;

  CycleRingSegment? segmentFor(CycleRingPhase phase) =>
      segments.where((segment) => segment.phase == phase).firstOrNull;
}

int _observedPeriodDays(PeriodRecord latest, int currentDay) {
  final duration = latest.durationDays;
  if (duration != null) return duration.clamp(1, currentDay);
  // An open period has no recorded end yet. Every day from its recorded start
  // through today is therefore observed bleeding, even when it is unusually
  // long. Capping this at 14 previously caused the ring to label later days
  // as estimated follicular/ovulation/luteal phases while the source record
  // still explicitly said the period was open.
  return currentDay;
}

enum TodayCycleRingFailure { insufficientHistory }

final class TodayCycleRingException implements Exception {
  const TodayCycleRingException(this.failure);

  final TodayCycleRingFailure failure;
}
