import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/record_hub/data/drift_record_interventions_repository.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';
import 'package:letter_mobile/features/record_hub/domain/record_interventions.dart';

void main() {
  const today = LocalDate(2026, 10, 8);
  late LetterHealthDatabase database;
  late DriftRecordInterventionsRepository repository;
  late DateTime now;
  var nextId = 0;
  setUp(() {
    database = LetterHealthDatabase(NativeDatabase.memory());
    now = DateTime(2026, 10, 8, 12);
    nextId = 0;
    repository = DriftRecordInterventionsRepository(
      database,
      clock: () => now,
      zoneProvider: () => 'Synthetic/Zone',
      idGenerator: () => 'fictional-${nextId++}',
    );
  });
  tearDown(() => database.close());
  ProductDetails details(String dose) => ProductDetails(
    family: ProductFamily.medication,
    exactName: '  Fictional medicine  ',
    dose: dose,
    unit: DoseUnit.mg,
    route: ProductRoute.oral,
  );
  TriedActionDraft action({
    bool inApp = false,
    LocalDate date = today,
    String? target = 'Fictional target',
  }) => TriedActionDraft(
    experiencedDate: date,
    actions: [
      TriedActionSelection(TriedActionKind.meditation),
      TriedActionSelection(TriedActionKind.heat),
    ],
    bundle: true,
    status: TriedActionStatus.completed,
    target: target,
    source: inApp ? TriedActionSource.inAppCare : TriedActionSource.outsideApp,
    completionToken: inApp ? 'fictional-completion' : null,
    completionOccurredAt: inApp ? DateTime(2026, 10, 8, 12) : null,
  );

  test(
    'episode creation records no use, stopped episode accepts only eligible history',
    () async {
      final episode = await repository.createEpisode(
        ProductEpisodeDraft(
          startDate: today.addDays(-5),
          details: details('10'),
        ),
      );
      expect(await repository.getUses(), isEmpty);
      await repository.stopEpisode(episode.id, today.addDays(-2));
      final use = await repository.saveUse(
        ProductUseDraft(
          experiencedDate: today.addDays(-3),
          episodeId: episode.id,
          status: ProductUseStatus.taken,
        ),
      );
      expect(use.metadata.provenance, HealthRecordProvenance.laterRecall);
      expect(
        () => repository.saveUse(
          ProductUseDraft(
            experiencedDate: today,
            episodeId: episode.id,
            status: ProductUseStatus.taken,
          ),
        ),
        throwsA(isA<RecordHubException>()),
      );
      expect((await repository.getUses()).length, 1);
    },
  );
  test(
    'dated dose revisions preserve exact previous saved use version',
    () async {
      final episode = await repository.createEpisode(
        ProductEpisodeDraft(
          startDate: today.addDays(-5),
          details: details('10'),
        ),
      );
      final old = await repository.saveUse(
        ProductUseDraft(
          experiencedDate: today,
          episodeId: episode.id,
          status: ProductUseStatus.taken,
        ),
      );
      final revised = await repository.reviseEpisode(
        episode.id,
        details('20'),
        effectiveFrom: today.addDays(-1),
      );
      expect(revised.versions.map((version) => version.details.dose), [
        '10',
        '20',
      ]);
      expect((await repository.getUses()).single.versionId, old.versionId);
      final edited = await repository.saveUse(
        ProductUseDraft(
          experiencedDate: today,
          episodeId: episode.id,
          status: ProductUseStatus.skipped,
        ),
      );
      expect(edited.id, old.id);
      expect(edited.versionId, old.versionId);
      final distinct = await repository.saveUse(
        ProductUseDraft(
          experiencedDate: today,
          episodeId: episode.id,
          status: ProductUseStatus.asNeeded,
        ),
        dailyShortcut: false,
      );
      expect(distinct.versionId, revised.versions.last.id);
      expect((await repository.getUses()).length, 2);
    },
  );
  test(
    'archive preserves versions and use sources, and prevents new use',
    () async {
      final episode = await repository.createEpisode(
        ProductEpisodeDraft(startDate: today, details: details('10')),
      );
      final use = await repository.saveUse(
        ProductUseDraft(
          experiencedDate: today,
          episodeId: episode.id,
          status: ProductUseStatus.taken,
        ),
      );
      await repository.archiveEpisode(episode.id);
      expect(await repository.getEpisodes(), isEmpty);
      expect(
        (await repository.getEpisodes(
          includeArchived: true,
        )).single.versions.length,
        1,
      );
      expect((await repository.getUses()).single.id, use.id);
      expect(
        () => repository.saveUse(
          ProductUseDraft(
            experiencedDate: today,
            episodeId: episode.id,
            status: ProductUseStatus.taken,
          ),
          dailyShortcut: false,
        ),
        throwsA(isA<RecordHubException>()),
      );
    },
  );
  test(
    'same completion token is idempotent while manual repeat is distinct',
    () async {
      final completed = await repository.saveAction(action(inApp: true));
      final retry = await repository.saveAction(action(inApp: true));
      expect(retry.id, completed.id);
      expect((await repository.getActions()).length, 1);
      await repository.saveAction(action());
      await repository.saveAction(action());
      expect((await repository.getActions()).length, 3);
      expect(
        () =>
            repository.saveAction(action(inApp: true, date: today.addDays(-1))),
        throwsA(isA<RecordHubException>()),
      );
    },
  );
  test(
    'one checkback belongs to entire bundle; skip writes nothing; corrections retain identity',
    () async {
      final completed = await repository.saveAction(
        action(date: today.addDays(-1)),
      );
      expect(await repository.getCheckbacks(), isEmpty);
      final first = await repository.saveCheckback(
        ActionCheckbackDraft(
          experiencedDate: today,
          actionId: completed.id,
          outcome: ActionOutcome.mixed,
          targetDegree: 0,
          unexpected: UnexpectedObservation.notSure,
          reflection: 'Fictional reflection',
        ),
      );
      now = DateTime(2026, 10, 9, 12);
      final corrected = await repository.saveCheckback(
        ActionCheckbackDraft(
          experiencedDate: today,
          actionId: completed.id,
          outcome: ActionOutcome.worse,
        ),
      );
      expect(corrected.id, first.id);
      expect(corrected.metadata.recordedAt, first.metadata.recordedAt);
      expect(
        corrected.metadata.originalProvenance,
        HealthRecordProvenance.sameDay,
      );
      expect(corrected.metadata.provenance, HealthRecordProvenance.laterRecall);
      expect((await repository.getCheckbacks()).length, 1);
      await repository.deleteAction(completed.id);
      expect(await repository.getCheckbacks(), isEmpty);
      expect(
        await database.select(database.recordTriedActionItemRows).get(),
        isEmpty,
      );
    },
  );
  test(
    'future episode/action writes fail atomically; absent target degree stays absent',
    () async {
      expect(
        () => repository.createEpisode(
          ProductEpisodeDraft(
            startDate: today.addDays(1),
            details: details('10'),
          ),
        ),
        throwsA(isA<RecordHubException>()),
      );
      expect(await repository.getEpisodes(), isEmpty);
      expect(
        () => repository.saveAction(action(date: today.addDays(1))),
        throwsA(isA<RecordHubException>()),
      );
      final unspecified = await repository.saveAction(action(target: null));
      expect(
        () => repository.saveCheckback(
          ActionCheckbackDraft(
            experiencedDate: today,
            actionId: unspecified.id,
            outcome: ActionOutcome.better,
            targetDegree: 2,
          ),
        ),
        throwsA(isA<RecordHubException>()),
      );
      expect(await repository.getCheckbacks(), isEmpty);
    },
  );
  test(
    'same-day dose changes preserve earlier uses and shortened-stop history stays correctable',
    () async {
      final episode = await repository.createEpisode(
        ProductEpisodeDraft(
          startDate: today.addDays(-3),
          details: details('10'),
        ),
      );
      final first = await repository.saveUse(
        ProductUseDraft(
          experiencedDate: today,
          episodeId: episode.id,
          status: ProductUseStatus.taken,
        ),
      );
      final changed = await repository.reviseEpisode(
        episode.id,
        details('20'),
        effectiveFrom: today,
      );
      final changedAgain = await repository.reviseEpisode(
        episode.id,
        details('30'),
        effectiveFrom: today,
      );
      expect(changedAgain.versions.map((version) => version.versionNumber), [
        1,
        2,
        3,
      ]);
      expect((await repository.getUses()).single.versionId, first.versionId);
      final unchanged = await repository.reviseEpisode(
        episode.id,
        details('30'),
        effectiveFrom: today,
      );
      expect(unchanged.versions.length, 3);
      expect(unchanged.updatedAt, changedAgain.updatedAt);
      expect(
        changed.versions[1].effectiveFrom,
        changedAgain.versions[2].effectiveFrom,
      );
      final separate = await repository.createEpisode(
        ProductEpisodeDraft(
          startDate: today.addDays(-3),
          details: details('5'),
        ),
      );
      final historical = await repository.saveUse(
        ProductUseDraft(
          experiencedDate: today,
          episodeId: separate.id,
          status: ProductUseStatus.taken,
        ),
      );
      await repository.stopEpisode(separate.id, today.addDays(-1));
      final corrected = await repository.saveUse(
        ProductUseDraft(
          experiencedDate: today,
          episodeId: separate.id,
          status: ProductUseStatus.skipped,
        ),
        id: historical.id,
      );
      expect(corrected.id, historical.id);
      expect(corrected.versionId, historical.versionId);
      expect(
        () => repository.saveUse(
          ProductUseDraft(
            experiencedDate: today,
            episodeId: separate.id,
            status: ProductUseStatus.taken,
          ),
          dailyShortcut: false,
        ),
        throwsA(isA<RecordHubException>()),
      );
    },
  );
  test(
    'trusted captured completion retries after midnight without changing its experienced day',
    () async {
      now = DateTime(2026, 10, 10, 12);
      final captured = DateTime.utc(2026, 10, 8, 23, 30);
      final draft = TriedActionDraft(
        experiencedDate: today.addDays(1),
        actions: [
          TriedActionSelection(
            TriedActionKind.other,
            customName: 'Fictional native scene',
          ),
        ],
        bundle: false,
        status: TriedActionStatus.completed,
        source: TriedActionSource.inAppCare,
        completionToken: 'synthetic-midnight-token',
        careSourceId: 'synthetic-scene',
        completionOccurredAt: captured,
        completionUtcOffsetMinutes: 540,
      );
      final first = await repository.saveAction(draft);
      expect(first.metadata.provenance, HealthRecordProvenance.laterRecall);
      expect(
        first.metadata.originalProvenance,
        HealthRecordProvenance.laterRecall,
      );
      final retryRepository = DriftRecordInterventionsRepository(
        database,
        clock: () => DateTime(2026, 10, 11, 12),
        zoneProvider: () => 'Synthetic/Travel',
      );
      final retried = await retryRepository.saveAction(draft);
      expect(retried.id, first.id);
      expect(retried.experiencedDate, today.addDays(1));
      expect(retried.metadata.recordedAt, first.metadata.recordedAt);
      expect(retried.metadata.updatedAt, first.metadata.updatedAt);
      expect(
        retried.value.completionOccurredAt!.isAtSameMomentAs(captured),
        isTrue,
      );
      expect(retried.value.completionUtcOffsetMinutes, 540);
      expect((await repository.getActions()).length, 1);
    },
  );
}
