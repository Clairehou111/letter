import '../../cycle/domain/period_record.dart';

enum PlusPreviewAccess { notEligible, active, ended, entitled }

final class PlusPreviewGrant {
  const PlusPreviewGrant({
    required this.startedAt,
    required this.expiresAt,
    required this.anchorPeriodId,
  });

  final DateTime startedAt;
  final DateTime expiresAt;
  final String anchorPeriodId;
}

abstract interface class PlusPreviewGrantRepository {
  Future<PlusPreviewGrant?> load();
  Future<void> save(PlusPreviewGrant grant);
}

final class PlusPreviewDecision {
  const PlusPreviewDecision(this.access, {this.grant});

  final PlusPreviewAccess access;
  final PlusPreviewGrant? grant;

  bool get canUsePlusDepth =>
      access == PlusPreviewAccess.active ||
      access == PlusPreviewAccess.entitled;
}

/// Starts once, only after real Plus-grade evidence exists. The grant covers
/// the remainder of the current cycle and one following cycle, but never more
/// than 45 days. A second period start after the anchor closes it.
final class PlusPreviewController {
  const PlusPreviewController(this._repository);

  final PlusPreviewGrantRepository _repository;

  Future<PlusPreviewDecision> resolve({
    required bool hasPaidAccess,
    required bool hasPlusGradeEvidence,
    required List<PeriodRecord> periods,
    required DateTime now,
  }) async {
    if (hasPaidAccess) {
      return const PlusPreviewDecision(PlusPreviewAccess.entitled);
    }
    final ordered = periods.toList(growable: false)
      ..sort((left, right) => left.startDate.compareTo(right.startDate));
    final current = await _repository.load();
    if (current == null) {
      if (!hasPlusGradeEvidence || ordered.isEmpty) {
        return const PlusPreviewDecision(PlusPreviewAccess.notEligible);
      }
      final started = now.toUtc();
      final grant = PlusPreviewGrant(
        startedAt: started,
        expiresAt: started.add(const Duration(days: 45)),
        anchorPeriodId: ordered.last.id,
      );
      await _repository.save(grant);
      return PlusPreviewDecision(PlusPreviewAccess.active, grant: grant);
    }

    final afterAnchor = _startsAfterAnchor(ordered, current.anchorPeriodId);
    final expiredByTime = !now.toUtc().isBefore(current.expiresAt);
    if (expiredByTime || afterAnchor >= 2) {
      return PlusPreviewDecision(PlusPreviewAccess.ended, grant: current);
    }
    return PlusPreviewDecision(PlusPreviewAccess.active, grant: current);
  }

  int _startsAfterAnchor(List<PeriodRecord> periods, String anchorId) {
    final anchorIndex = periods.indexWhere((period) => period.id == anchorId);
    if (anchorIndex < 0) return 2;
    return periods.length - anchorIndex - 1;
  }
}
