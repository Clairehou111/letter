import 'dart:math';

import '../domain/health_record.dart';
import '../domain/health_record_repository.dart';

final class InMemoryHealthRecordRepository implements HealthRecordRepository {
  InMemoryHealthRecordRepository({
    Iterable<HealthRecord> seed = const [],
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _records = [...seed],
       _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _randomId;

  final List<HealthRecord> _records;
  final DateTime Function() _clock;
  final String Function() _idGenerator;

  @override
  Future<List<HealthRecord>> getAll() async {
    return [..._records]..sort((left, right) {
      final date = right.experiencedDate.compareTo(left.experiencedDate);
      return date == 0 ? right.recordedAt.compareTo(left.recordedAt) : date;
    });
  }

  @override
  Future<HealthRecord> create(HealthRecordDraft draft) async {
    final valid = validateHealthRecordDraft(draft);
    final now = _clock().toUtc();
    final existingIndex = _records.indexWhere(
      (record) =>
          record.symptom == valid.symptom &&
          record.experiencedDate == valid.experiencedDate,
    );
    if (existingIndex != -1) {
      final updated = _records[existingIndex].copyWith(
        draft: valid,
        updatedAt: now,
      );
      _records[existingIndex] = updated;
      return updated;
    }
    final record = _fromDraft(
      id: _idGenerator(),
      draft: valid,
      recordedAt: now,
      updatedAt: now,
    );
    _records.add(record);
    return record;
  }

  @override
  Future<HealthRecord> update(String id, HealthRecordDraft draft) async {
    final index = _records.indexWhere((record) => record.id == id);
    if (index == -1) {
      throw const HealthRecordException(HealthRecordFailure.notFound);
    }
    final valid = validateHealthRecordDraft(draft);
    final previous = _records[index];
    final updated = previous.copyWith(
      draft: valid,
      updatedAt: _clock().toUtc(),
    );
    _records[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    final index = _records.indexWhere((record) => record.id == id);
    if (index == -1) {
      throw const HealthRecordException(HealthRecordFailure.notFound);
    }
    _records.removeAt(index);
  }

  @override
  Future<void> close() async {}

  static HealthRecord _fromDraft({
    required String id,
    required HealthRecordDraft draft,
    required DateTime recordedAt,
    required DateTime updatedAt,
  }) {
    return HealthRecord(
      id: id,
      symptom: draft.symptom,
      severity: draft.severity,
      painRating: draft.painRating,
      painLocations: Set.unmodifiable(draft.painLocations),
      functionalImpacts: Set.unmodifiable(draft.functionalImpacts),
      experiencedDate: draft.experiencedDate,
      recordedAt: recordedAt,
      updatedAt: updatedAt,
      provenance: draft.provenance,
      userConfirmed: true,
      vocabularyVersion: healthRecordVocabularyVersion,
    );
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
