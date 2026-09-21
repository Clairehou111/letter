import '../../health_records/domain/health_record.dart';
import '../../check_in/domain/moment_check_in.dart';
import '../../care/domain/care_memory.dart';
import '../../cycle/domain/local_date.dart';

/// View-state for a clinician-readable summary of confirmed local evidence.
///
/// The left axis contains observed days -14 to -1 before a subsequent
/// observed period start. The right axis contains observed cycle days 1 to 14.
/// Cells are nullable: null means no observation, while a numeric value is an
/// average of confirmed ratings. No value is inferred from the other axis.
class TwinMatrixViewModel {
  const TwinMatrixViewModel({
    required this.clusters,
    required this.cycleLabel,
    required this.exportTimestamp,
    required this.totalDays,
    this.todayDay,
    this.totalObservations = 0,
    this.beforePeriodMapped = 0,
    this.cycleMapped = 0,
    this.mappedObservations = 0,
    this.cyclesCovered = 0,
    this.observedRelativeDays = 0,
    this.sameDayObservations = 0,
    this.laterRecallObservations = 0,
    this.qualitativeCheckIns = const [],
    this.careOutcomes = const [],
  });

  final List<TwinMatrixCluster> clusters;
  final String cycleLabel;
  final String exportTimestamp;
  final int totalDays;
  final int? todayDay;
  final int totalObservations;
  final int beforePeriodMapped;
  final int cycleMapped;
  final int mappedObservations;

  /// Distinct cycle keys represented by mapped symptom ratings. This is
  /// matrix coverage, not the number of observed period starts or the total
  /// number of completed cycles in the report.
  final int cyclesCovered;
  final int observedRelativeDays;
  final int sameDayObservations;
  final int laterRecallObservations;

  /// Difficult Today check-ins are qualitative companion evidence. They are
  /// deliberately excluded from the 1–5 symptom averages above.
  final List<TwinMatrixCheckInMarker> qualitativeCheckIns;

  /// Saved Care check-backs are outcome evidence. They share the timing axes
  /// but are never converted to symptom ratings or included in averages.
  final List<TwinMatrixCareMarker> careOutcomes;

  int get blankRelativeDays => totalDays - observedRelativeDays;

  /// The grouping is for scanability only; each cell retains its evidence.
  static const clusterMap = <int, String>{
    1: 'mood/irritability',
    2: 'anxiety/cognition',
    3: 'energy/sleep',
    4: 'social withdrawal',
    5: 'physical symptoms',
  };

  static const _clusterDefinitions = <_TwinMatrixClusterDefinition>[
    _TwinMatrixClusterDefinition('mood/irritability', <SymptomType>{
      SymptomType.lowMood,
      SymptomType.irritability,
      SymptomType.crying,
      SymptomType.hopelessness,
      SymptomType.anhedonia,
      SymptomType.moodSwings,
      SymptomType.rage,
      SymptomType.hypersensitivity,
      SymptomType.paranoia,
      SymptomType.impulsiveUrges,
      SymptomType.overwhelm,
    }),
    _TwinMatrixClusterDefinition('anxiety/cognition', <SymptomType>{
      SymptomType.anxiety,
      SymptomType.panicAttack,
      SymptomType.brainFog,
      SymptomType.concentration,
      SymptomType.forgetfulness,
    }),
    _TwinMatrixClusterDefinition('energy/sleep', <SymptomType>{
      SymptomType.lowEnergy,
      SymptomType.fatigue,
      SymptomType.sleepDifficulty,
      SymptomType.sleepiness,
      SymptomType.hypersomnia,
      SymptomType.insomnia,
      SymptomType.sleepDisruption,
    }),
    _TwinMatrixClusterDefinition('social withdrawal', <SymptomType>{
      SymptomType.socialWithdrawal,
    }),
    _TwinMatrixClusterDefinition('physical symptoms', <SymptomType>{
      SymptomType.cramps,
      SymptomType.headache,
      SymptomType.breastTenderness,
      SymptomType.bloating,
      SymptomType.nausea,
      SymptomType.bodyAches,
      SymptomType.pelvicPain,
      SymptomType.backPain,
      SymptomType.jointMusclePain,
      SymptomType.waterRetention,
      SymptomType.appetiteChange,
      SymptomType.constipation,
      SymptomType.hotFlashes,
      SymptomType.palpitations,
      SymptomType.diarrhea,
      SymptomType.acne,
      SymptomType.dizziness,
      SymptomType.migraine,
    }),
  ];

