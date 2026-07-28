import '../../care/domain/care_memory_repository.dart';
import '../../cycle/domain/period_repository.dart';
import '../../health_records/domain/health_record.dart';
import '../../health_records/domain/health_record_repository.dart';
import '../domain/pattern_source.dart';

/// Adapts existing local repositories without creating a patterns database.
final class RepositoryPatternSource
    implements PatternSourceReader, PatternMutationPort {
  const RepositoryPatternSource({
    required this.healthRecords,
    required this.careMemory,
    required this.periods,
  });

  final HealthRecordRepository healthRecords;
  final CareMemoryRepository careMemory;
  final PeriodRepository periods;

  @override
  Future<PatternSourceSnapshot> read() async {
    final healthRecordsFuture = healthRecords.getAll();
    final careRecordsFuture = careMemory.getRecords();
    final reflectionsFuture = careMemory.getReflections();
    final periodsFuture = periods.getAll();
    return PatternSourceSnapshot(
      healthRecords: await healthRecordsFuture,
      careRecords: await careRecordsFuture,
      careReflections: await reflectionsFuture,
      periods: await periodsFuture,
    );
  }

  @override
  Future<void> setCareActionPinned(
    String careRecordId, {
    required bool pinned,
  }) async {
    await careMemory.setPinned(careRecordId, pinned: pinned);
  }

  @override
  Future<void> updateHealthRecord(
    String healthRecordId,
    HealthRecordDraft draft,
  ) async {
    await healthRecords.update(healthRecordId, draft);
  }

  @override
  Future<void> deleteHealthRecord(String healthRecordId) {
    return healthRecords.delete(healthRecordId);
  }

  @override
  Future<void> deleteCareRecord(String careRecordId) {
    return careMemory.deleteRecord(careRecordId);
  }
}
