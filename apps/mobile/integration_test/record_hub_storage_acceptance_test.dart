import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/cycle/domain/bleeding_flow.dart';
import 'package:letter_mobile/features/comfort_window/domain/comfort_reminder_preference.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_data/data/local_health_store_factory_native.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_import.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_models.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';
import 'package:letter_mobile/features/record_hub/domain/record_interventions.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'V-26 Build17 and Record Hub sources survive encrypted schema 18 reopen and atomic restore',
    (tester) async {
      final directory = await Directory(
        path.join((await getTemporaryDirectory()).path, 'record-hub-synthetic'),
      ).create(recursive: true);
      final file = File(
        path.join(
          directory.path,
          'record-hub-${DateTime.now().microsecondsSinceEpoch}.sqlite',
        ),
      );
      final restoredFile = File('${file.path}.restored');
      const key =
          '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
      final now = DateTime(2026, 10, 9, 12);
      final date = LocalDate.fromDateTime(now).addDays(-1);
      final store = createNativeLocalHealthStoreForDatabase(
        databaseFile: file,
        loadKey: () async => key,
        clock: () => now,
      );
      final symptom = await store.healthRecordRepository.create(
        HealthRecordDraft(
          symptom: SymptomType.cramps,
          severity: SymptomSeverity.notPresent,
          experiencedDate: date,
          provenance: HealthRecordProvenance.sameDay,
        ),
      );
      final facts = store.recordHubRepository!;
      await facts.setPins(
        SymptomPins([SymptomType.cramps, SymptomType.anxiety]),
      );
      await facts.upsertImpact(
        DailyImpactDraft(experiencedDate: date, overall: 0),
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
          duration: RecordedDuration.bucket(DurationBucket.sleep5To7Hours),
        ),
      );
      await facts.saveTemperature(
        TemperatureDraft(
          experiencedDate: date,
          enteredValue: 36.5,
          unit: TemperatureUnit.celsius,
          method: TemperatureMethod.manualOral,
        ),
      );
      await store.captureNoteStore.save(
        CaptureNote(
          id: 'synthetic-note',
          text: 'RECORD_HUB_SYNTHETIC_PRIVATE_NOTE',
          source: CaptureSource.typed,
          createdAt: now,
          experiencedDate: date,
          keepInComfortKit: true,
        ),
      );
      await store.comfortKitRepository.dontShowAgain(
        sourceId: 'quick-note:synthetic-note',
        updatedAt: now,
      );
      await store.comfortReminderPreferenceRepository.save(
        ComfortReminderPreference(enabled: false, leadDays: 1, updatedAt: now),
      );
      await facts.upsertAppetite(
        AppetiteDraft(
          experiencedDate: date,
          appetite: AppetiteLevel.moreThanUsual,
          cravingScore: 0,
        ),
      );
      await facts.saveActivity(
        ActivityDraft(
          experiencedDate: date,
          type: ActivityType.intentionalRest,
          duration: RecordedDuration.exact(20),
        ),
      );
      await facts.saveEvent(
        ContextEventDraft(
          experiencedDate: date,
          type: ContextEventType.travelOrTimeZoneChange,
        ),
      );
      final moment = await store.momentCheckInRepository.create(
        MomentCheckInState.steady,
        occurredAt: now,
      );
      final interventions = store.interventionsRepository!;
      final episode = await interventions.createEpisode(
        ProductEpisodeDraft(
          startDate: date.addDays(-2),
          details: ProductDetails(
            family: ProductFamily.medication,
            exactName: 'Fictional native product',
            dose: '10',
            unit: DoseUnit.mg,
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
          exactName: 'Fictional native product',
          dose: '20',
          unit: DoseUnit.mg,
        ),
        effectiveFrom: date,
      );
      TriedActionDraft completed() => TriedActionDraft(
        experiencedDate: LocalDate.fromDateTime(now),
        actions: [TriedActionSelection(TriedActionKind.breathing)],
        bundle: false,
        status: TriedActionStatus.completed,
        target: 'Cramps',
        source: TriedActionSource.inAppCare,
        completionToken: 'fictional-native-completion',
        completionOccurredAt: now,
      );
      final action = await interventions.saveAction(completed());
      expect((await interventions.saveAction(completed())).id, action.id);
      await interventions.saveCheckback(
        ActionCheckbackDraft(
          experiencedDate: LocalDate.fromDateTime(now),
          actionId: action.id,
          outcome: ActionOutcome.mixed,
          targetDegree: 0,
        ),
      );
      final programmes = store.programmeRepository!;
      final programme = await programmes.enroll(
        startDate: date.addDays(-5),
        symptoms: [SymptomType.cramps],
      );
      await programmes.pause(programme.id, date: date.addDays(-3));
      await programmes.resume(programme.id, date: date.addDays(-1));
      await programmes.updateConfig(
        programme.id,
        effectiveDate: LocalDate.fromDateTime(now),
        symptoms: [SymptomType.cramps, SymptomType.anxiety],
      );
      final snapshot = await store.localBackupStore!.captureSnapshot();
      await store.close();
      _expectSchema18(file, key);
      final bytes = await file.readAsBytes();
      expect(
        utf8.decode(bytes, allowMalformed: true),
        isNot(contains('RECORD_HUB_SYNTHETIC_PRIVATE_NOTE')),
      );
      expect(
        bytes.take(16).toList(),
        isNot(utf8.encode('SQLite format 3\u0000')),
      );
      final reopened = createNativeLocalHealthStoreForDatabase(
        databaseFile: file,
        loadKey: () async => key,
        clock: () => now,
      );
      final saved = (await reopened.healthRecordRepository.getAll()).single;
      expect(saved.id, symptom.id);
      expect(saved.recordedAt, symptom.recordedAt);
      expect(saved.provenance, HealthRecordProvenance.laterRecall);
      expect(saved.severity.score, 0);
      expect(
        (await reopened.recordHubRepository!.getDateFacts(
          date,
        )).sleep!.value.duration!.exactMinutes,
        isNull,
      );
      expect(
        (await reopened.captureNoteStore.getAll()).single.experiencedDate,
        date,
      );
      expect(
        (await reopened.captureNoteStore.getAll()).single.keepInComfortKit,
        isTrue,
      );
      expect(
        (await reopened.comfortKitRepository.getOverrides()).single.sourceId,
        'quick-note:synthetic-note',
      );
      expect(
        (await reopened.comfortReminderPreferenceRepository.load()).leadDays,
        1,
      );
      expect(
        (await reopened.comfortReminderPreferenceRepository.load()).enabled,
        isFalse,
      );
      expect(
        (await reopened.interventionsRepository!.getUses()).single.versionId,
        use.versionId,
      );
      expect(
        (await reopened.interventionsRepository!.getActions()).single.id,
        action.id,
      );
      expect(
        (await reopened.momentCheckInRepository.getAll())
            .single
            .experiencedDate,
        moment.experiencedDate,
      );
      expect(
        (await reopened.programmeRepository!.getCurrent())!.configurations,
        hasLength(2),
      );
      await reopened.close();
      final restored = createNativeLocalHealthStoreForDatabase(
        databaseFile: restoredFile,
        loadKey: () async => key,
        clock: () => now,
      );
      final target = restored.localBackupStore!;
      final plan = planLocalBackupImport(
        incoming: snapshot,
        destination: await target.captureSnapshot(),
        policy: LocalBackupImportPolicy.replace,
      );
      await (await target.stage(plan)).commit();
      final loaded = await restored.recordHubRepository!.getDateFacts(date);
      expect(loaded.impact!.value.overall, 0);
      expect(loaded.bleeding!.value.flow, BleedingFlow.spotting);
      expect(loaded.temperatures.single.value.enteredValue, 36.5);
      expect((await restored.recordHubRepository!.getPins())!.symptoms, [
        SymptomType.cramps,
        SymptomType.anxiety,
      ]);
      final restoredSnapshot = await target.captureSnapshot();
      for (final collection in snapshot.collections) {
        final actual = restoredSnapshot.collections.singleWhere(
          (candidate) => candidate.name == collection.name,
        );
        expect(
          [
            for (final record in actual.records)
              [record.id, record.updatedAt, record.data],
          ],
          [
            for (final record in collection.records)
              [record.id, record.updatedAt, record.data],
          ],
          reason: collection.name,
        );
      }
      expect(
        (await restored.interventionsRepository!.getCheckbacks())
            .single
            .value
            .outcome,
        ActionOutcome.mixed,
      );
      expect(
        (await restored.programmeRepository!.getCurrent())!.pauses,
        hasLength(1),
      );
      await restored.close();
      _expectSchema18(restoredFile, key);
      for (final base in [file.path, restoredFile.path]) {
        for (final suffix in ['', '-wal', '-shm']) {
          final temporary = File('$base$suffix');
          if (await temporary.exists()) await temporary.delete();
        }
      }
    },
  );

  testWidgets(
    'encrypted Build17 schema 12 upgrades without losing Kit or reminder choices',
    (tester) async {
      final directory = await getTemporaryDirectory();
      final file = File(
        path.join(
          directory.path,
          'build17-schema12-${DateTime.now().microsecondsSinceEpoch}.sqlite',
        ),
      );
      const key =
          '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
      final created = DateTime.utc(2026, 10, 8, 10).millisecondsSinceEpoch;
      final updated = DateTime.utc(2026, 10, 8, 11).millisecondsSinceEpoch;
      final raw = sqlite3.open(file.path);
      try {
        expect(raw.select('PRAGMA cipher;'), isNotEmpty);
        raw.execute("PRAGMA key = '$key';");
        raw.execute(
          'CREATE TABLE capture_note_rows (id TEXT NOT NULL PRIMARY KEY, content TEXT NOT NULL, source TEXT NOT NULL, created_at_millis INTEGER NOT NULL, updated_at_millis INTEGER NOT NULL DEFAULT 0, keep_in_comfort_kit INTEGER NOT NULL DEFAULT 0)',
        );
        raw.execute(
          'CREATE TABLE moment_check_in_rows (id TEXT NOT NULL PRIMARY KEY, state TEXT NOT NULL, occurred_at_millis INTEGER NOT NULL, created_at_millis INTEGER NOT NULL)',
        );
        raw.execute(
          'CREATE TABLE comfort_kit_override_rows (source_id TEXT NOT NULL PRIMARY KEY, action TEXT NOT NULL, source_version TEXT, updated_at_millis INTEGER NOT NULL)',
        );
        raw.execute(
          'CREATE TABLE comfort_reminder_preference_rows (id TEXT NOT NULL PRIMARY KEY, enabled INTEGER NOT NULL DEFAULT 0, lead_days INTEGER NOT NULL DEFAULT 2, hour INTEGER NOT NULL DEFAULT 9, minute INTEGER NOT NULL DEFAULT 0, updated_at_millis INTEGER NOT NULL)',
        );
        raw.execute('INSERT INTO capture_note_rows VALUES (?, ?, ?, ?, ?, ?)', [
          'build17-note',
          'BUILD17_SYNTHETIC_PRIVATE_NOTE',
          'typed',
          created,
          updated,
          1,
        ]);
        raw.execute('INSERT INTO moment_check_in_rows VALUES (?, ?, ?, ?)', [
          'build17-moment',
          'calm',
          created,
          created,
        ]);
        raw.execute(
          'INSERT INTO comfort_kit_override_rows VALUES (?, ?, ?, ?)',
          ['quick-note:build17-note', 'dontShowAgain', null, updated],
        );
        raw.execute(
          'INSERT INTO comfort_reminder_preference_rows VALUES (?, ?, ?, ?, ?, ?)',
          ['active', 0, 1, 9, 0, updated],
        );
        raw.userVersion = 12;
      } finally {
        raw.close();
      }
      final migrated = createNativeLocalHealthStoreForDatabase(
        databaseFile: file,
        loadKey: () async => key,
        clock: () => DateTime(2026, 10, 9, 12),
      );
      try {
        final note = (await migrated.captureNoteStore.getAll()).single;
        expect(note.id, 'build17-note');
        expect(note.text, 'BUILD17_SYNTHETIC_PRIVATE_NOTE');
        expect(note.keepInComfortKit, isTrue);
        expect(note.createdAt.millisecondsSinceEpoch, created);
        expect(note.updatedAt.millisecondsSinceEpoch, updated);
        expect(note.experiencedDate, isNull);
        expect(note.provenance, HealthRecordProvenance.timingUnknown);
        final moment = (await migrated.momentCheckInRepository.getAll()).single;
        expect(moment.id, 'build17-moment');
        expect(moment.experiencedDate, isNull);
        expect(moment.provenance, HealthRecordProvenance.timingUnknown);
        expect(
          (await migrated.comfortKitRepository.getOverrides()).single.sourceId,
          'quick-note:build17-note',
        );
        final reminder = await migrated.comfortReminderPreferenceRepository
            .load();
        expect(reminder.enabled, isFalse);
        expect(reminder.leadDays, 1);
        expect(reminder.updatedAt!.millisecondsSinceEpoch, updated);
        expect(
          (await migrated.recordHubRepository!.getDateFacts(
            const LocalDate(2026, 10, 8),
          )).impact,
          isNull,
        );
      } finally {
        await migrated.close();
      }
      _expectSchema18(file, key);
      expect(
        utf8.decode(await file.readAsBytes(), allowMalformed: true),
        isNot(contains('BUILD17_SYNTHETIC_PRIVATE_NOTE')),
      );
      for (final suffix in ['', '-wal', '-shm']) {
        final temporary = File('${file.path}$suffix');
        if (await temporary.exists()) await temporary.delete();
      }
    },
  );
}

void _expectSchema18(File file, String key) {
  final raw = sqlite3.open(file.path);
  try {
    raw.execute("PRAGMA key = '$key';");
    expect(raw.userVersion, 18);
  } finally {
    raw.close();
  }
}
