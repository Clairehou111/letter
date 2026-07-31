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
import '../../check_in/data/drift_moment_check_in_repository.dart';
import '../../cycle/data/drift_period_repository.dart';
import '../../cycle/data/letter_health_database.dart';
import '../../health_records/data/drift_health_record_repository.dart';
import '../../local_backup/data/drift_local_backup_store.dart';
import 'local_health_store.dart';

const _databaseKeyName = 'letter.health_database.key.v1';

LocalHealthStore createDefaultLocalHealthStore() {
  final executor = LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    final databaseFile = File(
      path.join(directory.path, 'letter-health.sqlite'),
    );
    final key = await _loadOrCreateKey(directory);

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
    momentCheckInRepository: DriftMomentCheckInRepository(
      database,
      closeDatabase: false,
    ),
    localBackupStore: DriftLocalBackupStore(database),
    closeStore: database.close,
  );
}

Future<String> _loadOrCreateKey(Directory directory) async {
  // Primary: iOS Keychain / Android EncryptedSharedPreferences.
  try {
    const secureStorage = FlutterSecureStorage();
    final existing = await secureStorage.read(key: _databaseKeyName);
    if (existing != null && existing.isNotEmpty) return existing;

    final newKey = _generateKey();
    await secureStorage.write(key: _databaseKeyName, value: newKey);
    return newKey;
  } on Object {
    // Fallback: file-based key for platforms where secure storage is
    // unavailable (macOS debug builds without provisioning).
  }

  // macOS / desktop fallback — file in sandboxed app support directory.
  final keyFile = File(path.join(directory.path, 'letter.health_database.key'));
  if (await keyFile.exists()) {
    final key = await keyFile.readAsString();
    if (key.trim().isNotEmpty) return key.trim();
  }
  final newKey = _generateKey();
  await keyFile.writeAsString(newKey);
  return newKey;
}

String _generateKey() {
  final random = Random.secure();
  return List.generate(
    32,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
