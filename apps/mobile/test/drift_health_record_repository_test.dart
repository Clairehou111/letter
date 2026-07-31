import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/data/drift_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';

void main() {
  test(
    'Drift persists confirmed health record fields and supports deletion',
    () async {
      final database = LetterHealthDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftHealthRecordRepository(
        database,
        closeDatabase: false,
        clock: () => DateTime.utc(2026, 7, 28, 13),
        idGenerator: () => 'drift-health-1',
      );

      final created = await repository.create(
        const HealthRecordDraft(
          symptom: SymptomType.cramps,
          severity: SymptomSeverity.extreme,
          painRating: 9,
          painLocations: {PainLocation.lowerAbdomen, PainLocation.lowerBack},
          functionalImpacts: {
            FunctionalImpact.workOrSchool,
            FunctionalImpact.sleep,
          },
          experiencedDate: LocalDate(2026, 7, 27),
          provenance: HealthRecordProvenance.laterRecall,
        ),
      );

      final loaded = (await repository.getAll()).single;
      expect(loaded.id, created.id);
      expect(loaded.severity, SymptomSeverity.extreme);
      expect(loaded.painRating, 9);
      expect(loaded.painLocations, {
        PainLocation.lowerAbdomen,
        PainLocation.lowerBack,
      });
      expect(loaded.functionalImpacts, {
        FunctionalImpact.workOrSchool,
        FunctionalImpact.sleep,
      });
      expect(loaded.userConfirmed, isTrue);
      expect(loaded.provenance, HealthRecordProvenance.laterRecall);

      await repository.delete(created.id);
      expect(await repository.getAll(), isEmpty);
    },
  );

  test('Drift upserts the same symptom on the same experienced date', () async {
    final database = LetterHealthDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    var now = DateTime.utc(2026, 7, 28, 9);
    var nextId = 0;
    final repository = DriftHealthRecordRepository(
      database,
      closeDatabase: false,
      clock: () => now,
      idGenerator: () => 'drift-health-${nextId++}',
    );
    final first = await repository.create(
      const HealthRecordDraft(
        symptom: SymptomType.lowMood,
        severity: SymptomSeverity.mild,
        experiencedDate: LocalDate(2026, 7, 28),
        provenance: HealthRecordProvenance.sameDay,
      ),
    );

    now = DateTime.utc(2026, 7, 28, 19);
    final second = await repository.create(
      const HealthRecordDraft(
        symptom: SymptomType.lowMood,
        severity: SymptomSeverity.extreme,
        experiencedDate: LocalDate(2026, 7, 28),
        provenance: HealthRecordProvenance.sameDay,
      ),
    );

    expect(second.id, first.id);
    expect(second.recordedAt, first.recordedAt);
    expect(second.updatedAt, now);
    expect(second.severity, SymptomSeverity.extreme);
    expect(await repository.getAll(), hasLength(1));
  });
}
