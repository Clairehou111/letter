import '../../cycle/domain/period_record.dart';
import '../../patterns/domain/personal_pattern.dart';

/// Decides when the one-time Plus preview has something honest to show.
///
/// Three recorded starts represent two completed cycles. A repeated symptom
/// pattern already requires at least two confirmed observations; Care evidence
/// must also repeat, so one acute moment can never start a commercial preview.
abstract final class PlusPreviewEvidencePolicy {
  static bool isEligible({
    required List<PeriodRecord> periods,
    required PersonalPatternAnalysis analysis,
  }) {
    final distinctStarts = periods.map((period) => period.startDate).toSet();
    if (distinctStarts.length < 3) return false;
    return analysis.symptomPatterns.isNotEmpty ||
        analysis.supportActions.any((action) => action.count >= 2);
  }
}
