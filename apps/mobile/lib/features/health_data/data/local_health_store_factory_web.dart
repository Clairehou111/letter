import '../../care/data/in_memory_impulse_buffer_repository.dart';
import '../../care/data/in_memory_care_memory_repository.dart';
import '../../capture/domain/capture_models.dart';
import '../../check_in/data/in_memory_moment_check_in_repository.dart';
import '../../cycle/data/in_memory_period_repository.dart';
import '../../health_records/data/in_memory_health_record_repository.dart';
import 'local_health_store.dart';

LocalHealthStore createDefaultLocalHealthStore() {
  final periodRepository = InMemoryPeriodRepository();
  final impulseBufferRepository = InMemoryImpulseBufferRepository();
  final careMemoryRepository = InMemoryCareMemoryRepository();
  final healthRecordRepository = InMemoryHealthRecordRepository();
  return LocalHealthStore(
    periodRepository: periodRepository,
    impulseBufferRepository: impulseBufferRepository,
    careMemoryRepository: careMemoryRepository,
    healthRecordRepository: healthRecordRepository,
    captureNoteStore: InMemoryCaptureNoteStore(),
    momentCheckInRepository: InMemoryMomentCheckInRepository(),
    localBackupStore: null,
    closeStore: () async {
      await periodRepository.close();
      await impulseBufferRepository.close();
      await careMemoryRepository.close();
      await healthRecordRepository.close();
    },
  );
}
