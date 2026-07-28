import '../../care/domain/impulse_buffer_repository.dart';
import '../../care/domain/care_memory_repository.dart';
import '../../cycle/domain/period_repository.dart';

final class LocalHealthStore {
  LocalHealthStore({
    required this.periodRepository,
    required this.impulseBufferRepository,
    required this.careMemoryRepository,
    required this.closeStore,
  });

  final PeriodRepository periodRepository;
  final ImpulseBufferRepository impulseBufferRepository;
  final CareMemoryRepository careMemoryRepository;
  final Future<void> Function() closeStore;

  Future<void> close() => closeStore();
}
