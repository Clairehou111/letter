import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('v11 keeps obsolete daily rows available for recovery', () async {
    final directory = await Directory.systemTemp.createTemp(
      'letter-health-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(path.join(directory.path, 'legacy.sqlite'));
    final legacy = sqlite.sqlite3.open(file.path);
    legacy.execute('''
      CREATE TABLE daily_record_rows (
        day INTEGER NOT NULL PRIMARY KEY,
        emotions_json TEXT NOT NULL,
        bleeding_flow TEXT,
        bleeding_color TEXT,
        note TEXT,
        created_at_millis INTEGER NOT NULL,
        updated_at_millis INTEGER NOT NULL
      );
    ''');
    legacy.execute('''
      INSERT INTO daily_record_rows VALUES
      (20600, '{"low":"moderate"}', 'heavy', 'darkRed', 'old note', 1, 2);
    ''');
    legacy.execute('PRAGMA user_version = 4;');
    legacy.close();

    final database = LetterHealthDatabase(NativeDatabase(file));
    addTearDown(database.close);
    await database.customSelect('SELECT 1').get();

    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
          variables: [const Variable<String>('daily_record_rows')],
        )
        .get();
    expect(tables, hasLength(1));
    final rows = await database
        .customSelect('SELECT note FROM daily_record_rows')
        .get();
    expect(rows.single.read<String>('note'), 'old note');
  });

  test('v7 upgrades without losing cycle identity or health records', () async {
    final directory = await Directory.systemTemp.createTemp(
      'letter-v7-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(path.join(directory.path, 'v7.sqlite'));
    final legacy = sqlite.sqlite3.open(file.path);
    legacy.execute('''
      CREATE TABLE period_rows (
        id TEXT NOT NULL PRIMARY KEY,
        start_day INTEGER NOT NULL,
        end_day INTEGER,
        created_at_millis INTEGER NOT NULL,
        updated_at_millis INTEGER NOT NULL
      );
      CREATE TABLE cycle_reflection_rows (
        id TEXT NOT NULL PRIMARY KEY,
        cycle_start_day INTEGER NOT NULL UNIQUE,
        observation TEXT,
        need TEXT,
        what_helped TEXT,
        future_self_note TEXT,
        created_at_millis INTEGER NOT NULL,
        updated_at_millis INTEGER NOT NULL
      );
      CREATE TABLE health_record_rows (
        id TEXT NOT NULL PRIMARY KEY,
        symptom TEXT NOT NULL,
        severity INTEGER NOT NULL,
        pain_rating INTEGER,
        pain_locations_json TEXT NOT NULL,
        functional_impacts_json TEXT NOT NULL,
        experienced_day INTEGER NOT NULL,
        recorded_at_millis INTEGER NOT NULL,
        updated_at_millis INTEGER NOT NULL,
        provenance TEXT NOT NULL,
        user_confirmed INTEGER NOT NULL,
        vocabulary_version INTEGER NOT NULL
      );
      INSERT INTO period_rows VALUES ('period-v7', 20662, 20666, 1, 2);
      INSERT INTO cycle_reflection_rows VALUES (
        'reflection-v7', 20662, 'kept', NULL, NULL, NULL, 1, 2
      );
      INSERT INTO health_record_rows VALUES (
        'health-old', 'lowMood', 1, 4, '[]', '[]', 20663,
        1, 2, 'same_day', 1, 1
      );
      INSERT INTO health_record_rows VALUES (
        'health-new', 'lowMood', 3, NULL, '[]', '["work"]', 20663,
        2, 3, 'later_recall', 1, 2
      );
      PRAGMA user_version = 7;
    ''');
    legacy.close();

    final database = LetterHealthDatabase(NativeDatabase(file));
    addTearDown(database.close);
    await database.customSelect('SELECT 1').get();

    expect(
      await database
          .customSelect('PRAGMA user_version')
          .map((row) => row.read<int>('user_version'))
          .getSingle(),
      11,
    );
    final reflection =
        (await database.select(database.cycleReflectionRows).get()).single;
    expect(reflection.startingPeriodId, 'period-v7');
    expect(reflection.observation, 'kept');
    final health =
        (await database.select(database.healthRecordRows).get()).single;
    expect(health.id, 'health-new');
    expect(health.severity, 3);
    expect(health.functionalImpactsJson, '["work"]');
    expect(await database.select(database.periodFlowRows).get(), isEmpty);
    expect(await database.select(database.preparationPlanRows).get(), isEmpty);
    expect(
      await database.select(database.preparationDismissalRows).get(),
      isEmpty,
    );
  });

  test('v10 adjacent period rows consolidate during upgrade', () async {
    final directory = await Directory.systemTemp.createTemp(
      'letter-v10-period-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(path.join(directory.path, 'v10.sqlite'));
    final legacy = sqlite.sqlite3.open(file.path);
    legacy.execute('''
      CREATE TABLE period_rows (
        id TEXT NOT NULL PRIMARY KEY,
        start_day INTEGER NOT NULL,
        end_day INTEGER,
        created_at_millis INTEGER NOT NULL,
        updated_at_millis INTEGER NOT NULL
      );
      CREATE TABLE period_flow_rows (
        period_id TEXT NOT NULL REFERENCES period_rows(id) ON DELETE CASCADE,
        day INTEGER NOT NULL,
        flow TEXT NOT NULL,
        color TEXT,
        created_at_millis INTEGER NOT NULL,
        updated_at_millis INTEGER NOT NULL,
        PRIMARY KEY (period_id, day)
      );
      INSERT INTO period_rows VALUES ('first', 20662, 20664, 1, 1);
      INSERT INTO period_rows VALUES ('second', 20665, 20667, 2, 2);
      INSERT INTO period_flow_rows VALUES (
        'second', 20666, 'heavy', 'darkRed', 2, 2
      );
      PRAGMA user_version = 10;
    ''');
    legacy.close();

    final database = LetterHealthDatabase(NativeDatabase(file));
    addTearDown(database.close);
    final periods = await database.select(database.periodRows).get();

    expect(periods, hasLength(1));
    expect(periods.single.id, 'first');
    expect(periods.single.startDay, 20662);
    expect(periods.single.endDay, 20667);
    final flow = (await database.select(database.periodFlowRows).get()).single;
    expect(flow.periodId, 'first');
    expect(flow.day, 20666);
  });
}
