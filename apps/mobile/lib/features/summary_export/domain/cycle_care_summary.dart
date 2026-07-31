import '../../care/domain/care_memory.dart';
import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';

enum SummaryRecordProvenance {
  sameDay('Same day'),
  laterRecall('Later recall'),
  factualCareEvent('Factual Care event');

  const SummaryRecordProvenance(this.label);

  final String label;
}

final class SummaryDateRange {
  const SummaryDateRange({required this.start, required this.end});

  final LocalDate start;
  final LocalDate end;

  bool contains(LocalDate date) => !date.isBefore(start) && !date.isAfter(end);

  String get label => '${_dateLabel(start)} to ${_dateLabel(end)}';
}

/// A factual period day. It is not a prediction or inferred phase marker.
final class SummaryPeriodDay {
  const SummaryPeriodDay(this.date);

  final LocalDate date;
}

/// A stored prediction is kept visibly separate from observed period dates.
final class SummaryPredictionRange {
  const SummaryPredictionRange({
    required this.start,
    required this.end,
    required this.sourceLabel,
  });

  final LocalDate start;
  final LocalDate end;
  final String sourceLabel;
}

/// A saved note is never included until the user selects it for this export.
final class SummarySelectableNote {
  const SummarySelectableNote({
    required this.id,
    required this.date,
    required this.label,
    required this.text,
    required this.sourceLabel,
  });

  final String id;
  final LocalDate date;
  final String label;
  final String text;
  final String sourceLabel;
}

final class SummaryExportInput {
  const SummaryExportInput({
    required this.periodDays,
    required this.predictions,
    required this.healthRecords,
    required this.careRecords,
    required this.notes,
  });

  final List<SummaryPeriodDay> periodDays;
  final List<SummaryPredictionRange> predictions;
  final List<HealthRecord> healthRecords;
  final List<CareRecord> careRecords;
  final List<SummarySelectableNote> notes;
}

final class SummaryHealthRow {
  const SummaryHealthRow({
    required this.date,
    required this.cycleDay,
    required this.daysBeforeMenses,
    required this.symptom,
    required this.severity,
    required this.painRating,
    required this.painLocations,
    required this.functionalImpacts,
    required this.provenance,
    required this.sourceLabel,
  });

  final LocalDate date;
  final int? cycleDay;
  final int? daysBeforeMenses;
  final SymptomType symptom;
  final SymptomSeverity severity;
  final int? painRating;
  final Set<PainLocation> painLocations;
  final Set<FunctionalImpact> functionalImpacts;
  final SummaryRecordProvenance provenance;
  final String sourceLabel;
}

final class SummaryCareRow {
  const SummaryCareRow({
    required this.date,
    required this.cycleDay,
    required this.actionLabel,
    required this.outcome,
    required this.provenance,
    required this.sourceLabel,
  });

  final LocalDate date;
  final int? cycleDay;
  final String actionLabel;
  final CareOutcome outcome;
  final SummaryRecordProvenance provenance;
  final String sourceLabel;
}

final class CycleAndCareSummary {
  const CycleAndCareSummary({
    required this.range,
    required this.periodDays,
    required this.predictions,
    required this.healthRows,
    required this.careRows,
    required this.notes,
    required this.missingness,
  });

  static const nonDiagnosticDisclosure =
      'This is a user-recorded summary of local observations. It does not diagnose PMS, PMDD, pain conditions, or any other disorder.';

  static const exclusionDisclosure =
      'Excluded: drafts, unsaved text, clipboard contents, unresolved candidates, medication, contacts, and inferred causes.';

  final SummaryDateRange range;
  final List<SummaryPeriodDay> periodDays;
  final List<SummaryPredictionRange> predictions;
  final List<SummaryHealthRow> healthRows;
  final List<SummaryCareRow> careRows;
  final List<SummarySelectableNote> notes;
  final List<String> missingness;
}

