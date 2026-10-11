import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/bleeding_flow.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/record_hub/data/drift_record_hub_repository.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';

void main() {
  const date = LocalDate(2026, 10, 8);
  late LetterHealthDatabase database;
  late DriftRecordHubRepository repository;
  late DateTime now;
  late String zone;
  var nextId = 0;

  setUp(() {
    database = LetterHealthDatabase(NativeDatabase.memory());
    now = DateTime(2026, 10, 8, 10);
    zone = 'Synthetic/Original';
    nextId = 0;
    repository = DriftRecordHubRepository(
      database,
      clock: () => now,
      zoneProvider: () => zone,
      idGenerator: () => 'synthetic-record-${nextId++}',
    );
  });
  tearDown(() => database.close());

  test(
    'zero upserts one daily impact, unchanged past save is read-only',
    () async {
      final first = await repository.upsertImpact(
        DailyImpactDraft(experiencedDate: date, overall: 0),
      );
      expect(first.metadata.provenance, HealthRecordProvenance.sameDay);
      now = DateTime(2026, 10, 9, 12);
      final unchanged = await repository.upsertImpact(
        DailyImpactDraft(experiencedDate: date, overall: 0),
      );
      expect(unchanged.id, first.id);
      expect(unchanged.metadata.updatedAt, first.metadata.updatedAt);
      expect(unchanged.metadata.provenance, HealthRecordProvenance.sameDay);
      expect(
        (await database.select(database.recordHubImpactRows).get()).length,
        1,
      );
      zone = 'Synthetic/Changed';
      final updated = await repository.upsertImpact(
        DailyImpactDraft(experiencedDate: date, overall: 3),
      );
      expect(updated.id, first.id);
      expect(updated.metadata.recordedAt, first.metadata.recordedAt);
      expect(
        updated.metadata.originalProvenance,
        HealthRecordProvenance.sameDay,
      );
      expect(updated.metadata.provenance, HealthRecordProvenance.laterRecall);
      expect(updated.metadata.originalWriteZoneId, 'Synthetic/Original');
      expect(updated.metadata.writeZoneId, 'Synthetic/Changed');
      await repository.clearImpact(date);
      expect((await repository.getDateFacts(date)).impact, isNull);
    },
  );

  test(
    'future write rechecks the save clock without partially persisting',
    () async {
      final future = DailyImpactDraft(
        experiencedDate: date.addDays(1),
        overall: 2,
      );
      expect(
        () => repository.upsertImpact(future),
        throwsA(
          isA<RecordHubException>().having(
            (error) => error.failure,
            'failure',
            RecordHubFailure.futureDate,
          ),
        ),
      );
      expect(await repository.getAllFacts(), isEmpty);
      await repository.upsertImpact(
        DailyImpactDraft(experiencedDate: date, overall: 2),
      );
      now = DateTime(2026, 10, 7, 23);
      expect(
        () => repository.upsertImpact(
          DailyImpactDraft(experiencedDate: date, overall: 2),
        ),
        throwsA(
          isA<RecordHubException>().having(
            (error) => error.failure,
            'failure',
            RecordHubFailure.futureDate,
          ),
        ),
      );
      expect((await repository.getDateFacts(date)).impact!.value.overall, 2);
    },
  );

  test('standalone spotting and explicit none create no period', () async {
    final first = await repository.upsertBleeding(
      BleedingFactDraft(
        experiencedDate: date,
        flow: BleedingFlow.spotting,
        color: BleedingColor.brown,
        clots: ClotObservation.notSure,
      ),
    );
    expect((await database.select(database.periodRows).get()), isEmpty);
    expect(
      (await repository.getDateFacts(date)).bleeding!.value.periodId,
      isNull,
    );
    final none = await repository.upsertBleeding(
      BleedingFactDraft(experiencedDate: date, flow: null),
    );
    expect(none.id, first.id);
    expect(
      (await repository.getDateFacts(date)).bleeding!.value.noBleeding,
      isTrue,
    );
    await repository.clearBleeding(date);
    expect((await repository.getDateFacts(date)).bleeding, isNull);
  });

  test(
    'pins persist exact user order and never modify symptom records',
    () async {
      expect(await repository.getPins(), isNull);
      await repository.setPins(
        SymptomPins([SymptomType.anxiety, SymptomType.cramps]),
      );
      expect((await repository.getPins())!.symptoms, [
        SymptomType.anxiety,
        SymptomType.cramps,
      ]);
      await repository.setPins(
        SymptomPins([
          SymptomType.fatigue,
          SymptomType.cramps,
          SymptomType.anxiety,
        ]),
      );
      expect((await repository.getPins())!.symptoms, [
        SymptomType.fatigue,
        SymptomType.cramps,
        SymptomType.anxiety,
      ]);
      expect(await database.select(database.healthRecordRows).get(), isEmpty);
    },
  );

  test(
    'typed context round trips missing fields, buckets and separate events',
    () async {
      await repository.upsertSleep(
        SleepDraft(
          experiencedDate: date,
          duration: RecordedDuration.bucket(DurationBucket.sleep5To7Hours),
          quality: SleepQuality.veryPoor,
          signals: {SleepSignal.wakingDuringNight},
        ),
      );
      await repository.upsertAppetite(
        AppetiteDraft(experiencedDate: date, cravingScore: 0),
      );
      final first = await repository.saveActivity(
        ActivityDraft(
          experiencedDate: date,
          type: ActivityType.walking,
          duration: RecordedDuration.bucket(
            DurationBucket.activity10To20Minutes,
          ),
        ),
      );
      final second = await repository.saveActivity(
        ActivityDraft(
          experiencedDate: date,
          type: ActivityType.intentionalRest,
        ),
      );
      await repository.saveEvent(
        ContextEventDraft(
          experiencedDate: date,
          type: ContextEventType.other,
          customName: '  Synthetic event  ',
          note: 'Fictional context',
        ),
      );
      final snapshot = await repository.getDateFacts(date);
      expect(
        snapshot.sleep!.value.duration!.bucket,
        DurationBucket.sleep5To7Hours,
      );
      expect(snapshot.sleep!.value.duration!.exactMinutes, isNull);
      expect(snapshot.sleep!.value.quality, SleepQuality.veryPoor);
      expect(snapshot.appetite!.value.appetite, isNull);
      expect(snapshot.appetite!.value.cravingScore, 0);
      expect(snapshot.activities.map((value) => value.id).toSet(), {
        first.id,
        second.id,
      });
      expect(snapshot.events.single.value.customName, '  Synthetic event  ');
      final edited = await repository.saveActivity(
        ActivityDraft(
          experiencedDate: date,
          type: ActivityType.walking,
          duration: RecordedDuration.exact(12),
        ),
        id: first.id,
      );
      expect(edited.id, first.id);
      expect((await repository.getDateFacts(date)).activities.length, 2);
      await repository.deleteActivity(second.id);
      expect((await repository.getDateFacts(date)).activities.length, 1);
      expect((await repository.getAllFacts()).single.date, date);
    },
  );

  test(
    'manual BBT retains exact original data after repository recreation',
    () async {
      now = DateTime(2026, 10, 8, 10, 0, 0, 123, 456);
      final first = await repository.saveTemperature(
        TemperatureDraft(
          experiencedDate: date,
          enteredValue: 97.556,
          unit: TemperatureUnit.fahrenheit,
          method: TemperatureMethod.manualOther,
          measuredAt: LocalMeasurementTime(7, 5),
          flags: {TemperatureQualityFlag.poorSleep},
        ),
      );
      final reopenedRepository = DriftRecordHubRepository(
        database,
        clock: () => now,
      );
      final loaded = (await reopenedRepository.getDateFacts(
        date,
      )).temperatures.single;
      expect(loaded.id, first.id);
      expect(loaded.value.enteredValue, 97.556);
      expect(loaded.value.unit, TemperatureUnit.fahrenheit);
      expect(loaded.value.method, TemperatureMethod.manualOther);
      expect(loaded.value.measuredAt!.minute, 5);
      expect(loaded.value.flags, {TemperatureQualityFlag.poorSleep});
      expect(loaded.metadata.recordedAt, first.metadata.recordedAt);
      expect(loaded.metadata.recordedAt.microsecond, 0);
    },
  );

  test(
    'typed decoder rejects unknown timing and inconsistent duration fields',
    () async {
      await repository.upsertSleep(
        SleepDraft(
          experiencedDate: date,
          duration: RecordedDuration.bucket(DurationBucket.sleep5To7Hours),
        ),
      );
      final original =
          (await database.select(database.recordHubSleepRows).get()).single;
      expect(
        () => decodeRecordHubSleep(original.copyWith(vocabularyVersion: 2)),
        throwsA(isA<RecordHubException>()),
      );
      expect(
        () =>
            decodeRecordHubSleep(original.copyWith(provenance: 'unsupported')),
        throwsA(isA<RecordHubException>()),
      );
      expect(
        () => decodeRecordHubSleep(
          original.copyWith(exactMinutes: const Value(390)),
        ),
        throwsA(isA<RecordHubException>()),
      );
      expect(
        () => decodeRecordHubSleep(
          original.copyWith(durationLabel: const Value('6 h')),
        ),
        throwsA(isA<RecordHubException>()),
      );
      expect(
        () => decodeRecordHubSleep(
          original.copyWith(durationCatalogVersion: const Value(2)),
        ),
        throwsA(isA<RecordHubException>()),
      );
    },
  );
}
