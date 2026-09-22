import '../../care/domain/care_memory.dart';
import '../../check_in/domain/moment_check_in.dart';
import '../../cycle/domain/bleeding_flow.dart';
import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_record.dart';
import '../../health_records/domain/health_record.dart';

final class PatternSourceSnapshot {
  const PatternSourceSnapshot({
    this.healthRecords = const [],
    this.careRecords = const [],
    this.careReflections = const [],
    this.periods = const [],
    this.flowDays = const [],
    this.momentCheckIns = const [],
  });

  final List<HealthRecord> healthRecords;
  final List<CareRecord> careRecords;
  final List<CareReflection> careReflections;
  final List<PeriodRecord> periods;
  final List<BleedingDayRecord> flowDays;
  final List<MomentCheckIn> momentCheckIns;

  /// Excludes imported records that have not happened in the device's local
  /// calendar yet. A future-dated row remains in the archive but cannot alter
  /// current Patterns, Spectrum, or Care memory.
  PatternSourceSnapshot through(LocalDate today) {
    final retainedCare = careRecords
        .where((record) {
          return !LocalDate.fromDateTime(
            record.occurredAt.toLocal(),
          ).isAfter(today);
        })
        .toList(growable: false);
    final retainedCareIds = retainedCare.map((record) => record.id).toSet();
    return PatternSourceSnapshot(
      healthRecords: healthRecords
          .where((record) => !record.experiencedDate.isAfter(today))
          .toList(growable: false),
      careRecords: retainedCare,
      careReflections: careReflections
          .where(
            (reflection) => retainedCareIds.contains(reflection.careRecordId),
          )
          .toList(growable: false),
      periods: periods
          .where((period) => !period.startDate.isAfter(today))
          .toList(growable: false),
      flowDays: flowDays
          .where((flow) => !flow.date.isAfter(today))
          .toList(growable: false),
      momentCheckIns: momentCheckIns
          .where((checkIn) {
            return !LocalDate.fromDateTime(
              checkIn.occurredAt.toLocal(),
            ).isAfter(today);
          })
          .toList(growable: false),
    );
  }
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
