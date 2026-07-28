import '../../care/domain/care_memory.dart';
import '../../care/domain/care_mode.dart';
import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';

enum RecoveryReceiptSignal {
  irritability('Angry or irritable', SymptomType.irritability),
  lowMood('Low mood', SymptomType.lowMood),
  anxiety('Anxious or tense', SymptomType.anxiety),
  concentration('Difficulty concentrating', SymptomType.concentration),
  cramps('Cramps', SymptomType.cramps),
  headache('Headache', SymptomType.headache),
  breastTenderness('Breast tenderness', SymptomType.breastTenderness),
  bloating('Bloating', SymptomType.bloating),
  nausea('Nausea', SymptomType.nausea),
  bodyAches('Body aches', SymptomType.bodyAches),
  somethingElse('Something else', null),
  iDoNotRemember('I do not remember', null);

  const RecoveryReceiptSignal(this.label, this.symptom);

  final String label;
  final SymptomType? symptom;
}

enum RecoveryReceiptFailure {
  careRecordNotFound,
  signalRequired,
  severityRequired,
  invalidAdditionalSignal,
  incompletePainEntry,
  storageUnavailable,
}

final class RecoveryReceiptException implements Exception {
  const RecoveryReceiptException(this.failure);

  final RecoveryReceiptFailure failure;

  String get userMessage => switch (failure) {
    RecoveryReceiptFailure.careRecordNotFound =>
      'This Care moment is no longer available. Refresh and try again.',
    RecoveryReceiptFailure.signalRequired =>
      'Choose a signal, or choose I do not remember.',
    RecoveryReceiptFailure.severityRequired =>
      'Choose the intensity that feels true to you.',
    RecoveryReceiptFailure.invalidAdditionalSignal =>
      'Choose only physical signals for the optional physical step.',
    RecoveryReceiptFailure.incompletePainEntry =>
      'Add a pain location and a 0-10 rating together.',
    RecoveryReceiptFailure.storageUnavailable =>
      'Letter could not save this private receipt. Try again.',
  };

  @override
  String toString() => 'RecoveryReceiptException($failure)';
}

final class RecoveryReceiptDraft {
  const RecoveryReceiptDraft({
    required this.careRecordId,
    required this.symptom,
    required this.severity,
    this.functionalImpacts = const {},
    this.additionalPhysicalSignals = const {},
    this.painRating,
    this.painLocations = const {},
  });

  final String careRecordId;
  final SymptomType symptom;
  final SymptomSeverity severity;
  final Set<FunctionalImpact> functionalImpacts;
  final Set<SymptomType> additionalPhysicalSignals;
  final int? painRating;
  final Set<PainLocation> painLocations;
}

final class RecoveryReceiptResult {
  const RecoveryReceiptResult({
    required this.careRecordId,
    required this.records,
    required this.provenance,
    required this.recordedAt,
  });

  final String careRecordId;
  final List<HealthRecord> records;
  final HealthRecordProvenance provenance;
  final DateTime recordedAt;
}

SymptomType? suggestedSymptomForCare(CareRecord record) {
  return switch (record.mode) {
    CareMode.explode => SymptomType.irritability,
    CareMode.heavy => SymptomType.lowMood,
    CareMode.racing => SymptomType.anxiety,
    CareMode.space => null,
    CareMode.physical => SymptomType.cramps,
  };
}

HealthRecordProvenance recoveryReceiptProvenance({
  required LocalDate experiencedDate,
  required DateTime recordedAt,
}) {
  final recordedDate = LocalDate.fromDateTime(recordedAt.toLocal());
  return recordedDate == experiencedDate
      ? HealthRecordProvenance.sameDay
      : HealthRecordProvenance.laterRecall;
}

RecoveryReceiptDraft validateRecoveryReceiptDraft(RecoveryReceiptDraft draft) {
  if (draft.careRecordId.trim().isEmpty) {
    throw const RecoveryReceiptException(
      RecoveryReceiptFailure.careRecordNotFound,
    );
  }
  if (draft.painRating != null &&
      (draft.painRating! < 0 || draft.painRating! > 10)) {
    throw const RecoveryReceiptException(
      RecoveryReceiptFailure.incompletePainEntry,
    );
  }
  if ((draft.painRating == null) != draft.painLocations.isEmpty) {
    throw const RecoveryReceiptException(
      RecoveryReceiptFailure.incompletePainEntry,
    );
  }
  if (draft.additionalPhysicalSignals.any(
    (signal) => signal.category != SymptomCategory.physical,
  )) {
    throw const RecoveryReceiptException(
      RecoveryReceiptFailure.invalidAdditionalSignal,
    );
  }
  if (draft.additionalPhysicalSignals.contains(draft.symptom)) {
    throw const RecoveryReceiptException(
      RecoveryReceiptFailure.invalidAdditionalSignal,
    );
  }
  return RecoveryReceiptDraft(
    careRecordId: draft.careRecordId.trim(),
    symptom: draft.symptom,
    severity: draft.severity,
    functionalImpacts: Set.unmodifiable(draft.functionalImpacts),
    additionalPhysicalSignals: Set.unmodifiable(
      draft.additionalPhysicalSignals,
    ),
    painRating: draft.painRating,
    painLocations: Set.unmodifiable(draft.painLocations),
  );
}
