import '../../cycle/domain/local_date.dart';

const healthRecordVocabularyVersion = 3;

enum SymptomCategory { physical, mood, energy, sleep }

enum SymptomType {
  cramps('Cramps', SymptomCategory.physical),
  headache('Headache', SymptomCategory.physical),
  breastTenderness('Breast tenderness', SymptomCategory.physical),
  bloating('Bloating', SymptomCategory.physical),
  nausea('Nausea', SymptomCategory.physical),
  bodyAches('Body aches', SymptomCategory.physical),
  lowMood('Depressed mood', SymptomCategory.mood),
  irritability('Irritability', SymptomCategory.mood),
  anxiety('Anxiety or worry', SymptomCategory.mood),
  concentration(
    'Difficulty concentrating',
    SymptomCategory.mood,
    availableForNewRecords: false,
  ),
  lowEnergy('Low energy', SymptomCategory.energy),
  sleepDifficulty('Difficulty sleeping', SymptomCategory.sleep),
  sleepiness('Sleepiness', SymptomCategory.sleep),
  crying('Crying', SymptomCategory.mood),
  hopelessness('Hopelessness or despair', SymptomCategory.mood),
  anhedonia('Loss of interest or pleasure', SymptomCategory.mood),
  moodSwings('Mood swings', SymptomCategory.mood),
  rage('Rage', SymptomCategory.mood),
  panicAttack('Panic attack', SymptomCategory.mood),
  hypersensitivity('Feeling unusually sensitive', SymptomCategory.mood),
  paranoia('Suspicious or paranoid thoughts', SymptomCategory.mood),
  socialWithdrawal('Social withdrawal', SymptomCategory.mood),
  impulsiveUrges('Impulsive urges', SymptomCategory.mood),
  brainFog('Brain fog', SymptomCategory.energy),
  fatigue('Fatigue', SymptomCategory.energy),
  hypersomnia('Sleeping much more', SymptomCategory.sleep),
  insomnia('Insomnia', SymptomCategory.sleep),
  sleepDisruption('Broken or disrupted sleep', SymptomCategory.sleep),
  pelvicPain('Pelvic pain', SymptomCategory.physical),
  backPain('Back pain', SymptomCategory.physical),
  jointMusclePain('Joint or muscle pain', SymptomCategory.physical),
  waterRetention('Water retention', SymptomCategory.physical),
  appetiteChange('Appetite change or cravings', SymptomCategory.physical),
  constipation('Constipation', SymptomCategory.physical),
  diarrhea('Diarrhea', SymptomCategory.physical),
  acne('Acne or skin changes', SymptomCategory.physical),
  dizziness('Dizziness', SymptomCategory.physical),
  migraine('Migraine', SymptomCategory.physical),
  hotFlashes('Hot flashes or sweating', SymptomCategory.physical),
  overwhelm('Feeling overwhelmed', SymptomCategory.mood),
  forgetfulness('Forgetfulness', SymptomCategory.energy),
  palpitations(
    'Heart palpitations',
    SymptomCategory.physical,
    availableForNewRecords: false,
  );

  const SymptomType(
    this.label,
    this.category, {
    this.availableForNewRecords = true,
  });

  final String label;
  final SymptomCategory category;
  final bool availableForNewRecords;
}

enum SafetySignal {
  suicidalThoughts('Suicidal thoughts'),
  selfHarm('Self-harm'),
  palpitations('Heart palpitations', physical: true);

  const SafetySignal(this.label, {this.physical = false});

  final String label;
  final bool physical;
}

enum SymptomSeverity {
  minimal('Minimal', 1),
  mild('Mild', 2),
  moderate('Moderate', 3),
  severe('Severe', 4),
  extreme('Extreme', 5),
  notPresent('Not present', 0);

  const SymptomSeverity(this.label, this.score);

  final String label;
  final int score;

  static const orderedDegrees = [
    notPresent,
    minimal,
    mild,
    moderate,
    severe,
    extreme,
  ];

  static SymptomSeverity fromScore(int score) => switch (score) {
    0 => notPresent,
    1 => minimal,
    2 => mild,
    3 => moderate,
    4 => severe,
    5 => extreme,
    _ => throw const FormatException('Unsupported symptom degree.'),
  };
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
  laterRecall('Later recall', 'later_recall'),
  timingUnknown('Timing unknown', 'timing_unknown');

  const HealthRecordProvenance(this.label, this.storageKey);

  final String label;
  final String storageKey;

