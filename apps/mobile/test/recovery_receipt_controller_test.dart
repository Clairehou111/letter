import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/recovery_receipt/application/recovery_receipt_controller.dart';
import 'package:letter_mobile/features/recovery_receipt/domain/recovery_receipt.dart';

CareRecord sampleCareRecord({String id = 'care-1', DateTime? occurredAt}) {
  final occurred = occurredAt ?? DateTime.utc(2026, 7, 28, 10);
  return CareRecord(
    id: id,
    mode: CareMode.explode,
    actionId: 'shatter',
    actionLabel: 'Put the force somewhere safe.',
    outcome: CareOutcome.better,
    occurredAt: occurred,
    createdAt: occurred,
    updatedAt: occurred,
    pinned: false,
  );
}

RecoveryReceiptController buildController({
  required CareRecord careRecord,
  required InMemoryHealthRecordRepository healthRepository,
  DateTime Function()? now,
}) {
  return RecoveryReceiptController(
    careMemoryRepository: InMemoryCareMemoryRepository(records: [careRecord]),
    healthRecordRepository: healthRepository,
    now: now,
  );
}

void main() {
  test('cannot start from an unsaved or missing Care record', () async {
    final controller = RecoveryReceiptController(
      careMemoryRepository: InMemoryCareMemoryRepository(),
      healthRecordRepository: InMemoryHealthRecordRepository(),
    );

    expect(
      () => controller.requirePersistedCareRecord('not-saved'),
      throwsA(
        isA<RecoveryReceiptException>().having(
          (error) => error.failure,
          'failure',
          RecoveryReceiptFailure.careRecordNotFound,
        ),
      ),
    );
  });

  test(
    'saves only confirmed primary and explicitly selected physical signals',
    () async {
      final care = sampleCareRecord();
      final health = InMemoryHealthRecordRepository(
        idGenerator: () => 'health-${DateTime.now().microsecondsSinceEpoch}',
      );
      final controller = buildController(
        careRecord: care,
        healthRepository: health,
        now: () => DateTime.utc(2026, 7, 28, 12),
      );

      final result = await controller.save(
        RecoveryReceiptDraft(
          careRecordId: care.id,
          symptom: SymptomType.irritability,
          severity: SymptomSeverity.severe,
          functionalImpacts: {FunctionalImpact.workOrSchool},
          additionalPhysicalSignals: {SymptomType.headache},
        ),
      );
      final records = await health.getAll();

      expect(result.careRecordId, care.id);
      expect(result.provenance, HealthRecordProvenance.sameDay);
      expect(records, hasLength(2));
      expect(
        records.map((record) => record.symptom),
        containsAll([SymptomType.irritability, SymptomType.headache]),
      );
      for (final record in records) {
        expect(record.severity, SymptomSeverity.severe);
        expect(record.userConfirmed, isTrue);
        expect(record.functionalImpacts, {FunctionalImpact.workOrSchool});
        expect(record.provenance, HealthRecordProvenance.sameDay);
      }
    },
  );

  test(
    'marks a receipt entered on a later local date as later recall',
    () async {
      final care = sampleCareRecord(
        occurredAt: DateTime.utc(2026, 7, 27, 23, 30),
      );
      final health = InMemoryHealthRecordRepository();
      final controller = buildController(
        careRecord: care,
        healthRepository: health,
        now: () => DateTime.utc(2026, 7, 28, 15),
      );

      final result = await controller.save(
        const RecoveryReceiptDraft(
          careRecordId: 'care-1',
          symptom: SymptomType.lowMood,
          severity: SymptomSeverity.mild,
        ),
      );

      expect(result.provenance, HealthRecordProvenance.laterRecall);
      expect(
        (await health.getAll()).single.provenance,
        HealthRecordProvenance.laterRecall,
      );
    },
  );

  test('rejects an additional signal that was not physical', () async {
    final care = sampleCareRecord();
    final health = InMemoryHealthRecordRepository();
    final controller = buildController(
      careRecord: care,
      healthRepository: health,
    );

    expect(
      () => controller.save(
        const RecoveryReceiptDraft(
          careRecordId: 'care-1',
          symptom: SymptomType.irritability,
          severity: SymptomSeverity.moderate,
          additionalPhysicalSignals: {SymptomType.anxiety},
        ),
      ),
      throwsA(
        isA<RecoveryReceiptException>().having(
          (error) => error.failure,
          'failure',
          RecoveryReceiptFailure.invalidAdditionalSignal,
        ),
      ),
    );
    expect(await health.getAll(), isEmpty);
  });
}
