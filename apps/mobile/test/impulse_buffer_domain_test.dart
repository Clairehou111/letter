import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/data/in_memory_impulse_buffer_repository.dart';
import 'package:letter_mobile/features/care/domain/impulse_buffer_repository.dart';
import 'package:letter_mobile/features/care/domain/impulse_draft_record.dart';

void main() {
  final createdAt = DateTime.utc(2026, 7, 28, 8);

  test('draft, locked, and ready states derive from the injected time', () {
    final record = ImpulseDraftRecord(
      id: 'draft',
      content: 'Private text',
      createdAt: createdAt,
      updatedAt: createdAt,
      sealedAt: createdAt,
      unlockAt: createdAt.add(impulseCooldown),
    );

    expect(record.stateAt(createdAt), ImpulseDraftState.locked);
    expect(
      record.stateAt(createdAt.add(const Duration(hours: 23, minutes: 59))),
      ImpulseDraftState.locked,
    );
    expect(
      record.stateAt(createdAt.add(impulseCooldown)),
      ImpulseDraftState.ready,
    );
    expect(record.remainingAt(createdAt), impulseCooldown);
    expect(record.remainingAt(createdAt.add(impulseCooldown)), Duration.zero);
  });

  test('content validation trims text and enforces the 4000 limit', () {
    expect(validateImpulseDraftContent('  say it here  '), 'say it here');
    expect(
      () => validateImpulseDraftContent('   '),
      throwsA(
        isA<ImpulseBufferException>().having(
          (error) => error.failure,
          'failure',
          ImpulseBufferFailure.invalidContent,
        ),
      ),
    );
    expect(
      () => validateImpulseDraftContent(List.filled(4001, 'a').join()),
      throwsA(isA<ImpulseBufferException>()),
    );
  });

  test(
    'in-memory repository supports the complete cooldown lifecycle',
    () async {
      var now = createdAt;
      final repository = InMemoryImpulseBufferRepository(
        clock: () => now,
        idGenerator: () => 'active',
      );

      final draft = await repository.saveDraft('Raw private words');
      expect(draft.id, 'active');
      expect(draft.stateAt(now), ImpulseDraftState.draft);

      final edited = await repository.saveDraft('Rewritten before seal');
      expect(edited.id, draft.id);
      expect(edited.createdAt, draft.createdAt);

      final locked = await repository.sealDraft(draft.id, now: now);
      expect(locked.stateAt(now), ImpulseDraftState.locked);
      expect(locked.unlockAt, now.add(impulseCooldown));

      expect(
        () => repository.saveDraft('Another active draft'),
        throwsA(
          isA<ImpulseBufferException>().having(
            (error) => error.failure,
            'failure',
            ImpulseBufferFailure.activeSealed,
          ),
        ),
      );

      now = now.add(impulseCooldown);
      expect(
        (await repository.getActive())!.stateAt(now),
        ImpulseDraftState.ready,
      );

      final kept = await repository.keepReadySealed(draft.id, now: now);
      expect(kept.unlockAt, now.add(impulseCooldown));
      expect(kept.createdAt, draft.createdAt);

      now = now.add(impulseCooldown);
      final resealed = await repository.resealReady(
        draft.id,
        'Calmer rewrite',
        now: now,
      );
      expect(resealed.content, 'Calmer rewrite');
      expect(resealed.unlockAt, now.add(impulseCooldown));

      await repository.delete(draft.id);
      expect(await repository.getActive(), isNull);
    },
  );

  test('locked drafts cannot be extended or resealed early', () async {
    final repository = InMemoryImpulseBufferRepository(
      clock: () => createdAt,
      idGenerator: () => 'active',
    );
    final draft = await repository.saveDraft('Private');
    await repository.sealDraft(draft.id, now: createdAt);

    for (final operation in [
      () => repository.keepReadySealed(draft.id, now: createdAt),
      () => repository.resealReady(draft.id, 'Rewrite', now: createdAt),
    ]) {
      expect(
        operation,
        throwsA(
          isA<ImpulseBufferException>().having(
            (error) => error.failure,
            'failure',
            ImpulseBufferFailure.notReady,
          ),
        ),
      );
    }
  });
}
