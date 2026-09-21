import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test(
    'v5 removes the obsolete daily-record table without copying its data',
    () async {
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
      expect(tables, isEmpty);
    },
  );
}