CycleAndCareSummary buildCycleAndCareSummary({
  required SummaryExportInput input,
  required SummaryDateRange range,
  required Set<String> selectedNoteIds,
}) {
  final periodDays =
      input.periodDays.where((day) => range.contains(day.date)).toList()
        ..sort((left, right) => left.date.compareTo(right.date));
  final allPeriodDays = [...input.periodDays]
    ..sort((left, right) => left.date.compareTo(right.date));
  final healthRows =
      input.healthRecords
          .where(
            (record) =>
                record.userConfirmed && range.contains(record.experiencedDate),
          )
          .map(
            (record) => SummaryHealthRow(
              date: record.experiencedDate,
              cycleDay: _cycleDayFor(record.experiencedDate, allPeriodDays),
              daysBeforeMenses: _daysBeforeNextPeriod(
                record.experiencedDate,
                allPeriodDays,
              ),
              symptom: record.symptom,
              severity: record.severity,
              painRating: record.painRating,
              painLocations: Set.unmodifiable(record.painLocations),
              functionalImpacts: Set.unmodifiable(record.functionalImpacts),
              provenance: record.provenance == HealthRecordProvenance.sameDay
                  ? SummaryRecordProvenance.sameDay
                  : SummaryRecordProvenance.laterRecall,
              sourceLabel: 'User-confirmed health record · local only',
            ),
          )
          .toList()
        ..sort(_compareHealthRows);
  final careRows =
      input.careRecords
          .where(
            (record) => range.contains(
              LocalDate.fromDateTime(record.occurredAt.toLocal()),
            ),
          )
          .map((record) {
            final date = LocalDate.fromDateTime(record.occurredAt.toLocal());
            return SummaryCareRow(
              date: date,
              cycleDay: _cycleDayFor(date, allPeriodDays),
              actionLabel: record.actionLabel,
              outcome: record.outcome,
              provenance: SummaryRecordProvenance.factualCareEvent,
              sourceLabel: 'Saved Care event · local only',
            );
          })
          .toList()
        ..sort(_compareCareRows);
  final predictions =
      input.predictions
          .where(
            (prediction) =>
                !prediction.end.isBefore(range.start) &&
                !prediction.start.isAfter(range.end),
          )
          .toList()
        ..sort((left, right) => left.start.compareTo(right.start));
  final notes =
      input.notes
          .where(
            (note) =>
                selectedNoteIds.contains(note.id) && range.contains(note.date),
          )
          .toList()
        ..sort((left, right) {
          final dateComparison = left.date.compareTo(right.date);
          return dateComparison != 0
              ? dateComparison
              : left.id.compareTo(right.id);
        });

  final missingness = <String>[
    if (periodDays.isEmpty) 'No observed period days in this date range.',
    if (predictions.isEmpty) 'No prediction ranges included.',
    if (healthRows.isEmpty) 'No confirmed health records in this date range.',
    if (careRows.isEmpty) 'No saved Care events in this date range.',
    if (notes.isEmpty) 'No user-selected notes included.',
  ];
  return CycleAndCareSummary(
    range: range,
    periodDays: List.unmodifiable(periodDays),
    predictions: List.unmodifiable(predictions),
    healthRows: List.unmodifiable(healthRows),
    careRows: List.unmodifiable(careRows),
    notes: List.unmodifiable(notes),
    missingness: List.unmodifiable(missingness),
  );
}

int? _cycleDayFor(LocalDate date, List<SummaryPeriodDay> periodDays) {
  LocalDate? latestStart;
  LocalDate? previous;
  for (final periodDay in periodDays) {
    if (periodDay.date.isAfter(date)) break;
    if (previous == null || periodDay.date.epochDay != previous.epochDay + 1) {
      latestStart = periodDay.date;
    }
    previous = periodDay.date;
  }
  return latestStart == null ? null : date.epochDay - latestStart.epochDay + 1;
}

int? _daysBeforeNextPeriod(LocalDate date, List<SummaryPeriodDay> periodDays) {
  LocalDate? previous;
  final starts = <LocalDate>[];
  for (final periodDay in periodDays) {
    if (previous == null || periodDay.date.epochDay != previous.epochDay + 1) {
      starts.add(periodDay.date);
    }
    previous = periodDay.date;
  }
  final laterStarts = starts.where((start) => start.isAfter(date)).toList()
    ..sort();
  if (laterStarts.isEmpty) return null;
  final distance = date.epochDay - laterStarts.first.epochDay;
  return distance >= -14 && distance <= -1 ? distance : null;
}

int _compareHealthRows(SummaryHealthRow left, SummaryHealthRow right) {
  final dateComparison = left.date.compareTo(right.date);
  if (dateComparison != 0) return dateComparison;
  return left.symptom.index.compareTo(right.symptom.index);
}

int _compareCareRows(SummaryCareRow left, SummaryCareRow right) {
  final dateComparison = left.date.compareTo(right.date);
  return dateComparison != 0
      ? dateComparison
      : left.actionLabel.compareTo(right.actionLabel);
}

String summaryDateLabel(LocalDate date) => _dateLabel(date);

String _dateLabel(LocalDate date) => '${date.month}/${date.day}/${date.year}';
