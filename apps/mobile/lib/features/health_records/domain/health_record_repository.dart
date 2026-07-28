import 'health_record.dart';

abstract interface class HealthRecordRepository {
  Future<List<HealthRecord>> getAll();

  Future<HealthRecord> create(HealthRecordDraft draft);

  Future<HealthRecord> update(String id, HealthRecordDraft draft);

  Future<void> delete(String id);

  Future<void> close();
}
