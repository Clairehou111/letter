import 'impulse_draft_record.dart';

const impulseDraftMaximumCharacters = 4000;
const impulseCooldown = Duration(hours: 24);

enum ImpulseBufferFailure {
  invalidContent,
  activeSealed,
  notFound,
  notDraft,
  notReady,
  storageUnavailable,
}

final class ImpulseBufferException implements Exception {
  const ImpulseBufferException(this.failure);

  final ImpulseBufferFailure failure;

  String get userMessage => switch (failure) {
    ImpulseBufferFailure.invalidContent =>
      'Write between 1 and 4,000 characters before continuing.',
    ImpulseBufferFailure.activeSealed =>
      'Your current envelope must be handled before starting another.',
    ImpulseBufferFailure.notFound =>
      'This private draft is no longer available. Refresh and try again.',
    ImpulseBufferFailure.notDraft =>
      'This draft is already sealed and cannot be changed yet.',
    ImpulseBufferFailure.notReady =>
      'This envelope is still inside its cooldown.',
    ImpulseBufferFailure.storageUnavailable =>
      'Letter could not update private draft storage. Try again.',
  };

  @override
  String toString() => 'ImpulseBufferException($failure)';
}

abstract interface class ImpulseBufferRepository {
  Future<ImpulseDraftRecord?> getActive();

  Future<ImpulseDraftRecord> saveDraft(String content);

  Future<ImpulseDraftRecord> sealDraft(String id, {required DateTime now});

  Future<ImpulseDraftRecord> keepReadySealed(
    String id, {
    required DateTime now,
  });

  Future<ImpulseDraftRecord> resealReady(
    String id,
    String content, {
    required DateTime now,
  });

  Future<void> delete(String id);

  Future<void> close();
}

String validateImpulseDraftContent(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty || trimmed.length > impulseDraftMaximumCharacters) {
    throw const ImpulseBufferException(ImpulseBufferFailure.invalidContent);
  }
  return trimmed;
}