  /// Builds the canonical matrix from confirmed, source-linked observations.
  factory TwinMatrixViewModel.fromObservations({
    required List<TwinMatrixObservation> observations,
    List<TwinMatrixCheckInMarker> qualitativeCheckIns = const [],
    List<TwinMatrixCareMarker> careOutcomes = const [],
    required String cycleLabel,
    required String exportTimestamp,
    int? todayDay,
  }) {
    final eligible = observations
        .where((observation) => observation.userConfirmed)
        .toList(growable: false);
    final clusters = [
      for (final definition in _clusterDefinitions)
        _buildCluster(definition, eligible),
    ];
    final mapped = eligible
        .where(
          (observation) =>
              _isBeforePeriodDay(observation.daysBeforeMenses) ||
              _isCycleDay(observation.cycleDay),
        )
        .toList(growable: false);
    final observedRelativeDays = <String>{};
    for (final cluster in clusters) {
      for (var index = 0; index < cluster.beforePeriodCells.length; index++) {
        if (cluster.beforePeriodCells[index].severity != null) {
          observedRelativeDays.add('before:${-14 + index}');
        }
      }
      for (var index = 0; index < cluster.cycleCells.length; index++) {
        if (cluster.cycleCells[index].severity != null) {
          observedRelativeDays.add('cycle:${index + 1}');
        }
      }
    }
    return TwinMatrixViewModel(
      clusters: List.unmodifiable(clusters),
      cycleLabel: cycleLabel,
      exportTimestamp: exportTimestamp,
      totalDays: 28,
      todayDay: todayDay,
      totalObservations: eligible.length,
      beforePeriodMapped: eligible
          .where(
            (observation) => _isBeforePeriodDay(observation.daysBeforeMenses),
          )
          .length,
      cycleMapped: eligible
          .where((observation) => _isCycleDay(observation.cycleDay))
          .length,
      mappedObservations: mapped.length,
      cyclesCovered: mapped
          .map((observation) => observation.cycleKey)
          .whereType<String>()
          .toSet()
          .length,
      observedRelativeDays: observedRelativeDays.length,
      sameDayObservations: eligible
          .where(
            (observation) =>
                observation.provenance == HealthRecordProvenance.sameDay,
          )
          .length,
      laterRecallObservations: eligible
          .where(
            (observation) =>
                observation.provenance == HealthRecordProvenance.laterRecall,
          )
          .length,
      qualitativeCheckIns: List.unmodifiable(qualitativeCheckIns),
      careOutcomes: List.unmodifiable(careOutcomes),
    );
  }

  static TwinMatrixCluster _buildCluster(
    _TwinMatrixClusterDefinition definition,
    List<TwinMatrixObservation> observations,
  ) {
    return TwinMatrixCluster(
      label: definition.label,
      beforePeriodCells: List.unmodifiable(
        _buildCells(
          observations,
          definition.symptoms,
          (observation) => observation.daysBeforeMenses,
          minDay: -14,
          maxDay: -1,
        ),
      ),
      cycleCells: List.unmodifiable(
        _buildCells(
          observations,
          definition.symptoms,
          (observation) => observation.cycleDay,
          minDay: 1,
          maxDay: 14,
        ),
      ),
    );
  }

