import '../../care/domain/care_memory.dart';
import '../../care/domain/care_mode.dart';
import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_record.dart';
import '../../health_records/domain/health_record.dart';
import 'pattern_source.dart';
import 'personal_pattern.dart';

/// Builds factual views from a fresh source snapshot. Nothing returned here is
/// persisted as a health record, so source deletion is reflected on the next run.
final class PersonalPatternEngine {
  const PersonalPatternEngine();

  PersonalPatternAnalysis analyze(
    PatternSourceSnapshot source, {
    CareMode? selectedCareMode,
  }) {
    return PersonalPatternAnalysis(
      symptomPatterns: _symptomPatterns(source),
      supportActions: _supportActions(
        source,
        selectedCareMode: selectedCareMode,
      ),
      selectedCareMode: selectedCareMode,
    );
  }

  List<ObservedSymptomPattern> _symptomPatterns(PatternSourceSnapshot source) {
    final confirmed = source.healthRecords.where(
      (record) => record.userConfirmed,
    );
    final grouped = <SymptomType, List<HealthRecord>>{};
    for (final record in confirmed) {
      grouped.putIfAbsent(record.symptom, () => []).add(record);
    }

    final patterns = <ObservedSymptomPattern>[];
    for (final entry in grouped.entries) {
      final records = [...entry.value]
        ..sort((left, right) {
          final date = left.experiencedDate.compareTo(right.experiencedDate);
          return date == 0 ? left.recordedAt.compareTo(right.recordedAt) : date;
        });
      if (records.length < 2) {
        continue;
      }

      final dates = records.map((record) => record.experiencedDate).toSet();
      final sortedDates = dates.toList()..sort();
      final severityCounts = <SymptomSeverity, int>{};
      final painLocationCounts = <PainLocation, int>{};
      final functionalImpactCounts = <FunctionalImpact, int>{};
      for (final record in records) {
        severityCounts.update(
          record.severity,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        for (final location in record.painLocations) {
          painLocationCounts.update(
            location,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
        for (final impact in record.functionalImpacts) {
          functionalImpactCounts.update(
            impact,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
      final cycleDays = records
          .map((record) => _cycleDayFor(record.experiencedDate, source.periods))
          .whereType<PatternCycleDayObservation>()
          .toList();

      patterns.add(
        ObservedSymptomPattern(
          id: 'symptom:${entry.key.name}',
          symptom: entry.key,
          count: records.length,
          firstDate: sortedDates.first,
          lastDate: sortedDates.last,
          coveredDates: List.unmodifiable(sortedDates),
          severityCounts: Map.unmodifiable(severityCounts),
          painLocationCounts: Map.unmodifiable(painLocationCounts),
          functionalImpactCounts: Map.unmodifiable(functionalImpactCounts),
          sources: List.unmodifiable(
            records.map(
              (record) => PatternSourceReference(
                id: record.id,
                kind: PatternSourceKind.healthRecord,
                date: record.experiencedDate,
              ),
            ),
          ),
          cycleDayObservations: List.unmodifiable(cycleDays),
          severityByDaysBeforeMenses: _buildDaysBeforeMensesMatrix(
            records,
            source.periods,
          ),
        ),
      );
    }
    patterns.sort(
      (left, right) => left.symptom.label.compareTo(right.symptom.label),
    );
    return List.unmodifiable(patterns);
  }

  List<SupportActionPattern> _supportActions(
    PatternSourceSnapshot source, {
    required CareMode? selectedCareMode,
  }) {
    final records = source.careRecords.where(
      (record) => selectedCareMode == null || record.mode == selectedCareMode,
    );
    final grouped = <String, List<CareRecord>>{};
    for (final record in records) {
      final key = '${record.mode.name}:${record.actionId}';
      grouped.putIfAbsent(key, () => []).add(record);
    }

    final patterns = <SupportActionPattern>[];
    for (final entry in grouped.entries) {
      final records = [...entry.value]
        ..sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
      // A prior action can be returned after one explicit check-back. The
      // repeated-pattern rule applies to symptom patterns, not the user's
      // explicitly saved Care history.
      if (records.isEmpty) {
        continue;
      }
      final dates =
          records
              .map((record) => LocalDate.fromDateTime(record.occurredAt))
              .toSet()
              .toList()
            ..sort();
      final reflections = <AuthoredReflectionEvidence>[];
      for (final record in records) {
        final reflection = source.careReflections
            .where((item) => item.careRecordId == record.id)
            .firstOrNull;
        final text = _reflectionText(reflection);
        if (text != null) {
          reflections.add(
            AuthoredReflectionEvidence(careRecordId: record.id, text: text),
          );
        }
      }
      patterns.add(
        SupportActionPattern(
          id: 'action:${entry.key}',
          actionId: records.first.actionId,
          actionLabel: records.first.actionLabel,
          mode: records.first.mode,
          count: records.length,
          firstDate: dates.first,
          lastDate: dates.last,
          coveredDates: List.unmodifiable(dates),
          betterCount: records
              .where((record) => record.outcome == CareOutcome.better)
              .length,
          sameCount: records
              .where((record) => record.outcome == CareOutcome.same)
              .length,
          worseCount: records
              .where((record) => record.outcome == CareOutcome.worse)
              .length,
          sources: List.unmodifiable(
            records.map(
              (record) => PatternSourceReference(
                id: record.id,
                kind: PatternSourceKind.careRecord,
                date: LocalDate.fromDateTime(record.occurredAt),
              ),
            ),
          ),
          pinned: records.any((record) => record.pinned),
          reflections: List.unmodifiable(reflections),
        ),
      );
    }
    patterns.sort((left, right) => right.count.compareTo(left.count));
    return List.unmodifiable(patterns);
  }

  PatternCycleDayObservation? _cycleDayFor(
    LocalDate date,
    List<PeriodRecord> periods,
  ) {
    final starts =
        periods
            .where((period) => !period.startDate.isAfter(date))
            .map((period) => period.startDate)
            .toList()
          ..sort();
    if (starts.isEmpty) {
      return null;
    }
    final mostRecentStart = starts.last;
    final cycleDay = date.epochDay - mostRecentStart.epochDay + 1;

    // Negative index: days before the NEXT period start.
    // Find the first period start strictly after this date.
    final nextStarts =
        periods
            .where((period) => period.startDate.isAfter(date))
            .map((period) => period.startDate)
            .toList()
          ..sort();
    final int? daysBeforeMenses = nextStarts.isEmpty
        ? null
        : date.epochDay - nextStarts.first.epochDay;

    return PatternCycleDayObservation(
      date: date,
      cycleDay: cycleDay,
      daysBeforeMenses: daysBeforeMenses,
    );
  }

  /// Builds a severity-by-days-before-menses matrix (negative index).
  /// Aggregates severity scores for each day in the luteal window (-14 to -1)
  /// across all cycles where a subsequent period start is known.
  Map<int, double> _buildDaysBeforeMensesMatrix(
    List<HealthRecord> records,
    List<PeriodRecord> periods,
  ) {
    final severityByDay = <int, List<int>>{};
    for (final record in records) {
      final observation = _cycleDayFor(record.experiencedDate, periods);
      final daysBefore = observation?.daysBeforeMenses;
      if (daysBefore == null || daysBefore < -14 || daysBefore > -1) {
        continue;
      }
      severityByDay.putIfAbsent(daysBefore, () => []).add(record.severity.score);
    }
    final result = <int, double>{};
    for (final entry in severityByDay.entries) {
      final avg = entry.value.fold<int>(0, (sum, v) => sum + v) /
          entry.value.length;
      result[entry.key] = double.parse(avg.toStringAsFixed(1));
    }
    return Map.unmodifiable(result);
  }

  String? _reflectionText(CareReflection? reflection) {
    if (reflection == null) {
      return null;
    }
    final parts = [
      reflection.observation,
      reflection.whatHelped,
      reflection.futureSelfNote,
    ].whereType<String>().where((text) => text.trim().isNotEmpty).toList();
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' ');
  }
}
