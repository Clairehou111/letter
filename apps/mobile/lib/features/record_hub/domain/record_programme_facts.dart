import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_record.dart';
import '../../health_records/domain/health_record.dart';
import '../../health_records/domain/observation_catalog.dart';
import 'record_hub_facts.dart';
import 'record_programme.dart';

/// A reference to a current shared source, never a programme-owned rating.
final class ProgrammeSourceValue {
  const ProgrammeSourceValue({
    required this.sourceId,
    required this.date,
    required this.score,
    required this.provenance,
  });
  final String sourceId;
  final LocalDate date;
  final int score;
  final HealthRecordProvenance provenance;
}

final class ProgrammeDayEvidence {
  ProgrammeDayEvidence({
    required this.date,
    required this.configurationVersion,
    required this.paused,
    required Iterable<String> expectedSymptomIds,
    required Map<String, ProgrammeSourceValue> symptoms,
    required this.impact,
  }) : expectedSymptomIds = List.unmodifiable(expectedSymptomIds),
       symptoms = Map.unmodifiable(symptoms);
  final LocalDate date;
  final int configurationVersion;
  final bool paused;
  final List<String> expectedSymptomIds;
  final Map<String, ProgrammeSourceValue> symptoms;
  final ProgrammeSourceValue? impact;
  int get expectedFieldCount => paused ? 0 : expectedSymptomIds.length + 1;
  int get recordedExpectedFields => paused
      ? 0
      : expectedSymptomIds.where(symptoms.containsKey).length +
            (impact == null ? 0 : 1);
  int get missingFieldCount => expectedFieldCount - recordedExpectedFields;
  int get sameDayExpectedFields => paused
      ? 0
      : [
              for (final id in expectedSymptomIds)
                if (symptoms[id] != null) symptoms[id]!,
              ?impact,
            ]
            .where(
              (source) => source.provenance == HealthRecordProvenance.sameDay,
            )
            .length;
  bool get isLiterallyComplete =>
      !paused && expectedFieldCount == sameDayExpectedFields;
}

/// Factual descriptive statistics. There is no eligibility or diagnosis gate.
final class ProgrammeLevelFacts {
  ProgrammeLevelFacts(Iterable<ProgrammeSourceValue> values)
    : sources = List.unmodifiable(_unique(values)) {
    final scores = sources.map((value) => value.score).toList()..sort();
    median = scores.isEmpty
        ? null
        : scores.length.isOdd
        ? scores[scores.length ~/ 2].toDouble()
        : (scores[scores.length ~/ 2 - 1] + scores[scores.length ~/ 2]) / 2;
    peak = scores.lastOrNull;
    distribution = List.unmodifiable([
      for (var score = 0; score <= 5; score++)
        scores.where((value) => value == score).length,
    ]);
  }
  final List<ProgrammeSourceValue> sources;
  late final double? median;
  late final int? peak;
  late final List<int> distribution;
  int get sourceCount => sources.length;
  int get sameDayCount => sources
      .where((source) => source.provenance == HealthRecordProvenance.sameDay)
      .length;
  int get laterRecallCount => sources
      .where(
        (source) => source.provenance == HealthRecordProvenance.laterRecall,
      )
      .length;
  int get timingUnknownCount => sources
      .where(
        (source) => source.provenance == HealthRecordProvenance.timingUnknown,
      )
      .length;
  static List<ProgrammeSourceValue> _unique(
    Iterable<ProgrammeSourceValue> values,
  ) {
    final byId = <String, ProgrammeSourceValue>{};
    for (final value in values) {
      byId[value.sourceId] = value;
    }
    return byId.values.toList()..sort((left, right) {
      final date = left.date.compareTo(right.date);
      return date == 0 ? left.sourceId.compareTo(right.sourceId) : date;
    });
  }
}

final class ProgrammeFieldFacts {
  ProgrammeFieldFacts({
    required this.id,
    required Iterable<ProgrammeSourceValue> all,
    required Iterable<ProgrammeSourceValue> before,
    required Iterable<ProgrammeSourceValue> after,
    required this.overallCoverage,
    required this.beforeCoverage,
    required this.afterCoverage,
  }) : overall = ProgrammeLevelFacts(all),
       before = ProgrammeLevelFacts(before),
       after = ProgrammeLevelFacts(after);
  final String id;
  final ProgrammeLevelFacts overall;
  final ProgrammeLevelFacts before;
  final ProgrammeLevelFacts after;
  final ProgrammeFieldCoverage overallCoverage;
  final ProgrammeFieldCoverage beforeCoverage;
  final ProgrammeFieldCoverage afterCoverage;
}

