import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/capture/data/drift_capture_note_store.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/bleeding_flow.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/data/drift_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/local_backup/data/drift_local_backup_store.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_import.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_models.dart';
import 'package:letter_mobile/features/record_hub/data/drift_record_hub_repository.dart';
import 'package:letter_mobile/features/record_hub/data/drift_record_interventions_repository.dart';
import 'package:letter_mobile/features/record_hub/data/drift_record_programme_repository.dart';
import 'package:letter_mobile/features/record_hub/domain/record_interventions.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';

void main() {
  const date = LocalDate(2026, 10, 8);
  final now = DateTime(2026, 10, 9, 12);
  late LetterHealthDatabase source;
  late LetterHealthDatabase destination;
  late DriftRecordHubRepository facts;
  late DriftLocalBackupStore backup;
  late DriftLocalBackupStore target;
  setUp(() {
    source = LetterHealthDatabase(NativeDatabase.memory());
    destination = LetterHealthDatabase(NativeDatabase.memory());
    facts = DriftRecordHubRepository(source, clock: () => now);
    backup = DriftLocalBackupStore(source, clock: () => now);
    target = DriftLocalBackupStore(destination, clock: () => now);
  });
  tearDown(() async {
    await source.close();
    await destination.close();
  });

  Future<void> restore(LocalBackupSnapshot incoming) async {
    final plan = planLocalBackupImport(
      incoming: incoming,
      destination: await target.captureSnapshot(),
      policy: LocalBackupImportPolicy.replace,
    );
    await (await target.stage(plan)).commit();
  }

  test(
    'V-26 every typed source, zero, pins and dated note round trip in one snapshot',
    () async {
      final symptom =
          await DriftHealthRecordRepository(
            source,
            closeDatabase: false,
            clock: () => now,
          ).create(
            const HealthRecordDraft(
              symptom: SymptomType.cramps,
              severity: SymptomSeverity.notPresent,
              experiencedDate: date,
              provenance: HealthRecordProvenance.sameDay,
            ),
          );
      await facts.setPins(
        SymptomPins([SymptomType.cramps, SymptomType.anxiety]),
      );
      await facts.upsertImpact(
        DailyImpactDraft(
          experiencedDate: date,
          overall: 0,
          domains: {DailyImpactDomain.homeResponsibilities},
        ),
      );
      await facts.upsertBleeding(
        BleedingFactDraft(
          experiencedDate: date,
          flow: BleedingFlow.spotting,
          color: BleedingColor.pink,
        ),
      );
      await facts.upsertSleep(
        SleepDraft(
          experiencedDate: date,
          duration: RecordedDuration.bucket(DurationBucket.sleep7To9Hours),
          quality: SleepQuality.good,
        ),
      );
      await facts.upsertAppetite(
        AppetiteDraft(
          experiencedDate: date,
          appetite: AppetiteLevel.lessThanUsual,
          cravingScore: 0,
        ),
      );
      await facts.saveActivity(
        ActivityDraft(
          experiencedDate: date,
          type: ActivityType.intentionalRest,
          duration: RecordedDuration.exact(21),
        ),
      );
      await facts.saveEvent(
        ContextEventDraft(
          experiencedDate: date,
          type: ContextEventType.travelOrTimeZoneChange,
        ),
      );
      await facts.saveTemperature(
        TemperatureDraft(
          experiencedDate: date,
          enteredValue: 97.8,
          unit: TemperatureUnit.fahrenheit,
          method: TemperatureMethod.manualOral,
        ),
      );
      await DriftCaptureNoteStore(source, closeDatabase: false).save(
        CaptureNote(
          id: 'synthetic-note',
          text: 'Synthetic private note',
          source: CaptureSource.typed,
          createdAt: now.toUtc(),
          experiencedDate: date,
        ),
      );
      await restore(await backup.captureSnapshot());
      final loaded = await DriftRecordHubRepository(
        destination,
      ).getDateFacts(date);
      expect(loaded.impact!.value.overall, 0);
      expect(loaded.bleeding!.value.flow, BleedingFlow.spotting);
      expect(loaded.sleep!.value.duration!.exactMinutes, isNull);
      expect(
        loaded.sleep!.value.duration!.bucket,
        DurationBucket.sleep7To9Hours,
      );
      expect(loaded.activities.single.value.duration!.exactMinutes, 21);
      expect(loaded.temperatures.single.value.enteredValue, 97.8);
      expect(
        (await DriftRecordHubRepository(destination).getPins())!.symptoms,
        [SymptomType.cramps, SymptomType.anxiety],
      );
      final restoredSymptom = (await DriftHealthRecordRepository(
        destination,
        closeDatabase: false,
      ).getAll()).single;
      expect(restoredSymptom.id, symptom.id);
      expect(restoredSymptom.recordedAt, symptom.recordedAt);
      expect(restoredSymptom.provenance, HealthRecordProvenance.laterRecall);
      expect(
        (await DriftCaptureNoteStore(
          destination,
          closeDatabase: false,
        ).getAll()).single.experiencedDate,
        date,
      );
    },
  );

  test(
    'V-26 episode versions, bundle/checkback and programme config/pauses round-trip exactly',
    () async {
      final interventions = DriftRecordInterventionsRepository(
        source,
        clock: () => now,
      );
      final episode = await interventions.createEpisode(
        ProductEpisodeDraft(
          startDate: date.addDays(-5),
          details: ProductDetails(
            family: ProductFamily.medication,
            exactName: 'Fictional exact name',
            dose: '10',
            unit: DoseUnit.mg,
            route: ProductRoute.oral,
          ),
        ),
      );
      final use = await interventions.saveUse(
        ProductUseDraft(
          experiencedDate: date,
          episodeId: episode.id,
          status: ProductUseStatus.taken,
        ),
      );
      await interventions.reviseEpisode(
        episode.id,
        ProductDetails(
          family: ProductFamily.medication,
          exactName: 'Fictional exact name',
          dose: '20',
          unit: DoseUnit.mg,
          route: ProductRoute.oral,
        ),
        effectiveFrom: date,
      );
      final action = await interventions.saveAction(
        TriedActionDraft(
          experiencedDate: date,
          actions: [
            TriedActionSelection(TriedActionKind.meditation),
            TriedActionSelection(TriedActionKind.heat),
          ],
          bundle: true,
          status: TriedActionStatus.completed,
          target: 'Fictional target',
          source: TriedActionSource.outsideApp,
        ),
      );
      await interventions.saveCheckback(
        ActionCheckbackDraft(
          experiencedDate: date,
          actionId: action.id,
          outcome: ActionOutcome.mixed,
          targetDegree: 0,
          unexpected: UnexpectedObservation.notSure,
          reflection: 'Synthetic reflection',
        ),
      );
      final programmes = DriftRecordProgrammeRepository(
        source,
        clock: () => now,
      );
      final programme = await programmes.enroll(
        startDate: date.addDays(-10),
        symptoms: [SymptomType.cramps],
      );
      await programmes.pause(programme.id, date: date.addDays(-4));
      await programmes.resume(programme.id, date: date.addDays(-2));
      await programmes.updateConfig(
        programme.id,
        effectiveDate: LocalDate.fromDateTime(now),
        symptoms: [SymptomType.cramps, SymptomType.anxiety],
      );
      final snapshot = await backup.captureSnapshot();
      await restore(snapshot);
      final restored = await target.captureSnapshot();
      for (final collection in snapshot.collections) {
        final other = restored.collections.singleWhere(
          (c) => c.name == collection.name,
        );
        expect(other.schemaVersion, collection.schemaVersion);
        expect(
          [
            for (final row in other.records) [row.id, row.updatedAt, row.data],
          ],
          [
            for (final row in collection.records)
              [row.id, row.updatedAt, row.data],
          ],
          reason: collection.name,
        );
      }
      final targetInterventions = DriftRecordInterventionsRepository(
        destination,
      );
      expect(
        (await targetInterventions.getUses()).single.versionId,
        use.versionId,
      );
      expect(
        (await targetInterventions.getEpisodes()).single.versions,
        hasLength(2),
      );
      expect((await targetInterventions.getActions()).single.id, action.id);
      expect(
        (await targetInterventions.getCheckbacks()).single.value.outcome,
        ActionOutcome.mixed,
      );
      expect(
        (await DriftRecordProgrammeRepository(
          destination,
        ).getCurrent())!.configurations,
        hasLength(2),
      );
    },
  );

  test(
    'V-26 orphan typed references reject atomically before replacing existing facts',
    () async {
      final interventions = DriftRecordInterventionsRepository(
        source,
        clock: () => now,
      );
      final episode = await interventions.createEpisode(
        ProductEpisodeDraft(
          startDate: date,
          details: ProductDetails(
            family: ProductFamily.supplement,
            exactName: 'Synthetic supplement',
          ),
        ),
      );
      await interventions.saveUse(
        ProductUseDraft(
          experiencedDate: date,
          episodeId: episode.id,
          status: ProductUseStatus.taken,
        ),
      );
      final snapshot = await backup.captureSnapshot();
      final missingParent = LocalBackupSnapshot(
        createdAt: snapshot.createdAt,
        collections: [
          for (final c in snapshot.collections)
            LocalBackupCollection(
              name: c.name,
              schemaVersion: c.schemaVersion,
              records: c.name == 'record_product_episodes' ? [] : c.records,
            ),
        ],
      );
      await DriftRecordHubRepository(
        destination,
        clock: () => now,
      ).upsertImpact(DailyImpactDraft(experiencedDate: date, overall: 2));
      await expectLater(
        restore(missingParent),
        throwsA(isA<LocalBackupException>()),
      );
      expect(
        (await DriftRecordHubRepository(
          destination,
        ).getDateFacts(date)).impact!.value.overall,
        2,
      );
      expect(
        await DriftRecordInterventionsRepository(destination).getUses(),
        isEmpty,
      );
    },
  );

  test(
    'V-26 unknown/newer schemas reject before changing destination',
    () async {
      await facts.upsertImpact(
        DailyImpactDraft(experiencedDate: date, overall: 4),
      );
      final snapshot = await backup.captureSnapshot();
      final newer = LocalBackupSnapshot(
        createdAt: snapshot.createdAt,
        collections: [
          for (final c in snapshot.collections)
            LocalBackupCollection(
              name: c.name,
              schemaVersion: c.name == 'record_hub_impact'
                  ? 99
                  : c.schemaVersion,
              records: c.records,
            ),
        ],
      );
      await expectLater(restore(newer), throwsA(isA<LocalBackupException>()));
      expect(
        (await DriftRecordHubRepository(
          destination,
        ).getDateFacts(date)).isEmpty,
        isTrue,
      );
    },
  );

  test(
    'V-24 undeclared typed backup fields and invalid scores reject before writes',
    () async {
      await facts.upsertImpact(
        DailyImpactDraft(experiencedDate: date, overall: 0),
      );
      final snapshot = await backup.captureSnapshot();
      final bad = LocalBackupSnapshot(
        createdAt: snapshot.createdAt,
        collections: [
          for (final c in snapshot.collections)
            LocalBackupCollection(
              name: c.name,
              schemaVersion: c.schemaVersion,
              records: [
                for (final r in c.records)
                  LocalBackupRecord(
                    id: r.id,
                    updatedAt: r.updatedAt,
                    data: c.name == 'record_hub_impact'
                        ? {
                            ...r.data,
                            'overall': 9,
                            'undeclaredField': 'synthetic',
                          }
                        : r.data,
                  ),
              ],
            ),
        ],
      );
      await expectLater(restore(bad), throwsA(isA<LocalBackupException>()));
      expect(
        (await DriftRecordHubRepository(
          destination,
        ).getDateFacts(date)).isEmpty,
        isTrue,
      );
    },
  );
}