  /// Aggregates within each observed cycle first, then averages cycles.
  /// This prevents a heavily logged cycle from dominating a lightly logged
  /// cycle at the same relative day. Evidence remains attached to the cell.
  static List<TwinMatrixCell> _buildCells(
    List<TwinMatrixObservation> observations,
    Set<SymptomType> symptoms,
    int? Function(TwinMatrixObservation) dayFor, {
    required int minDay,
    required int maxDay,
  }) {
    final grouped = <int, Map<String, List<TwinMatrixObservation>>>{};
    for (final observation in observations) {
      if (!symptoms.contains(observation.symptom)) continue;
      final day = dayFor(observation);
      if (day == null || day < minDay || day > maxDay) continue;
      final cycleKey = observation.cycleKey ?? 'record:${observation.recordId}';
      grouped
          .putIfAbsent(day, () => {})
          .putIfAbsent(cycleKey, () => [])
          .add(observation);
    }

    return [
      for (var day = minDay; day <= maxDay; day++) _cellFor(grouped[day]),
    ];
  }

  static TwinMatrixCell _cellFor(
    Map<String, List<TwinMatrixObservation>>? byCycle,
  ) {
    if (byCycle == null || byCycle.isEmpty) {
      return const TwinMatrixCell.empty();
    }
    final cycleMeans = <double>[];
    final evidence = <TwinMatrixEvidence>[];
    for (final observations in byCycle.values) {
      cycleMeans.add(_mean(observations.map((item) => item.severity.score)));
      evidence.addAll(
        observations.map(
          (observation) => TwinMatrixEvidence.fromObservation(observation),
        ),
      );
    }
    return TwinMatrixCell(
      severity: _mean(cycleMeans),
      observationCount: evidence.length,
      cycleCount: byCycle.length,
      evidence: List.unmodifiable(evidence),
    );
  }

  static double _mean(Iterable<num> values) {
    final list = values.toList(growable: false);
    if (list.isEmpty) return 0;
    return list.fold<double>(0, (sum, value) => sum + value) / list.length;
  }

  static bool _isBeforePeriodDay(int? day) =>
      day != null && day >= -14 && day <= -1;

  static bool _isCycleDay(int? day) => day != null && day >= 1 && day <= 14;

  /// A compact text alternative for screen readers and non-visual review.
  String get accessibilitySummary {
    final lines = <String>[
      'Cyclical Symptom Summary. $cycleLabel.',
      '$mappedObservations of $totalObservations confirmed records map to the '
          'two observed timing windows across $cyclesCovered '
          '${cyclesCovered == 1 ? 'cycle' : 'cycles'} with mapped symptom '
          'ratings.',
      '$observedRelativeDays of $totalDays relative-day columns have ratings; '
          '$blankRelativeDays are blank because no eligible observation was '
          'recorded.',
      'Provenance: $sameDayObservations same-day and '
          '$laterRecallObservations later-recall records.',
      if (qualitativeCheckIns.isNotEmpty)
        '${qualitativeCheckIns.length} difficult Today '
            '${qualitativeCheckIns.length == 1 ? 'check-in is' : 'check-ins are'} '
            'shown separately and do not change symptom ratings.',
      if (careOutcomes.isNotEmpty)
        '${careOutcomes.length} saved Care '
            '${careOutcomes.length == 1 ? 'check-back is' : 'check-backs are'} '
            'shown separately with Better, Same, or Worse outcomes and do '
            'not change symptom ratings.',
    ];
    for (final cluster in clusters) {
      final cells = <String>[];
      for (var index = 0; index < cluster.beforePeriodCells.length; index++) {
        final cell = cluster.beforePeriodCells[index];
        if (cell.severity != null) {
          cells.add(
            '${(-14 + index).abs()} days before period average '
            '${cell.severity!.toStringAsFixed(1)} from '
            '${cell.observationCount} ratings across ${cell.cycleCount} cycles',
          );
        }
      }
      for (var index = 0; index < cluster.cycleCells.length; index++) {
        final cell = cluster.cycleCells[index];
        if (cell.severity != null) {
          cells.add(
            'cycle day ${index + 1} average '
            '${cell.severity!.toStringAsFixed(1)} from '
            '${cell.observationCount} ratings across ${cell.cycleCount} cycles',
          );
        }
      }
      lines.add(
        cells.isEmpty
            ? '${cluster.label}: no observed cells.'
            : '${cluster.label}: ${cells.join('; ')}.',
      );
    }
    return lines.join(' ');
  }
}

