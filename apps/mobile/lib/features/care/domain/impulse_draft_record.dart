enum ImpulseDraftState { draft, locked, ready }

final class ImpulseDraftRecord {
  const ImpulseDraftRecord({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.sealedAt,
    required this.unlockAt,
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? sealedAt;
  final DateTime? unlockAt;

  ImpulseDraftState stateAt(DateTime now) {
    final unlock = unlockAt;
    if (sealedAt == null || unlock == null) {
      return ImpulseDraftState.draft;
    }
    return now.toUtc().isBefore(unlock.toUtc())
        ? ImpulseDraftState.locked
        : ImpulseDraftState.ready;
  }

  Duration remainingAt(DateTime now) {
    if (stateAt(now) != ImpulseDraftState.locked) {
      return Duration.zero;
    }
    return unlockAt!.toUtc().difference(now.toUtc());
  }
}
