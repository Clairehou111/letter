import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/local_backup/application/local_backup_service.dart';
import 'package:letter_mobile/features/local_backup/data/drift_local_backup_store.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_import.dart';
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
        batch.insertAll(source.periodFlowRows, [
          PeriodFlowRowsCompanion.insert(
            periodId: 'period-source',
            day: 20400,
            flow: 'medium',
            createdAtMillis: 210,
            updatedAtMillis: 220,
          ),
          PeriodFlowRowsCompanion.insert(
            periodId: 'period-source',
            day: 20401,
            flow: 'light',
            createdAtMillis: 230,
            updatedAtMillis: 240,
          ),
        ]);
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
          source.cycleReflectionRows,
          CycleReflectionRowsCompanion.insert(
            id: 'cycle-reflection-source',
            startingPeriodId: const Value('period-source'),
            cycleStartDay: 20400,
            observation: const Value('This cycle needed a quieter pace.'),
            need: const Value('restOrPhysicalCapacity'),
            whatHelped: const Value('Fewer plans.'),
            futureSelfNote: const Value('Keep an evening open.'),
            createdAtMillis: 610,
            updatedAtMillis: 620,
          ),
        );
        batch.insert(
          source.healthRecordRows,
          HealthRecordRowsCompanion.insert(
            id: 'health-source',
            symptom: 'cramps',
            severity: 3,
            functionalImpactsJson: '["homeResponsibilities"]',
            experiencedDay: 20400,
            recordedAtMillis: 700,
            updatedAtMillis: 800,
            provenance: 'same_day',
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
          source.preparationPlanRows,
          PreparationPlanRowsCompanion.insert(
            id: 'active',
            status: 'current',
            evidenceFingerprint: 'evidence-v1',
            sourceRecordIdsJson: '["care-source"]',
            includeCare: true,
            careActionId: 'heavy.quiet-presence',
            careActionLabel: 'Quiet presence',
            careMode: 'heavy',
            betterCount: 1,
            sameCount: 0,
            worseCount: 0,
            noteText: const Value('Keep the room quiet.'),
            personalText: const Value('Put a heat pack beside the bed.'),
            createdAtMillis: 910,
            updatedAtMillis: 920,
          ),
        );
        batch.insert(
          source.preparationDismissalRows,
          PreparationDismissalRowsCompanion.insert(
            fingerprint: 'proposal-hidden',
            evidenceLine: 'You marked Quiet presence Better once.',
            dismissedAtMillis: 930,
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
          'period_flows',
          'care_records',
          'care_reflections',
          'cycle_reflections',
          'health_records',
          'capture_notes',
          'moment_check_ins',
          'preparation_plans',
          'preparation_dismissals',
        ]),
      );
      final cycleBackup = snapshot.collections.singleWhere(
        (collection) => collection.name == 'cycle_reflections',
      );
      expect(cycleBackup.schemaVersion, 2);
      expect(
        cycleBackup.records.single.data['startingPeriodId'],
        'period-source',
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
      final restoredFlows = await destination
          .select(destination.periodFlowRows)
          .get();
      expect(restoredFlows, hasLength(2));
      expect(
        restoredFlows.map((row) => (row.periodId, row.day, row.flow)),
        containsAll([
          ('period-source', 20400, 'medium'),
          ('period-source', 20401, 'light'),
        ]),
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
        (await destination.select(destination.cycleReflectionRows).get())
            .single
            .id,
        'cycle-reflection-source',
      );
      expect(
        (await destination.select(destination.cycleReflectionRows).get())
            .single
            .startingPeriodId,
        'period-source',
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
        (await destination.select(destination.preparationPlanRows).get())
            .single
            .evidenceFingerprint,
        'evidence-v1',
      );
      expect(
        (await destination.select(destination.preparationPlanRows).get())
            .single
            .personalText,
        'Put a heat pack beside the bed.',
      );
      expect(
        (await destination.select(destination.preparationDismissalRows).get())
            .single
            .fingerprint,
        'proposal-hidden',
      );
    },
  );

  test(
    'imports an older snapshot without period_flows and clears destination flow on replace',
    () async {
      final source = LetterHealthDatabase(NativeDatabase.memory());
      final destination = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(destination.close);

      await source
          .into(source.periodRows)
          .insert(
            PeriodRowsCompanion.insert(
              id: 'period-legacy',
              startDay: 20500,
              endDay: Value(20504),
              createdAtMillis: 300,
              updatedAtMillis: 400,
            ),
          );
      await destination.batch((batch) {
        batch.insert(
          destination.periodRows,
          PeriodRowsCompanion.insert(
            id: 'period-destination',
            startDay: 20400,
            endDay: Value(20403),
            createdAtMillis: 500,
            updatedAtMillis: 600,
          ),
        );
        batch.insert(
          destination.periodFlowRows,
          PeriodFlowRowsCompanion.insert(
            periodId: 'period-destination',
            day: 20401,
            flow: 'heavy',
            createdAtMillis: 510,
            updatedAtMillis: 520,
          ),
        );
      });

      final captured = await DriftLocalBackupStore(source).captureSnapshot();
      final legacySnapshot = LocalBackupSnapshot(
        createdAt: captured.createdAt,
        collections: captured.collections
            .where((collection) => collection.name != 'period_flows')
            .toList(growable: false),
      );
      final service = LocalBackupService();
      final package = await service.encryptSnapshot(
        snapshot: legacySnapshot,
        passphrase: 'legacy backup password',
      );
      final destinationStore = DriftLocalBackupStore(destination);
      final staged = await service.prepareImport(
        packageBytes: package,
        passphrase: 'legacy backup password',
        policy: LocalBackupImportPolicy.replace,
        destination: destinationStore,
        stager: destinationStore,
      );

      await staged.commit();

      expect(
        (await destination.select(destination.periodRows).get()).single.id,
        'period-legacy',
      );
      expect(
        await destination.select(destination.periodFlowRows).get(),
        isEmpty,
      );
    },
  );

  test('rejects orphan period flow rows during staging', () async {
    final database = LetterHealthDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await expectLater(
      DriftLocalBackupStore(database).stage(
        _plan(
          _snapshot(
            collections: [
              _collection('period_flows', [
                _record('missing-period:20400', {
                  'periodId': 'missing-period',
                  'day': 20400,
                  'flow': 'light',
                  'createdAtMillis': 1,
                  'updatedAtMillis': 2,
                }),
              ]),
            ],
          ),
        ),
      ),
      throwsA(_malformedPayload),
    );
  });

  test('rejects orphan care reflections during staging', () async {
    final database = LetterHealthDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await expectLater(
      DriftLocalBackupStore(database).stage(
        _plan(
          _snapshot(
            collections: [
              _collection('care_reflections', [
                _record('reflection-1', {
                  'careRecordId': 'missing-care-record',
                  'mode': 'heavy',
                  'observation': null,
                  'need': null,
                  'whatHelped': null,
                  'futureSelfNote': null,
                  'createdAtMillis': 1,
                  'updatedAtMillis': 2,
                }),
              ]),
            ],
          ),
        ),
      ),
      throwsA(_malformedPayload),
    );
  });

  test(
    'rejects invalid cycle-reflection period references during staging',
    () async {
      final database = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await expectLater(
        DriftLocalBackupStore(database).stage(
          _plan(
            _snapshot(
              collections: [
                _collection('cycle_reflections', [
                  _record('cycle-reflection-1', {
                    'cycleStartDay': 20400,
                    'startingPeriodId': 'missing-period',
                    'observation': null,
                    'need': null,
                    'whatHelped': null,
                    'futureSelfNote': null,
                    'createdAtMillis': 1,
                    'updatedAtMillis': 2,
                  }),
                ], 2),
              ],
            ),
          ),
        ),
        throwsA(_malformedPayload),
      );
    },
  );

  test('rejects health rows that domain repositories cannot decode', () async {
    final database = LetterHealthDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await expectLater(
      DriftLocalBackupStore(database).stage(
        _plan(
          _snapshot(
            collections: [
              _collection('health_records', [
                _record('invalid-health', {
                  'symptom': 'cramps',
                  'severity': 9,
                  'functionalImpactsJson': '["notARealImpact"]',
                  'experiencedDay': 20400,
                  'recordedAtMillis': 1,
                  'updatedAtMillis': 2,
                  'provenance': 'invented',
                  'userConfirmed': true,
                  'vocabularyVersion': 1,
                }),
              ], 2),
            ],
          ),
        ),
      ),
      throwsA(_malformedPayload),
    );
  });
}

