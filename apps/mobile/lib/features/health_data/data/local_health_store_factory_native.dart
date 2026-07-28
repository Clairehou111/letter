import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../care/data/drift_impulse_buffer_repository.dart';
import '../../care/data/drift_care_memory_repository.dart';
import '../../capture/data/drift_capture_note_store.dart';
import '../../cycle/data/drift_period_repository.dart';
import '../../cycle/data/letter_health_database.dart';
import '../../health_records/data/drift_health_record_repository.dart';
import 'local_health_store.dart';

const _databaseKeyName = 'letter.health_database.key.v1';

LocalHealthStore createDefaultLocalHealthStore() {
  const secureStorage = FlutterSecureStorage();
  final executor = LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    final databaseFile = File(
      path.join(directory.path, 'letter-health.sqlite'),
    );
    final key = await _loadOrCreateKey(secureStorage);

    return NativeDatabase.createInBackground(
      databaseFile,
      setup: (database) {
        if (database.select('PRAGMA cipher;').isEmpty) {
          throw StateError('Encrypted SQLite support is unavailable.');
        }
        database.execute("PRAGMA key = '$key';");
      },
    );
  });
  final database = LetterHealthDatabase(executor);
  return LocalHealthStore(
    periodRepository: DriftPeriodRepository(database, closeDatabase: false),
    impulseBufferRepository: DriftImpulseBufferRepository(
      database,
      closeDatabase: false,
    ),
    careMemoryRepository: DriftCareMemoryRepository(
      database,
      closeDatabase: false,
    ),
    healthRecordRepository: DriftHealthRecordRepository(
      database,
      closeDatabase: false,
    ),
    captureNoteStore: DriftCaptureNoteStore(database, closeDatabase: false),
    closeStore: database.close,
  );
}

Future<String> _loadOrCreateKey(FlutterSecureStorage storage) async {
  final existing = await storage.read(key: _databaseKeyName);
  if (existing != null && existing.isNotEmpty) {
    return existing;
  }

  final random = Random.secure();
  final key = List.generate(
    32,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  await storage.write(key: _databaseKeyName, value: key);
  return key;
}
