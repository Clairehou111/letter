import 'care_memory.dart';

const careMemoryTextMaximumCharacters = 280;
const careActionLabelMaximumCharacters = 120;

enum CareMemoryFailure {
  invalidAction,
  emptyReflection,
  invalidText,
  notFound,
  storageUnavailable,
}

final class CareMemoryException implements Exception {
  const CareMemoryException(this.failure);

  final CareMemoryFailure failure;

  String get userMessage => switch (failure) {
    CareMemoryFailure.invalidAction =>
      'Letter could not recognize this Care action.',
    CareMemoryFailure.emptyReflection =>
      'Add one thought before saving this reflection.',
    CareMemoryFailure.invalidText =>
      'Keep each reflection answer within 280 characters.',
    CareMemoryFailure.notFound =>
      'This Care memory is no longer available. Refresh and try again.',
    CareMemoryFailure.storageUnavailable =>
      'Letter could not update private Care memory. Try again.',
  };

  @override
  String toString() => 'CareMemoryException($failure)';
}

abstract interface class CareMemoryRepository {
  Future<List<CareRecord>> getRecords();

  Future<CareRecord> saveOutcome(
    CareActionCompletion completion,
    CareOutcome outcome,
  );

  Future<CareRecord> setPinned(String recordId, {required bool pinned});

  Future<void> deleteRecord(String recordId);

  Future<List<CareReflection>> getReflections();

  Future<CareReflection?> getReflectionForRecord(String recordId);

  Future<CareReflection> saveReflection(
    String recordId,
    CareReflectionDraft draft,
  );

  Future<void> deleteReflection(String reflectionId);

  Future<void> close();
}

CareActionCompletion validateCareCompletion(CareActionCompletion completion) {
  final id = completion.actionId.trim();
  final label = completion.actionLabel.trim();
  if (id.isEmpty ||
      !RegExp(r'^[a-z0-9._-]+$').hasMatch(id) ||
      label.isEmpty ||
      label.length > careActionLabelMaximumCharacters) {
    throw const CareMemoryException(CareMemoryFailure.invalidAction);
  }
  return CareActionCompletion(
    mode: completion.mode,
    actionId: id,
    actionLabel: label,
    occurredAt: completion.occurredAt.toUtc(),
  );
}

CareReflectionDraft validateCareReflection(CareReflectionDraft draft) {
  String? normalize(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length > careMemoryTextMaximumCharacters) {
      throw const CareMemoryException(CareMemoryFailure.invalidText);
    }
    return trimmed;
  }

  final normalized = CareReflectionDraft(
    observation: normalize(draft.observation),
    need: draft.need,
    whatHelped: normalize(draft.whatHelped),
    futureSelfNote: normalize(draft.futureSelfNote),
  );
  if (normalized.observation == null &&
      normalized.need == null &&
      normalized.whatHelped == null &&
      normalized.futureSelfNote == null) {
    throw const CareMemoryException(CareMemoryFailure.emptyReflection);
  }
  return normalized;
}
