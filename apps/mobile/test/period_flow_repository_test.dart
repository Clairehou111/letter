import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/data/drift_period_repository.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/bleeding_flow.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/cycle/domain/period_repository.dart';

const today = LocalDate(2026, 8, 6);

PeriodRecord _period() => PeriodRecord(
  id: 'period-flow',
  startDate: const LocalDate(2026, 8, 2),
  endDate: const LocalDate(2026, 8, 6),
  createdAt: DateTime.utc(2026, 8, 2),
  updatedAt: DateTime.utc(2026, 8, 2),
);

void main() {
  group('in-memory daily flow', () {
    test(
      'records, replaces, clears, and orders all four flow values',
      () async {
        var clockTick = 0;
        final repository = InMemoryPeriodRepository(
          seed: [_period()],
          clock: () => DateTime.utc(2026, 8, 6, 10, clockTick++),
        );

        for (var index = 0; index < BleedingFlow.values.length; index++) {
          await repository.setFlow(
            'period-flow',
            const LocalDate(2026, 8, 2).addDays(index),
            BleedingFlow.values[index],
            today: today,
          );
        }
        final original = (await repository.getAllFlowDays()).last;
        final replaced = await repository.setFlow(
          'period-flow',
          original.date,
          BleedingFlow.heavy,
          today: today,
        );

        expect(await repository.getAllFlowDays(), hasLength(4));
        expect(replaced.flow, BleedingFlow.heavy);
        expect(replaced.createdAt, original.createdAt);
        expect(replaced.updatedAt.isAfter(original.updatedAt), isTrue);

        final colored = await repository.setBleedingColor(
          'period-flow',
          replaced.date,
          BleedingColor.darkRed,
        );
        expect(colored.color, BleedingColor.darkRed);

        final flowChanged = await repository.setFlow(
          'period-flow',
          replaced.date,
          BleedingFlow.medium,
          today: today,
        );
        expect(flowChanged.color, BleedingColor.darkRed);

        await repository.clearFlow('period-flow', original.date);
        expect(await repository.getAllFlowDays(), hasLength(3));
      },
    );

    test('rejects future and out-of-period dates', () async {
      final repository = InMemoryPeriodRepository(seed: [_period()]);

      expect(
        () => repository.setFlow(
          'period-flow',
          const LocalDate(2026, 8, 7),
          BleedingFlow.light,
          today: today,
        ),
        throwsA(
          isA<PeriodWriteException>().having(
            (error) => error.failure,
            'failure',
            PeriodWriteFailure.flowDateInFuture,
          ),
        ),
      );
      expect(
        () => repository.setFlow(
          'period-flow',
          const LocalDate(2026, 8, 1),
          BleedingFlow.spotting,
          today: today,
        ),
        throwsA(
          isA<PeriodWriteException>().having(
            (error) => error.failure,
            'failure',
            PeriodWriteFailure.flowDateOutsidePeriod,
          ),
        ),
      );
    });

    test('date correction and deletion clean up attached flow', () async {
      final repository = InMemoryPeriodRepository(seed: [_period()]);
      for (final day in [2, 3, 4, 5, 6]) {
        await repository.setFlow(
          'period-flow',
          LocalDate(2026, 8, day),
          BleedingFlow.medium,
          today: today,
        );
      }

      await repository.update(
        'period-flow',
        const PeriodDraft(
          startDate: LocalDate(2026, 8, 3),
          endDate: LocalDate(2026, 8, 5),
        ),
        today: today,
      );
      expect(
        (await repository.getAllFlowDays()).map((record) => record.date.day),
        [5, 4, 3],
      );

      await repository.delete('period-flow');
      expect(await repository.getAllFlowDays(), isEmpty);
    });
  });

  test('Drift persists flow and cleans it up with its period', () async {
    final database = LetterHealthDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftPeriodRepository(
      database,
      clock: () => DateTime.utc(2026, 8, 6, 12),
      idGenerator: () => 'period-flow',
      closeDatabase: false,
    );
    await repository.create(
      const PeriodDraft(
        startDate: LocalDate(2026, 8, 2),
        endDate: LocalDate(2026, 8, 6),
      ),
      today: today,
    );

    await repository.setFlow(
      'period-flow',
      const LocalDate(2026, 8, 4),
      BleedingFlow.heavy,
      today: today,
    );
    await repository.setBleedingColor(
      'period-flow',
      const LocalDate(2026, 8, 4),
      BleedingColor.brightRed,
    );
    expect((await repository.getAllFlowDays()).single.flow, BleedingFlow.heavy);
    expect(
      (await repository.getAllFlowDays()).single.color,
      BleedingColor.brightRed,
    );
    expect(
      (await database.select(database.periodFlowRows).get()).single,
      isA<PeriodFlowRow>()
          .having((row) => row.flow, 'flow', 'heavy')
          .having((row) => row.color, 'color', 'brightRed'),
    );

    await repository.delete('period-flow');
    expect(await repository.getAllFlowDays(), isEmpty);
    expect(await database.select(database.periodFlowRows).get(), isEmpty);
  });
}
