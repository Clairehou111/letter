import '../../care/data/in_memory_impulse_buffer_repository.dart';
import '../../care/data/in_memory_care_memory_repository.dart';
import '../../cycle/data/in_memory_period_repository.dart';
import 'local_health_store.dart';

LocalHealthStore createDefaultLocalHealthStore() {
  final periodRepository = InMemoryPeriodRepository();
  final impulseBufferRepository = InMemoryImpulseBufferRepository();
  final careMemoryRepository = InMemoryCareMemoryRepository();
  return LocalHealthStore(
    periodRepository: periodRepository,
    impulseBufferRepository: impulseBufferRepository,
    careMemoryRepository: careMemoryRepository,
    closeStore: () async {
      await periodRepository.close();
      await impulseBufferRepository.close();
      await careMemoryRepository.close();
    },
  );
}
