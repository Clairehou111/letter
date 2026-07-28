import '../../cycle/domain/local_date.dart';

const healthRecordVocabularyVersion = 1;

enum SymptomCategory { physical, mood, energy, sleep }

enum SymptomType {
  cramps('Cramps', SymptomCategory.physical),
  headache('Headache', SymptomCategory.physical),
  breastTenderness('Breast tenderness', SymptomCategory.physical),
  bloating('Bloating', SymptomCategory.physical),
  nausea('Nausea', SymptomCategory.physical),
  bodyAches('Body aches', SymptomCategory.physical),
  lowMood('Low mood', SymptomCategory.mood),
  irritability('Irritability', SymptomCategory.mood),
  anxiety('Anxiety', SymptomCategory.mood),
  concentration('Difficulty concentrating', SymptomCategory.mood),
  lowEnergy('Low energy', SymptomCategory.energy),
  sleepDifficulty('Difficulty sleeping', SymptomCategory.sleep),
  sleepiness('Sleepiness', SymptomCategory.sleep);

  const SymptomType(this.label, this.category);

  final String label;
  final SymptomCategory category;
}

enum SymptomSeverity {
  notAtAll('Not at all', 1),
  minimal('Minimal', 2),
  mild('Mild', 3),
  moderate('Moderate', 4),
  severe('Severe', 5),
  extreme('Extreme', 6);

  const SymptomSeverity(this.label, this.score);

  final String label;
  final int score;
}

enum PainLocation {
  lowerAbdomen('Lower abdomen'),
  lowerBack('Lower back'),
  pelvis('Pelvis'),
  head('Head'),
  jointsOrMuscles('Joints or muscles'),
  other('Other');

  const PainLocation(this.label);

  final String label;
}

enum FunctionalImpact {
  workOrSchool('Work or school'),
  homeResponsibilities('Home responsibilities'),
  relationships('Relationships'),
  socialActivity('Social activity'),
  sleep('Sleep');

  const FunctionalImpact(this.label);

  final String label;
}

enum HealthRecordProvenance {
  sameDay('Same day', 'same_day'),
  laterRecall('Later recall', 'later_recall');

  const HealthRecordProvenance(this.label, this.storageKey);

  final String label;
  final String storageKey;
}

final class HealthRecordDraft {
  const HealthRecordDraft({
    required this.symptom,
    required this.severity,
    required this.experiencedDate,
    required this.provenance,
    this.painRating,
    this.painLocations = const {},
    this.functionalImpacts = const {},
  });

  final SymptomType symptom;
  final SymptomSeverity severity;
  final int? painRating;
  final Set<PainLocation> painLocations;
  final Set<FunctionalImpact> functionalImpacts;
  final LocalDate experiencedDate;
  final HealthRecordProvenance provenance;
}

final class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.symptom,
    required this.severity,
    required this.painRating,
    required this.painLocations,
    required this.functionalImpacts,
    required this.experiencedDate,
    required this.recordedAt,
    required this.updatedAt,
    required this.provenance,
    required this.userConfirmed,
    required this.vocabularyVersion,
  });

  final String id;
  final SymptomType symptom;
  final SymptomSeverity severity;
  final int? painRating;
  final Set<PainLocation> painLocations;
  final Set<FunctionalImpact> functionalImpacts;
  final LocalDate experiencedDate;
  final DateTime recordedAt;
  final DateTime updatedAt;
  final HealthRecordProvenance provenance;
  final bool userConfirmed;
  final int vocabularyVersion;

  HealthRecord copyWith({
    required HealthRecordDraft draft,
    DateTime? updatedAt,
  }) {
    return HealthRecord(
      id: id,
      symptom: draft.symptom,
      severity: draft.severity,
      painRating: draft.painRating,
      painLocations: Set.unmodifiable(draft.painLocations),
      functionalImpacts: Set.unmodifiable(draft.functionalImpacts),
      experiencedDate: draft.experiencedDate,
      recordedAt: recordedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      provenance: draft.provenance,
      userConfirmed: userConfirmed,
      vocabularyVersion: vocabularyVersion,
    );
  }
}

HealthRecordDraft validateHealthRecordDraft(HealthRecordDraft draft) {
  if (draft.painRating != null &&
      (draft.painRating! < 0 || draft.painRating! > 10)) {
    throw const HealthRecordException(HealthRecordFailure.invalidPainRating);
  }
  if ((draft.painRating == null) != draft.painLocations.isEmpty) {
    throw const HealthRecordException(HealthRecordFailure.incompletePainEntry);
  }
  return HealthRecordDraft(
    symptom: draft.symptom,
    severity: draft.severity,
    painRating: draft.painRating,
    painLocations: Set.unmodifiable(draft.painLocations),
    functionalImpacts: Set.unmodifiable(draft.functionalImpacts),
    experiencedDate: draft.experiencedDate,
    provenance: draft.provenance,
  );
}

enum HealthRecordFailure {
  invalidPainRating,
  incompletePainEntry,
  notFound,
  storageUnavailable,
}

final class HealthRecordException implements Exception {
  const HealthRecordException(this.failure);

  final HealthRecordFailure failure;

  String get userMessage => switch (failure) {
    HealthRecordFailure.invalidPainRating =>
      'Pain must be a number from 0 to 10.',
    HealthRecordFailure.incompletePainEntry =>
      'Add a pain location and a 0-10 rating together.',
    HealthRecordFailure.notFound =>
      'This health record is no longer available. Refresh and try again.',
    HealthRecordFailure.storageUnavailable =>
      'Letter could not update your private health record. Try again.',
  };

  @override
  String toString() => 'HealthRecordException($failure)';
}
