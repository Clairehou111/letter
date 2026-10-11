import 'dart:math';

import '../../check_in/domain/moment_check_in.dart';
import '../../cycle/domain/cycle_prediction.dart';
import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_record.dart';
import '../../health_records/domain/health_record.dart';
import 'record_hub_facts.dart';
import 'record_programme.dart';

enum ComfortDayClass { harder, nonHard, partial, unobserved }

enum ComfortWindowStrength { emerging, clearer }

/// A new explicit-zero algorithm. It never mixes legacy classifications into
/// its denominator, and never interprets a positive Moment as symptom absence.
final class ComfortDayEvidence {
  ComfortDayEvidence({
    required this.date,
    required this.classification,
    required Iterable<String> sourceIds,
    required Iterable<String> configurationIds,
    Map<String, int> sourceRevisions = const {},
  }) : sourceIds = List.unmodifiable(sourceIds.toSet().toList()..sort()),
       sourceRevisions = Map.unmodifiable(
         Map.fromEntries(
           sourceRevisions.entries.toList()
             ..sort((a, b) => a.key.compareTo(b.key)),
         ),
       ),
       configurationIds = List.unmodifiable(
         configurationIds.toSet().toList()..sort(),
       );
  final LocalDate date;
  final ComfortDayClass classification;
  final List<String> sourceIds;
  final List<String> configurationIds;
  final Map<String, int> sourceRevisions;
  bool get isClassified =>
      classification == ComfortDayClass.harder ||
      classification == ComfortDayClass.nonHard;
}

final class ComfortCycleEvidence {
  ComfortCycleEvidence({
    required this.cycleId,
    required this.cycleStart,
    required this.followingPeriodId,
    required this.anchor,
    required Iterable<ComfortDayEvidence> days,
  }) : days = List.unmodifiable(days);
  final String cycleId;
  final LocalDate cycleStart;
  final String followingPeriodId;
  final LocalDate anchor;
  final List<ComfortDayEvidence> days;
  int get observedDays => days.where((day) => day.isClassified).length;
  int get nonHardDays =>
      days.where((day) => day.classification == ComfortDayClass.nonHard).length;
  bool get eligible => observedDays >= 9 && nonHardDays >= 3;
}

final class ComfortCycleVote {
  const ComfortCycleVote({
    required this.evidence,
    required this.insideObserved,
    required this.outsideObserved,
    required this.insideHarder,
    required this.outsideHarder,
    required this.supports,
  });
  final ComfortCycleEvidence evidence;
  final int insideObserved, outsideObserved, insideHarder, outsideHarder;
  final bool supports;
  double get insideRate => insideHarder / insideObserved;
  double get outsideRate => outsideHarder / outsideObserved;
  double get lift => insideRate - outsideRate;
}

final class ComfortWindowResult {
  ComfortWindowResult({
    required this.startOffset,
    required this.endOffset,
    required this.strength,
    required Iterable<ComfortCycleVote> votes,
    required Iterable<ComfortCycleEvidence> examinedCycles,
    required this.prediction,
  }) : votes = List.unmodifiable(votes),
       examinedCycles = List.unmodifiable(examinedCycles);
  static const algorithmVersion = 'native-comfort-window-explicit-zero-v1';
  final int startOffset, endOffset;
  final ComfortWindowStrength strength;
  final List<ComfortCycleVote> votes;
  final List<ComfortCycleEvidence> examinedCycles;
  final CyclePrediction? prediction;
  Map<String, Object?> get canonicalEvidence => {
    'algorithmVersion': algorithmVersion,
    'startOffset': startOffset,
    'endOffset': endOffset,
    'strength': strength.name,
    'supportCount': supportCount,
    'votingCycles': votes.length,
    'supportRatio': supportRatio,
    'averageLift': averageLift,
    'confidence': prediction?.confidence.name,
    'forecastSpreadDays': prediction?.observedSpreadDays,
    'rangeStart': rangeStart?.toString(),
    'rangeEnd': rangeEnd?.toString(),
    'cycles': [
      for (final cycle in examinedCycles)
        {
          'cycleId': cycle.cycleId,
          'followingPeriodId': cycle.followingPeriodId,
          'anchor': cycle.anchor.toString(),
          'observedDays': cycle.observedDays,
          'nonHardDays': cycle.nonHardDays,
          'eligible': cycle.eligible,
          'days': [
            for (final day in cycle.days)
              {
                'date': day.date.toString(),
                'class': day.classification.name,
                'sourceIds': day.sourceIds,
                'sourceRevisions': day.sourceRevisions,
                'configurationIds': day.configurationIds,
              },
          ],
        },
    ],
    'votes': [
      for (final vote in votes)
        {
          'cycleId': vote.evidence.cycleId,
          'insideObserved': vote.insideObserved,
          'outsideObserved': vote.outsideObserved,
          'insideHarder': vote.insideHarder,
          'outsideHarder': vote.outsideHarder,
          'support': vote.supports,
          'lift': vote.lift,
        },
    ],
  };

