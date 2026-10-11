import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/record_hub/data/drift_record_programme_repository.dart';
import 'package:letter_mobile/features/record_hub/domain/record_programme.dart';

void main() {
  late LetterHealthDatabase database;
  late DriftRecordProgrammeRepository repository;
  var now = DateTime(2026, 10, 1, 12);
  var nextId = 0;
  setUp(() {
    database = LetterHealthDatabase(NativeDatabase.memory());
    now = DateTime(2026, 10, 1, 12);
    nextId = 0;
    repository = DriftRecordProgrammeRepository(
      database,
      clock: () => now,
      idGenerator: () => 'synthetic-programme-${nextId++}',
    );
  });
  tearDown(() => database.close());

  test(
    'enrollment is optional configuration and creates no symptom or impact',
    () async {
      final programme = await repository.enroll(
        startDate: const LocalDate(2026, 10, 1),
        symptoms: [SymptomType.cramps],
      );
      expect(programme.configurations.single.symptomIds, ['cramps']);
      expect(programme.configurations.single.dailyImpactRequired, isTrue);
      expect((await database.select(database.healthRecordRows).get()), isEmpty);
      expect(
        (await database.select(database.recordHubImpactRows).get()),
        isEmpty,
      );
      expect((await repository.getCurrent())!.id, programme.id);
      await expectLater(
        repository.enroll(
          startDate: const LocalDate(2026, 10, 1),
          symptoms: [SymptomType.anxiety],
        ),
        throwsA(
          isA<RecordProgrammeException>().having(
            (error) => error.failure,
            'failure',
            RecordProgrammeFailure.alreadyCurrent,
          ),
        ),
      );
    },
  );

  test(
    'read-only decoder validates source closure, configuration IDs and pause order',
    () async {
      final programme = await repository.enroll(
        startDate: const LocalDate(2026, 10, 1),
        symptoms: [SymptomType.cramps],
      );
      final row =
          (await database.select(database.recordProgrammeRows).get()).single;
      final configs = await database
          .select(database.recordProgrammeConfigRows)
          .get();
      expect(decodeRecordProgramme(row, configs, []).id, programme.id);
      expect(
        () => decodeRecordProgramme(row, [
          configs.single.copyWith(symptomIds: 'unknownCanonicalId'),
        ], []),
        throwsA(isA<RecordProgrammeException>()),
      );
      expect(
        () => decodeRecordProgramme(row, [
          configs.single.copyWith(programmeId: 'another-programme'),
        ], []),
        throwsA(isA<RecordProgrammeException>()),
      );
      await repository.pause(programme.id, date: const LocalDate(2026, 10, 1));
      final pauses = await database
          .select(database.recordProgrammePauseRows)
          .get();
      expect(
        () => decodeRecordProgramme(row, configs, [
          pauses.single.copyWith(sequenceNumber: 2),
        ]),
        throwsA(isA<RecordProgrammeException>()),
      );
    },
  );

  test(
    'dated field versions leave historical denominator unchanged and reject backdating',
    () async {
      final programme = await repository.enroll(
        startDate: const LocalDate(2026, 10, 1),
        symptoms: [SymptomType.cramps],
      );
      now = DateTime(2026, 10, 5);
      final updated = await repository.updateConfig(
        programme.id,
        effectiveDate: const LocalDate(2026, 10, 5),
        symptoms: [SymptomType.cramps, SymptomType.anxiety],
      );
      expect(updated.configOn(const LocalDate(2026, 10, 4))!.symptoms, [
        SymptomType.cramps,
      ]);
      expect(updated.configOn(const LocalDate(2026, 10, 5))!.symptoms, [
        SymptomType.cramps,
        SymptomType.anxiety,
      ]);
      await repository.updateConfig(
        programme.id,
        effectiveDate: const LocalDate(2026, 10, 5),
        symptoms: [SymptomType.cramps, SymptomType.anxiety],
      );
      expect((await repository.getCurrent())!.configurations.length, 2);
      await expectLater(
        repository.updateConfig(
          programme.id,
          effectiveDate: const LocalDate(2026, 10, 4),
          symptoms: [SymptomType.anxiety],
        ),
        throwsA(
          isA<RecordProgrammeException>().having(
            (error) => error.failure,
            'failure',
            RecordProgrammeFailure.historicalConfigChange,
          ),
        ),
      );
    },
  );

  test(
    'pause/resume dates are retained, resume expects fields that day, ended history bounded',
    () async {
      final programme = await repository.enroll(
        startDate: const LocalDate(2026, 10, 1),
        symptoms: [SymptomType.cramps],
      );
      now = DateTime(2026, 10, 3);
      await repository.pause(programme.id, date: const LocalDate(2026, 10, 2));
      final resumed = await repository.resume(
        programme.id,
        date: const LocalDate(2026, 10, 3),
      );
      expect(resumed.expectedSymptomsOn(const LocalDate(2026, 10, 2)), isEmpty);
      expect(resumed.expectedSymptomsOn(const LocalDate(2026, 10, 3)), [
        SymptomType.cramps,
      ]);
      await repository.pause(programme.id, date: const LocalDate(2026, 10, 3));
      await repository.resume(programme.id, date: const LocalDate(2026, 10, 3));
      final paused = await repository.pause(
        programme.id,
        date: const LocalDate(2026, 10, 3),
      );
      expect(paused.pauses.length, 3);
      expect(paused.isPaused, isTrue);
      final ended = await repository.end(
        programme.id,
        date: const LocalDate(2026, 10, 3),
      );
      expect(await repository.getCurrent(), isNull);
      expect(ended.includes(const LocalDate(2026, 10, 4)), isFalse);
      expect((await repository.getAll()).single.pauses.length, 3);
      await expectLater(
        repository.resume(programme.id, date: const LocalDate(2026, 10, 3)),
        throwsA(isA<RecordProgrammeException>()),
      );
    },
  );

  test(
    'future and invalid selections roll back; clock rollback revalidates each mutation',
    () async {
      await expectLater(
        repository.enroll(
          startDate: const LocalDate(2026, 10, 2),
          symptoms: [SymptomType.cramps],
        ),
        throwsA(isA<RecordProgrammeException>()),
      );
      await expectLater(
        repository.enroll(
          startDate: const LocalDate(2026, 10, 1),
          symptoms: [SymptomType.concentration],
        ),
        throwsA(isA<RecordProgrammeException>()),
      );
      expect(await repository.getAll(), isEmpty);
      final programme = await repository.enroll(
        startDate: const LocalDate(2026, 10, 1),
        symptoms: [SymptomType.cramps],
      );
      now = DateTime(2026, 9, 30, 23);
      await expectLater(
        repository.pause(programme.id, date: const LocalDate(2026, 10, 1)),
        throwsA(
          isA<RecordProgrammeException>().having(
            (error) => error.failure,
            'failure',
            RecordProgrammeFailure.futureDate,
          ),
        ),
      );
      expect((await repository.getCurrent())!.pauses, isEmpty);
    },
  );
}
