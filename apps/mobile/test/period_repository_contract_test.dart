import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/data/drift_period_repository.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/bleeding_flow.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/cycle/domain/period_repository.dart';

const _today = LocalDate(2026, 8, 15);
final _clock = DateTime.utc(2026, 8, 15, 12);

final class _RepositoryHandle {
  const _RepositoryHandle(this.repository, this.dispose);

  final PeriodRepository repository;
  final Future<void> Function() dispose;
}

void _registerContract(
  String name,
  Future<_RepositoryHandle> Function() createRepository,
) {
  group(name, () {
    late _RepositoryHandle handle;
    late PeriodRepository repository;

    setUp(() async {
      handle = await createRepository();
      repository = handle.repository;
    });

    tearDown(() => handle.dispose());

    test('empty state is stable and has no flow rows', () async {
      expect(await repository.getAll(), isEmpty);
      expect(await repository.getAllFlowDays(), isEmpty);
    });

    test('create supports a closed period and an open period', () async {
      final closed = await repository.create(
        const PeriodDraft(
          startDate: LocalDate(2026, 8, 10),
          endDate: LocalDate(2026, 8, 12),
        ),
        today: _today,
      );
      final open = await repository.create(
        const PeriodDraft(startDate: LocalDate(2026, 8, 14)),
        today: _today,
      );

      expect(closed.isOpen, isFalse);
      expect(closed.durationDays, 3);
      expect(open.isOpen, isTrue);
      expect((await repository.getAll()).map((p) => p.id), [
        open.id,
        closed.id,
      ]);
    });

    test('close, reopen, and enforce one open period', () async {
      final open = await repository.create(
        const PeriodDraft(startDate: LocalDate(2026, 8, 10)),
        today: _today,
      );

      await expectLater(
        repository.create(
          const PeriodDraft(startDate: LocalDate(2026, 8, 13)),
          today: _today,
        ),
        throwsA(
          isA<PeriodWriteException>().having(
            (e) => e.failure,
            'failure',
            PeriodWriteFailure.anotherPeriodOpen,
          ),
        ),
      );

      final closed = await repository.update(
        open.id,
        const PeriodDraft(
          startDate: LocalDate(2026, 8, 10),
          endDate: LocalDate(2026, 8, 12),
        ),
        today: _today,
      );
      expect(closed.isOpen, isFalse);
      expect(closed.durationDays, 3);

      final reopened = await repository.update(
        open.id,
        const PeriodDraft(startDate: LocalDate(2026, 8, 10)),
        today: _today,
      );
      expect(reopened.isOpen, isTrue);
      expect((await repository.getAll()).where((p) => p.isOpen), hasLength(1));
    });

    test(
      'adjacent periods are allowed but inclusive edge overlap is rejected',
      () async {
        final first = await repository.create(
          const PeriodDraft(
            startDate: LocalDate(2026, 8, 10),
            endDate: LocalDate(2026, 8, 12),
          ),
          today: _today,
        );
        final before = await repository.create(
          const PeriodDraft(
            startDate: LocalDate(2026, 8, 7),
            endDate: LocalDate(2026, 8, 9),
          ),
          today: _today,
        );
        final after = await repository.create(
          const PeriodDraft(
            startDate: LocalDate(2026, 8, 13),
            endDate: LocalDate(2026, 8, 15),
          ),
          today: _today,
        );
        expect({first.id, before.id, after.id}, hasLength(3));

        for (final draft in <PeriodDraft>[
          const PeriodDraft(
            startDate: LocalDate(2026, 8, 12),
            endDate: LocalDate(2026, 8, 14),
          ),
          const PeriodDraft(
            startDate: LocalDate(2026, 8, 9),
            endDate: LocalDate(2026, 8, 10),
          ),
          const PeriodDraft(startDate: LocalDate(2026, 8, 11)),
        ]) {
          await expectLater(
            repository.create(draft, today: _today),
            throwsA(
              isA<PeriodWriteException>().having(
                (e) => e.failure,
                'failure',
                PeriodWriteFailure.overlap,
              ),
            ),
          );
        }
      },
    );

    test(
      'reject future dates and reversed ranges without partial writes',
      () async {
        final before = await repository.getAll();
        for (final draft in <PeriodDraft>[
          const PeriodDraft(startDate: LocalDate(2026, 8, 16)),
          const PeriodDraft(
            startDate: LocalDate(2026, 8, 14),
            endDate: LocalDate(2026, 8, 16),
          ),
          const PeriodDraft(
            startDate: LocalDate(2026, 8, 14),
            endDate: LocalDate(2026, 8, 13),
          ),
        ]) {
          await expectLater(
            repository.create(draft, today: _today),
            throwsA(isA<PeriodWriteException>()),
          );
        }
        expect(await repository.getAll(), before);
      },
    );

    test(
      'same-day delete permits the same date to be recorded again',
      () async {
        final sameDay = await repository.create(
          const PeriodDraft(
            startDate: LocalDate(2026, 8, 14),
            endDate: LocalDate(2026, 8, 14),
          ),
          today: _today,
        );

        await expectLater(
          repository.create(
            const PeriodDraft(startDate: LocalDate(2026, 8, 14)),
            today: _today,
          ),
          throwsA(
            isA<PeriodWriteException>().having(
              (e) => e.failure,
              'failure',
              PeriodWriteFailure.overlap,
            ),
          ),
        );

        await repository.delete(sameDay.id);
        final replacement = await repository.create(
          const PeriodDraft(startDate: LocalDate(2026, 8, 14)),
          today: _today,
        );
        expect(replacement.isOpen, isTrue);
        expect((await repository.getAll()).single.id, replacement.id);
      },
    );

    test(
      'update preserves identity, supports date edits, and rejects overlaps',
      () async {
        final first = await repository.create(
          const PeriodDraft(
            startDate: LocalDate(2026, 8, 1),
            endDate: LocalDate(2026, 8, 3),
          ),
          today: _today,
        );
        final second = await repository.create(
          const PeriodDraft(
            startDate: LocalDate(2026, 8, 10),
            endDate: LocalDate(2026, 8, 12),
          ),
          today: _today,
        );

        final edited = await repository.update(
          first.id,
          const PeriodDraft(
            startDate: LocalDate(2026, 8, 4),
            endDate: LocalDate(2026, 8, 6),
          ),
          today: _today,
        );
        expect(edited.id, first.id);
        expect(edited.startDate, const LocalDate(2026, 8, 4));
        expect(edited.endDate, const LocalDate(2026, 8, 6));

        await expectLater(
          repository.update(
            second.id,
            const PeriodDraft(
              startDate: LocalDate(2026, 8, 6),
              endDate: LocalDate(2026, 8, 10),
            ),
            today: _today,
          ),
          throwsA(
            isA<PeriodWriteException>().having(
              (e) => e.failure,
              'failure',
              PeriodWriteFailure.overlap,
            ),
          ),
        );
        expect(
          (await repository.getAll())
              .singleWhere((p) => p.id == second.id)
              .startDate,
          const LocalDate(2026, 8, 10),
        );
      },
    );

    test(
      'flow lifecycle enforces period boundaries and color dependency',
      () async {
        final period = await repository.create(
          const PeriodDraft(
            startDate: LocalDate(2026, 8, 10),
            endDate: LocalDate(2026, 8, 12),
          ),
          today: _today,
        );

        await expectLater(
          repository.setBleedingColor(
            period.id,
            const LocalDate(2026, 8, 10),
            BleedingColor.brightRed,
          ),
          throwsA(
            isA<PeriodWriteException>().having(
              (e) => e.failure,
              'failure',
              PeriodWriteFailure.flowRequiredForColor,
            ),
          ),
        );
        final flow = await repository.setFlow(
          period.id,
          const LocalDate(2026, 8, 10),
          BleedingFlow.light,
          today: _today,
        );
        expect(flow.color, isNull);
        final colored = await repository.setBleedingColor(
          period.id,
          const LocalDate(2026, 8, 10),
          BleedingColor.brightRed,
        );
        expect(colored.color, BleedingColor.brightRed);

        final replaced = await repository.setFlow(
          period.id,
          const LocalDate(2026, 8, 10),
          BleedingFlow.heavy,
          today: _today,
        );
        expect(replaced.flow, BleedingFlow.heavy);
        expect(replaced.color, BleedingColor.brightRed);

        await repository.clearBleedingColor(
          period.id,
          const LocalDate(2026, 8, 10),
        );
        expect((await repository.getAllFlowDays()).single.color, isNull);
        await repository.clearFlow(period.id, const LocalDate(2026, 8, 10));
        expect(await repository.getAllFlowDays(), isEmpty);

        await expectLater(
          repository.setFlow(
            period.id,
            const LocalDate(2026, 8, 9),
            BleedingFlow.spotting,
            today: _today,
          ),
          throwsA(
            isA<PeriodWriteException>().having(
              (e) => e.failure,
              'failure',
              PeriodWriteFailure.flowDateOutsidePeriod,
            ),
          ),
        );
        await expectLater(
          repository.setFlow(
            period.id,
            const LocalDate(2026, 8, 16),
            BleedingFlow.spotting,
            today: _today,
          ),
          throwsA(
            isA<PeriodWriteException>().having(
              (e) => e.failure,
              'failure',
              PeriodWriteFailure.flowDateInFuture,
            ),
          ),
        );
      },
    );

    test('date edits remove only flow outside the new range', () async {
      final period = await repository.create(
        const PeriodDraft(
          startDate: LocalDate(2026, 8, 10),
          endDate: LocalDate(2026, 8, 14),
        ),
        today: _today,
      );
      for (final day in [10, 12, 14]) {
        await repository.setFlow(
          period.id,
          LocalDate(2026, 8, day),
          BleedingFlow.medium,
          today: _today,
        );
      }

      await repository.update(
        period.id,
        const PeriodDraft(
          startDate: LocalDate(2026, 8, 11),
          endDate: LocalDate(2026, 8, 13),
        ),
        today: _today,
      );
      expect((await repository.getAllFlowDays()).map((row) => row.date), [
        const LocalDate(2026, 8, 12),
      ]);

      await repository.delete(period.id);
      expect(await repository.getAll(), isEmpty);
      expect(await repository.getAllFlowDays(), isEmpty);
    });

    test(
      'missing records are typed failures and leave state unchanged',
      () async {
        await expectLater(
          repository.update(
            'missing',
            const PeriodDraft(startDate: LocalDate(2026, 8, 1)),
            today: _today,
          ),
          throwsA(
            isA<PeriodWriteException>().having(
              (e) => e.failure,
              'failure',
              PeriodWriteFailure.notFound,
            ),
          ),
        );
        await expectLater(
          repository.delete('missing'),
          throwsA(
            isA<PeriodWriteException>().having(
              (e) => e.failure,
              'failure',
              PeriodWriteFailure.notFound,
            ),
          ),
        );
        await expectLater(
          repository.setFlow(
            'missing',
            const LocalDate(2026, 8, 1),
            BleedingFlow.light,
            today: _today,
          ),
          throwsA(
            isA<PeriodWriteException>().having(
              (e) => e.failure,
              'failure',
              PeriodWriteFailure.flowPeriodNotFound,
            ),
          ),
        );
        expect(await repository.getAll(), isEmpty);
        expect(await repository.getAllFlowDays(), isEmpty);
      },
    );

    test('getAll returns complete history in newest-first order', () async {
      for (var index = 0; index < 8; index += 1) {
        final start = LocalDate(2026, 1, 1).addDays(index * 28);
        await repository.create(
          PeriodDraft(startDate: start, endDate: start.addDays(4)),
          today: _today,
        );
      }
      final periods = await repository.getAll();
      expect(periods, hasLength(8));
      expect(
        periods.map((period) => period.startDate).toList(),
        orderedEquals(periods.map((period) => period.startDate)),
      );
      for (var index = 1; index < periods.length; index += 1) {
        expect(
          periods[index - 1].startDate.isAfter(periods[index].startDate),
          isTrue,
        );
      }
    });
  });
}

Future<_RepositoryHandle> _inMemoryRepository() async {
  var nextId = 0;
  final repository = InMemoryPeriodRepository(
    clock: () => _clock,
    idGenerator: () => 'memory-${nextId++}',
  );
  return _RepositoryHandle(repository, () async {});
}

Future<_RepositoryHandle> _driftRepository() async {
  final database = LetterHealthDatabase(NativeDatabase.memory());
  var nextId = 0;
  final repository = DriftPeriodRepository(
    database,
    clock: () => _clock,
    idGenerator: () => 'drift-${nextId++}',
    closeDatabase: false,
  );
  return _RepositoryHandle(repository, database.close);
}

void main() {
  _registerContract('InMemoryPeriodRepository contract', _inMemoryRepository);
  _registerContract('DriftPeriodRepository contract', _driftRepository);
}
