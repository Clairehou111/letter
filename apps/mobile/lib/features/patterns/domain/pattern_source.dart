import '../../care/domain/care_memory.dart';
import '../../cycle/domain/period_record.dart';
import '../../health_records/domain/health_record.dart';

final class PatternSourceSnapshot {
  const PatternSourceSnapshot({
    this.healthRecords = const [],
    this.careRecords = const [],
    this.careReflections = const [],
    this.periods = const [],
  });

  final List<HealthRecord> healthRecords;
  final List<CareRecord> careRecords;
  final List<CareReflection> careReflections;
  final List<PeriodRecord> periods;
}

abstract interface class PatternSourceReader {
  Future<PatternSourceSnapshot> read();
}

abstract interface class PatternMutationPort {
  Future<void> setCareActionPinned(String careRecordId, {required bool pinned});

  Future<void> updateHealthRecord(
    String healthRecordId,
    HealthRecordDraft draft,
  );

  Future<void> deleteHealthRecord(String healthRecordId);

  Future<void> deleteCareRecord(String careRecordId);
}
