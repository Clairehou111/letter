import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/cycle/domain/period_repository.dart';

void main() {
  const today = LocalDate(2026, 7, 28);

  test(
    'local dates round-trip as calendar days without time-zone instants',
    () {
      for (final date in const [
        LocalDate(1970, 1, 1),
        LocalDate(2026, 7, 28),
        LocalDate(2032, 2, 29),
      ]) {
        expect(LocalDate.fromEpochDay(date.epochDay), date);
      }

      expect(
        LocalDate.fromDateTime(DateTime(2026, 7, 28, 23, 59)),
        const LocalDate(2026, 7, 28),
      );
    },
  );

  test('creates open and closed periods newest first', () async {
    var id = 0;
    final repository = InMemoryPeriodRepository(
      idGenerator: () => 'period-${id++}',
      clock: () => DateTime.utc(2026, 7, 28, 12),
    );

    await repository.create(
      const PeriodDraft(
        startDate: LocalDate(2026, 6, 20),
        endDate: LocalDate(2026, 6, 24),
      ),
      today: today,
    );
    await repository.create(
      const PeriodDraft(startDate: LocalDate(2026, 7, 28)),
      today: today,
    );

    final records = await repository.getAll();
    expect(records.map((record) => record.id), ['period-1', 'period-0']);
    expect(records.first.isOpen, isTrue);
    expect(records.last.durationDays, 5);
  });

  test('rejects future dates and an end before start', () async {
    final repository = InMemoryPeriodRepository();

    await expectLater(
      repository.create(
        const PeriodDraft(startDate: LocalDate(2026, 7, 29)),
        today: today,
      ),
      throwsA(
        isA<PeriodWriteException>().having(
          (error) => error.failure,
          'failure',
          PeriodWriteFailure.futureDate,
        ),
      ),
    );
    await expectLater(
      repository.create(
        const PeriodDraft(
          startDate: LocalDate(2026, 7, 20),
          endDate: LocalDate(2026, 7, 19),
        ),
        today: today,
      ),
      throwsA(
        isA<PeriodWriteException>().having(
          (error) => error.failure,
          'failure',
          PeriodWriteFailure.endBeforeStart,
        ),
      ),
    );
  });

  test('rejects overlaps and a second open period', () async {
    final repository = InMemoryPeriodRepository();
    await repository.create(
      const PeriodDraft(
        startDate: LocalDate(2026, 7, 10),
        endDate: LocalDate(2026, 7, 14),
      ),
      today: today,
    );

    await expectLater(
      repository.create(
        const PeriodDraft(
          startDate: LocalDate(2026, 7, 14),
          endDate: LocalDate(2026, 7, 18),
        ),
        today: today,
      ),
      throwsA(
        isA<PeriodWriteException>().having(
          (error) => error.failure,
          'failure',
          PeriodWriteFailure.overlap,
        ),
      ),
    );

    await repository.create(
      const PeriodDraft(startDate: LocalDate(2026, 7, 20)),
      today: today,
    );
    await expectLater(
      repository.create(
        const PeriodDraft(startDate: LocalDate(2026, 7, 28)),
        today: today,
      ),
      throwsA(
        isA<PeriodWriteException>().having(
          (error) => error.failure,
          'failure',
          PeriodWriteFailure.anotherPeriodOpen,
        ),
      ),
    );
  });

  test('editing preserves identity and creation time', () async {
    final createdAt = DateTime.utc(2026, 7, 20);
    var now = createdAt;
    final repository = InMemoryPeriodRepository(
      idGenerator: () => 'stable-id',
      clock: () => now,
    );
    final created = await repository.create(
      const PeriodDraft(
        startDate: LocalDate(2026, 7, 20),
        endDate: LocalDate(2026, 7, 24),
      ),
      today: today,
    );

    now = DateTime.utc(2026, 7, 28);
    final updated = await repository.update(
      created.id,
      const PeriodDraft(
        startDate: LocalDate(2026, 7, 19),
        endDate: LocalDate(2026, 7, 25),
      ),
      today: today,
    );

    expect(updated.id, created.id);
    expect(updated.createdAt, createdAt);
    expect(updated.updatedAt, now);
    expect(updated.durationDays, 7);
  });

  test('deletion removes only the selected period', () async {
    var id = 0;
    final repository = InMemoryPeriodRepository(
      idGenerator: () => 'period-${id++}',
    );
    final first = await repository.create(
      const PeriodDraft(
        startDate: LocalDate(2026, 6, 1),
        endDate: LocalDate(2026, 6, 5),
      ),
      today: today,
    );
    await repository.create(
      const PeriodDraft(
        startDate: LocalDate(2026, 7, 1),
        endDate: LocalDate(2026, 7, 5),
      ),
      today: today,
    );

    await repository.delete(first.id);

    final records = await repository.getAll();
    expect(records, hasLength(1));
    expect(records.single.id, 'period-1');
  });
}
