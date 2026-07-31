import '../../health_records/domain/health_record.dart';
import '../../patterns/domain/personal_pattern.dart';

/// View-state for the Twin Matrix clinical report.
///
/// Maps confirmed personal-pattern data into a black-and-white clinical grid.
/// X-axis: observed days -14 to -1 before menses on the left and observed cycle
/// days 1 to 14 on the right.
///
/// Design spec: clinical_representation.md.
class TwinMatrixViewModel {
  const TwinMatrixViewModel({
    required this.clusters,
    required this.cycleLabel,
    required this.exportTimestamp,
    required this.totalDays,
  });

  /// The 4 PMDD clusters with their severity data.
  final List<TwinMatrixCluster> clusters;

  /// e.g. "last 3 cycles"
  final String cycleLabel;

  /// Export timestamp for the header.
  final String exportTimestamp;

  /// Total days across the matrix (28).
  final int totalDays;

  /// Maps SymptomTypes to PMDD clusters.
  static const clusterMap = {
    1: 'irritability/anger',
    2: 'depressed mood/anxiety',
    3: 'social withdrawal',
    4: 'physical cramps/pain',
  };

  factory TwinMatrixViewModel.fromPatterns({
    required List<ObservedSymptomPattern> patterns,
    required String cycleLabel,
    required String exportTimestamp,
  }) {
    final clusters = <TwinMatrixCluster>[];

    // Cluster 1: irritability
    final irritabilityMatrix = _mergeSymptomMatrices(patterns, [
      SymptomType.irritability,
    ]);
    final irritabilityCycleDays = _mergeCycleDayMatrices(patterns, [
      SymptomType.irritability,
    ]);
    clusters.add(
      TwinMatrixCluster(
        label: clusterMap[1]!,
        lutealSeverities: _matrixToList(irritabilityMatrix),
        mensesSeverities: _cycleDayMatrixToList(irritabilityCycleDays),
      ),
    );

    // Cluster 2: depressed mood + anxiety
    final moodMatrix = _mergeSymptomMatrices(patterns, [
      SymptomType.lowMood,
      SymptomType.anxiety,
    ]);
    final moodCycleDays = _mergeCycleDayMatrices(patterns, [
      SymptomType.lowMood,
      SymptomType.anxiety,
    ]);
    clusters.add(
      TwinMatrixCluster(
        label: clusterMap[2]!,
        lutealSeverities: _matrixToList(moodMatrix),
        mensesSeverities: _cycleDayMatrixToList(moodCycleDays),
      ),
    );

    // Cluster 3: social withdrawal (from functional impacts)
    clusters.add(
      TwinMatrixCluster(
        label: clusterMap[3]!,
        lutealSeverities: List.filled(14, 0),
        mensesSeverities: List.filled(14, 0),
      ),
    );

    // Cluster 4: physical symptoms
    final physicalMatrix = _mergeSymptomMatrices(patterns, [
      SymptomType.cramps,
      SymptomType.headache,
      SymptomType.bodyAches,
      SymptomType.breastTenderness,
      SymptomType.bloating,
    ]);
    final physicalCycleDays = _mergeCycleDayMatrices(patterns, [
      SymptomType.cramps,
      SymptomType.headache,
      SymptomType.bodyAches,
      SymptomType.breastTenderness,
      SymptomType.bloating,
    ]);
    clusters.add(
      TwinMatrixCluster(
        label: clusterMap[4]!,
        lutealSeverities: _matrixToList(physicalMatrix),
        mensesSeverities: _cycleDayMatrixToList(physicalCycleDays),
      ),
    );

    return TwinMatrixViewModel(
      clusters: clusters,
      cycleLabel: cycleLabel,
      exportTimestamp: exportTimestamp,
      totalDays: 28,
    );
  }

