import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('v12 keeps obsolete daily rows available for recovery', () async {
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
      18,
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
    expect(
      await database.select(database.comfortKitOverrideRows).get(),
      isEmpty,
    );
    expect(
      await database.select(database.comfortReminderPreferenceRows).get(),
      isEmpty,
    );
  });

  test('v11 adds Quick note Kit metadata without losing note text', () async {
    final directory = await Directory.systemTemp.createTemp(
      'letter-v11-note-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(path.join(directory.path, 'v11.sqlite'));
    final legacy = sqlite.sqlite3.open(file.path);
    legacy.execute('''
      CREATE TABLE capture_note_rows (
        id TEXT NOT NULL PRIMARY KEY,
        content TEXT NOT NULL,
        source TEXT NOT NULL,
        created_at_millis INTEGER NOT NULL
      );
      INSERT INTO capture_note_rows VALUES (
        'note-v11', 'Keep this exact text', 'typed', 1234
      );
      PRAGMA user_version = 11;
    ''');
    legacy.close();

    final database = LetterHealthDatabase(NativeDatabase(file));
    addTearDown(database.close);
    final note = (await database.select(database.captureNoteRows).get()).single;

    expect(note.content, 'Keep this exact text');
    expect(note.createdAtMillis, 1234);
    expect(note.updatedAtMillis, 1234);
    expect(note.keepInComfortKit, isFalse);
  });

  test(
    'v10 adjacent periods and attached sources remain intact during upgrade',
    () async {
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
      INSERT INTO period_rows VALUES ('first', 20662, 20664, 1, 1);
      INSERT INTO period_rows VALUES ('second', 20665, 20667, 2, 2);
      INSERT INTO period_flow_rows VALUES (
        'second', 20666, 'heavy', 'darkRed', 2, 2
      );
      INSERT INTO cycle_reflection_rows VALUES ('first-letter', 20662, 'First original source', NULL, NULL, NULL, 3, 4);
      INSERT INTO cycle_reflection_rows VALUES ('second-letter', 20665, NULL, NULL, 'Second original source', NULL, 5, 6);
      PRAGMA user_version = 10;
    ''');
      legacy.close();

      final database = LetterHealthDatabase(NativeDatabase(file));
      addTearDown(database.close);
      final periods = await database.select(database.periodRows).get();

      expect(periods, hasLength(2));
      final first = periods.singleWhere((row) => row.id == 'first');
      final second = periods.singleWhere((row) => row.id == 'second');
      expect(first.startDay, 20662);
      expect(first.endDay, 20664);
      expect(first.createdAtMillis, 1);
      expect(first.updatedAtMillis, 1);
      expect(second.startDay, 20665);
      expect(second.endDay, 20667);
      expect(second.createdAtMillis, 2);
      expect(second.updatedAtMillis, 2);
      final flow =
          (await database.select(database.periodFlowRows).get()).single;
      expect(flow.periodId, 'second');
      expect(flow.day, 20666);
      expect(flow.flow, 'heavy');
      expect(flow.color, 'darkRed');
      expect(flow.createdAtMillis, 2);
      expect(flow.updatedAtMillis, 2);
      final letters = await database.select(database.cycleReflectionRows).get();
      expect(letters, hasLength(2));
      final firstLetter = letters.singleWhere(
        (row) => row.id == 'first-letter',
      );
      final secondLetter = letters.singleWhere(
        (row) => row.id == 'second-letter',
      );
      expect(firstLetter.cycleStartDay, 20662);
      expect(firstLetter.observation, 'First original source');
      expect(firstLetter.createdAtMillis, 3);
      expect(firstLetter.updatedAtMillis, 4);
      expect(secondLetter.cycleStartDay, 20665);
      expect(secondLetter.whatHelped, 'Second original source');
      expect(secondLetter.createdAtMillis, 5);
      expect(secondLetter.updatedAtMillis, 6);
    },
  );
  test(
    'Build17 schema 12 retains Kit, reminder consent and undated notes in schema 18',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'letter-build17-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(path.join(directory.path, 'build17.sqlite'));
      final legacy = sqlite.sqlite3.open(file.path);
      legacy.execute("""
      CREATE TABLE period_rows (
        id TEXT NOT NULL PRIMARY KEY, start_day INTEGER NOT NULL, end_day INTEGER,
        created_at_millis INTEGER NOT NULL, updated_at_millis INTEGER NOT NULL);
      CREATE TABLE cycle_reflection_rows (
        id TEXT NOT NULL PRIMARY KEY, starting_period_id TEXT REFERENCES period_rows(id) ON DELETE SET NULL,
        cycle_start_day INTEGER NOT NULL UNIQUE, observation TEXT, need TEXT,
        what_helped TEXT, future_self_note TEXT, created_at_millis INTEGER NOT NULL, updated_at_millis INTEGER NOT NULL);
      INSERT INTO period_rows VALUES ('matching-new-period', 20600, 20604, 10, 20);
      INSERT INTO cycle_reflection_rows VALUES ('explicitly-unlinked-letter', NULL, 20600, 'Unlinked original words', NULL, NULL, NULL, 30, 40);
      CREATE TABLE capture_note_rows (
        id TEXT NOT NULL PRIMARY KEY, content TEXT NOT NULL, source TEXT NOT NULL,
        created_at_millis INTEGER NOT NULL, updated_at_millis INTEGER NOT NULL DEFAULT 0,
        keep_in_comfort_kit INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE comfort_kit_override_rows (
        source_id TEXT NOT NULL PRIMARY KEY, action TEXT NOT NULL,
        source_version TEXT, updated_at_millis INTEGER NOT NULL);
      CREATE TABLE comfort_reminder_preference_rows (
        id TEXT NOT NULL PRIMARY KEY, enabled INTEGER NOT NULL DEFAULT 0,
        lead_days INTEGER NOT NULL DEFAULT 2, hour INTEGER NOT NULL DEFAULT 9,
        minute INTEGER NOT NULL DEFAULT 0, updated_at_millis INTEGER NOT NULL);
      CREATE TABLE health_record_rows (
        id TEXT NOT NULL PRIMARY KEY, symptom TEXT NOT NULL, severity INTEGER NOT NULL,
        functional_impacts_json TEXT NOT NULL, experienced_day INTEGER NOT NULL,
        recorded_at_millis INTEGER NOT NULL, updated_at_millis INTEGER NOT NULL,
        provenance TEXT NOT NULL, user_confirmed INTEGER NOT NULL, vocabulary_version INTEGER NOT NULL,
        UNIQUE(symptom, experienced_day));
      INSERT INTO capture_note_rows VALUES ('kept-note', 'Exact kept words', 'typed', 100, 250, 1);
      INSERT INTO comfort_kit_override_rows VALUES ('care:existing', 'dontShowAgain', 'v-existing', 300);
      INSERT INTO comfort_reminder_preference_rows VALUES ('active', 1, 1, 10, 15, 400);
      INSERT INTO health_record_rows VALUES ('source-existing', 'cramps', 2, '[]', 20600, 50, 60, 'same_day', 1, 1);
      PRAGMA user_version = 12;
    """);
      legacy.close();
      final database = LetterHealthDatabase(NativeDatabase(file));
      addTearDown(database.close);
      final note =
          (await database.select(database.captureNoteRows).get()).single;
      expect(note.id, 'kept-note');
      expect(note.content, 'Exact kept words');
      expect(note.createdAtMillis, 100);
      expect(note.updatedAtMillis, 250);
      expect(note.keepInComfortKit, isTrue);
      expect(note.experiencedDay, isNull);
      expect(note.provenance, isNull);
      expect(note.writeZoneOffsetMinutes, isNull);
      final letter =
          (await database.select(database.cycleReflectionRows).get()).single;
      expect(letter.startingPeriodId, isNull);
      expect(letter.cycleStartDay, 20600);
      expect(letter.observation, 'Unlinked original words');
      expect(letter.createdAtMillis, 30);
      expect(letter.updatedAtMillis, 40);

      final kit =
          (await database.select(database.comfortKitOverrideRows).get()).single;
      expect(kit.sourceId, 'care:existing');
      expect(kit.action, 'dontShowAgain');
      expect(kit.sourceVersion, 'v-existing');
      expect(kit.updatedAtMillis, 300);
      final reminder =
          (await database.select(database.comfortReminderPreferenceRows).get())
              .single;
      expect(reminder.enabled, isTrue);
      expect(reminder.leadDays, 1);
      expect(reminder.hour, 10);
      expect(reminder.minute, 15);
      expect(reminder.updatedAtMillis, 400);
      final health =
          (await database.select(database.healthRecordRows).get()).single;
      expect(health.id, 'source-existing');
      expect(health.recordedAtMillis, 50);
      expect(health.updatedAtMillis, 60);
      expect(health.originalProvenance, 'same_day');
      expect(health.writeZoneName, isNull);
      expect(
        await database.select(database.recordHubImpactRows).get(),
        isEmpty,
      );
      expect(
        await database.select(database.recordProductEpisodeRows).get(),
        isEmpty,
      );
      expect(
        await database.select(database.recordProgrammeRows).get(),
        isEmpty,
      );
      expect(
        (await database.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        18,
      );
    },
  );
}
