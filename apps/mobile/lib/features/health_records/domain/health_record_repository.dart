import 'health_record.dart';

abstract interface class HealthRecordRepository {
  Future<List<HealthRecord>> getAll();

  Future<HealthRecord> create(HealthRecordDraft draft);

  Future<HealthRecord> update(String id, HealthRecordDraft draft);

  Future<void> delete(String id, {HealthRecord? expectedCurrent});

  /// Restores an exact source only if the change has not been superseded.
  /// A null expectedCurrent requires the symptom/day to be absent.
  Future<HealthRecord> restore(HealthRecord record, {HealthRecord? expectedCurrent});

  Future<void> close();
}
