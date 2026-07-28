import '../../care/domain/care_memory.dart';
import '../../cycle/domain/local_date.dart';

final class CycleLetter {
  const CycleLetter({
    required this.number,
    required this.startDate,
    required this.endDate,
    required this.periodDays,
    required this.careRecords,
    required this.reflections,
    required this.isComplete,
  });

  final int? number;
  final LocalDate startDate;
  final LocalDate? endDate;
  final int? periodDays;
  final List<CareRecord> careRecords;
  final List<CareReflection> reflections;
  final bool isComplete;
}

final class CycleLettersArchive {
  const CycleLettersArchive({
    required this.completed,
    required this.current,
    required this.unassignedCareRecords,
  });

  final List<CycleLetter> completed;
  final CycleLetter? current;
  final List<CareRecord> unassignedCareRecords;
}