final class ProgrammeFieldCoverage {
  const ProgrammeFieldCoverage({
    required this.expected,
    required this.recorded,
    required this.sameDay,
    required this.laterRecall,
    required this.timingUnknown,
  });
  final int expected;
  final int recorded;
  final int sameDay;
  final int laterRecall;
  final int timingUnknown;
  int get missing => expected - recorded;
}

final class ProgrammeCycleFacts {
  const ProgrammeCycleFacts({
    required this.periodId,
    required this.startDate,
    required this.endDate,
    required this.expectedFields,
    required this.sameDayFields,
    required this.fullyWithinProgramme,
  });
  final String periodId;
  final LocalDate startDate;
  final LocalDate endDate;
  final int expectedFields;
  final int sameDayFields;
  final bool fullyWithinProgramme;
  bool get literallyFullyRecorded =>
      fullyWithinProgramme &&
      expectedFields > 0 &&
      sameDayFields == expectedFields;
}

final class RecordProgrammeFacts {
  RecordProgrammeFacts({
    required this.programme,
    required Iterable<ProgrammeDayEvidence> days,
    required Iterable<ProgrammeFieldFacts> fields,
    required Iterable<ProgrammeCycleFacts> cycles,
    this.unresolvedLegacyPause = false,
  }) : days = List.unmodifiable(days),
       fields = List.unmodifiable(fields),
       cycles = List.unmodifiable(cycles);
  final RecordProgramme programme;
  final List<ProgrammeDayEvidence> days;
  final List<ProgrammeFieldFacts> fields;
  final List<ProgrammeCycleFacts> cycles;
  final bool unresolvedLegacyPause;
  int get expectedFieldCount =>
      days.fold(0, (count, day) => count + day.expectedFieldCount);
  int get missingFieldCount =>
      days.fold(0, (count, day) => count + day.missingFieldCount);
  int get sameDayFieldCount =>
      days.fold(0, (count, day) => count + day.sameDayExpectedFields);
  int get elapsedCycles => cycles.length;
  int get literallyFullyRecordedCycles => unresolvedLegacyPause
      ? 0
      : cycles.where((cycle) => cycle.literallyFullyRecorded).length;
}

