import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/data/drift_period_repository.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';

void main() {
  test(
    'Drift repository persists create, update, and delete operations',
    () async {
      final database = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftPeriodRepository(
        database,
        idGenerator: () => 'drift-record',
        clock: () => DateTime.utc(2026, 7, 28),
      );
      const today = LocalDate(2026, 7, 28);

      final created = await repository.create(
        const PeriodDraft(
          startDate: LocalDate(2026, 7, 20),
          endDate: LocalDate(2026, 7, 24),
        ),
        today: today,
      );
      expect((await repository.getAll()).single.id, created.id);

      await repository.update(
        created.id,
        const PeriodDraft(
          startDate: LocalDate(2026, 7, 19),
          endDate: LocalDate(2026, 7, 25),
        ),
        today: today,
      );
      expect((await repository.getAll()).single.durationDays, 7);

      await repository.delete(created.id);
      expect(await repository.getAll(), isEmpty);
    },
  );
}
