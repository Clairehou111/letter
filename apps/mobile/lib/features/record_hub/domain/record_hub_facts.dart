import '../../cycle/domain/bleeding_flow.dart';
import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';

const recordHubVocabularyVersion = 1;

enum RecordHubFailure {
  invalidValue,
  futureDate,
  notFound,
  dateCollision,
  changedSinceUndo,
  storageUnavailable,
}

final class RecordHubException implements Exception {
  const RecordHubException(this.failure);

  final RecordHubFailure failure;

  String get userMessage => switch (failure) {
    RecordHubFailure.invalidValue => 'Check the selected fields and try again.',
    RecordHubFailure.futureDate => 'Choose today or an earlier date.',
    RecordHubFailure.notFound => 'This record is no longer available.',
    RecordHubFailure.dateCollision =>
      'This date already has a record. Review it before changing the date.',
    RecordHubFailure.changedSinceUndo =>
      'This record changed after that action and can no longer be restored.',
    RecordHubFailure.storageUnavailable =>
      'Your private record could not be saved. Try again.',
  };

  @override
  String toString() => 'RecordHubException($failure)';
}

void _require(bool condition) {
  if (!condition) {
    throw const RecordHubException(RecordHubFailure.invalidValue);
  }
}

void _requireScore(int value) => _require(value >= 0 && value <= 5);

void _requireCustom(bool required, String? value) {
  _require(!required || (value != null && value.trim().isNotEmpty));
}

/// Write-time evidence is frozen; viewing a source never changes its timing.
/// Missing legacy zone evidence remains null rather than being reconstructed.
final class RecordFactMetadata {
  RecordFactMetadata({
    required this.id,
    required this.experiencedDate,
    required this.recordedAt,
    required this.updatedAt,
    required this.originalProvenance,
    required this.provenance,
    this.originalWriteZoneId,
    this.writeZoneId,
    this.originalUtcOffsetMinutes,
    this.utcOffsetMinutes,
    this.vocabularyVersion = recordHubVocabularyVersion,
  }) {
    _require(id.trim().isNotEmpty);
    _require(!updatedAt.isBefore(recordedAt));
    _require(vocabularyVersion > 0);
  }

  final String id;
  final LocalDate experiencedDate;
  final DateTime recordedAt;
  final DateTime updatedAt;
  final HealthRecordProvenance originalProvenance;
  final HealthRecordProvenance provenance;
  final String? originalWriteZoneId;
  final String? writeZoneId;
  final int? originalUtcOffsetMinutes;
  final int? utcOffsetMinutes;
  final int vocabularyVersion;
}

abstract interface class DatedRecordDraft {
  LocalDate get experiencedDate;
}

/// Typed values share metadata, without storing opaque JSON health payloads.
final class RecordHubFact<T extends DatedRecordDraft> {
  RecordHubFact({required this.metadata, required this.value}) {
    _require(metadata.experiencedDate == value.experiencedDate);
  }

  final RecordFactMetadata metadata;
  final T value;

  String get id => metadata.id;
  LocalDate get experiencedDate => metadata.experiencedDate;
}

final class SymptomPins {
  SymptomPins(Iterable<SymptomType> symptoms)
    : symptoms = List.unmodifiable(symptoms) {
    _require(this.symptoms.length >= 2 && this.symptoms.length <= 4);
    _require(this.symptoms.toSet().length == this.symptoms.length);
    _require(this.symptoms.every((symptom) => symptom.availableForNewRecords));
  }

  /// The user's order is stable and independent from recent recording.
  final List<SymptomType> symptoms;
}

enum DailyImpactDomain {
  workOrSchool('Work or school'),
  homeResponsibilities('Home responsibilities'),
  relationships('Relationships'),
  socialActivity('Social activity'),
  sleep('Sleep'),
  hobbiesOrInterests('Hobbies or interests');

  const DailyImpactDomain(this.label);
  final String label;
}

final class DailyImpactDraft implements DatedRecordDraft {
  DailyImpactDraft({
    required this.experiencedDate,
    required this.overall,
    Set<DailyImpactDomain> domains = const {},
  }) : domains = Set.unmodifiable(domains) {
    _requireScore(overall);
  }

  @override
  final LocalDate experiencedDate;
  final int overall;
  final Set<DailyImpactDomain> domains;

  String get label => switch (overall) {
    0 => 'No impact',
    1 => 'Minimal',
    2 => 'Mild',
    3 => 'Moderate',
    4 => 'Severe',
    5 => 'Extreme',
    _ => throw const RecordHubException(RecordHubFailure.invalidValue),
  };
}

enum ClotObservation {
  notPresent('Not present'),
  present('Present'),
  notSure('Not sure');

  const ClotObservation(this.label);
  final String label;
}

final class BleedingFactDraft implements DatedRecordDraft {
  BleedingFactDraft({
    required this.experiencedDate,
    required this.flow,
    this.periodId,
    this.color,
    this.clots,
  }) {
    _require(periodId == null || periodId!.trim().isNotEmpty);
    _require(flow != null || (color == null && clots == null));
  }

