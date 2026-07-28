import '../../care/domain/care_memory.dart';
import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_record.dart';
import 'cycle_letter.dart';

abstract final class CycleLettersAggregator {
  static CycleLettersArchive build({
    required Iterable<PeriodRecord> periods,
    required Iterable<CareRecord> careRecords,
    required Iterable<CareReflection> reflections,
  }) {
    final orderedPeriods = [...periods]
      ..sort((left, right) => left.startDate.compareTo(right.startDate));
    final unassigned = [...careRecords];
    final reflectionsByRecord = {
      for (final reflection in reflections) reflection.careRecordId: reflection,
    };
    final completed = <CycleLetter>[];

    for (var index = 0; index + 1 < orderedPeriods.length; index += 1) {
      final period = orderedPeriods[index];
      final end = orderedPeriods[index + 1].startDate.addDays(-1);
      final records = _takeRecords(
        unassigned,
        start: period.startDate,
        end: end,
      );
      completed.add(
        CycleLetter(
          number: index + 1,
          startDate: period.startDate,
          endDate: end,
          periodDays: period.durationDays,
          careRecords: records,
          reflections: _matchingReflections(records, reflectionsByRecord),
          isComplete: true,
        ),
      );
    }

    CycleLetter? current;
    if (orderedPeriods.isNotEmpty) {
      final period = orderedPeriods.last;
      final records = _takeRecords(
        unassigned,
        start: period.startDate,
        end: null,
      );
      current = CycleLetter(
        number: null,
        startDate: period.startDate,
        endDate: null,
        periodDays: period.durationDays,
        careRecords: records,
        reflections: _matchingReflections(records, reflectionsByRecord),
        isComplete: false,
      );
    }

    completed.sort((left, right) => right.startDate.compareTo(left.startDate));
    unassigned.sort(
      (left, right) => right.occurredAt.compareTo(left.occurredAt),
    );
    return CycleLettersArchive(
      completed: List.unmodifiable(completed),
      current: current,
      unassignedCareRecords: List.unmodifiable(unassigned),
    );
  }

  static List<CareRecord> _takeRecords(
    List<CareRecord> source, {
    required LocalDate start,
    required LocalDate? end,
  }) {
    final matches = source.where((record) {
      final date = LocalDate.fromDateTime(record.occurredAt.toLocal());
      return !date.isBefore(start) && (end == null || !date.isAfter(end));
    }).toList();
    source.removeWhere(matches.contains);
    matches.sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
    return List.unmodifiable(matches);
  }

  static List<CareReflection> _matchingReflections(
    Iterable<CareRecord> records,
    Map<String, CareReflection> reflectionsByRecord,
  ) {
    return List.unmodifiable([
      for (final record in records) ?reflectionsByRecord[record.id],
    ]);
  }
}
