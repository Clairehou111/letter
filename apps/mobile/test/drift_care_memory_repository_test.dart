import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/data/drift_care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';

void main() {
  test(
    'Drift persists Care outcomes, pinning, reflection, and cascade delete',
    () async {
      final database = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final now = DateTime.utc(2026, 7, 28, 9);
      var id = 0;
      final repository = DriftCareMemoryRepository(
        database,
        closeDatabase: false,
        clock: () => now,
        idGenerator: () => 'care-${id++}',
      );
      await database
          .into(database.periodRows)
          .insert(
            PeriodRowsCompanion.insert(
              id: 'period-stable',
              startDay: 20662,
              createdAtMillis: now.millisecondsSinceEpoch,
              updatedAtMillis: now.millisecondsSinceEpoch,
            ),
          );

      final record = await repository.saveOutcome(
        CareActionCompletion(
          mode: CareMode.physical,
          actionId: 'physical.heat',
          actionLabel: 'Get familiar heat',
          occurredAt: DateTime.utc(2026, 7, 28, 8),
        ),
        CareOutcome.better,
      );
      await repository.setPinned(record.id, pinned: true);
      final reflection = await repository.saveReflection(
        record.id,
        const CareReflectionDraft(
          need: ReflectionNeed.restOrPhysicalCapacity,
          futureSelfNote: 'The heat wrap is in the drawer.',
        ),
      );
      final cycleReflection = await repository.saveCycleReflection(
        20662,
        const CycleReflectionDraft(
          observation: 'The cycle needed more room.',
          futureSelfNote: 'Keep one evening open.',
        ),
        startingPeriodId: 'period-stable',
      );

      expect((await repository.getRecords()).single.pinned, isTrue);
      expect(
        (await repository.getReflectionForRecord(record.id))!.futureSelfNote,
        'The heat wrap is in the drawer.',
      );
      expect(
        (await repository.getCycleReflection(20662))?.futureSelfNote,
        'Keep one evening open.',
      );
      expect(
        (await repository.getCycleReflection(
          99999,
          startingPeriodId: 'period-stable',
        ))?.id,
        cycleReflection.id,
      );

      await repository.deleteRecord(record.id);
      expect(await repository.getRecords(), isEmpty);
      expect(await repository.getReflections(), isEmpty);
      expect(
        await repository.getReflectionForRecord(reflection.careRecordId),
        isNull,
      );
      expect(
        (await repository.getCycleReflections()).single.id,
        cycleReflection.id,
      );
      await repository.deleteCycleReflection(cycleReflection.id);
      expect(await repository.getCycleReflections(), isEmpty);
    },
  );
}
