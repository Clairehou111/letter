import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/check_in/data/drift_moment_check_in_repository.dart';
import 'package:letter_mobile/features/check_in/data/in_memory_moment_check_in_repository.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in_repository.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/local_backup/data/drift_local_backup_store.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_import.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_models.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test(
    'same-day Moment freezes date, save zone and canonical milliseconds',
    () async {
      final now = DateTime(2026, 10, 9, 12, 0, 0, 456, 789);
      final repository = InMemoryMomentCheckInRepository(clock: () => now);
      final record = await repository.create(
        MomentCheckInState.good,
        occurredAt: DateTime(2026, 10, 9, 11, 59, 59, 123, 456),
      );
      expect(record.experiencedDate, const LocalDate(2026, 10, 9));
      expect(record.provenance, HealthRecordProvenance.sameDay);
      expect(record.createdAt.microsecond, 0);
      expect(record.occurredAt.microsecond, 0);
      expect(record.writeZoneOffsetMinutes, now.timeZoneOffset.inMinutes);
      expect(record.writeZoneName, now.timeZoneName);
    },
  );

  test(
    'save just after midnight preserves selected day and becomes later recall',
    () async {
      final database = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftMomentCheckInRepository(
        database,
        closeDatabase: false,
        clock: () => DateTime(2026, 10, 10, 0, 1),
      );
      final created = await repository.create(
        MomentCheckInState.physical,
        occurredAt: DateTime(2026, 10, 9, 23, 59),
      );
      final reloaded = (await DriftMomentCheckInRepository(
        database,
        closeDatabase: false,
      ).getAll()).single;
      expect(reloaded.id, created.id);
      expect(reloaded.experiencedDate, const LocalDate(2026, 10, 9));
      expect(reloaded.provenance, HealthRecordProvenance.laterRecall);
      expect(reloaded.createdAt, created.createdAt);
      expect(reloaded.occurredAt, created.occurredAt);
      expect(reloaded.writeZoneOffsetMinutes, created.writeZoneOffsetMinutes);
    },
  );

  test(
    'both repositories reject future moments without partial writes',
    () async {
      final database = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final now = DateTime(2026, 10, 9, 12);
      for (final repository in <MomentCheckInRepository>[
        InMemoryMomentCheckInRepository(clock: () => now),
        DriftMomentCheckInRepository(
          database,
          closeDatabase: false,
          clock: () => now,
        ),
      ]) {
        await expectLater(
          repository.create(
            MomentCheckInState.low,
            occurredAt: DateTime(2026, 10, 9, 13),
          ),
          throwsA(
            isA<MomentCheckInException>().having(
              (error) => error.failure,
              'future rejection',
              MomentCheckInFailure.futureDate,
            ),
          ),
        );
        expect(await repository.getAll(), isEmpty);
      }
    },
  );

  test('legacy timestamp-only model and rows retain unknown timing', () async {
    final database = LetterHealthDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database
        .into(database.momentCheckInRows)
        .insert(
          MomentCheckInRowsCompanion.insert(
            id: 'legacy',
            state: 'good',
            occurredAtMillis: 1000,
            createdAtMillis: 2000,
          ),
        );
    final loaded = (await DriftMomentCheckInRepository(
      database,
      closeDatabase: false,
    ).getAll()).single;
    expect(loaded.experiencedDate, isNull);
    expect(loaded.provenance, HealthRecordProvenance.timingUnknown);
    expect(loaded.writeZoneOffsetMinutes, isNull);
    expect(loaded.occurredAt.millisecondsSinceEpoch, 1000);
    final legacy = MomentCheckIn(
      id: 'legacy-model',
      state: MomentCheckInState.good,
      occurredAt: DateTime.utc(2026, 10, 9),
      createdAt: DateTime.utc(2026, 10, 9),
    );
    expect(legacy.provenance, HealthRecordProvenance.timingUnknown);
    expect(legacy.experiencedDate, isNull);
  });

  test(
    'v15 Moment migration preserves timestamps without fabricated date or provenance',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'letter-moment-v15-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/synthetic.sqlite');
      final created = LetterHealthDatabase(NativeDatabase(file));
      await created
          .into(created.momentCheckInRows)
          .insert(
            MomentCheckInRowsCompanion.insert(
              id: 'legacy-v15',
              state: 'physical',
              occurredAtMillis: 1000,
              createdAtMillis: 2000,
            ),
          );
      await created.close();
      final legacy = sqlite.sqlite3.open(file.path);
      for (final column in [
        'experienced_day',
        'provenance',
        'write_zone_offset_minutes',
        'write_zone_name',
      ]) {
        legacy.execute('ALTER TABLE moment_check_in_rows DROP COLUMN $column');
      }
      legacy.execute('PRAGMA user_version = 15');
      legacy.close();
      final database = LetterHealthDatabase(NativeDatabase(file));
      addTearDown(database.close);
      final record = (await DriftMomentCheckInRepository(
        database,
        closeDatabase: false,
      ).getAll()).single;
      expect(record.id, 'legacy-v15');
      expect(record.state, MomentCheckInState.physical);
      expect(record.occurredAt.millisecondsSinceEpoch, 1000);
      expect(record.createdAt.millisecondsSinceEpoch, 2000);
      expect(record.experiencedDate, isNull);
      expect(record.provenance, HealthRecordProvenance.timingUnknown);
      expect(
        (await database.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        18,
      );
    },
  );

  test(
    'Moment v3 backup round-trip preserves frozen current timing and identity',
    () async {
      final source = LetterHealthDatabase(NativeDatabase.memory());
      final destination = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(destination.close);
      final repository = DriftMomentCheckInRepository(
        source,
        closeDatabase: false,
        clock: () => DateTime(2026, 10, 10, 0, 1),
      );
      final created = await repository.create(
        MomentCheckInState.anxious,
        occurredAt: DateTime(2026, 10, 9, 23, 59),
      );
      final snapshot = await DriftLocalBackupStore(source).captureSnapshot();
      expect(
        snapshot.collections
            .singleWhere((collection) => collection.name == 'moment_check_ins')
            .schemaVersion,
        3,
      );
      await _restore(destination, snapshot);
      final loaded = (await DriftMomentCheckInRepository(
        destination,
        closeDatabase: false,
      ).getAll()).single;
      expect(loaded.id, created.id);
      expect(loaded.experiencedDate, created.experiencedDate);
      expect(loaded.provenance, HealthRecordProvenance.laterRecall);
      expect(loaded.createdAt, created.createdAt);
      expect(loaded.occurredAt, created.occurredAt);
      expect(loaded.writeZoneOffsetMinutes, created.writeZoneOffsetMinutes);
      expect(loaded.writeZoneName, created.writeZoneName);
    },
  );

  test(
    'legacy Moment backup merges as unknown alongside a new same-day source',
    () async {
      final source = LetterHealthDatabase(NativeDatabase.memory());
      final destination = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(destination.close);
      await source
          .into(source.momentCheckInRows)
          .insert(
            MomentCheckInRowsCompanion.insert(
              id: 'legacy-backup',
              state: 'steady',
              occurredAtMillis: 1000,
              createdAtMillis: 2000,
            ),
          );
      final snapshot = await DriftLocalBackupStore(source).captureSnapshot();
      final old = _mapMoments(
        snapshot,
        (collection) => LocalBackupCollection(
          name: collection.name,
          schemaVersion: 1,
          records: collection.records.map(
            (record) => LocalBackupRecord(
              id: record.id,
              updatedAt: record.updatedAt,
              data: {
                'state': record.data['state'],
                'occurredAtMillis': record.data['occurredAtMillis'],
                'createdAtMillis': record.data['createdAtMillis'],
              },
            ),
          ),
        ),
      );
      final repository = DriftMomentCheckInRepository(
        destination,
        closeDatabase: false,
        clock: () => DateTime(2026, 10, 9, 12),
        idGenerator: () => 'new-moment',
      );
      await repository.create(
        MomentCheckInState.good,
        occurredAt: DateTime(2026, 10, 9, 11),
      );
      await _restore(destination, old, policy: LocalBackupImportPolicy.merge);
      final records = await repository.getAll();
      expect(records, hasLength(2));
      final legacy = records.singleWhere(
        (record) => record.id == 'legacy-backup',
      );
      expect(legacy.experiencedDate, isNull);
      expect(legacy.provenance, HealthRecordProvenance.timingUnknown);
      expect(
        records.singleWhere((record) => record.id == 'new-moment').provenance,
        HealthRecordProvenance.sameDay,
      );
    },
  );

  test(
    'malformed prospective timing is rejected before replacing destination sources',
    () async {
      final source = LetterHealthDatabase(NativeDatabase.memory());
      final destination = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(destination.close);
      final now = DateTime(2026, 10, 9, 12);
      await DriftMomentCheckInRepository(
        source,
        closeDatabase: false,
        clock: () => now,
        idGenerator: () => 'incoming',
      ).create(MomentCheckInState.low, occurredAt: DateTime(2026, 10, 9, 11));
      final existing = DriftMomentCheckInRepository(
        destination,
        closeDatabase: false,
        clock: () => now,
        idGenerator: () => 'retained',
      );
      await existing.create(
        MomentCheckInState.good,
        occurredAt: DateTime(2026, 10, 9, 11),
      );
      final snapshot = await DriftLocalBackupStore(source).captureSnapshot();
      final malformed = _mapMoments(
        snapshot,
        (collection) => LocalBackupCollection(
          name: collection.name,
          schemaVersion: 2,
          records: collection.records.map(
            (record) => LocalBackupRecord(
              id: record.id,
              updatedAt: record.updatedAt,
              data: {
                ...record.data,
                'experiencedDay': const LocalDate(2026, 10, 8).epochDay,
              },
            ),
          ),
        ),
      );
      await expectLater(
        _restore(destination, malformed),
        throwsA(isA<LocalBackupException>()),
      );
      expect((await existing.getAll()).single.id, 'retained');
    },
  );
}

Future<void> _restore(
  LetterHealthDatabase database,
  LocalBackupSnapshot snapshot, {
  LocalBackupImportPolicy policy = LocalBackupImportPolicy.replace,
}) async {
  final store = DriftLocalBackupStore(database);
  final plan = planLocalBackupImport(
    incoming: snapshot,
    destination: await store.captureSnapshot(),
    policy: policy,
  );
  await (await store.stage(plan)).commit();
}

LocalBackupSnapshot _mapMoments(
  LocalBackupSnapshot snapshot,
  LocalBackupCollection Function(LocalBackupCollection) transform,
) => LocalBackupSnapshot(
  createdAt: snapshot.createdAt,
  collections: snapshot.collections.map(
    (collection) => collection.name == 'moment_check_ins'
        ? transform(collection)
        : collection,
  ),
);
