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
}
