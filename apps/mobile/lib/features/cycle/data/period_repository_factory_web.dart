import '../domain/period_repository.dart';
import 'in_memory_period_repository.dart';

PeriodRepository createDefaultPeriodRepository() {
  return InMemoryPeriodRepository();
}
