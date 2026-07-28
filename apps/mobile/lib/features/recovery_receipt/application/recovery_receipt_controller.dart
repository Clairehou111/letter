// The public constructor keeps repository dependencies named for callers while
// retaining private fields inside the controller.
// ignore_for_file: prefer_initializing_formals

import 'dart:math';

import '../../care/domain/care_memory.dart';
import '../../care/domain/care_memory_repository.dart';
import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';
import '../../health_records/domain/health_record_repository.dart';
import '../domain/recovery_receipt.dart';

final class RecoveryReceiptController {
  RecoveryReceiptController({
    required CareMemoryRepository careMemoryRepository,
    required HealthRecordRepository healthRecordRepository,
    DateTime Function()? now,
  }) : _careMemoryRepository = careMemoryRepository,
       _healthRecordRepository = healthRecordRepository,
       _now = now ?? DateTime.now;

  final CareMemoryRepository _careMemoryRepository;
  final HealthRecordRepository _healthRecordRepository;
  final DateTime Function() _now;

  DateTime get nowForReceipt => _now();

  Future<CareRecord> requirePersistedCareRecord(String careRecordId) async {
    try {
      final records = await _careMemoryRepository.getRecords();
      for (final record in records) {
        if (record.id == careRecordId) {
          return record;
        }
      }
    } on CareMemoryException {
      rethrow;
    } on Object {
      throw const RecoveryReceiptException(
        RecoveryReceiptFailure.storageUnavailable,
      );
    }
    throw const RecoveryReceiptException(
      RecoveryReceiptFailure.careRecordNotFound,
    );
  }

  Future<RecoveryReceiptResult> save(
    RecoveryReceiptDraft draft, {
    DateTime? recordedAt,
  }) async {
    final careRecord = await requirePersistedCareRecord(draft.careRecordId);
    final valid = validateRecoveryReceiptDraft(draft);
    final recorded = (recordedAt ?? _now()).toUtc();
    final experiencedDate = LocalDate.fromDateTime(
      careRecord.occurredAt.toLocal(),
    );
    final provenance = recoveryReceiptProvenance(
      experiencedDate: experiencedDate,
      recordedAt: recorded,
    );

    try {
      final records = <HealthRecord>[
        await _healthRecordRepository.create(
          HealthRecordDraft(
            symptom: valid.symptom,
            severity: valid.severity,
            painRating: valid.painRating,
            painLocations: valid.painLocations,
            functionalImpacts: valid.functionalImpacts,
            experiencedDate: experiencedDate,
            provenance: provenance,
          ),
        ),
      ];
      for (final symptom in valid.additionalPhysicalSignals) {
        records.add(
          await _healthRecordRepository.create(
            HealthRecordDraft(
              symptom: symptom,
              severity: valid.severity,
              functionalImpacts: valid.functionalImpacts,
              experiencedDate: experiencedDate,
              provenance: provenance,
            ),
          ),
        );
      }
      return RecoveryReceiptResult(
        careRecordId: careRecord.id,
        records: List.unmodifiable(records),
        provenance: provenance,
        recordedAt: recorded,
      );
    } on RecoveryReceiptException {
      rethrow;
    } on HealthRecordException catch (error) {
      if (error.failure == HealthRecordFailure.storageUnavailable) {
        throw const RecoveryReceiptException(
          RecoveryReceiptFailure.storageUnavailable,
        );
      }
      rethrow;
    } on Object {
      throw const RecoveryReceiptException(
        RecoveryReceiptFailure.storageUnavailable,
      );
    }
  }

  static String generateId() {
    final random = Random.secure();
    return '${DateTime.now().microsecondsSinceEpoch}-'
        '${random.nextInt(1 << 32).toRadixString(16)}';
  }
}
