import '../../cycle/domain/cycle_prediction.dart';
import '../../cycle/domain/local_date.dart';
import '../../patterns/domain/pattern_source.dart';
import '../../patterns/domain/personal_pattern.dart';
import 'preparation_snapshot.dart';

/// Derives one conservative preparation snapshot from existing local evidence.
/// It does not persist interpretations or alter any prediction engine input.
final class PreparationSnapshotComposer {
  const PreparationSnapshotComposer();

  PreparationComposition compose({
    required PatternSourceSnapshot source,
    required PersonalPatternAnalysis patterns,
    required CyclePrediction? prediction,
    required LocalDate today,
  }) {
    final completedCycles = _completedCycles(source);
    if (completedCycles.length < 2) {
      return const PreparationComposition.unavailable(
        PreparationAvailability.insufficientCycleHistory,
      );
    }
    if (prediction == null) {
      return const PreparationComposition.unavailable(
        PreparationAvailability.estimateUnavailable,
      );
    }
    if (today.isAfter(prediction.predictedMensesEnd)) {
      return const PreparationComposition.unavailable(
        PreparationAvailability.estimateHasPassed,
      );
    }

    final observation = _chooseObservation(patterns, completedCycles);
    final care = _chooseCare(patterns.supportActions);
    final futureNote = care == null ? null : _futureNote(source, care);

    return PreparationComposition.available(
      PreparationSnapshot(
        timing: PreparationTimingEvidence(
          rangeStart: prediction.predictedLutealStart,
          rangeEnd: prediction.predictedMensesEnd,
          periodRangeStart: prediction.predictedMensesStart,
          periodRangeEnd: prediction.predictedMensesEnd,
          confidence: prediction.confidence,
          observedIntervalCount: prediction.intervalCount,
          observedSpreadDays: prediction.observedSpreadDays,
        ),
        observation: observation,
        care: care,
        futureNote: futureNote,
      ),
    );
  }

  List<_CompletedCycle> _completedCycles(PatternSourceSnapshot source) {
    final starts =
        source.periods.map((record) => record.startDate).toSet().toList()
          ..sort();
    return [
      for (var index = 0; index < starts.length - 1; index += 1)
        _CompletedCycle(start: starts[index], nextStart: starts[index + 1]),
    ];
  }

  PreparationObservationEvidence? _chooseObservation(
    PersonalPatternAnalysis patterns,
    List<_CompletedCycle> completedCycles,
  ) {
    final eligible = <PreparationObservationEvidence>[];
    for (final pattern in patterns.symptomPatterns) {
      final cycleStarts = <LocalDate>{};
      final sources = <PatternSourceReference>[];
      for (final reference in pattern.sources) {
        final cycle = completedCycles
            .where((item) => item.contains(reference.date))
            .firstOrNull;
        if (cycle == null) continue;
        cycleStarts.add(cycle.start);
        sources.add(reference);
      }
      if (cycleStarts.length < 2) continue;
      final sortedStarts = cycleStarts.toList()..sort();
      eligible.add(
        PreparationObservationEvidence(
          symptom: pattern.symptom,
          recordCount: sources.length,
          distinctCompletedCycles: sortedStarts.length,
          totalCompletedCycles: completedCycles.length,
          supportingCycleStarts: List.unmodifiable(sortedStarts),
          sources: List.unmodifiable(sources),
          strength: sortedStarts.length == 2
              ? PreparationPatternStrength.early
              : PreparationPatternStrength.repeated,
        ),
      );
    }
    eligible.sort((left, right) {
      var order = right.distinctCompletedCycles.compareTo(
        left.distinctCompletedCycles,
      );
      if (order != 0) return order;
      order = right.recordCount.compareTo(left.recordCount);
      if (order != 0) return order;
      final leftLatest = left.sources
          .map((item) => item.date)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final rightLatest = right.sources
          .map((item) => item.date)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      order = rightLatest.compareTo(leftLatest);
      if (order != 0) return order;
      return left.symptom.label.compareTo(right.symptom.label);
    });
    return eligible.firstOrNull;
  }

  PreparationCareEvidence? _chooseCare(List<SupportActionPattern> actions) {
    if (actions.isEmpty) return null;
    final ranked = [...actions]
      ..sort((left, right) {
        var order = _boolScore(right.pinned).compareTo(_boolScore(left.pinned));
        if (order != 0) return order;
        order = _boolScore(
          right.betterCount > 0,
        ).compareTo(_boolScore(left.betterCount > 0));
        if (order != 0) return order;
        order = right.count.compareTo(left.count);
        if (order != 0) return order;
        order = right.lastDate.compareTo(left.lastDate);
        if (order != 0) return order;
        return left.actionId.compareTo(right.actionId);
      });
    final action = ranked.first;
    return PreparationCareEvidence(
      actionId: action.actionId,
      actionLabel: action.actionLabel,
      mode: action.mode,
      recordCount: action.count,
      betterCount: action.betterCount,
      sameCount: action.sameCount,
      worseCount: action.worseCount,
      pinned: action.pinned,
      lastRecordedDate: action.lastDate,
      sources: action.sources,
    );
  }

  PreparationFutureNoteEvidence? _futureNote(
    PatternSourceSnapshot source,
    PreparationCareEvidence care,
  ) {
    final recordIds = care.sources.map((item) => item.id).toSet();
    final matches =
        source.careReflections.where((reflection) {
            final note = reflection.futureSelfNote?.trim();
            return reflection.mode == care.mode &&
                recordIds.contains(reflection.careRecordId) &&
                note != null &&
                note.isNotEmpty;
          }).toList()
          ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    final reflection = matches.firstOrNull;
    if (reflection == null) return null;
    return PreparationFutureNoteEvidence(
      text: reflection.futureSelfNote!.trim(),
      mode: reflection.mode,
      careRecordId: reflection.careRecordId,
    );
  }

  int _boolScore(bool value) => value ? 1 : 0;
}

final class _CompletedCycle {
  const _CompletedCycle({required this.start, required this.nextStart});

  final LocalDate start;
  final LocalDate nextStart;

  bool contains(LocalDate date) =>
      !date.isBefore(start) && date.isBefore(nextStart);
}
