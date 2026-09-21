import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/health_data/data/local_health_store.dart';
import 'package:letter_mobile/features/health_data/data/local_health_store_factory_native.dart';
import 'package:letter_mobile/features/local_backup/application/local_backup_service.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_models.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

const _correctKey =
    '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
const _wrongKey =
    'ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100';
const _cipherSentinel = 'LETTER_NATIVE_CIPHER_SENTINEL_2026_08_08';
const _persistentNoteId = 'native-secure-storage-persistence-v1';
const _restartMarkerName = 'native-storage-restart-marker-v1';
const _phase = String.fromEnvironment(
  'NATIVE_STORAGE_PHASE',
  defaultValue: 'roundTrip',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('default mobile key survives a native store reopen', (
    tester,
  ) async {
    final store = createDefaultLocalHealthStore();
    final existing = await store.captureNoteStore.getAll();
    final previous = existing.where((note) => note.id == _persistentNoteId);

    if (_phase == 'externalRestart') {
      final supportDirectory = await getApplicationSupportDirectory();
      final restartMarker = File(
        path.join(supportDirectory.path, _restartMarkerName),
      );
      if (!await restartMarker.exists()) {
        expect(previous, isEmpty);
        await store.captureNoteStore.save(_persistentNote());
        await restartMarker.writeAsString('seeded');
      } else {
        expect(previous, hasLength(1));
        expect(previous.single.text, _cipherSentinel);
        await store.captureNoteStore.delete(previous.single);
        await restartMarker.delete();
      }
      await store.close();
      return;
    }

    if (_phase == 'verify') {
      expect(previous, hasLength(1));
      expect(previous.single.text, _cipherSentinel);
      await store.captureNoteStore.delete(previous.single);
      await store.close();
      return;
    }

    for (final note in previous) {
      await store.captureNoteStore.delete(note);
    }
    await store.captureNoteStore.save(_persistentNote());
    await store.close();

    if (_phase == 'seed') return;

    final reopened = createDefaultLocalHealthStore();
    final notes = await reopened.captureNoteStore.getAll();
    final saved = notes.singleWhere((note) => note.id == _persistentNoteId);
    expect(saved.text, _cipherSentinel);
    await reopened.captureNoteStore.delete(saved);
    await reopened.close();
  });

  testWidgets(
    'native cipher hides plaintext, rejects wrong keys, and restores backup',
    (tester) async {
      final directory = await getTemporaryDirectory();
      final sourceFile = File(
        path.join(directory.path, 'letter-native-cipher-source.sqlite'),
      );
      final destinationFile = File(
        path.join(directory.path, 'letter-native-cipher-destination.sqlite'),
      );
      await _deleteDatabaseFamily(sourceFile);
      await _deleteDatabaseFamily(destinationFile);
      addTearDown(() async {
        await _deleteDatabaseFamily(sourceFile);
        await _deleteDatabaseFamily(destinationFile);
      });

      final source = _isolatedStore(sourceFile, _correctKey);
      await source.captureNoteStore.save(_sentinelNote());
      final snapshot = await source.localBackupStore!.captureSnapshot();
      final backup = await LocalBackupService().encryptSnapshot(
        snapshot: snapshot,
        passphrase: 'native acceptance passphrase',
      );
      await source.close();

      final databaseBytes = await sourceFile.readAsBytes();
      final readable = utf8.decode(databaseBytes, allowMalformed: true);
      expect(readable, isNot(contains(_cipherSentinel)));
      expect(
        databaseBytes.take(16).toList(),
        isNot(equals(utf8.encode('SQLite format 3\u0000'))),
      );

      final wrongKeyStore = _isolatedStore(sourceFile, _wrongKey);
      await expectLater(
        wrongKeyStore.captureNoteStore.getAll(),
        throwsA(anything),
      );
      await _closeAfterFailedOpen(wrongKeyStore);

      final reopened = _isolatedStore(sourceFile, _correctKey);
      expect(
        (await reopened.captureNoteStore.getAll()).single.text,
        _cipherSentinel,
      );
      await reopened.close();

      final destination = _isolatedStore(destinationFile, _correctKey);
      final destinationBackup = destination.localBackupStore!;
      final service = LocalBackupService();
      await expectLater(
        service.prepareImport(
          packageBytes: backup,
          passphrase: 'wrong passphrase',
          policy: LocalBackupImportPolicy.replace,
          destination: destinationBackup,
          stager: destinationBackup,
        ),
        throwsA(anything),
      );
      expect(await destination.captureNoteStore.getAll(), isEmpty);

      final tampered = [...backup];
      tampered[backup.length ~/ 2] ^= 1;
      await expectLater(
        service.prepareImport(
          packageBytes: tampered,
          passphrase: 'native acceptance passphrase',
          policy: LocalBackupImportPolicy.replace,
          destination: destinationBackup,
          stager: destinationBackup,
        ),
        throwsA(anything),
      );
      expect(await destination.captureNoteStore.getAll(), isEmpty);

      final staged = await service.prepareImport(
        packageBytes: backup,
        passphrase: 'native acceptance passphrase',
        policy: LocalBackupImportPolicy.replace,
        destination: destinationBackup,
        stager: destinationBackup,
      );
      await staged.commit();
      expect(
        (await destination.captureNoteStore.getAll()).single.text,
        _cipherSentinel,
      );
      await destination.close();
    },
  );

  testWidgets('encrypted schema 10 migrates without losing cycle identity', (
    tester,
  ) async {
    final directory = await getTemporaryDirectory();
    final databaseFile = File(
      path.join(directory.path, 'letter-native-migration.sqlite'),
    );
    await _deleteDatabaseFamily(databaseFile);
    addTearDown(() => _deleteDatabaseFamily(databaseFile));

    final raw = sqlite3.open(databaseFile.path);
    expect(raw.select('PRAGMA cipher;'), isNotEmpty);
    raw.execute("PRAGMA key = '$_correctKey';");
    raw.select('SELECT count(*) FROM sqlite_master;');
    raw.execute('''
      CREATE TABLE period_rows (
        id TEXT NOT NULL PRIMARY KEY,
        start_day INTEGER NOT NULL,
        end_day INTEGER,
        created_at_millis INTEGER NOT NULL,
        updated_at_millis INTEGER NOT NULL
      )
    ''');
    raw.execute('''
      CREATE TABLE cycle_reflection_rows (
        id TEXT NOT NULL PRIMARY KEY,
        cycle_start_day INTEGER NOT NULL UNIQUE,
        observation TEXT,
        need TEXT,
        what_helped TEXT,
        future_self_note TEXT,
        created_at_millis INTEGER NOT NULL,
        updated_at_millis INTEGER NOT NULL
      )
    ''');
    raw.execute(
      "INSERT INTO period_rows VALUES ('native-period-v10', 20662, 20666, 1, 1)",
    );
    raw.execute(
      "INSERT INTO cycle_reflection_rows VALUES "
      "('native-reflection-v10', 20662, 'Encrypted migration sentinel', "
      'NULL, NULL, NULL, 1, 1)',
    );
    raw.userVersion = 10;
    raw.close();

    final migrated = _isolatedStore(databaseFile, _correctKey);
    final periods = await migrated.periodRepository.getAll();
    final reflections = await migrated.careMemoryRepository
        .getCycleReflections();

    expect(periods.single.id, 'native-period-v10');
    expect(reflections.single.id, 'native-reflection-v10');
    expect(reflections.single.startingPeriodId, 'native-period-v10');
    expect(reflections.single.observation, 'Encrypted migration sentinel');
    await migrated.close();

    final bytes = await databaseFile.readAsBytes();
    final readable = utf8.decode(bytes, allowMalformed: true);
    expect(readable, isNot(contains('Encrypted migration sentinel')));
  });
}

LocalHealthStore _isolatedStore(File file, String key) =>
    createNativeLocalHealthStoreForDatabase(
      databaseFile: file,
      loadKey: () async => key,
    );

CaptureNote _sentinelNote() => CaptureNote(
  id: 'native-cipher-sentinel',
  text: _cipherSentinel,
  source: CaptureSource.typed,
  createdAt: DateTime.utc(2026, 8, 8, 12),
);

CaptureNote _persistentNote() => CaptureNote(
  id: _persistentNoteId,
  text: _cipherSentinel,
  source: CaptureSource.typed,
  createdAt: DateTime.utc(2026, 8, 8, 12),
);

Future<void> _closeAfterFailedOpen(LocalHealthStore store) async {
  try {
    await store.close();
  } on Object {
    // The acceptance condition is that a wrong key cannot open the store.
  }
}

Future<void> _deleteDatabaseFamily(File file) async {
  for (final suffix in ['', '-shm', '-wal']) {
    final candidate = File('${file.path}$suffix');
    if (await candidate.exists()) await candidate.delete();
  }
}
