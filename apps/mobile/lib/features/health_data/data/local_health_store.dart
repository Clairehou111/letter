import '../../care/domain/care_memory_repository.dart';
import '../../capture/domain/capture_models.dart';
import '../../check_in/domain/moment_check_in_repository.dart';
import '../../cycle/domain/period_repository.dart';
import '../../health_records/domain/health_record_repository.dart';
import '../../local_backup/domain/local_backup_import.dart';
import '../../preparation/domain/preparation_plan.dart';
import '../domain/local_health_read_transaction.dart';

final class LocalHealthStore {
  LocalHealthStore({
    required this.periodRepository,
    required this.careMemoryRepository,
    required this.healthRecordRepository,
    required this.captureNoteStore,
    required this.momentCheckInRepository,
    required this.preparationRepository,
    required this.readTransaction,
    this.localBackupStore,
    required this.closeStore,
  });

  final PeriodRepository periodRepository;
  final CareMemoryRepository careMemoryRepository;
  final HealthRecordRepository healthRecordRepository;
  final CaptureNoteStore captureNoteStore;
  final MomentCheckInRepository momentCheckInRepository;
  final PreparationRepository preparationRepository;
  final LocalHealthReadTransaction readTransaction;
  final LocalBackupStore? localBackupStore;
  final Future<void> Function() closeStore;

  Future<void> close() => closeStore();
}
