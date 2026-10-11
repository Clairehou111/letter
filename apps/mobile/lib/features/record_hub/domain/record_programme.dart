import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';
import '../../health_records/domain/observation_catalog.dart';

enum RecordProgrammeFailure {
  invalidSelection,
  futureDate,
  alreadyCurrent,
  notFound,
  ended,
  alreadyPaused,
  notPaused,
  dateOutsideProgramme,
  historicalConfigChange,
  storageUnavailable,
}

final class RecordProgrammeException implements Exception {
  const RecordProgrammeException(this.failure);
  final RecordProgrammeFailure failure;
  String get userMessage => switch (failure) {
    RecordProgrammeFailure.invalidSelection =>
      'Choose at least one available symptom.',
    RecordProgrammeFailure.futureDate => 'Choose today or an earlier date.',
    RecordProgrammeFailure.alreadyCurrent =>
      'You already have a Pattern Record programme. Open it to continue.',
    RecordProgrammeFailure.notFound => 'This programme is no longer available.',
    RecordProgrammeFailure.ended =>
      'This programme has ended. Its saved history remains available.',
    RecordProgrammeFailure.alreadyPaused => 'This programme is already paused.',
    RecordProgrammeFailure.notPaused => 'This programme is already recording.',
    RecordProgrammeFailure.dateOutsideProgramme =>
      'Choose a date within this programme and after its latest change.',
    RecordProgrammeFailure.historicalConfigChange =>
      'Field changes begin today. Earlier configurations stay unchanged.',
    RecordProgrammeFailure.storageUnavailable =>
      'Your private programme could not be updated. Try again.',
  };
  @override
  String toString() => 'RecordProgrammeException($failure)';
}

void requireProgramme(bool condition, RecordProgrammeFailure failure) {
  if (!condition) throw RecordProgrammeException(failure);
}

final class RecordProgrammeConfig {
  RecordProgrammeConfig({
    required this.id,
    required this.version,
    required this.effectiveDate,
    required Iterable<SymptomType> symptoms,
    this.vocabularyVersion = healthRecordVocabularyVersion,
  }) : symptoms = List.unmodifiable(symptoms) {
    requireProgramme(
      id.isNotEmpty &&
          version > 0 &&
          vocabularyVersion > 0 &&
          this.symptoms.isNotEmpty &&
          this.symptoms.toSet().length == this.symptoms.length &&
          this.symptoms.every((symptom) => symptom.availableForNewRecords),
      RecordProgrammeFailure.invalidSelection,
    );
  }
  final String id;
  final int version;
  final LocalDate effectiveDate;
  final List<SymptomType> symptoms;
  final int vocabularyVersion;
  bool get dailyImpactRequired => true;
  List<String> get symptomIds => [
    for (final symptom in symptoms)
      ObservationCatalog.definitionFor(symptom).id,
  ];
}

final class RecordProgrammePause {
  RecordProgrammePause({
    required this.id,
    required this.startDate,
    this.resumedDate,
  }) {
    requireProgramme(
      id.isNotEmpty &&
          (resumedDate == null || !resumedDate!.isBefore(startDate)),
      RecordProgrammeFailure.dateOutsideProgramme,
    );
  }
  final String id;
  final LocalDate startDate;

  /// Exclusive: fields are expected again on the resume date.
  final LocalDate? resumedDate;
  bool includes(LocalDate date) =>
      !date.isBefore(startDate) &&
      (resumedDate == null || date.isBefore(resumedDate!));
}

final class RecordProgramme {
  RecordProgramme({
    required this.id,
    required this.startDate,
    required this.createdAt,
    required this.updatedAt,
    required Iterable<RecordProgrammeConfig> configurations,
    Iterable<RecordProgrammePause> pauses = const [],
    this.endDate,
  }) : configurations = List.unmodifiable(configurations),
       pauses = List.unmodifiable(pauses) {
    requireProgramme(
      id.isNotEmpty &&
          this.configurations.isNotEmpty &&
          this.configurations.first.effectiveDate == startDate &&
          (endDate == null || !endDate!.isBefore(startDate)) &&
          !updatedAt.isBefore(createdAt),
      RecordProgrammeFailure.dateOutsideProgramme,
    );
    for (var index = 0; index < this.configurations.length; index++) {
      final config = this.configurations[index];
      requireProgramme(
        config.version == index + 1 &&
            !config.effectiveDate.isBefore(startDate) &&
            (endDate == null || !config.effectiveDate.isAfter(endDate!)) &&
            (index == 0 ||
                !config.effectiveDate.isBefore(
                  this.configurations[index - 1].effectiveDate,
                )),
        RecordProgrammeFailure.dateOutsideProgramme,
      );
    }
    for (var index = 0; index < this.pauses.length; index++) {
      final pause = this.pauses[index];
      requireProgramme(
        !pause.startDate.isBefore(startDate) &&
            (endDate == null || !pause.startDate.isAfter(endDate!)) &&
            (pause.resumedDate == null ||
                endDate == null ||
                !pause.resumedDate!.isAfter(endDate!)) &&
            (index == 0 ||
                (this.pauses[index - 1].resumedDate != null &&
                    !pause.startDate.isBefore(
                      this.pauses[index - 1].resumedDate!,
                    ))),
        RecordProgrammeFailure.dateOutsideProgramme,
      );
    }
  }
  final String id;
  final LocalDate startDate;
  final LocalDate? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RecordProgrammeConfig> configurations;
  final List<RecordProgrammePause> pauses;
  bool get isEnded => endDate != null;
  bool get isPaused =>
      !isEnded && pauses.isNotEmpty && pauses.last.resumedDate == null;
  bool includes(LocalDate date) =>
      !date.isBefore(startDate) && (endDate == null || !date.isAfter(endDate!));
  bool isPausedOn(LocalDate date) =>
      includes(date) && pauses.any((pause) => pause.includes(date));
  RecordProgrammeConfig? configOn(LocalDate date) {
    if (!includes(date)) return null;
    return configurations
        .where((config) => !config.effectiveDate.isAfter(date))
        .lastOrNull;
  }

  List<SymptomType> expectedSymptomsOn(LocalDate date) =>
      isPausedOn(date) ? const [] : configOn(date)?.symptoms ?? const [];
  bool expectsImpactOn(LocalDate date) => includes(date) && !isPausedOn(date);
}

abstract interface class RecordProgrammeRepository {
  Future<List<RecordProgramme>> getAll();
  Future<RecordProgramme?> getCurrent();
  Future<RecordProgramme> enroll({
    required LocalDate startDate,
    required List<SymptomType> symptoms,
  });
  Future<RecordProgramme> updateConfig(
    String id, {
    required LocalDate effectiveDate,
    required List<SymptomType> symptoms,
  });
  Future<RecordProgramme> pause(String id, {required LocalDate date});
  Future<RecordProgramme> resume(String id, {required LocalDate date});
  Future<RecordProgramme> end(String id, {required LocalDate date});
}
