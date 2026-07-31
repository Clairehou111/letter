import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/local_backup/application/local_backup_service.dart';
import 'package:letter_mobile/features/local_backup/data/drift_local_backup_store.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_models.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test(
    'captures saved local records and commits a staged atomic restore',
    () async {
      final source = LetterHealthDatabase(NativeDatabase.memory());
      final destination = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(destination.close);

      await source.batch((batch) {
        batch.insert(
          source.periodRows,
          PeriodRowsCompanion.insert(
            id: 'period-source',
            startDay: 20400,
            endDay: Value(20404),
            createdAtMillis: 100,
            updatedAtMillis: 200,
          ),
        );
        batch.insert(
          source.careRecordRows,
          CareRecordRowsCompanion.insert(
            id: 'care-source',
            mode: 'heavy',
            actionId: 'heavy.quiet-presence',
            actionLabel: 'Quiet presence',
            outcome: 'better',
            occurredAtMillis: 300,
            createdAtMillis: 300,
            updatedAtMillis: 400,
            pinned: Value(true),
          ),
        );
        batch.insert(
          source.careReflectionRows,
          CareReflectionRowsCompanion.insert(
            id: 'reflection-source',
            careRecordId: 'care-source',
            mode: 'heavy',
            observation: Value('Less sharp after quiet.'),
            need: Value.absent(),
            whatHelped: Value('Quiet presence'),
            futureSelfNote: Value.absent(),
            createdAtMillis: 500,
            updatedAtMillis: 600,
          ),
        );
        batch.insert(
          source.healthRecordRows,
          HealthRecordRowsCompanion.insert(
            id: 'health-source',
            symptom: 'cramps',
            severity: 3,
            painRating: Value(6),
            painLocationsJson: '["lowerAbdomen"]',
            functionalImpactsJson: '["neededRest"]',
            experiencedDay: 20400,
            recordedAtMillis: 700,
            updatedAtMillis: 800,
            provenance: 'manual',
            userConfirmed: true,
            vocabularyVersion: 1,
          ),
        );
        batch.insert(
          source.captureNoteRows,
          CaptureNoteRowsCompanion.insert(
            id: 'note-source',
            content: 'A saved private note.',
            source: 'typed',
            createdAtMillis: 900,
          ),
        );
        batch.insert(
          source.momentCheckInRows,
          MomentCheckInRowsCompanion.insert(
            id: 'check-in-source',
            state: 'steady',
            occurredAtMillis: 850,
            createdAtMillis: 875,
          ),
        );
        batch.insert(
          source.impulseDraftRows,
          ImpulseDraftRowsCompanion.insert(
            id: 'sealed-not-exported',
            content: 'Keep this out of the backup.',
            createdAtMillis: 1,
            updatedAtMillis: 2,
            sealedAtMillis: Value(1),
            unlockAtMillis: Value(3),
          ),
        );
      });
      await destination
          .into(destination.periodRows)
          .insert(
            PeriodRowsCompanion.insert(
              id: 'period-destination',
              startDay: 20300,
              endDay: Value(20303),
              createdAtMillis: 1,
              updatedAtMillis: 2,
            ),
          );

      final sourceStore = DriftLocalBackupStore(
        source,
        clock: () => DateTime.utc(2026, 7, 28),
      );
      final snapshot = await sourceStore.captureSnapshot();
      expect(
        snapshot.collections.map((collection) => collection.name),
        containsAll([
          'periods',
          'care_records',
          'care_reflections',
          'health_records',
          'capture_notes',
          'moment_check_ins',
        ]),
      );
      expect(
        snapshot.collections
            .expand((collection) => collection.records)
            .map((record) => record.id),
        isNot(contains('sealed-not-exported')),
      );

      final service = LocalBackupService();
      final package = await service.encryptSnapshot(
        snapshot: snapshot,
        passphrase: 'private backup password',
      );
      final destinationStore = DriftLocalBackupStore(destination);
      final staged = await service.prepareImport(
        packageBytes: package,
        passphrase: 'private backup password',
        policy: LocalBackupImportPolicy.replace,
        destination: destinationStore,
        stager: destinationStore,
      );

      expect(
        (await destination.select(destination.periodRows).get()).single.id,
        'period-destination',
      );
      expect(
        staged.preview.collections
            .singleWhere((item) => item.name == 'periods')
            .wouldRemove,
        1,
      );
      await staged.commit();

      expect(
        (await destination.select(destination.periodRows).get()).single.id,
        'period-source',
      );
      expect(
        (await destination.select(destination.careRecordRows).get()).single.id,
        'care-source',
      );
      expect(
        (await destination.select(destination.careReflectionRows).get())
            .single
            .id,
        'reflection-source',
      );
      expect(
        (await destination.select(destination.healthRecordRows).get())
            .single
            .id,
        'health-source',
      );
      expect(
        (await destination.select(destination.captureNoteRows).get()).single.id,
        'note-source',
      );
      expect(
        (await destination.select(destination.momentCheckInRows).get())
            .single
            .id,
        'check-in-source',
      );
      expect(
        await destination.select(destination.impulseDraftRows).get(),
        isEmpty,
      );
    },
  );
}
