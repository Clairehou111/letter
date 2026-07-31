import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/check_in/data/drift_moment_check_in_repository.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';

void main() {
  test('Drift persists and deletes timestamped moment check-ins', () async {
    final database = LetterHealthDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftMomentCheckInRepository(
      database,
      closeDatabase: false,
      clock: () => DateTime.utc(2026, 7, 31, 9),
      idGenerator: () => 'drift-check-in',
    );

    await repository.create(
      MomentCheckInState.energized,
      occurredAt: DateTime.utc(2026, 7, 31, 8, 45),
    );

    final loaded = (await repository.getAll()).single;
    expect(loaded.id, 'drift-check-in');
    expect(loaded.state, MomentCheckInState.energized);
    expect(loaded.occurredAt, DateTime.utc(2026, 7, 31, 8, 45));
    expect(loaded.createdAt, DateTime.utc(2026, 7, 31, 9));

    await repository.delete(loaded.id);
    expect(await repository.getAll(), isEmpty);
  });
}
