import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/check_in/data/in_memory_moment_check_in_repository.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in_repository.dart';

void main() {
  test('creates, orders, and deletes timestamped moment check-ins', () async {
    var nextId = 0;
    final repository = InMemoryMomentCheckInRepository(
      clock: () => DateTime.utc(2026, 7, 31, 9),
      idGenerator: () => 'check-in-${nextId++}',
    );

    await repository.create(
      MomentCheckInState.steady,
      occurredAt: DateTime.utc(2026, 7, 31, 8),
    );
    final latest = await repository.create(
      MomentCheckInState.low,
      occurredAt: DateTime.utc(2026, 7, 31, 10),
    );

    final records = await repository.getAll();
    expect(records.map((record) => record.state), [
      MomentCheckInState.low,
      MomentCheckInState.steady,
    ]);
    expect(records.first.createdAt, DateTime.utc(2026, 7, 31, 9));

    await repository.delete(latest.id);
    expect((await repository.getAll()).single.state, MomentCheckInState.steady);
    expect(
      () => repository.delete('missing'),
      throwsA(
        isA<MomentCheckInException>().having(
          (error) => error.failure,
          'failure',
          MomentCheckInFailure.notFound,
        ),
      ),
    );
  });
}
