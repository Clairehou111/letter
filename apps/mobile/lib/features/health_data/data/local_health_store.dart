import '../../care/domain/impulse_buffer_repository.dart';
import '../../care/domain/care_memory_repository.dart';
import '../../capture/domain/capture_models.dart';
import '../../cycle/domain/period_repository.dart';
import '../../health_records/domain/health_record_repository.dart';
import '../../local_backup/domain/local_backup_import.dart';

final class LocalHealthStore {
  LocalHealthStore({
    required this.periodRepository,
    required this.impulseBufferRepository,
    required this.careMemoryRepository,
    required this.healthRecordRepository,
    required this.captureNoteStore,
    this.localBackupStore,
    required this.closeStore,
  });

  final PeriodRepository periodRepository;
  final ImpulseBufferRepository impulseBufferRepository;
  final CareMemoryRepository careMemoryRepository;
  final HealthRecordRepository healthRecordRepository;
  final CaptureNoteStore captureNoteStore;
  final LocalBackupStore? localBackupStore;
  final Future<void> Function() closeStore;

  Future<void> close() => closeStore();
}
