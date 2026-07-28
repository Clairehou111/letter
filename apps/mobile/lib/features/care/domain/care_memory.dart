import 'care_mode.dart';

enum CareOutcome { better, same, worse }

enum ReflectionNeed {
  boundaries,
  connection,
  autonomy,
  restOrPhysicalCapacity,
  somethingElse,
  notSure,
}

final class CareActionCompletion {
  const CareActionCompletion({
    required this.mode,
    required this.actionId,
    required this.actionLabel,
    required this.occurredAt,
  });

  final CareMode mode;
  final String actionId;
  final String actionLabel;
  final DateTime occurredAt;
}

final class CareRecord {
  const CareRecord({
    required this.id,
    required this.mode,
    required this.actionId,
    required this.actionLabel,
    required this.outcome,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    required this.pinned,
  });

  final String id;
  final CareMode mode;
  final String actionId;
  final String actionLabel;
  final CareOutcome outcome;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pinned;

  CareRecord copyWith({bool? pinned, DateTime? updatedAt}) {
    return CareRecord(
      id: id,
      mode: mode,
      actionId: actionId,
      actionLabel: actionLabel,
      outcome: outcome,
      occurredAt: occurredAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pinned: pinned ?? this.pinned,
    );
  }
}

final class CareReflectionDraft {
  const CareReflectionDraft({
    this.observation,
    this.need,
    this.whatHelped,
    this.futureSelfNote,
  });

  final String? observation;
  final ReflectionNeed? need;
  final String? whatHelped;
  final String? futureSelfNote;
}

final class CareReflection {
  const CareReflection({
    required this.id,
    required this.careRecordId,
    required this.mode,
    required this.observation,
    required this.need,
    required this.whatHelped,
    required this.futureSelfNote,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String careRecordId;
  final CareMode mode;
  final String? observation;
  final ReflectionNeed? need;
  final String? whatHelped;
  final String? futureSelfNote;
  final DateTime createdAt;
  final DateTime updatedAt;
}
