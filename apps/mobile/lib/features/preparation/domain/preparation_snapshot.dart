import '../../care/domain/care_mode.dart';
import '../../cycle/domain/cycle_prediction.dart';
import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';
import '../../patterns/domain/personal_pattern.dart';

enum PreparationAvailability {
  available,
  insufficientCycleHistory,
  estimateUnavailable,
  estimateHasPassed,
  noRepeatedObservation,
}

enum PreparationPatternStrength { early, repeated }

final class PreparationTimingEvidence {
  const PreparationTimingEvidence({
    required this.rangeStart,
    required this.rangeEnd,
    required this.periodRangeStart,
    required this.periodRangeEnd,
    required this.confidence,
    required this.observedIntervalCount,
    required this.observedSpreadDays,
  });

  final LocalDate rangeStart;
  final LocalDate rangeEnd;
  final LocalDate periodRangeStart;
  final LocalDate periodRangeEnd;
  final PredictionConfidence confidence;
  final int observedIntervalCount;
  final int observedSpreadDays;

  bool get hasWideVariation => observedSpreadDays > 7;
}

final class PreparationObservationEvidence {
  const PreparationObservationEvidence({
    required this.symptom,
    required this.recordCount,
    required this.distinctCompletedCycles,
    required this.totalCompletedCycles,
    required this.supportingCycleStarts,
    required this.sources,
    required this.strength,
  });

  final SymptomType symptom;
  final int recordCount;
  final int distinctCompletedCycles;
  final int totalCompletedCycles;
  final List<LocalDate> supportingCycleStarts;
  final List<PatternSourceReference> sources;
  final PreparationPatternStrength strength;

  int get cyclesWithoutMatchingRecord =>
      totalCompletedCycles - distinctCompletedCycles;
}

final class PreparationCareEvidence {
  const PreparationCareEvidence({
    required this.actionId,
    required this.actionLabel,
    required this.mode,
    required this.recordCount,
    required this.betterCount,
    required this.sameCount,
    required this.worseCount,
    required this.pinned,
    required this.lastRecordedDate,
    required this.sources,
  });

  final String actionId;
  final String actionLabel;
  final CareMode mode;
  final int recordCount;
  final int betterCount;
  final int sameCount;
  final int worseCount;
  final bool pinned;
  final LocalDate lastRecordedDate;
  final List<PatternSourceReference> sources;
}

final class PreparationFutureNoteEvidence {
  const PreparationFutureNoteEvidence({
    required this.text,
    required this.mode,
    required this.careRecordId,
  });

  final String text;
  final CareMode mode;
  final String careRecordId;
}

final class PreparationSnapshot {
  const PreparationSnapshot({
    required this.timing,
    required this.observation,
    required this.care,
    required this.futureNote,
  });

  final PreparationTimingEvidence timing;

  /// A cautious cross-cycle observation when production has enough matching
  /// symptom evidence. Timing and independent Care history remain useful when
  /// this is absent.
  final PreparationObservationEvidence? observation;
  final PreparationCareEvidence? care;
  final PreparationFutureNoteEvidence? futureNote;

  bool get hasContinuityEvidence => observation != null || care != null;
}

final class PreparationComposition {
  const PreparationComposition._({required this.availability, this.snapshot});

  const PreparationComposition.available(PreparationSnapshot value)
    : this._(availability: PreparationAvailability.available, snapshot: value);

  const PreparationComposition.unavailable(PreparationAvailability reason)
    : this._(availability: reason);

  final PreparationAvailability availability;
  final PreparationSnapshot? snapshot;

  bool get isAvailable => snapshot != null;
}