  static HealthRecordProvenance fromStorageKey(String? key) => switch (key) {
    'same_day' => sameDay,
    'later_recall' => laterRecall,
    _ => timingUnknown,
  };
}

final class HealthRecordDraft {
  const HealthRecordDraft({
    required this.symptom,
    required this.severity,
    required this.experiencedDate,
    required this.provenance,
    this.functionalImpacts = const {},
  });

  final SymptomType symptom;
  final SymptomSeverity severity;
  final Set<FunctionalImpact> functionalImpacts;
  final LocalDate experiencedDate;
  final HealthRecordProvenance provenance;
}

final class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.symptom,
    required this.severity,
    required this.functionalImpacts,
    required this.experiencedDate,
    required this.recordedAt,
    required this.updatedAt,
    required this.provenance,
    required this.userConfirmed,
    required this.vocabularyVersion,
    this.originalProvenance,
    this.writeZoneOffsetMinutes,
    this.writeZoneName,
    this.updatedZoneOffsetMinutes,
    this.updatedZoneName,
  });

  final String id;
  final SymptomType symptom;
  final SymptomSeverity severity;
  final Set<FunctionalImpact> functionalImpacts;
  final LocalDate experiencedDate;
  final DateTime recordedAt;
  final DateTime updatedAt;
  final HealthRecordProvenance provenance;
  final bool userConfirmed;
  final int vocabularyVersion;
  final HealthRecordProvenance? originalProvenance;
  final int? writeZoneOffsetMinutes;
  final String? writeZoneName;
  final int? updatedZoneOffsetMinutes;
  final String? updatedZoneName;

  HealthRecordProvenance get effectiveOriginalProvenance =>
      originalProvenance ?? provenance;

  bool hasSameValue(HealthRecordDraft draft) =>
      symptom == draft.symptom &&
      severity == draft.severity &&
      experiencedDate == draft.experiencedDate &&
      functionalImpacts.length == draft.functionalImpacts.length &&
      functionalImpacts.containsAll(draft.functionalImpacts);

  HealthRecord copyWith({
    required HealthRecordDraft draft,
    DateTime? updatedAt,
    HealthRecordProvenance? activeProvenance,
    int? updatedZoneOffsetMinutes,
    String? updatedZoneName,
  }) {
    return HealthRecord(
      id: id,
      symptom: draft.symptom,
      severity: draft.severity,
      functionalImpacts: Set.unmodifiable(draft.functionalImpacts),
      experiencedDate: draft.experiencedDate,
      recordedAt: recordedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      provenance: activeProvenance ?? draft.provenance,
      userConfirmed: userConfirmed,
      vocabularyVersion: vocabularyVersion,
      originalProvenance: effectiveOriginalProvenance,
      writeZoneOffsetMinutes: writeZoneOffsetMinutes,
      writeZoneName: writeZoneName,
      updatedZoneOffsetMinutes:
          updatedZoneOffsetMinutes ?? this.updatedZoneOffsetMinutes,
      updatedZoneName: updatedZoneName ?? this.updatedZoneName,
    );
  }
}

HealthRecordDraft validateHealthRecordDraft(HealthRecordDraft draft) {
  return HealthRecordDraft(
    symptom: draft.symptom,
    severity: draft.severity,
    functionalImpacts: Set.unmodifiable(draft.functionalImpacts),
    experiencedDate: draft.experiencedDate,
    provenance: draft.provenance,
  );
}

enum HealthRecordFailure {
  notFound,
  duplicateForDay,
  storageUnavailable,
  futureDate,
  dateCollision,
  undoConflict,
}

final class HealthRecordException implements Exception {
  const HealthRecordException(this.failure);

  final HealthRecordFailure failure;

  String get userMessage => switch (failure) {
    HealthRecordFailure.notFound =>
      'This health record is no longer available. Refresh and try again.',
    HealthRecordFailure.duplicateForDay =>
      'That symptom is already recorded for this day. Edit or delete the existing entry first.',
    HealthRecordFailure.storageUnavailable =>
      'Letter Within could not update your private health record. Try again.',
    HealthRecordFailure.futureDate => 'Choose a date on or before today.',
    HealthRecordFailure.dateCollision =>
      'This symptom already has a record on that date. Open that record to make a correction.',
    HealthRecordFailure.undoConflict =>
      'This record changed again. The earlier change can no longer be undone.',
  };

  @override
  String toString() => 'HealthRecordException($failure)';
}
