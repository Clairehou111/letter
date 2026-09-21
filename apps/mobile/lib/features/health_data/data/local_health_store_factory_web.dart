import '../../care/data/in_memory_care_memory_repository.dart';
import '../../capture/domain/capture_models.dart';
import '../../check_in/data/in_memory_moment_check_in_repository.dart';
import '../../cycle/data/in_memory_period_repository.dart';
import '../../health_records/data/in_memory_health_record_repository.dart';
import '../../preparation/data/in_memory_preparation_repository.dart';
import 'local_health_store.dart';

LocalHealthStore createDefaultLocalHealthStore() {
  final periodRepository = InMemoryPeriodRepository();
  final careMemoryRepository = InMemoryCareMemoryRepository();
  final healthRecordRepository = InMemoryHealthRecordRepository();
  return LocalHealthStore(
    periodRepository: periodRepository,
    careMemoryRepository: careMemoryRepository,
    healthRecordRepository: healthRecordRepository,
    captureNoteStore: InMemoryCaptureNoteStore(),
    momentCheckInRepository: InMemoryMomentCheckInRepository(),
    preparationRepository: InMemoryPreparationRepository(),
    localBackupStore: null,
    closeStore: () async {
      await periodRepository.close();
      await careMemoryRepository.close();
      await healthRecordRepository.close();
    },
  );
}
