import '../../care/domain/care_memory.dart';
import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';

/// A read-only cycle boundary owned by the archive feature.
///
/// The archive receives cycle facts from an adapter at the integration
/// boundary. It never creates or repairs cycle boundaries itself.
final class ArchiveCycleInput {
  const ArchiveCycleInput({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.periodDates,
    required this.isComplete,
    this.number,
  });

  final String id;
  final int? number;
  final LocalDate startDate;
  final LocalDate? endDate;
  final List<LocalDate> periodDates;
  final bool isComplete;
}

final class ArchiveInput {
  const ArchiveInput({
    required this.cycles,
    required this.healthRecords,
    required this.careRecords,
    required this.reflections,
  });

  final List<ArchiveCycleInput> cycles;
  final List<HealthRecord> healthRecords;
  final List<CareRecord> careRecords;
  final List<CareReflection> reflections;
}

abstract interface class ArchiveRepository {
  Future<ArchiveInput> load();
}

/// A deterministic repository useful for previews and focused widget tests.
final class InMemoryArchiveRepository implements ArchiveRepository {
  const InMemoryArchiveRepository(this.input);

  final ArchiveInput input;

  @override
  Future<ArchiveInput> load() async => input;
}
