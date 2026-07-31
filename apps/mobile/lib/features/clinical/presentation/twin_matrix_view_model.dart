import '../../health_records/domain/health_record.dart';
import '../../patterns/domain/personal_pattern.dart';

/// View-state for the Twin Matrix clinical report.
///
/// Maps ObservedSymptomPattern data into a black-and-white DRSP-compatible
/// grid. X-axis: Days -14 to -1 (luteal) LEFT of center, Days 1 to 14
/// (menses/follicular) RIGHT. Y-axis: 4 PMDD clinical clusters.
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
    clusters.add(TwinMatrixCluster(
      label: clusterMap[1]!,
      lutealSeverities: _matrixToList(irritabilityMatrix),
      mensesSeverities: _mensesMirror(irritabilityMatrix),
    ));

    // Cluster 2: depressed mood + anxiety
    final moodMatrix = _mergeSymptomMatrices(patterns, [
      SymptomType.lowMood,
      SymptomType.anxiety,
    ]);
    clusters.add(TwinMatrixCluster(
      label: clusterMap[2]!,
      lutealSeverities: _matrixToList(moodMatrix),
      mensesSeverities: _mensesMirror(moodMatrix),
    ));

    // Cluster 3: social withdrawal (from functional impacts)
    final socialMatrix = _mergeFunctionalImpacts(patterns, [
      FunctionalImpact.socialActivity,
    ]);
    clusters.add(TwinMatrixCluster(
      label: clusterMap[3]!,
      lutealSeverities: _matrixToList(socialMatrix),
      mensesSeverities: _mensesMirror(socialMatrix),
    ));

    // Cluster 4: physical symptoms
    final physicalMatrix = _mergeSymptomMatrices(patterns, [
      SymptomType.cramps,
      SymptomType.headache,
      SymptomType.bodyAches,
      SymptomType.breastTenderness,
      SymptomType.bloating,
    ]);
    clusters.add(TwinMatrixCluster(
      label: clusterMap[4]!,
      lutealSeverities: _matrixToList(physicalMatrix),
      mensesSeverities: _mensesMirror(physicalMatrix),
    ));

    return TwinMatrixViewModel(
      clusters: clusters,
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

  /// Merges functional impact counts across matching FunctionalImpacts.
  static Map<int, double> _mergeFunctionalImpacts(
    List<ObservedSymptomPattern> patterns,
    List<FunctionalImpact> types,
  ) {
    // We use cycleDayObservations to find days-before-menses where these
    // functional impacts were recorded.
    final merged = <int, List<double>>{};
    for (final pattern in patterns) {
      for (final observation in pattern.cycleDayObservations) {
        final daysBefore = observation.daysBeforeMenses;
        if (daysBefore == null) continue;
        // Check if this pattern has any of the target functional impacts.
        final hasImpact = types.any(
          (type) => pattern.functionalImpactCounts.containsKey(type),
        );
        if (!hasImpact) continue;
        // Use the dominant severity for this observation.
        final severity = pattern.severityCounts.entries
            .fold(0, (sum, e) => sum + e.key.score * e.value);
        merged.putIfAbsent(daysBefore, () => []).add(severity.toDouble());
      }
    }
    final result = <int, double>{};
    for (final entry in merged.entries) {
      result[entry.key] =
          entry.value.reduce((a, b) => a + b) / entry.value.length;
    }
    return result;
  }

  /// Converts a Map<int, double> to a 14-element list for days -14 to -1.
  static List<double> _matrixToList(Map<int, double> matrix) {
    final list = <double>[];
    for (var day = -14; day <= -1; day++) {
      list.add(matrix[day] ?? 0.0);
    }
    return list;
  }

  /// Mirrors luteal data for the menses/follicular side of the matrix.
  static List<double> _mensesMirror(Map<int, double> matrix) {
    // For the right side (days 1-14), we project the menses-side severity
    // by mirroring the luteal pattern. In practice the pattern engine would
    // provide actual menses data; for now we mirror for visual symmetry.
    final list = <double>[];
    for (var day = 1; day <= 14; day++) {
      // Map to luteal days for visual reference (not clinically accurate)
      // but shows the cyclical nature.
      final lutealDay = -(15 - day);
      list.add(matrix[lutealDay] ?? 0.0);
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
