import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';

void main() {
  test(
    'in-memory repository creates, updates, sorts, and deletes records',
    () async {
      final repository = InMemoryHealthRecordRepository(
        clock: () => DateTime.utc(2026, 7, 28, 12),
        idGenerator: () => 'health-1',
      );
      final created = await repository.create(
        const HealthRecordDraft(
          symptom: SymptomType.lowMood,
          severity: SymptomSeverity.moderate,
          experiencedDate: LocalDate(2026, 7, 27),
          provenance: HealthRecordProvenance.laterRecall,
        ),
      );

      expect(created.userConfirmed, isTrue);
      expect(created.recordedAt, DateTime.utc(2026, 7, 28, 12));
      expect(created.provenance, HealthRecordProvenance.laterRecall);

      final updated = await repository.update(
        created.id,
        const HealthRecordDraft(
          symptom: SymptomType.lowMood,
          severity: SymptomSeverity.severe,
          functionalImpacts: {FunctionalImpact.relationships},
          experiencedDate: LocalDate(2026, 7, 28),
          provenance: HealthRecordProvenance.sameDay,
        ),
      );
      expect(updated.severity, SymptomSeverity.severe);
      expect(updated.recordedAt, created.recordedAt);
      expect(updated.updatedAt, DateTime.utc(2026, 7, 28, 12));
      expect((await repository.getAll()).single.experiencedDate.day, 28);

      await repository.delete(created.id);
      expect(await repository.getAll(), isEmpty);
    },
  );
}
