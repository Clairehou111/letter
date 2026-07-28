import 'dart:math';

import '../domain/impulse_buffer_repository.dart';
import '../domain/impulse_draft_record.dart';

final class InMemoryImpulseBufferRepository implements ImpulseBufferRepository {
  InMemoryImpulseBufferRepository({
    ImpulseDraftRecord? seed,
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _active = seed,
       _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _randomId;

  ImpulseDraftRecord? _active;
  final DateTime Function() _clock;
  final String Function() _idGenerator;

  @override
  Future<ImpulseDraftRecord?> getActive() async => _active;

  @override
  Future<ImpulseDraftRecord> saveDraft(String content) async {
    final value = validateImpulseDraftContent(content);
    final existing = _active;
    final now = _clock().toUtc();
    if (existing != null && existing.stateAt(now) != ImpulseDraftState.draft) {
      throw const ImpulseBufferException(ImpulseBufferFailure.activeSealed);
    }
    final record = ImpulseDraftRecord(
      id: existing?.id ?? _idGenerator(),
      content: value,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      sealedAt: null,
      unlockAt: null,
    );
    _active = record;
    return record;
  }

  @override
  Future<ImpulseDraftRecord> sealDraft(
    String id, {
    required DateTime now,
  }) async {
    final existing = _require(id);
    if (existing.stateAt(now) != ImpulseDraftState.draft) {
      throw const ImpulseBufferException(ImpulseBufferFailure.notDraft);
    }
    return _replaceSealed(existing, existing.content, now);
  }

  @override
  Future<ImpulseDraftRecord> keepReadySealed(
    String id, {
    required DateTime now,
  }) async {
    final existing = _require(id);
    if (existing.stateAt(now) != ImpulseDraftState.ready) {
      throw const ImpulseBufferException(ImpulseBufferFailure.notReady);
    }
    return _replaceSealed(existing, existing.content, now);
  }

  @override
  Future<ImpulseDraftRecord> resealReady(
    String id,
    String content, {
    required DateTime now,
  }) async {
    final existing = _require(id);
    if (existing.stateAt(now) != ImpulseDraftState.ready) {
      throw const ImpulseBufferException(ImpulseBufferFailure.notReady);
    }
    return _replaceSealed(existing, validateImpulseDraftContent(content), now);
  }

  @override
  Future<void> delete(String id) async {
    _require(id);
    _active = null;
  }

  @override
  Future<void> close() async {}

  ImpulseDraftRecord _require(String id) {
    final existing = _active;
    if (existing == null || existing.id != id) {
      throw const ImpulseBufferException(ImpulseBufferFailure.notFound);
    }
    return existing;
  }

  ImpulseDraftRecord _replaceSealed(
    ImpulseDraftRecord existing,
    String content,
    DateTime now,
  ) {
    final sealedAt = now.toUtc();
    final record = ImpulseDraftRecord(
      id: existing.id,
      content: content,
      createdAt: existing.createdAt,
      updatedAt: sealedAt,
      sealedAt: sealedAt,
      unlockAt: sealedAt.add(impulseCooldown),
    );
    _active = record;
    return record;
  }

  static String _randomId() {
    final random = Random.secure();
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final suffix = List.generate(
      12,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '$timestamp-$suffix';
  }
}