Matcher get _malformedPayload => isA<LocalBackupException>().having(
  (error) => error.failure,
  'failure',
  LocalBackupFailure.malformedPayload,
);

LocalBackupImportPlan _plan(LocalBackupSnapshot snapshot) =>
    LocalBackupImportPlan(
      preview: const LocalBackupImportPreview(
        policy: LocalBackupImportPolicy.replace,
        collections: [],
      ),
      resultingSnapshot: snapshot,
    );

LocalBackupSnapshot _snapshot({
  required List<LocalBackupCollection> collections,
}) {
  final required = [
    _collection('periods'),
    _collection('care_records'),
    _collection('care_reflections'),
    _collection('health_records'),
    _collection('capture_notes'),
  ];
  final byName = {
    for (final collection in [...required, ...collections])
      collection.name: collection,
  };
  return LocalBackupSnapshot(
    createdAt: DateTime.utc(2026, 7, 28),
    collections: byName.values,
  );
}

LocalBackupCollection _collection(
  String name, [
  List<LocalBackupRecord> records = const [],
  int schemaVersion = 1,
]) => LocalBackupCollection(
  name: name,
  schemaVersion: schemaVersion,
  records: records,
);

LocalBackupRecord _record(String id, Map<String, Object?> data) =>
    LocalBackupRecord(
      id: id,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        data['updatedAtMillis']! as int,
        isUtc: true,
      ),
      data: data,
    );
