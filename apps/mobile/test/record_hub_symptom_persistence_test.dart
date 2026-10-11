import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/data/drift_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';

void main() {
  late LetterHealthDatabase database;
  late DriftHealthRecordRepository repository;
  late DateTime now;
  var counter = 0;
  setUp(() {
    now = DateTime(2026, 10, 8, 23, 59);
    database = LetterHealthDatabase(NativeDatabase.memory());
    repository = DriftHealthRecordRepository(database, closeDatabase: false,
      clock: () => now, idGenerator: () => 'synthetic-${counter++}');
  });
  tearDown(() => database.close());
  HealthRecordDraft draft(int score, {LocalDate date = const LocalDate(2026, 10, 8), SymptomType symptom = SymptomType.cramps}) =>
    HealthRecordDraft(symptom: symptom, severity: SymptomSeverity.fromScore(score), experiencedDate: date,
      // Repository must use its save clock, even if an old caller passes this.
      provenance: HealthRecordProvenance.sameDay);

  test('V-09 all 0–5 scores round trip; missing rows stay absent', () async {
    for (var score = 0; score <= 5; score++) {
      await repository.create(draft(score));
      expect((await repository.getAll()).single.severity.score, score);
    }
    expect((await repository.getAll()).single.symptom, SymptomType.cramps);
    expect((await repository.getAll()).where((r) => r.symptom == SymptomType.anxiety), isEmpty);
    expect(() => SymptomSeverity.fromScore(6), throwsFormatException);
  });

  test('V-20 unchanged history save is a no-op; past change recalls active value only', () async {
    final first = await repository.create(draft(2));
    now = DateTime(2026, 10, 9, 0, 1);
    final viewed = await repository.create(draft(2));
    expect(viewed.updatedAt, first.updatedAt);
    expect(viewed.provenance, HealthRecordProvenance.sameDay);
    final changed = await repository.create(draft(0));
    expect(changed.id, first.id);
    expect(changed.recordedAt, first.recordedAt);
    expect(changed.effectiveOriginalProvenance, HealthRecordProvenance.sameDay);
    expect(changed.provenance, HealthRecordProvenance.laterRecall);
    expect(changed.writeZoneName, first.writeZoneName);
    expect(changed.updatedAt, now.toUtc());
    final loaded = (await repository.getAll()).single;
    expect(loaded.effectiveOriginalProvenance, HealthRecordProvenance.sameDay);
    expect(loaded.writeZoneOffsetMinutes, first.writeZoneOffsetMinutes);
  });

  test('V-27 past saves at 00:01, 03:59 and 04:00 have no grace', () async {
    for (final (hour, minute) in [(0, 1), (3, 59), (4, 0)]) {
      now = DateTime(2026, 10, 9, hour, minute);
      final saved = await repository.create(draft(hour, symptom: SymptomType.values[hour]));
      expect(saved.provenance, HealthRecordProvenance.laterRecall);
    }
    final today = await repository.create(draft(1, date: const LocalDate(2026, 10, 9)));
    expect(today.provenance, HealthRecordProvenance.sameDay);
    await expectLater(repository.create(draft(1, date: const LocalDate(2026, 10, 10))),
      throwsA(isA<HealthRecordException>().having((e) => e.failure, 'failure', HealthRecordFailure.futureDate)));
  });

  test('V-10 concurrent daily upserts keep a stable source', () async {
    final saved = await Future.wait([repository.create(draft(1)), repository.create(draft(2)), repository.create(draft(3))]);
    expect(saved.map((r) => r.id).toSet(), hasLength(1));
    expect(await repository.getAll(), hasLength(1));
    expect((await repository.getAll()).single.severity.score, 3);
  });

  test('V-09 withdrawal and Undo restore exact source; newer change blocks Undo', () async {
    final first = await repository.create(draft(0));
    await repository.delete(first.id);
    final restored = await repository.restore(first);
    expect(restored.id, first.id);
    expect(restored.updatedAt, first.updatedAt);
    now = now.add(const Duration(minutes: 1));
    final second = await repository.create(draft(4));
    await repository.restore(first, expectedCurrent: second);
    expect((await repository.getAll()).single.updatedAt, first.updatedAt);
    final later = await repository.create(draft(5));
    await expectLater(repository.restore(first, expectedCurrent: second),
      throwsA(isA<HealthRecordException>().having((e) => e.failure, 'failure', HealthRecordFailure.undoConflict)));
    expect((await repository.getAll()).single.severity, later.severity);
  });

  test('source date collision fails without partial writes', () async {
    final first = await repository.create(draft(1));
    final second = await repository.create(draft(2, date: const LocalDate(2026, 10, 7)));
    await expectLater(repository.update(second.id, draft(3)),
      throwsA(isA<HealthRecordException>().having((e) => e.failure, 'failure', HealthRecordFailure.dateCollision)));
    expect(await repository.getAll(), hasLength(2));
    expect((await repository.getAll()).first.id, first.id);
  });
}
