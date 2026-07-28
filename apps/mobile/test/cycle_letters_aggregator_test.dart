import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/letters/domain/cycle_letters_aggregator.dart';

void main() {
  PeriodRecord period(String id, int month, int day, {int? endDay}) {
    return PeriodRecord(
      id: id,
      startDate: LocalDate(2026, month, day),
      endDate: endDay == null ? null : LocalDate(2026, month, endDay),
      createdAt: DateTime.utc(2026, month, day),
      updatedAt: DateTime.utc(2026, month, day),
    );
  }

  CareRecord care(String id, DateTime occurredAt) {
    return CareRecord(
      id: id,
      mode: CareMode.heavy,
      actionId: 'heavy.presence',
      actionLabel: 'Quiet presence',
      outcome: CareOutcome.better,
      occurredAt: occurredAt,
      createdAt: occurredAt,
      updatedAt: occurredAt,
      pinned: false,
    );
  }

  test('builds completed letters, current cycle, and unassigned records', () {
    final beforeHistory = care('before', DateTime(2026, 4, 20, 12));
    final firstCycle = care('first', DateTime(2026, 5, 20, 12));
    final currentCycle = care('current', DateTime(2026, 7, 20, 12));
    final reflection = CareReflection(
      id: 'reflection',
      careRecordId: firstCycle.id,
      mode: CareMode.heavy,
      observation: null,
      need: ReflectionNeed.restOrPhysicalCapacity,
      whatHelped: null,
      futureSelfNote: 'Rest first.',
      createdAt: DateTime.utc(2026, 5, 21),
      updatedAt: DateTime.utc(2026, 5, 21),
    );

    final archive = CycleLettersAggregator.build(
      periods: [
        period('may', 5, 10, endDay: 14),
        period('june', 6, 8, endDay: 12),
        period('july', 7, 7),
      ],
      careRecords: [beforeHistory, firstCycle, currentCycle],
      reflections: [reflection],
    );

    expect(archive.completed, hasLength(2));
    expect(archive.completed.last.number, 1);
    expect(archive.completed.last.endDate, const LocalDate(2026, 6, 7));
    expect(archive.completed.last.careRecords.single.id, firstCycle.id);
    expect(archive.completed.last.reflections.single.id, reflection.id);
    expect(archive.current!.isComplete, isFalse);
    expect(archive.current!.careRecords.single.id, currentCycle.id);
    expect(archive.unassignedCareRecords.single.id, beforeHistory.id);
  });

  test('one period creates only a current incomplete cycle', () {
    final archive = CycleLettersAggregator.build(
      periods: [period('july', 7, 7)],
      careRecords: const [],
      reflections: const [],
    );

    expect(archive.completed, isEmpty);
    expect(archive.current, isNotNull);
    expect(archive.current!.number, isNull);
    expect(archive.current!.endDate, isNull);
  });
}