  factory TwinMatrixViewModel.fromObservations({
    required List<TwinMatrixObservation> observations,
    required String cycleLabel,
    required String exportTimestamp,
  }) {
    TwinMatrixCluster cluster(String label, Set<SymptomType> symptoms) {
      final relevant = observations.where(
        (observation) => symptoms.contains(observation.symptom),
      );
      final before = <int, List<int>>{};
      final after = <int, List<int>>{};
      for (final observation in relevant) {
        final beforeDay = observation.daysBeforeMenses;
        if (beforeDay != null && beforeDay >= -14 && beforeDay <= -1) {
          before
              .putIfAbsent(beforeDay, () => [])
              .add(observation.severity.score);
        }
        final cycleDay = observation.cycleDay;
        if (cycleDay != null && cycleDay >= 1 && cycleDay <= 14) {
          after.putIfAbsent(cycleDay, () => []).add(observation.severity.score);
        }
      }
      double average(List<int>? values) {
        if (values == null || values.isEmpty) return 0;
        return values.fold<int>(0, (sum, value) => sum + value) / values.length;
      }

      return TwinMatrixCluster(
        label: label,
        lutealSeverities: [
          for (var day = -14; day <= -1; day++) average(before[day]),
        ],
        mensesSeverities: [
          for (var day = 1; day <= 14; day++) average(after[day]),
        ],
      );
    }

    return TwinMatrixViewModel(
      clusters: [
        cluster(clusterMap[1]!, {SymptomType.irritability}),
        cluster(clusterMap[2]!, {SymptomType.lowMood, SymptomType.anxiety}),
        TwinMatrixCluster(
          label: clusterMap[3]!,
          lutealSeverities: List.filled(14, 0),
          mensesSeverities: List.filled(14, 0),
        ),
        cluster(clusterMap[4]!, {
          SymptomType.cramps,
          SymptomType.headache,
          SymptomType.bodyAches,
          SymptomType.breastTenderness,
          SymptomType.bloating,
        }),
      ],
      cycleLabel: cycleLabel,
      exportTimestamp: exportTimestamp,
      totalDays: 28,
    );
  }

  /// Merges severityByDaysBeforeMenses across matching SymptomTypes.
  static Map<int, double> _mergeSymptomMatrices(
    List<ObservedSymptomPattern> patterns,
    List<SymptomType> types,
  ) {
    final merged = <int, List<double>>{};
    for (final pattern in patterns) {
      if (!types.contains(pattern.symptom)) continue;
      for (final entry in pattern.severityByDaysBeforeMenses.entries) {
        merged.putIfAbsent(entry.key, () => []).add(entry.value);
      }
    }
    final result = <int, double>{};
    for (final entry in merged.entries) {
      result[entry.key] =
          entry.value.reduce((a, b) => a + b) / entry.value.length;
    }
    return result;
  }

  static Map<int, double> _mergeCycleDayMatrices(
    List<ObservedSymptomPattern> patterns,
    List<SymptomType> types,
  ) {
    final merged = <int, List<double>>{};
    for (final pattern in patterns) {
      if (!types.contains(pattern.symptom)) continue;
      for (final entry in pattern.severityByCycleDay.entries) {
        merged.putIfAbsent(entry.key, () => []).add(entry.value);
      }
    }
    final result = <int, double>{};
    for (final entry in merged.entries) {
      result[entry.key] =
          entry.value.reduce((a, b) => a + b) / entry.value.length;
    }
    return result;
  }

  /// Converts a `Map<int, double>` to a 14-element list for days -14 to -1.
  static List<double> _matrixToList(Map<int, double> matrix) {
    final list = <double>[];
    for (var day = -14; day <= -1; day++) {
      list.add(matrix[day] ?? 0.0);
    }
    return list;
  }

  static List<double> _cycleDayMatrixToList(Map<int, double> matrix) {
    final list = <double>[];
    for (var day = 1; day <= 14; day++) {
      list.add(matrix[day] ?? 0.0);
    }
    return list;
  }
}

/// One PMDD cluster row in the Twin Matrix.
class TwinMatrixCluster {
  const TwinMatrixCluster({
    required this.label,
    required this.lutealSeverities,
    required this.mensesSeverities,
  });

  /// e.g. "irritability/anger"
  final String label;

  /// 14 values for days -14 to -1 (luteal phase, left of center).
  final List<double> lutealSeverities;

  /// 14 values for days 1 to 14 (menses/follicular, right of center).
  final List<double> mensesSeverities;
}

final class TwinMatrixObservation {
  const TwinMatrixObservation({
    required this.symptom,
    required this.severity,
    required this.daysBeforeMenses,
    required this.cycleDay,
  });

  final SymptomType symptom;
  final SymptomSeverity severity;
  final int? daysBeforeMenses;
  final int? cycleDay;
}
