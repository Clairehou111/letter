import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/check_in/data/drift_moment_check_in_repository.dart';
import 'package:letter_mobile/features/check_in/data/in_memory_moment_check_in_repository.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in_repository.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/local_backup/data/drift_local_backup_store.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_import.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_models.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

Matcher _failure(MomentCheckInFailure failure) => isA<MomentCheckInException>()
    .having((error) => error.failure, 'failure', failure);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  for (final drift in [false, true]) {
    group(drift ? 'durable Moment correction' : 'memory Moment correction', () {
      late CorrectableMomentRepository repository;
      LetterHealthDatabase? database;
      late DateTime now;
      late int clockReads;
      setUp(() {
        now = DateTime(2026, 10, 9, 12, 0, 0, 123, 456);
        clockReads = 0;
        DateTime clock() {
          clockReads++;
          return now;
        }

        if (drift) {
          database = LetterHealthDatabase(NativeDatabase.memory());
          repository = DriftMomentCheckInRepository(
            database!,
            clock: clock,
            idGenerator: () => 'source-id',
            closeDatabase: false,
          );
        } else {
          repository = InMemoryMomentCheckInRepository(
            clock: clock,
            idGenerator: () => 'source-id',
          );
        }
      });
      tearDown(() async => database?.close());

      test(
        'past correction keeps identity, original day and original trust',
        () async {
          final original = await repository.create(
            MomentCheckInState.good,
            occurredAt: now.subtract(const Duration(minutes: 1)),
          );
          now = DateTime(2026, 10, 10, 13, 0, 0, 567, 890);
          final corrected = await repository.update(
            original.id,
            MomentCheckInState.tender,
            expected: original,
          );
          expect(corrected.id, original.id);
          expect(corrected.occurredAt, original.occurredAt);
          expect(corrected.experiencedDate, original.experiencedDate);
          expect(corrected.createdAt, original.createdAt);
          expect(
            corrected.writeZoneOffsetMinutes,
            original.writeZoneOffsetMinutes,
          );
          expect(corrected.writeZoneName, original.writeZoneName);
          expect(corrected.originalProvenance, HealthRecordProvenance.sameDay);
          expect(corrected.provenance, HealthRecordProvenance.laterRecall);
          expect(corrected.updatedAt.microsecondsSinceEpoch % 1000, 0);
          expect(
            corrected.updatedAt.millisecondsSinceEpoch,
            now.millisecondsSinceEpoch,
          );
          expect(
            corrected.updatedZoneOffsetMinutes,
            now.toLocal().timeZoneOffset.inMinutes,
          );
          final loaded = (await repository.getAll()).single;
          expect(loaded.state, MomentCheckInState.tender);
          expect(loaded.updatedAt, corrected.updatedAt);
          expect(loaded.originalProvenance, HealthRecordProvenance.sameDay);
          expect(loaded.provenance, HealthRecordProvenance.laterRecall);
        },
      );

      test(
        'unchanged state is a no-op without a new clock read or provenance',
        () async {
          final original = await repository.create(
            MomentCheckInState.calm,
            occurredAt: now,
          );
          final reads = clockReads;
          now = DateTime(2026, 10, 20);
          final unchanged = await repository.update(
            original.id,
            original.state,
            expected: original,
          );
          expect(clockReads, reads);
          expect(unchanged.updatedAt, original.updatedAt);
          expect(unchanged.provenance, original.provenance);
          expect(
            unchanged.updatedZoneOffsetMinutes,
            original.updatedZoneOffsetMinutes,
          );
          expect(await repository.getAll(), hasLength(1));
        },
      );

      test(
        'date-null legacy correction remains undated and timing unknown',
        () async {
          final legacy = MomentCheckIn(
            id: 'legacy',
            state: MomentCheckInState.steady,
            occurredAt: DateTime.utc(2026, 9, 1),
            createdAt: DateTime.utc(2026, 9, 1, 1),
          );
          if (drift) {
            await database!
                .into(database!.momentCheckInRows)
                .insert(
                  MomentCheckInRowsCompanion.insert(
                    id: legacy.id,
                    state: legacy.state.name,
                    occurredAtMillis: legacy.occurredAt.millisecondsSinceEpoch,
                    createdAtMillis: legacy.createdAt.millisecondsSinceEpoch,
                  ),
                );
          } else {
            repository = InMemoryMomentCheckInRepository(
              seed: [legacy],
              clock: () => now,
            );
          }
          final corrected = await repository.update(
            legacy.id,
            MomentCheckInState.low,
          );
          expect(corrected.experiencedDate, isNull);
          expect(corrected.provenance, HealthRecordProvenance.timingUnknown);
          expect(
            corrected.originalProvenance,
            HealthRecordProvenance.timingUnknown,
          );
          expect(corrected.createdAt, legacy.createdAt);
          expect(corrected.occurredAt, legacy.occurredAt);
          expect(corrected.writeZoneOffsetMinutes, isNull);
          expect(
            corrected.updatedZoneOffsetMinutes,
            now.toLocal().timeZoneOffset.inMinutes,
          );
        },
      );

      test(
        'stale source cannot overwrite or delete a corrected state at the same clock tick',
        () async {
          final original = await repository.create(
            MomentCheckInState.good,
            occurredAt: now,
          );
          final corrected = await repository.update(
            original.id,
            MomentCheckInState.low,
            expected: original,
          );
          expect(corrected.updatedAt, original.updatedAt);
          await expectLater(
            repository.update(
              original.id,
              MomentCheckInState.anxious,
              expected: original,
            ),
            throwsA(_failure(MomentCheckInFailure.staleWrite)),
          );
          expect(await repository.deleteIfUnchanged(original), isFalse);
          expect(
            (await repository.getAll()).single.state,
            MomentCheckInState.low,
          );
        },
      );

      test(
        'trusted undo restores the exact deleted source and rejects fabricated historical insertion',
        () async {
          final source = await repository.create(
            MomentCheckInState.hopeful,
            occurredAt: now,
          );
          await expectLater(
            repository.restoreDeleted(source),
            throwsA(_failure(MomentCheckInFailure.staleWrite)),
          );
          expect(await repository.deleteIfUnchanged(source), isTrue);
          expect(await repository.getAll(), isEmpty);
          final altered = correctMomentCheckIn(
            previous: source,
            state: MomentCheckInState.physical,
            savedAt: now,
          );
          await expectLater(
            repository.restoreDeleted(altered),
            throwsA(_failure(MomentCheckInFailure.staleWrite)),
          );
          now = DateTime(2026, 10, 20);
          final restored = await repository.restoreDeleted(source);
          expect(restored.id, source.id);
          expect(restored.state, source.state);
          expect(restored.createdAt, source.createdAt);
          expect(restored.updatedAt, source.updatedAt);
          expect(restored.experiencedDate, source.experiencedDate);
          expect(restored.provenance, source.provenance);
          expect(restored.originalProvenance, source.originalProvenance);
          expect(
            restored.updatedZoneOffsetMinutes,
            source.updatedZoneOffsetMinutes,
          );
          await expectLater(
            repository.restoreDeleted(source),
            throwsA(_failure(MomentCheckInFailure.staleWrite)),
          );
        },
      );

      test('undo cannot overwrite a reused source ID', () async {
        final original = await repository.create(
          MomentCheckInState.good,
          occurredAt: now,
        );
        expect(await repository.deleteIfUnchanged(original), isTrue);
        now = DateTime(2026, 10, 10, 12);
        final replacement = await repository.create(
          MomentCheckInState.exhausted,
          occurredAt: now,
        );
        expect(replacement.id, original.id);
        await expectLater(
          repository.restoreDeleted(original),
          throwsA(_failure(MomentCheckInFailure.staleWrite)),
        );
        expect(
          (await repository.getAll()).single.state,
          MomentCheckInState.exhausted,
        );
      });
    });
  }

  test(
    'schema16 upgrade preserves trusted original timing and legacy unknown',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'moment-correction-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/schema16.sqlite');
      final oldDatabase = LetterHealthDatabase(NativeDatabase(file));
      final savedAt = DateTime(2026, 10, 9, 12);
      final original = await DriftMomentCheckInRepository(
        oldDatabase,
        clock: () => savedAt,
        idGenerator: () => 'known',
        closeDatabase: false,
      ).create(MomentCheckInState.good, occurredAt: savedAt);
      await oldDatabase
          .into(oldDatabase.momentCheckInRows)
          .insert(
            MomentCheckInRowsCompanion.insert(
              id: 'unknown',
              state: 'low',
              occurredAtMillis: 1000,
              createdAtMillis: 2000,
            ),
          );
      await oldDatabase.close();
      final legacy = sqlite.sqlite3.open(file.path);
      for (final column in [
        'updated_at_millis',
        'original_provenance',
        'updated_zone_offset_minutes',
        'updated_zone_name',
      ]) {
        legacy.execute('ALTER TABLE moment_check_in_rows DROP COLUMN $column');
      }
      legacy.execute('PRAGMA user_version = 16');
      legacy.close();
      final database = LetterHealthDatabase(NativeDatabase(file));
      addTearDown(database.close);
      final repository = DriftMomentCheckInRepository(
        database,
        clock: () => DateTime(2026, 10, 10, 12),
        closeDatabase: false,
      );
      final sources = await repository.getAll();
      final known = sources.singleWhere((source) => source.id == 'known');
      expect(known.createdAt, original.createdAt);
      expect(known.updatedAt, original.createdAt);
      expect(known.originalProvenance, HealthRecordProvenance.sameDay);
      expect(known.writeZoneOffsetMinutes, original.writeZoneOffsetMinutes);
      final unknown = sources.singleWhere((source) => source.id == 'unknown');
      expect(unknown.experiencedDate, isNull);
      expect(unknown.originalProvenance, HealthRecordProvenance.timingUnknown);
      expect(unknown.updatedAt.millisecondsSinceEpoch, 2000);
      final corrected = await repository.update(
        known.id,
        MomentCheckInState.tender,
      );
      expect(corrected.originalProvenance, HealthRecordProvenance.sameDay);
      expect(corrected.provenance, HealthRecordProvenance.laterRecall);
      expect(
        (await database.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        18,
      );
    },
  );

  test(
    'Moment backupv3 round trip retains original and active timing after correction',
    () async {
      final source = LetterHealthDatabase(NativeDatabase.memory());
      final destination = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(destination.close);
      var now = DateTime(2026, 10, 9, 12);
      final repository = DriftMomentCheckInRepository(
        source,
        clock: () => now,
        idGenerator: () => 'source',
        closeDatabase: false,
      );
      final original = await repository.create(
        MomentCheckInState.energized,
        occurredAt: now,
      );
      now = DateTime(2026, 10, 10, 12);
      final corrected = await repository.update(
        original.id,
        MomentCheckInState.tender,
      );
      final snapshot = await DriftLocalBackupStore(source).captureSnapshot();
      final collection = snapshot.collections.singleWhere(
        (collection) => collection.name == 'moment_check_ins',
      );
      expect(collection.schemaVersion, 3);
      expect(collection.records.single.updatedAt, corrected.updatedAt);
      await _restore(destination, snapshot);
      final loaded = (await DriftMomentCheckInRepository(
        destination,
      ).getAll()).single;
      expect(loaded.id, original.id);
      expect(loaded.occurredAt, original.occurredAt);
      expect(loaded.createdAt, original.createdAt);
      expect(loaded.updatedAt, corrected.updatedAt);
      expect(loaded.experiencedDate, original.experiencedDate);
      expect(loaded.originalProvenance, HealthRecordProvenance.sameDay);
      expect(loaded.provenance, HealthRecordProvenance.laterRecall);
      expect(loaded.writeZoneOffsetMinutes, original.writeZoneOffsetMinutes);
      expect(
        loaded.updatedZoneOffsetMinutes,
        corrected.updatedZoneOffsetMinutes,
      );
    },
  );

  test(
    'v1/v2 Moment imports merge with v3 without changing original trust or winning over a newer edit',
    () async {
      final database = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var now = DateTime(2026, 10, 9, 12);
      final repository = DriftMomentCheckInRepository(
        database,
        clock: () => now,
        idGenerator: () => 'existing',
        closeDatabase: false,
      );
      final original = await repository.create(
        MomentCheckInState.good,
        occurredAt: now,
      );
      final oldV2 = LocalBackupSnapshot(
        createdAt: original.createdAt,
        collections: [
          LocalBackupCollection(
            name: 'moment_check_ins',
            schemaVersion: 2,
            records: [
              LocalBackupRecord(
                id: original.id,
                updatedAt: original.createdAt,
                data: {
                  'state': original.state.name,
                  'occurredAtMillis':
                      original.occurredAt.millisecondsSinceEpoch,
                  'createdAtMillis': original.createdAt.millisecondsSinceEpoch,
                  'experiencedDay': original.experiencedDate!.epochDay,
                  'provenance': original.provenance.storageKey,
                  'writeZoneOffsetMinutes': original.writeZoneOffsetMinutes,
                  'writeZoneName': original.writeZoneName,
                },
              ),
            ],
          ),
        ],
      );
      now = DateTime(2026, 10, 10, 12);
      await repository.update(original.id, MomentCheckInState.tender);
      await _restore(database, oldV2, merge: true);
      expect(
        (await repository.getAll()).single.state,
        MomentCheckInState.tender,
      );
      final legacy = LocalBackupSnapshot(
        createdAt: now,
        collections: [
          LocalBackupCollection(
            name: 'moment_check_ins',
            schemaVersion: 1,
            records: [
              LocalBackupRecord(
                id: 'legacy',
                updatedAt: DateTime.fromMillisecondsSinceEpoch(
                  2000,
                  isUtc: true,
                ),
                data: {
                  'state': 'low',
                  'occurredAtMillis': 1000,
                  'createdAtMillis': 2000,
                },
              ),
            ],
          ),
        ],
      );
      await _restore(database, legacy, merge: true);
      final loaded = await repository.getAll();
      expect(loaded, hasLength(2));
      final unknown = loaded.singleWhere((source) => source.id == 'legacy');
      expect(unknown.experiencedDate, isNull);
      expect(unknown.updatedAt, unknown.createdAt);
      expect(unknown.originalProvenance, HealthRecordProvenance.timingUnknown);
    },
  );

  test(
    'v3 null original trust remains unknown even with a known active recall',
    () async {
      final database = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftMomentCheckInRepository(
        database,
        clock: () => DateTime(2026, 10, 10, 12),
        closeDatabase: false,
      );
      await repository.create(
        MomentCheckInState.tender,
        occurredAt: DateTime(2026, 10, 9, 12),
      );
      final snapshot = await DriftLocalBackupStore(database).captureSnapshot();
      final collection = snapshot.collections.singleWhere(
        (collection) => collection.name == 'moment_check_ins',
      );
      final source = collection.records.single;
      final incoming = LocalBackupSnapshot(
        createdAt: snapshot.createdAt,
        collections: [
          ...snapshot.collections.where((item) => item.name != collection.name),
          LocalBackupCollection(
            name: collection.name,
            schemaVersion: 3,
            records: [
              LocalBackupRecord(
                id: source.id,
                updatedAt: source.updatedAt,
                data: {
                  ...source.data,
                  'originalProvenance': null,
                  'writeZoneOffsetMinutes': null,
                  'writeZoneName': null,
                },
              ),
            ],
          ),
        ],
      );
      await _restore(database, incoming);
      final loaded = (await repository.getAll()).single;
      expect(loaded.provenance, HealthRecordProvenance.laterRecall);
      expect(loaded.originalProvenance, HealthRecordProvenance.timingUnknown);
      expect(loaded.experiencedDate, isNotNull);
      expect(loaded.writeZoneOffsetMinutes, isNull);
      final roundTrip = await DriftLocalBackupStore(database).captureSnapshot();
      await _restore(database, roundTrip);
      expect(
        (await repository.getAll()).single.originalProvenance,
        HealthRecordProvenance.timingUnknown,
      );
    },
  );

  test(
    'malformed original provenance in v3 is rejected before replacing source data',
    () async {
      final database = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftMomentCheckInRepository(
        database,
        clock: () => DateTime(2026, 10, 10, 12),
        closeDatabase: false,
      );
      final original = await repository.create(
        MomentCheckInState.good,
        occurredAt: DateTime(2026, 10, 9, 12),
      );
      final snapshot = await DriftLocalBackupStore(database).captureSnapshot();
      final moment = snapshot.collections.singleWhere(
        (collection) => collection.name == 'moment_check_ins',
      );
      final record = moment.records.single;
      final malformed = LocalBackupSnapshot(
        createdAt: snapshot.createdAt,
        collections: [
          ...snapshot.collections.where((item) => item.name != moment.name),
          LocalBackupCollection(
            name: moment.name,
            schemaVersion: 3,
            records: [
              LocalBackupRecord(
                id: record.id,
                updatedAt: record.updatedAt,
                data: {...record.data, 'originalProvenance': 'same_day'},
              ),
            ],
          ),
        ],
      );
      await expectLater(
        _restore(database, malformed),
        throwsA(
          isA<LocalBackupException>().having(
            (error) => error.failure,
            'failure',
            LocalBackupFailure.malformedPayload,
          ),
        ),
      );
      expect((await repository.getAll()).single.id, original.id);
      expect(
        (await repository.getAll()).single.originalProvenance,
        HealthRecordProvenance.laterRecall,
      );
    },
  );
}

Future<void> _restore(
  LetterHealthDatabase database,
  LocalBackupSnapshot incoming, {
  bool merge = false,
}) async {
  final store = DriftLocalBackupStore(database);
  final destination = await store.captureSnapshot();
  final plan = planLocalBackupImport(
    incoming: incoming,
    destination: destination,
    policy: merge
        ? LocalBackupImportPolicy.merge
        : LocalBackupImportPolicy.replace,
  );
  final stage = await store.stage(plan);
  await stage.commit();
}