/// Reads the current versions of shared symptoms/impact. Pins are irrelevant.
/// Before: -14..-1; after: observed cycle days 1..3, anchored to observed starts.
/// These descriptive windows do not replace Spectrum/Twin or train a forecast.
RecordProgrammeFacts composeRecordProgrammeFacts({
  required RecordProgramme programme,
  required LocalDate today,
  required List<HealthRecord> healthRecords,
  required List<RecordHubDateFacts> datedFacts,
  required List<PeriodRecord> periods,
  bool unresolvedLegacyPause = false,
}) {
  final bound = programme.endDate != null && programme.endDate!.isBefore(today)
      ? programme.endDate!
      : today;
  final byDay = <LocalDate, Map<SymptomType, HealthRecord>>{};
  final ordered = [...healthRecords]
    ..sort((left, right) {
      final update = left.updatedAt.compareTo(right.updatedAt);
      return update == 0 ? left.id.compareTo(right.id) : update;
    });
  for (final source in ordered) {
    if (source.userConfirmed &&
        programme.includes(source.experiencedDate) &&
        !source.experiencedDate.isAfter(bound)) {
      byDay.putIfAbsent(source.experiencedDate, () => {})[source.symptom] =
          source;
    }
  }
  final impacts = {
    for (final facts in datedFacts)
      if (facts.impact != null) facts.date: facts.impact!,
  };
  final days = <ProgrammeDayEvidence>[];
  for (
    var date = programme.startDate;
    !date.isAfter(bound);
    date = date.addDays(1)
  ) {
    final config = programme.configOn(date)!;
    final paused = programme.isPausedOn(date);
    final symptomValues = <String, ProgrammeSourceValue>{};
    for (final symptom in config.symptoms) {
      final source = byDay[date]?[symptom];
      if (source != null) {
        symptomValues[ObservationCatalog.definitionFor(
          symptom,
        ).id] = ProgrammeSourceValue(
          sourceId: source.id,
          date: date,
          score: source.severity.score,
          provenance: source.provenance,
        );
      }
    }
    final impact = impacts[date];
    days.add(
      ProgrammeDayEvidence(
        date: date,
        configurationVersion: config.version,
        paused: paused,
        expectedSymptomIds: paused ? [] : config.symptomIds,
        symptoms: symptomValues,
        impact: impact == null
            ? null
            : ProgrammeSourceValue(
                sourceId: impact.id,
                date: date,
                score: impact.value.overall,
                provenance: impact.metadata.provenance,
              ),
      ),
    );
  }
  final dayMap = {for (final day in days) day.date: day};
  final sortedPeriods =
      periods.where((period) => !period.startDate.isAfter(today)).toList()
        ..sort((left, right) => left.startDate.compareTo(right.startDate));
  final cycles = <ProgrammeCycleFacts>[];
  final anchors = <LocalDate>[];
  for (var index = 0; index + 1 < sortedPeriods.length; index++) {
    final period = sortedPeriods[index];
    final end = sortedPeriods[index + 1].startDate.addDays(-1);
    if (period.isOpen ||
        end.isBefore(period.startDate) ||
        end.isBefore(programme.startDate) ||
        period.startDate.isAfter(bound) ||
        end.isAfter(bound)) {
      continue;
    }
    final inside = days.where(
      (day) => !day.date.isBefore(period.startDate) && !day.date.isAfter(end),
    );
    cycles.add(
      ProgrammeCycleFacts(
        periodId: period.id,
        startDate: period.startDate,
        endDate: end,
        expectedFields: inside.fold(
          0,
          (count, day) => count + day.expectedFieldCount,
        ),
        sameDayFields: inside.fold(
          0,
          (count, day) => count + day.sameDayExpectedFields,
        ),
        fullyWithinProgramme:
            !period.startDate.isBefore(programme.startDate) &&
            !end.isAfter(bound),
      ),
    );
    anchors.add(period.startDate);
  }
  final ids = <String>{
    for (final config in programme.configurations) ...config.symptomIds,
    'dailyImpact',
  };
  Iterable<ProgrammeSourceValue> valuesFor(
    String id,
    Iterable<ProgrammeDayEvidence> selected,
  ) sync* {
    for (final day in selected) {
      final source = id == 'dailyImpact' ? day.impact : day.symptoms[id];
      if (source != null) yield source;
    }
  }

  final beforeDays = <ProgrammeDayEvidence>[];
  final afterDays = <ProgrammeDayEvidence>[];
  final comparisonAnchors = anchors.length > 2
      ? anchors.skip(anchors.length - 2)
      : anchors;
  for (final anchor in comparisonAnchors) {
    for (var offset = -14; offset < 0; offset++) {
      final day = dayMap[anchor.addDays(offset)];
      if (day != null) beforeDays.add(day);
    }
    for (var offset = 0; offset < 3; offset++) {
      final day = dayMap[anchor.addDays(offset)];
      if (day != null) afterDays.add(day);
    }
  }
  ProgrammeFieldCoverage coverageFor(
    String id,
    Iterable<ProgrammeDayEvidence> days,
  ) {
    final uniqueDays = {for (final day in days) day.date: day}.values;
    var expected = 0;
    final observed = <ProgrammeSourceValue>[];
    for (final day in uniqueDays) {
      if (day.paused ||
          (id != 'dailyImpact' && !day.expectedSymptomIds.contains(id))) {
        continue;
      }
      expected++;
      final source = id == 'dailyImpact' ? day.impact : day.symptoms[id];
      if (source != null) observed.add(source);
    }
    return ProgrammeFieldCoverage(
      expected: expected,
      recorded: observed.length,
      sameDay: observed
          .where(
            (source) => source.provenance == HealthRecordProvenance.sameDay,
          )
          .length,
      laterRecall: observed
          .where(
            (source) => source.provenance == HealthRecordProvenance.laterRecall,
          )
          .length,
      timingUnknown: observed
          .where(
            (source) =>
                source.provenance == HealthRecordProvenance.timingUnknown,
          )
          .length,
    );
  }

  return RecordProgrammeFacts(
    programme: programme,
    unresolvedLegacyPause: unresolvedLegacyPause,
    days: days,
    cycles: cycles,
    fields: [
      for (final id in ids)
        ProgrammeFieldFacts(
          id: id,
          all: valuesFor(id, days),
          before: valuesFor(id, beforeDays),
          after: valuesFor(id, afterDays),
          overallCoverage: coverageFor(id, days),
          beforeCoverage: coverageFor(id, beforeDays),
          afterCoverage: coverageFor(id, afterDays),
        ),
    ],
  );
}
