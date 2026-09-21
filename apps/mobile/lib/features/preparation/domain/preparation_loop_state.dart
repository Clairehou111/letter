import 'preparation_plan.dart';
import 'preparation_snapshot.dart';

enum PreparationLoopKind {
  proposed,
  saved,
  privateReference,
  stale,
  withdrawn,
  dismissed,
}

final class PreparationLoopState {
  const PreparationLoopState({
    required this.kind,
    required this.snapshot,
    required this.proposalFingerprint,
    required this.plan,
    required this.dismissals,
  });

  final PreparationLoopKind kind;
  final PreparationSnapshot snapshot;
  final String proposalFingerprint;
  final PreparationPlan? plan;
  final List<PreparationDismissal> dismissals;

  static Future<PreparationLoopState> load({
    required PreparationSnapshot snapshot,
    required PreparationRepository repository,
    required Set<String> currentSourceIds,
  }) async {
    final plan = await repository.getActivePlan();
    final results = await Future.wait<Object>([
      PreparationFingerprint.forSnapshot(snapshot),
      repository.getDismissals(),
    ]);
    final fingerprint = results[0] as String;
    final dismissals = results[1] as List<PreparationDismissal>;

    if (plan != null) {
      final hasEvidenceSelection = plan.includeCare || plan.noteText != null;
      final currentSelectionFingerprint =
          snapshot.care == null && hasEvidenceSelection
          ? null
          : await PreparationFingerprint.forSelection(
              snapshot,
              includeCare: plan.includeCare,
              includeNote: plan.noteText != null,
            );
      final supportIds = plan.sourceRecordIds.toSet();
      final hasAnySupport =
          !hasEvidenceSelection || supportIds.any(currentSourceIds.contains);
      final kind = switch ((
        plan.status,
        hasAnySupport,
        plan.evidenceFingerprint == currentSelectionFingerprint,
      )) {
        (PreparationPlanStatus.privateReference, _, _) =>
          PreparationLoopKind.privateReference,
        (_, false, _) => PreparationLoopKind.withdrawn,
        (_, true, true) => PreparationLoopKind.saved,
        (_, true, false) => PreparationLoopKind.stale,
      };
      return PreparationLoopState(
        kind: kind,
        snapshot: snapshot,
        proposalFingerprint: fingerprint,
        plan: plan,
        dismissals: dismissals,
      );
    }

    final dismissed = dismissals.any((item) => item.fingerprint == fingerprint);
    return PreparationLoopState(
      kind: dismissed
          ? PreparationLoopKind.dismissed
          : PreparationLoopKind.proposed,
      snapshot: snapshot,
      proposalFingerprint: fingerprint,
      plan: null,
      dismissals: dismissals,
    );
  }
}
