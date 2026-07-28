import 'dart:math';

import '../domain/care_memory.dart';
import '../domain/care_memory_repository.dart';

final class InMemoryCareMemoryRepository implements CareMemoryRepository {
  InMemoryCareMemoryRepository({
    Iterable<CareRecord> records = const [],
    Iterable<CareReflection> reflections = const [],
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _records = [...records],
       _reflections = [...reflections],
       _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _randomId;

  final List<CareRecord> _records;
  final List<CareReflection> _reflections;
  final DateTime Function() _clock;
  final String Function() _idGenerator;

  @override
  Future<List<CareRecord>> getRecords() async {
    return [..._records]
      ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
  }

  @override
  Future<CareRecord> saveOutcome(
    CareActionCompletion completion,
    CareOutcome outcome,
  ) async {
    final valid = validateCareCompletion(completion);
    final now = _clock().toUtc();
    final record = CareRecord(
      id: _idGenerator(),
      mode: valid.mode,
      actionId: valid.actionId,
      actionLabel: valid.actionLabel,
      outcome: outcome,
      occurredAt: valid.occurredAt,
      createdAt: now,
      updatedAt: now,
      pinned: false,
    );
    _records.add(record);
    return record;
  }

  @override
  Future<CareRecord> setPinned(String recordId, {required bool pinned}) async {
    final index = _recordIndex(recordId);
    final updated = _records[index].copyWith(
      pinned: pinned,
      updatedAt: _clock().toUtc(),
    );
    _records[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteRecord(String recordId) async {
    final index = _recordIndex(recordId);
    _records.removeAt(index);
    _reflections.removeWhere((item) => item.careRecordId == recordId);
  }

  @override
  Future<List<CareReflection>> getReflections() async {
    return [..._reflections]
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  }

  @override
  Future<CareReflection?> getReflectionForRecord(String recordId) async {
    return _reflections
        .where((item) => item.careRecordId == recordId)
        .firstOrNull;
  }

  @override
  Future<CareReflection> saveReflection(
    String recordId,
    CareReflectionDraft draft,
  ) async {
    final record = _records[_recordIndex(recordId)];
    final valid = validateCareReflection(draft);
    final now = _clock().toUtc();
    final existingIndex = _reflections.indexWhere(
      (item) => item.careRecordId == recordId,
    );
    final existing = existingIndex == -1 ? null : _reflections[existingIndex];
    final reflection = CareReflection(
      id: existing?.id ?? _idGenerator(),
      careRecordId: recordId,
      mode: record.mode,
      observation: valid.observation,
      need: valid.need,
      whatHelped: valid.whatHelped,
      futureSelfNote: valid.futureSelfNote,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    if (existingIndex == -1) {
      _reflections.add(reflection);
    } else {
      _reflections[existingIndex] = reflection;
    }
    return reflection;
  }

  @override
  Future<void> deleteReflection(String reflectionId) async {
    final index = _reflections.indexWhere((item) => item.id == reflectionId);
    if (index == -1) {
      throw const CareMemoryException(CareMemoryFailure.notFound);
    }
    _reflections.removeAt(index);
  }

  @override
  Future<void> close() async {}

  int _recordIndex(String id) {
    final index = _records.indexWhere((record) => record.id == id);
    if (index == -1) {
      throw const CareMemoryException(CareMemoryFailure.notFound);
    }
    return index;
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