  @override
  final LocalDate experiencedDate;

  /// Null in a saved fact explicitly means no bleeding; no row means blank.
  final BleedingFlow? flow;
  final String? periodId;
  final BleedingColor? color;
  final ClotObservation? clots;
  bool get noBleeding => flow == null;
}

enum DurationFamily { sleep, activity, careAction }

enum DurationBucket {
  sleepUnder5Hours('Under 5 h', DurationFamily.sleep),
  sleep5To7Hours('5–7 h', DurationFamily.sleep),
  sleep7To9Hours('7–9 h', DurationFamily.sleep),
  sleepOver9Hours('Over 9 h', DurationFamily.sleep),
  activityUnder10Minutes('Under 10 min', DurationFamily.activity),
  activity10To20Minutes('10–20 min', DurationFamily.activity),
  activity21To40Minutes('21–40 min', DurationFamily.activity),
  activity41To60Minutes('41–60 min', DurationFamily.activity),
  activityOver60Minutes('Over 60 min', DurationFamily.activity),
  care5Minutes('5 min', DurationFamily.careAction),
  care10Minutes('10 min', DurationFamily.careAction),
  care20Minutes('20 min', DurationFamily.careAction),
  care30PlusMinutes('30+ min', DurationFamily.careAction);

  const DurationBucket(this.label, this.family);
  final String label;
  final DurationFamily family;
}

/// Catalog ranges retain the selected category, never a guessed midpoint.
final class RecordedDuration {
  RecordedDuration.bucket(this.bucket, {this.catalogVersion = 1})
    : exactMinutes = null {
    _require(bucket != null && catalogVersion == recordHubVocabularyVersion);
  }

  RecordedDuration.exact(int minutes, {this.catalogVersion = 1})
    : bucket = null,
      exactMinutes = minutes {
    _require(minutes > 0 && catalogVersion == recordHubVocabularyVersion);
  }

  final DurationBucket? bucket;
  final int? exactMinutes;
  final int catalogVersion;
  String get label => bucket?.label ?? '$exactMinutes min';

  void requireFamily(DurationFamily family) {
    _require(bucket == null || bucket!.family == family);
  }
}

enum SleepQuality {
  veryPoor('Very poor', 0),
  poor('Poor', 1),
  restless('Restless', 2),
  fair('Fair', 3),
  good('Good', 4),
  restful('Restful', 5);

  const SleepQuality(this.label, this.score);
  final String label;
  final int score;

  static SleepQuality fromScore(int score) => switch (score) {
    0 => veryPoor,
    1 => poor,
    2 => restless,
    3 => fair,
    4 => good,
    5 => restful,
    _ => throw const RecordHubException(RecordHubFailure.invalidValue),
  };
}

enum SleepSignal {
  troubleFallingAsleep('Trouble falling asleep'),
  wakingDuringNight('Waking during the night'),
  muchMoreThanUsual('Slept much more than usual'),
  muchLessThanUsual('Slept much less than usual');

  const SleepSignal(this.label);
  final String label;
}

final class SleepDraft implements DatedRecordDraft {
  SleepDraft({
    required this.experiencedDate,
    this.duration,
    this.quality,
    Set<SleepSignal> signals = const {},
  }) : signals = Set.unmodifiable(signals) {
    _require(duration != null || quality != null || signals.isNotEmpty);
    duration?.requireFamily(DurationFamily.sleep);
  }

  /// The night ending on this day, not a newly inferred sleep timestamp.
  @override
  final LocalDate experiencedDate;
  final RecordedDuration? duration;
  final SleepQuality? quality;
  final Set<SleepSignal> signals;
}

enum ActivityType {
  walking('Walking'),
  cardio('Cardio'),
  strength('Strength'),
  yogaOrStretching('Yoga or stretching'),
  gentleMovement('Gentle movement'),
  intentionalRest('Intentional rest'),
  other('Other');

  const ActivityType(this.label);
  final String label;
}

enum ActivityIntensity {
  gentle('Gentle'),
  moderate('Moderate'),
  hard('Hard');

  const ActivityIntensity(this.label);
  final String label;
}

final class ActivityDraft implements DatedRecordDraft {
  ActivityDraft({
    required this.experiencedDate,
    required this.type,
    this.duration,
    this.intensity,
    this.customName,
  }) {
    _requireCustom(type == ActivityType.other, customName);
    duration?.requireFamily(DurationFamily.activity);
  }

  @override
  final LocalDate experiencedDate;
  final ActivityType type;
  final RecordedDuration? duration;
  final ActivityIntensity? intensity;
  final String? customName;
}

enum AppetiteLevel {
  lessThanUsual('Less than usual'),
  aboutUsual('About usual'),
  moreThanUsual('More than usual');

  const AppetiteLevel(this.label);
  final String label;
}

enum CravingType {
  sweet('Sweet'),
  chocolate('Chocolate'),
  savoryOrSalty('Savory or salty'),
  carbohydrateRich('Carbohydrate-rich'),
  other('Other');

  const CravingType(this.label);
  final String label;
}

