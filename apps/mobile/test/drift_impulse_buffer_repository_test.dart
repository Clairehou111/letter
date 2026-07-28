import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/data/drift_impulse_buffer_repository.dart';
import 'package:letter_mobile/features/care/domain/impulse_buffer_repository.dart';
import 'package:letter_mobile/features/care/domain/impulse_draft_record.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final now = DateTime.utc(2026, 7, 28, 8);

  test('Drift repository persists draft, seal, reseal, and delete', () async {
    final database = LetterHealthDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftImpulseBufferRepository(
      database,
      closeDatabase: false,
      clock: () => now,
      idGenerator: () => 'drift-impulse',
    );

    final draft = await repository.saveDraft('Private draft');
    expect((await repository.getActive())!.content, 'Private draft');

    final locked = await repository.sealDraft(draft.id, now: now);
    expect(locked.stateAt(now), ImpulseDraftState.locked);
    expect(locked.unlockAt, now.add(impulseCooldown));

    final readyAt = now.add(impulseCooldown);
    final resealed = await repository.resealReady(
      draft.id,
      'Calmer words',
      now: readyAt,
    );
    expect(resealed.content, 'Calmer words');
    expect(resealed.createdAt, draft.createdAt);
    expect(resealed.unlockAt, readyAt.add(impulseCooldown));

    await repository.delete(draft.id);
    expect(await repository.getActive(), isNull);
  });

  test(
    'schema 1 migration preserves period rows and adds impulse drafts',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'letter-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/letter-health.sqlite');
      final raw = sqlite3.open(file.path);
      raw.execute('''
      CREATE TABLE period_rows (
        id TEXT NOT NULL PRIMARY KEY,
        start_day INTEGER NOT NULL,
        end_day INTEGER NULL,
        created_at_millis INTEGER NOT NULL,
        updated_at_millis INTEGER NOT NULL
      );
    ''');
      raw.execute('INSERT INTO period_rows VALUES (?, ?, ?, ?, ?)', [
        'existing',
        20660,
        20664,
        1,
        1,
      ]);
      raw.userVersion = 1;
      raw.close();

      final database = LetterHealthDatabase(NativeDatabase(file));
      addTearDown(database.close);

      final periodRows = await database.select(database.periodRows).get();
      expect(periodRows.single.id, 'existing');

      final repository = DriftImpulseBufferRepository(
        database,
        closeDatabase: false,
        clock: () => now,
        idGenerator: () => 'migrated-impulse',
      );
      final draft = await repository.saveDraft('Migration works');
      expect(draft.id, 'migrated-impulse');
      expect(
        (await database.select(database.impulseDraftRows).get()).single.id,
        'migrated-impulse',
      );
    },
  );
}
