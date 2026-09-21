import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('version 1 flow rows migrate without losing saved flow', () async {
    final directory = await Directory.systemTemp.createTemp(
      'letter-flow-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/letter.sqlite');
    final legacy = sqlite.sqlite3.open(file.path);
    legacy.execute('''
      CREATE TABLE period_rows (
        id TEXT NOT NULL PRIMARY KEY,
        start_day INTEGER NOT NULL,
        end_day INTEGER NULL,
        created_at_millis INTEGER NOT NULL,
        updated_at_millis INTEGER NOT NULL
      );
      CREATE TABLE period_flow_rows (
        period_id TEXT NOT NULL REFERENCES period_rows(id) ON DELETE CASCADE,
        day INTEGER NOT NULL,
        flow TEXT NOT NULL,
        created_at_millis INTEGER NOT NULL,
        updated_at_millis INTEGER NOT NULL,
        PRIMARY KEY (period_id, day)
      );
      INSERT INTO period_rows VALUES ('period', 20400, 20404, 1, 1);
      INSERT INTO period_flow_rows VALUES ('period', 20401, 'light', 1, 1);
      PRAGMA user_version = 1;
    ''');
    legacy.close();

    final database = LetterHealthDatabase(NativeDatabase(file));
    addTearDown(database.close);
    final row = (await database.select(database.periodFlowRows).get()).single;

    expect(row.flow, 'light');
    expect(row.color, isNull);
    await (database.update(database.periodFlowRows)
          ..where((candidate) => candidate.periodId.equals('period')))
        .write(const PeriodFlowRowsCompanion(color: Value('brightRed')));
    expect(
      (await database.select(database.periodFlowRows).get()).single.color,
      'brightRed',
    );
  });

  test('foreign keys reject orphan local health records', () async {
    final database = LetterHealthDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await expectLater(
      database
          .into(database.periodFlowRows)
          .insert(
            PeriodFlowRowsCompanion.insert(
              periodId: 'missing-period',
              day: 20400,
              flow: 'light',
              createdAtMillis: 1,
              updatedAtMillis: 1,
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      database
          .into(database.careReflectionRows)
          .insert(
            CareReflectionRowsCompanion.insert(
              id: 'reflection',
              careRecordId: 'missing-care-record',
              mode: 'heavy',
              createdAtMillis: 1,
              updatedAtMillis: 1,
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('parent deletion cascades or clears child references', () async {
    final database = LetterHealthDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database
        .into(database.periodRows)
        .insert(
          PeriodRowsCompanion.insert(
            id: 'period',
            startDay: 20400,
            createdAtMillis: 1,
            updatedAtMillis: 1,
          ),
        );
    await database
        .into(database.periodFlowRows)
        .insert(
          PeriodFlowRowsCompanion.insert(
            periodId: 'period',
            day: 20400,
            flow: 'medium',
            createdAtMillis: 1,
            updatedAtMillis: 1,
          ),
        );
    await database
        .into(database.cycleReflectionRows)
        .insert(
          CycleReflectionRowsCompanion.insert(
            id: 'cycle-reflection',
            startingPeriodId: const Value('period'),
            cycleStartDay: 20400,
            createdAtMillis: 1,
            updatedAtMillis: 1,
          ),
        );

    await (database.delete(
      database.periodRows,
    )..where((row) => row.id.equals('period'))).go();

    expect(await database.select(database.periodFlowRows).get(), isEmpty);
    expect(
      (await database.select(database.cycleReflectionRows).get())
          .single
          .startingPeriodId,
      isNull,
    );
  });

  test('one symptom has at most one record per experienced day', () async {
    final database = LetterHealthDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    HealthRecordRowsCompanion record(String id) =>
        HealthRecordRowsCompanion.insert(
          id: id,
          symptom: 'lowMood',
          severity: 2,
          functionalImpactsJson: '[]',
          experiencedDay: 20400,
          recordedAtMillis: 1,
          updatedAtMillis: 1,
          provenance: 'same_day',
          userConfirmed: true,
          vocabularyVersion: 2,
        );

    await database.into(database.healthRecordRows).insert(record('first'));
    await expectLater(
      database.into(database.healthRecordRows).insert(record('duplicate')),
      throwsA(isA<SqliteException>()),
    );
  });
}