  int get supportCount => votes.where((vote) => vote.supports).length;
  double get supportRatio => supportCount / votes.length;
  double get averageLift =>
      votes.map((vote) => vote.lift).reduce((a, b) => a + b) / votes.length;
  int get insideHarderCount =>
      votes.fold(0, (sum, vote) => sum + vote.insideHarder);
  int get length => endOffset - startOffset + 1;
  LocalDate? get rangeStart =>
      prediction?.predictedMensesStart.addDays(startOffset);
  LocalDate? get rangeEnd => prediction?.predictedMensesEnd.addDays(endOffset);
  bool get reliable =>
      strength == ComfortWindowStrength.clearer &&
      prediction != null &&
      !prediction!.isEarlyEstimate &&
      prediction!.confidence != PredictionConfidence.low &&
      prediction!.observedSpreadDays <= 7 &&
      rangeEnd!.epochDay - rangeStart!.epochDay + 1 <= 10;
  bool preparationVisibleOn(LocalDate today) =>
      reliable &&
      !today.isBefore(rangeStart!.addDays(-2)) &&
      !today.isAfter(rangeEnd!);
  DateTime? reminderAt({required LocalDate today, required int leadDays}) {
    if (!reliable || leadDays < 0 || leadDays > 2) return null;
    final day = rangeStart!.addDays(-leadDays);
    if (day.isBefore(today)) return null;
    return DateTime(day.year, day.month, day.day, 9);
  }
}

final class ComfortWindowEngine {
  const ComfortWindowEngine();

  ComfortDayEvidence classify({
    required LocalDate date,
    required Iterable<HealthRecord> symptoms,
    required Iterable<DailyImpactRecord> impacts,
    required Iterable<MomentCheckIn> moments,
    required Iterable<RecordProgramme> programmes,
  }) {
    // Select the active version first; a recalled replacement cannot expose an
    // older same-day value through duplicate legacy/imported source rows.
    final currentSymptoms = <SymptomType, HealthRecord>{};
    for (final record in symptoms.where(
      (record) => record.experiencedDate == date,
    )) {
      final previous = currentSymptoms[record.symptom];
      if (previous == null ||
          record.updatedAt.isAfter(previous.updatedAt) ||
          (record.updatedAt == previous.updatedAt &&
              record.id.compareTo(previous.id) > 0)) {
        currentSymptoms[record.symptom] = record;
      }
    }
    final trustedSymptoms = currentSymptoms.values
        .where(
          (record) =>
              record.provenance == HealthRecordProvenance.sameDay &&
              record.userConfirmed &&
              record.vocabularyVersion <= healthRecordVocabularyVersion,
        )
        .toList();
    final datedImpacts =
        impacts.where((record) => record.experiencedDate == date).toList()
          ..sort((a, b) {
            final time = b.metadata.updatedAt.compareTo(a.metadata.updatedAt);
            return time == 0 ? b.id.compareTo(a.id) : time;
          });
    final impact = datedImpacts.firstOrNull;
    final trustedImpact =
        impact?.metadata.provenance == HealthRecordProvenance.sameDay &&
            impact!.metadata.vocabularyVersion <= recordHubVocabularyVersion
        ? impact
        : null;
    final trustedMoments = moments
        .where(
          (record) =>
              record.experiencedDate == date &&
              record.provenance == HealthRecordProvenance.sameDay,
        )
        .toList();
    final configurations = programmes
        .where((programme) => programme.expectsImpactOn(date))
        .map((programme) => programme.configOn(date))
        .whereType<RecordProgrammeConfig>()
        .toList();
    final core = configurations.expand((config) => config.symptoms).toSet();
    final harder =
        trustedSymptoms.any((record) => record.severity.score > 0) ||
        (trustedImpact?.value.overall ?? 0) > 0 ||
        trustedMoments.any((record) => _difficult.contains(record.state));
    final completeZero =
        core.isNotEmpty &&
        trustedImpact?.value.overall == 0 &&
        core.every(
          (symptom) => trustedSymptoms.any(
            (record) => record.symptom == symptom && record.severity.score == 0,
          ),
        );
    return ComfortDayEvidence(
      date: date,
      classification: harder
          ? ComfortDayClass.harder
          : completeZero
          ? ComfortDayClass.nonHard
          : trustedSymptoms.isNotEmpty ||
                trustedImpact != null ||
                trustedMoments.isNotEmpty
          ? ComfortDayClass.partial
          : ComfortDayClass.unobserved,
      sourceIds: [
        ...trustedSymptoms.map((record) => record.id),
        if (trustedImpact != null) trustedImpact.id,
        ...trustedMoments.map((record) => record.id),
      ],
      configurationIds: configurations.map((config) => config.id),
      sourceRevisions: {
        for (final record in trustedSymptoms)
          'symptom:${record.id}': record.updatedAt.millisecondsSinceEpoch,
        if (trustedImpact != null)
          'impact:${trustedImpact.id}':
              trustedImpact.metadata.updatedAt.millisecondsSinceEpoch,
        for (final moment in trustedMoments)
          'moment:${moment.id}': moment.updatedAt.millisecondsSinceEpoch,
      },
    );
  }

