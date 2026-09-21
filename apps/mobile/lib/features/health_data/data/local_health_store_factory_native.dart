import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../care/data/drift_care_memory_repository.dart';
import '../../capture/data/drift_capture_note_store.dart';
import '../../check_in/data/drift_moment_check_in_repository.dart';
import '../../cycle/data/drift_period_repository.dart';
import '../../cycle/data/letter_health_database.dart';
import '../../health_records/data/drift_health_record_repository.dart';
import '../../local_backup/data/drift_local_backup_store.dart';
import '../../preparation/data/drift_preparation_repository.dart';
import 'local_health_store.dart';

const _databaseKeyName = 'letter.health_database.key.v1';
final _databaseKeyPattern = RegExp(r'^[0-9a-fA-F]{64}$');

LocalHealthStore createDefaultLocalHealthStore() {
  final executor = LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    final databaseFile = File(
      path.join(directory.path, 'letter-health.sqlite'),
    );
    final key = await _loadOrCreateKey(directory);
    return _openEncryptedDatabase(databaseFile, key);
  });
  return _buildLocalHealthStore(executor);
}

/// Creates the same encrypted native store against an explicit file and key.
/// This seam keeps native acceptance tests isolated from a user's app data.
LocalHealthStore createNativeLocalHealthStoreForDatabase({
  required File databaseFile,
  required Future<String> Function() loadKey,
}) {
  final executor = LazyDatabase(() async {
    final key = await loadKey();
    return _openEncryptedDatabase(databaseFile, key);
  });
  return _buildLocalHealthStore(executor);
}

QueryExecutor _openEncryptedDatabase(File databaseFile, String key) {
  final normalizedKey = key.trim();
  if (!_databaseKeyPattern.hasMatch(normalizedKey)) {
    throw StateError('The encrypted database key is unavailable or invalid.');
  }
  return NativeDatabase.createInBackground(
    databaseFile,
    setup: (database) {
      if (database.select('PRAGMA cipher;').isEmpty) {
        throw StateError('Encrypted SQLite support is unavailable.');
      }
      // Keep the original passphrase form for compatibility with databases
      // created before native acceptance testing was introduced.
      database.execute("PRAGMA key = '$normalizedKey';");
      // Force the key to be verified before Drift can run migrations or read
      // any health table. A wrong key must never look like an empty database.
      database.select('SELECT count(*) FROM sqlite_master;');
    },
  );
}

LocalHealthStore _buildLocalHealthStore(QueryExecutor executor) {
  final database = LetterHealthDatabase(executor);
  return LocalHealthStore(
    periodRepository: DriftPeriodRepository(database, closeDatabase: false),
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
    preparationRepository: DriftPreparationRepository(database),
    localBackupStore: DriftLocalBackupStore(database),
    closeStore: database.close,
  );
}

Future<String> _loadOrCreateKey(Directory directory) async {
  // `flutter run -d macos` is ad-hoc signed and cannot receive Keychain
  // entitlements without an Apple Development certificate. Keep its key in
  // Application Support so repeated local runs open the same database.
  if (Platform.isMacOS && kDebugMode) {
    return _loadOrCreateSandboxDatabaseKey(directory);
  }
  const secureStorage = FlutterSecureStorage();
  return loadOrCreateDatabaseKey(
    directory: directory,
    readSecureKey: () => secureStorage.read(key: _databaseKeyName),
    writeSecureKey: (key) =>
        secureStorage.write(key: _databaseKeyName, value: key),
    allowSandboxFallback: _allowsSandboxKeyFallback,
  );
}

@visibleForTesting
Future<String> loadOrCreateDatabaseKey({
  required Directory directory,
  required Future<String?> Function() readSecureKey,
  required Future<void> Function(String key) writeSecureKey,
  required bool allowSandboxFallback,
}) async {
  // Primary: iOS Keychain / Android EncryptedSharedPreferences.
  try {
    final existing = await readSecureKey();
    if (existing != null && existing.isNotEmpty) return existing;

    final newKey = _generateKey();
    await writeSecureKey(newKey);
    return newKey;
  } on Object {
    if (!allowSandboxFallback) {
      throw StateError(
        'Secure database key storage is unavailable on this device.',
      );
    }
    // Unsigned/ad-hoc iOS Simulator builds do not receive Keychain
    // entitlements. Keep those development builds usable without weakening
    // release or physical-device storage guarantees.
  }

  return _loadOrCreateSandboxDatabaseKey(directory);
}

Future<String> _loadOrCreateSandboxDatabaseKey(Directory directory) async {
  // Development-only fallback — file in the app's disposable sandbox.
  final keyFile = File(path.join(directory.path, 'letter.health_database.key'));
  if (await keyFile.exists()) {
    final key = await keyFile.readAsString();
    if (key.trim().isNotEmpty) return key.trim();
  }
  final newKey = _generateKey();
  await keyFile.writeAsString(newKey);
  return newKey;
}

bool get _allowsSandboxKeyFallback {
  return allowsSandboxKeyFallback(
    isMacOS: Platform.isMacOS,
    isIOS: Platform.isIOS,
    isDebug: kDebugMode,
    environment: Platform.environment,
  );
}

@visibleForTesting
bool allowsSandboxKeyFallback({
  required bool isMacOS,
  required bool isIOS,
  required bool isDebug,
  required Map<String, String> environment,
}) {
  if (isMacOS) return isDebug;
  if (!isDebug || !isIOS) return false;
  return environment.containsKey('SIMULATOR_DEVICE_NAME') ||
      environment.containsKey('SIMULATOR_UDID') ||
      environment.containsKey('SIMULATOR_RUNTIME_VERSION');
}

String _generateKey() {
  final random = Random.secure();
  return List.generate(
    32,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
