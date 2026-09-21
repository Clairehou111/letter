import '../../clinical/presentation/twin_matrix_view_model.dart';
import '../../health_records/domain/health_record.dart';
import '../domain/cycle_care_summary.dart';

/// Maps the exact summary snapshot shown and exported into Twin Matrix input.
///
/// Keeping this adapter public lets integration tests exercise the production
/// cycle anchoring instead of rebuilding observations by hand.
abstract final class TwinMatrixSummaryAdapter {
  static TwinMatrixViewModel fromSummary({
    required CycleAndCareSummary summary,
    required String exportTimestamp,
  }) {
    final qualitativeCheckIns = _groupDifficultCheckIns(summary.checkInRows);
    return TwinMatrixViewModel.fromObservations(
      observations: [
        for (final row in summary.healthRows)
          TwinMatrixObservation(
            recordId: row.id,
            experiencedDate: row.date,
            symptom: row.symptom,
            severity: row.severity,
            daysBeforeMenses: row.daysBeforeMenses,
            cycleDay: row.cycleDay,
            cycleKey: row.cycleStartDate?.epochDay.toString(),
            provenance: row.provenance == SummaryRecordProvenance.sameDay
                ? HealthRecordProvenance.sameDay
                : HealthRecordProvenance.laterRecall,
            userConfirmed: true,
            functionalImpacts: row.functionalImpacts,
          ),
      ],
      qualitativeCheckIns: qualitativeCheckIns,
      careOutcomes: [
        for (final row in summary.careRows)
          TwinMatrixCareMarker(
            recordId: row.id,
            recordedAt: row.recordedAt,
            actionLabel: row.actionLabel,
            outcome: row.outcome,
            daysBeforeMenses: row.daysBeforeMenses,
            cycleDay: row.cycleDay,
            cycleKey: row.cycleStartDate?.epochDay.toString(),
          ),
      ],
      cycleLabel: summary.range.label,
      exportTimestamp: exportTimestamp,
    );
  }

  static List<TwinMatrixCheckInMarker> _groupDifficultCheckIns(
    List<SummaryCheckInRow> rows,
  ) {
    final groups = <String, List<SummaryCheckInRow>>{};
    for (final row in rows.where((row) => row.isDifficult)) {
      final key = '${row.date.epochDay}:${row.state.name}';
      groups.putIfAbsent(key, () => <SummaryCheckInRow>[]).add(row);
    }

    final markers = <TwinMatrixCheckInMarker>[];
    for (final group in groups.values) {
      group.sort((left, right) => left.recordedAt.compareTo(right.recordedAt));
      final latest = group.last;
      markers.add(
        TwinMatrixCheckInMarker(
          recordId: latest.id,
          recordedAt: latest.recordedAt,
          state: latest.state,
          daysBeforeMenses: latest.daysBeforeMenses,
          cycleDay: latest.cycleDay,
          cycleKey: latest.cycleStartDate?.epochDay.toString(),
          occurrenceCount: group.length,
        ),
      );
    }
    markers.sort((left, right) => left.recordedAt.compareTo(right.recordedAt));
    return List.unmodifiable(markers);
  }
}