final class AppetiteDraft implements DatedRecordDraft {
  AppetiteDraft({
    required this.experiencedDate,
    this.appetite,
    this.cravingScore,
    this.cravingType,
    this.customCraving,
  }) {
    _require(appetite != null || cravingScore != null);
    if (cravingScore != null) _requireScore(cravingScore!);
    _requireCustom(cravingType == CravingType.other, customCraving);
  }

  @override
  final LocalDate experiencedDate;
  final AppetiteLevel? appetite;
  final int? cravingScore;
  final CravingType? cravingType;
  final String? customCraving;
}

enum ContextEventType {
  illnessOrFever('Illness or fever'),
  travelOrTimeZoneChange('Travel or time-zone change'),
  acuteStress('Acute stress'),
  trauma('Trauma'),
  grief('Grief'),
  injury('Injury'),
  highAlcoholOrHangover('High alcohol / hangover'),
  majorLifeEvent('Major life event'),
  other('Other');

  const ContextEventType(this.label);
  final String label;
}

enum ContextEventIntensity {
  low('Low'),
  moderate('Moderate'),
  high('High');

  const ContextEventIntensity(this.label);
  final String label;
}

final class ContextEventDraft implements DatedRecordDraft {
  ContextEventDraft({
    required this.experiencedDate,
    required this.type,
    this.intensity,
    this.customName,
    this.note,
  }) {
    _requireCustom(type == ContextEventType.other, customName);
  }

  @override
  final LocalDate experiencedDate;
  final ContextEventType type;
  final ContextEventIntensity? intensity;
  final String? customName;
  final String? note;
}

enum TemperatureUnit {
  celsius('°C'),
  fahrenheit('°F');

  const TemperatureUnit(this.label);
  final String label;
}

enum TemperatureMethod {
  manualOral('Manual oral'),
  manualOther('Manual other');

  const TemperatureMethod(this.label);
  final String label;
}

enum TemperatureQualityFlag {
  feverOrIllness('Fever or illness'),
  poorSleep('Poor sleep'),
  alcohol('Alcohol'),
  travelOrTimeZoneChange('Travel or time-zone change');

  const TemperatureQualityFlag(this.label);
  final String label;
}

/// A wall-clock time on the experienced day; it invents neither a zone nor UTC.
final class LocalMeasurementTime {
  LocalMeasurementTime(this.hour, this.minute) {
    _require(hour >= 0 && hour < 24 && minute >= 0 && minute < 60);
  }

  final int hour;
  final int minute;
}

final class TemperatureDraft implements DatedRecordDraft {
  TemperatureDraft({
    required this.experiencedDate,
    required this.enteredValue,
    required this.unit,
    required this.method,
    this.measuredAt,
    Set<TemperatureQualityFlag> flags = const {},
  }) : flags = Set.unmodifiable(flags) {
    _require(enteredValue.isFinite && enteredValue > 0);
  }

  @override
  final LocalDate experiencedDate;
  final double enteredValue;
  final TemperatureUnit unit;
  final TemperatureMethod method;
  final LocalMeasurementTime? measuredAt;
  final Set<TemperatureQualityFlag> flags;

  /// Derived display conversion never replaces the originally entered value.
  double get celsiusValue => switch (unit) {
    TemperatureUnit.celsius => enteredValue,
    TemperatureUnit.fahrenheit => (enteredValue - 32) * 5 / 9,
  };
}

typedef DailyImpactRecord = RecordHubFact<DailyImpactDraft>;
typedef BleedingFactRecord = RecordHubFact<BleedingFactDraft>;
typedef SleepRecord = RecordHubFact<SleepDraft>;
typedef ActivityRecord = RecordHubFact<ActivityDraft>;
typedef AppetiteRecord = RecordHubFact<AppetiteDraft>;
typedef ContextEventRecord = RecordHubFact<ContextEventDraft>;
typedef TemperatureRecord = RecordHubFact<TemperatureDraft>;

final class RecordHubDateFacts {
  RecordHubDateFacts({
    required this.date,
    this.impact,
    this.bleeding,
    this.sleep,
    this.appetite,
    Iterable<ActivityRecord> activities = const [],
    Iterable<ContextEventRecord> events = const [],
    Iterable<TemperatureRecord> temperatures = const [],
  }) : activities = List.unmodifiable(activities),
       events = List.unmodifiable(events),
       temperatures = List.unmodifiable(temperatures) {
    _require(
      [
        impact,
        bleeding,
        sleep,
        appetite,
        ...this.activities,
        ...this.events,
        ...this.temperatures,
      ].every((fact) => fact == null || fact.experiencedDate == date),
    );
  }

  final LocalDate date;
  final DailyImpactRecord? impact;
  final BleedingFactRecord? bleeding;
  final SleepRecord? sleep;
  final AppetiteRecord? appetite;
  final List<ActivityRecord> activities;
  final List<ContextEventRecord> events;
  final List<TemperatureRecord> temperatures;

  bool get isEmpty =>
      impact == null &&
      bleeding == null &&
      sleep == null &&
      appetite == null &&
      activities.isEmpty &&
      events.isEmpty &&
      temperatures.isEmpty;
}
