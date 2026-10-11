import 'dart:math';

import '../domain/health_record.dart';
import '../domain/health_record_repository.dart';
import '../domain/health_record_write_policy.dart';

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
    final now = _clock().toLocal();
    final existingIndex = _records.indexWhere(
      (record) =>
          record.symptom == valid.symptom &&
          record.experiencedDate == valid.experiencedDate,
    );
    if (existingIndex != -1) {
      final updated = buildHealthRecord(
        id: _records[existingIndex].id,
        draft: valid,
        localNow: now,
        previous: _records[existingIndex],
      );
      _records[existingIndex] = updated;
      return updated;
    }
    final record = buildHealthRecord(
      id: _idGenerator(),
      draft: valid,
      localNow: now,
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
    final duplicate = _records.any(
      (record) =>
          record.id != id &&
          record.symptom == valid.symptom &&
          record.experiencedDate == valid.experiencedDate,
    );
    if (duplicate) {
      throw const HealthRecordException(HealthRecordFailure.dateCollision);
    }
    final previous = _records[index];
    final updated = buildHealthRecord(
      id: id,
      draft: valid,
      localNow: _clock().toLocal(),
      previous: previous,
    );
    _records[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(String id, {HealthRecord? expectedCurrent}) async {
    final index = _records.indexWhere((record) => record.id == id);
    if (index == -1) {
      throw const HealthRecordException(HealthRecordFailure.notFound);
    }
    if (expectedCurrent != null &&
        !sameHealthRecordVersion(_records[index], expectedCurrent)) {
      throw const HealthRecordException(HealthRecordFailure.undoConflict);
    }
    _records.removeAt(index);
  }

  @override
  Future<void> close() async {}

  @override
  Future<HealthRecord> restore(
    HealthRecord record, {
    HealthRecord? expectedCurrent,
  }) async {
    final matches = _records
        .where(
          (r) =>
              r.id == record.id ||
              r.symptom == record.symptom &&
                  r.experiencedDate == record.experiencedDate,
        )
        .toList();
    if (expectedCurrent == null
        ? matches.isNotEmpty
        : matches.length != 1 ||
              !sameHealthRecordVersion(matches.single, expectedCurrent)) {
      throw const HealthRecordException(HealthRecordFailure.undoConflict);
    }
    if (expectedCurrent != null) {
      _records.removeWhere((r) => r.id == expectedCurrent.id);
    }
    _records.add(record);
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