  ComfortWindowResult? analyze({
    required Iterable<PeriodRecord> periods,
    required Iterable<HealthRecord> symptoms,
    required Iterable<DailyImpactRecord> impacts,
    required Iterable<MomentCheckIn> moments,
    required Iterable<RecordProgramme> programmes,
    required LocalDate today,
  }) {
    final byStart = <LocalDate, PeriodRecord>{};
    final ordered =
        CyclePredictionEngine.recordsThrough(periods, today).toList()
          ..sort((a, b) {
            final time = a.updatedAt.compareTo(b.updatedAt);
            return time == 0 ? a.id.compareTo(b.id) : time;
          });
    for (final period in ordered) {
      byStart[period.startDate] = period;
    }
    final starts = byStart.keys.toList()..sort();
    if (starts.length < 3) return null;
    final cycles = <ComfortCycleEvidence>[];
    for (
      var index = max(0, starts.length - 7);
      index < starts.length - 1;
      index++
    ) {
      final anchor = starts[index + 1];
      cycles.add(
        ComfortCycleEvidence(
          cycleId: byStart[starts[index]]!.id,
          cycleStart: starts[index],
          followingPeriodId: byStart[anchor]!.id,
          anchor: anchor,
          days: [
            for (var offset = -14; offset <= 3; offset++)
              // Never train on sources from the ongoing cycle. Earlier completed
              // windows retain their +0…+3 observations around the known anchor.
              if (anchor.addDays(offset).isBefore(starts.last) &&
                  !anchor.addDays(offset).isBefore(starts[index]))
                classify(
                  date: anchor.addDays(offset),
                  symptoms: symptoms,
                  impacts: impacts,
                  moments: moments,
                  programmes: programmes,
                ),
          ],
        ),
      );
    }
    final candidates = <ComfortWindowResult>[];
    final prediction = CyclePredictionEngine.calculate(byStart.values);
    for (var length = 3; length <= 7; length++) {
      for (var start = -14; start + length - 1 <= 3; start++) {
        final end = start + length - 1;
        final votes = <ComfortCycleVote>[];
        for (final cycle in cycles.where((cycle) => cycle.eligible)) {
          final classified = cycle.days.where((day) => day.isClassified);
          final inside = classified.where((day) {
            final offset = day.date.epochDay - cycle.anchor.epochDay;
            return offset >= start && offset <= end;
          }).toList();
          final outside = classified.where((day) {
            final offset = day.date.epochDay - cycle.anchor.epochDay;
            return offset < start || offset > end;
          }).toList();
          if (inside.length < max(2, (length / 2).ceil()) ||
              outside.length < 5) {
            continue;
          }
          final insideHarder = inside
              .where((day) => day.classification == ComfortDayClass.harder)
              .length;
          final outsideHarder = outside
              .where((day) => day.classification == ComfortDayClass.harder)
              .length;
          final lift =
              insideHarder / inside.length - outsideHarder / outside.length;
          votes.add(
            ComfortCycleVote(
              evidence: cycle,
              insideObserved: inside.length,
              outsideObserved: outside.length,
              insideHarder: insideHarder,
              outsideHarder: outsideHarder,
              supports:
                  insideHarder >= 2 &&
                  insideHarder / inside.length >= .5 &&
                  lift >= .25,
            ),
          );
        }
        final support = votes.where((vote) => vote.supports).length;
        final strength = votes.length >= 3 && support / votes.length >= .75
            ? ComfortWindowStrength.clearer
            : votes.length == 2 && support == 2
            ? ComfortWindowStrength.emerging
            : null;
        if (strength != null) {
          candidates.add(
            ComfortWindowResult(
              startOffset: start,
              endOffset: end,
              strength: strength,
              votes: votes,
              examinedCycles: cycles,
              prediction: prediction,
            ),
          );
        }
      }
    }
    candidates.sort((a, b) {
      for (final comparison in [
        b.supportRatio.compareTo(a.supportRatio),
        b.averageLift.compareTo(a.averageLift),
        b.insideHarderCount.compareTo(a.insideHarderCount),
        a.length.compareTo(b.length),
        (a.startOffset + a.endOffset).abs().compareTo(
          (b.startOffset + b.endOffset).abs(),
        ),
        a.startOffset.compareTo(b.startOffset),
      ]) {
        if (comparison != 0) return comparison;
      }
      return 0;
    });
    return candidates.firstOrNull;
  }

  static const _difficult = {
    MomentCheckInState.low,
    MomentCheckInState.irritable,
    MomentCheckInState.anxious,
    MomentCheckInState.overwhelmed,
    MomentCheckInState.exhausted,
    MomentCheckInState.physical,
  };
}