final class _TwinMatrixClusterDefinition {
  const _TwinMatrixClusterDefinition(this.label, this.symptoms);

  final String label;
  final Set<SymptomType> symptoms;
}

final class TwinMatrixCluster {
  const TwinMatrixCluster({
    required this.label,
    required this.beforePeriodCells,
    required this.cycleCells,
  });

  final String label;
  final List<TwinMatrixCell> beforePeriodCells;
  final List<TwinMatrixCell> cycleCells;
}

final class TwinMatrixCell {
  const TwinMatrixCell({
    required this.severity,
    required this.observationCount,
    required this.cycleCount,
    required this.evidence,
  });

  const TwinMatrixCell.empty()
    : severity = null,
      observationCount = 0,
      cycleCount = 0,
      evidence = const [];

  final double? severity;
  final int observationCount;
  final int cycleCount;
  final List<TwinMatrixEvidence> evidence;
}

final class TwinMatrixEvidence {
  const TwinMatrixEvidence({
    required this.recordId,
    required this.experiencedDate,
    required this.symptom,
    required this.severity,
    required this.provenance,
    required this.functionalImpacts,
  });

  factory TwinMatrixEvidence.fromObservation(
    TwinMatrixObservation observation,
  ) {
    return TwinMatrixEvidence(
      recordId: observation.recordId,
      experiencedDate: observation.experiencedDate,
      symptom: observation.symptom,
      severity: observation.severity,
      provenance: observation.provenance,
      functionalImpacts: Set.unmodifiable(observation.functionalImpacts),
    );
  }

  final String recordId;
  final LocalDate experiencedDate;
  final SymptomType symptom;
  final SymptomSeverity severity;
  final HealthRecordProvenance provenance;
  final Set<FunctionalImpact> functionalImpacts;
}

final class TwinMatrixObservation {
  const TwinMatrixObservation({
    required this.recordId,
    required this.experiencedDate,
    required this.symptom,
    required this.severity,
    required this.daysBeforeMenses,
    required this.cycleDay,
    required this.provenance,
    required this.userConfirmed,
    this.cycleKey,
    this.functionalImpacts = const {},
  });

  final String recordId;
  final LocalDate experiencedDate;
  final SymptomType symptom;
  final SymptomSeverity severity;
  final int? daysBeforeMenses;
  final int? cycleDay;
  final String? cycleKey;
  final HealthRecordProvenance provenance;
  final bool userConfirmed;
  final Set<FunctionalImpact> functionalImpacts;
}

/// A qualitative Today check-in that shares the matrix's timing axes without
/// being converted to a numerical symptom rating.
final class TwinMatrixCheckInMarker {
  const TwinMatrixCheckInMarker({
    required this.recordId,
    required this.recordedAt,
    required this.state,
    required this.daysBeforeMenses,
    required this.cycleDay,
    this.cycleKey,
    this.occurrenceCount = 1,
  });

  final String recordId;
  final DateTime recordedAt;
  final MomentCheckInState state;
  final int? daysBeforeMenses;
  final int? cycleDay;
  final String? cycleKey;

  /// Number of source check-ins represented by this marker.
  ///
  /// Older builds could leave more than one identical mood check-in on the
  /// same local day. The clinician view keeps that fact without rendering a
  /// row (or an overlapping ring) for every tap.
  final int occurrenceCount;
}

/// A saved Care outcome that shares the matrix timing axes without becoming
/// a numerical symptom observation.
final class TwinMatrixCareMarker {
  const TwinMatrixCareMarker({
    required this.recordId,
    required this.recordedAt,
    required this.actionLabel,
    required this.outcome,
    required this.daysBeforeMenses,
    required this.cycleDay,
    this.cycleKey,
  });

  final String recordId;
  final DateTime recordedAt;
  final String actionLabel;
  final CareOutcome outcome;
  final int? daysBeforeMenses;
  final int? cycleDay;
  final String? cycleKey;
}
