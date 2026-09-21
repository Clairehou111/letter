import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';

void main() {
  final occurredAt = DateTime.utc(2026, 7, 28, 8);
  final createdAt = DateTime.utc(2026, 7, 28, 9);

  CareActionCompletion completion() => CareActionCompletion(
    mode: CareMode.heavy,
    actionId: 'heavy.presence',
    actionLabel: 'Quiet presence',
    occurredAt: occurredAt,
  );

  test('persists only explicit outcomes and supports pin and delete', () async {
    var id = 0;
    final repository = InMemoryCareMemoryRepository(
      clock: () => createdAt,
      idGenerator: () => 'memory-${id++}',
    );

    expect(await repository.getRecords(), isEmpty);
    final record = await repository.saveOutcome(
      completion(),
      CareOutcome.better,
    );
    expect(record.outcome, CareOutcome.better);
    expect(record.pinned, isFalse);

    final pinned = await repository.setPinned(record.id, pinned: true);
    expect(pinned.pinned, isTrue);

    await repository.deleteRecord(record.id);
    expect(await repository.getRecords(), isEmpty);
  });

  test('persists Better, Same, and Worse without remapping', () async {
    var id = 0;
    final repository = InMemoryCareMemoryRepository(
      clock: () => createdAt,
      idGenerator: () => 'outcome-${id++}',
    );

    for (final outcome in CareOutcome.values) {
      final saved = await repository.saveOutcome(completion(), outcome);
      expect(saved.outcome, outcome);
    }

    expect(
      (await repository.getRecords()).map((record) => record.outcome).toSet(),
      CareOutcome.values.toSet(),
    );
  });

  test('saves, edits, and deletes one reflection per Care record', () async {
    var id = 0;
    final repository = InMemoryCareMemoryRepository(
      clock: () => createdAt,
      idGenerator: () => 'memory-${id++}',
    );
    final record = await repository.saveOutcome(completion(), CareOutcome.same);

    final reflection = await repository.saveReflection(
      record.id,
      const CareReflectionDraft(
        observation: 'I still needed less noise.',
        need: ReflectionNeed.restOrPhysicalCapacity,
        futureSelfNote: 'Put the phone face down.',
      ),
    );
    expect(reflection.mode, CareMode.heavy);
    expect(reflection.futureSelfNote, 'Put the phone face down.');

    final edited = await repository.saveReflection(
      record.id,
      const CareReflectionDraft(whatHelped: 'Sitting somewhere quiet.'),
    );
    expect(edited.id, reflection.id);
    expect(edited.observation, isNull);
    expect((await repository.getReflections()), hasLength(1));

    await repository.deleteReflection(edited.id);
    expect(await repository.getReflections(), isEmpty);
  });

  test('saves, edits, and deletes one reflection per cycle', () async {
    var id = 0;
    final repository = InMemoryCareMemoryRepository(
      clock: () => createdAt,
      idGenerator: () => 'cycle-reflection-${id++}',
    );

    final reflection = await repository.saveCycleReflection(
      20662,
      const CycleReflectionDraft(
        observation: 'The middle of the cycle felt harder.',
        need: ReflectionNeed.restOrPhysicalCapacity,
      ),
    );
    final edited = await repository.saveCycleReflection(
      20662,
      const CycleReflectionDraft(whatHelped: 'A quieter evening.'),
      startingPeriodId: 'period-stable',
    );
    final afterDateEdit = await repository.saveCycleReflection(
      20663,
      const CycleReflectionDraft(whatHelped: 'A quieter evening.'),
      startingPeriodId: 'period-stable',
    );

    expect(edited.id, reflection.id);
    expect(afterDateEdit.id, reflection.id);
    expect(afterDateEdit.startingPeriodId, 'period-stable');
    expect(afterDateEdit.cycleStartDay, 20663);
    expect(afterDateEdit.whatHelped, 'A quieter evening.');
    expect((await repository.getCycleReflections()), hasLength(1));

    await repository.deleteCycleReflection(afterDateEdit.id);
    expect(await repository.getCycleReflections(), isEmpty);
  });

  test(
    'Care records remain date-owned when a period is edited or deleted',
    () async {
      final periodRepository = InMemoryPeriodRepository(
        seed: [
          PeriodRecord(
            id: 'period-with-care',
            startDate: const LocalDate(2026, 7, 14),
            endDate: const LocalDate(2026, 7, 18),
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        ],
      );
      final careRepository = InMemoryCareMemoryRepository(
        clock: () => createdAt,
        idGenerator: () => 'care-date-owned',
      );

      await careRepository.saveOutcome(completion(), CareOutcome.better);
      await periodRepository.update(
        'period-with-care',
        const PeriodDraft(
          startDate: LocalDate(2026, 7, 13),
          endDate: LocalDate(2026, 7, 17),
        ),
        today: const LocalDate(2026, 7, 28),
      );
      await periodRepository.delete('period-with-care');

      expect(await periodRepository.getAll(), isEmpty);
      expect((await careRepository.getRecords()).single.id, 'care-date-owned');
      expect((await careRepository.getRecords()).single.occurredAt, occurredAt);
    },
  );

  test('rejects invalid actions, empty reflections, and oversized text', () {
    final repository = InMemoryCareMemoryRepository(
      clock: () => createdAt,
      idGenerator: () => 'memory',
    );

    expect(
      () => repository.saveOutcome(
        CareActionCompletion(
          mode: CareMode.heavy,
          actionId: 'not valid',
          actionLabel: 'Action',
          occurredAt: occurredAt,
        ),
        CareOutcome.better,
      ),
      throwsA(
        isA<CareMemoryException>().having(
          (error) => error.failure,
          'failure',
          CareMemoryFailure.invalidAction,
        ),
      ),
    );

    expect(
      () async {
        final record = await repository.saveOutcome(
          completion(),
          CareOutcome.better,
        );
        await repository.saveReflection(record.id, const CareReflectionDraft());
      },
      throwsA(
        isA<CareMemoryException>().having(
          (error) => error.failure,
          'failure',
          CareMemoryFailure.emptyReflection,
        ),
      ),
    );

    expect(
      () => repository.saveCycleReflection(20662, const CycleReflectionDraft()),
      throwsA(
        isA<CareMemoryException>().having(
          (error) => error.failure,
          'failure',
          CareMemoryFailure.emptyReflection,
        ),
      ),
    );
  });
}
