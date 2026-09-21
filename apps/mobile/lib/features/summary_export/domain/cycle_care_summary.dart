import '../../care/domain/care_memory.dart';
import '../../check_in/domain/moment_check_in.dart';
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

/// A contiguous run of observed period dates for compact display and export.
final class SummaryObservedPeriodRange {
  const SummaryObservedPeriodRange({required this.start, required this.end});

  final LocalDate start;
  final LocalDate end;

  int get dayCount => end.epochDay - start.epochDay + 1;
}

List<SummaryObservedPeriodRange> observedPeriodRanges(
  Iterable<SummaryPeriodDay> days,
) {
  final dates = days.map((day) => day.date).toList()..sort();
  if (dates.isEmpty) return const [];

  final ranges = <SummaryObservedPeriodRange>[];
  var start = dates.first;
  var end = start;
  for (final date in dates.skip(1)) {
    if (date.epochDay <= end.epochDay) continue;
    if (date.epochDay == end.epochDay + 1) {
      end = date;
      continue;
    }
    ranges.add(SummaryObservedPeriodRange(start: start, end: end));
    start = date;
    end = date;
  }
  ranges.add(SummaryObservedPeriodRange(start: start, end: end));
  return List.unmodifiable(ranges);
}

/// One completed menstrual cycle, bounded by two observed period starts.
///
/// [end] is the day immediately before the next observed period start. The
/// open span after the latest start is deliberately not a completed cycle.
final class SummaryCompletedCycle {
  const SummaryCompletedCycle({required this.start, required this.end});

  final LocalDate start;
  final LocalDate end;

  int get dayCount => end.epochDay - start.epochDay + 1;

  bool contains(LocalDate date) => !date.isBefore(start) && !date.isAfter(end);

  bool overlaps(SummaryDateRange range) =>
      !end.isBefore(range.start) && !start.isAfter(range.end);
}

/// Canonical cycle evidence derived from observed period dates.
///
/// The three counts intentionally remain distinct:
///
/// * [periodStartCount] is the number of observed bleeding starts.
/// * [completedCycleCount] is the number of start-to-next-start spans.
/// * matrix coverage is computed later from cycles that actually contain
///   mapped symptom ratings; it must never be presented as either count.
///
/// Keeping all date anchoring here prevents Reports, PDF, Today check-ins,
/// symptoms, and Care outcomes from inventing slightly different cycle days.
final class SummaryCycleEvidence {
  const SummaryCycleEvidence._({
    required this.periodRanges,
    required this.periodStarts,
    required this.completedCycles,
  });

  factory SummaryCycleEvidence.fromPeriodDays(
    Iterable<SummaryPeriodDay> periodDays,
  ) {
    final ranges = observedPeriodRanges(periodDays);
    final starts = <LocalDate>[for (final range in ranges) range.start];
    final completed = <SummaryCompletedCycle>[
      for (var index = 0; index + 1 < starts.length; index++)
        SummaryCompletedCycle(
          start: starts[index],
          end: starts[index + 1].addDays(-1),
        ),
    ];
    return SummaryCycleEvidence._(
      periodRanges: List.unmodifiable(ranges),
      periodStarts: List.unmodifiable(starts),
      completedCycles: List.unmodifiable(completed),
    );
  }

  final List<SummaryObservedPeriodRange> periodRanges;
  final List<LocalDate> periodStarts;
  final List<SummaryCompletedCycle> completedCycles;

  int get periodStartCount => periodStarts.length;
  int get completedCycleCount => completedCycles.length;
  LocalDate? get currentCycleStart =>
      periodStarts.isEmpty ? null : periodStarts.last;

  int completedCycleCountIn(SummaryDateRange range) =>
      completedCycles.where((cycle) => cycle.overlaps(range)).length;

  LocalDate? cycleStartFor(LocalDate date) {
    LocalDate? latest;
    for (final start in periodStarts) {
      if (start.isAfter(date)) break;
      latest = start;
    }
    return latest;
  }

  int? cycleDayFor(LocalDate date) {
    final start = cycleStartFor(date);
    return start == null ? null : date.epochDay - start.epochDay + 1;
  }

  int? daysBeforeNextPeriod(LocalDate date, {int windowDays = 14}) {
    LocalDate? next;
    for (final start in periodStarts) {
      if (start.isAfter(date)) {
        next = start;
        break;
      }
    }
    if (next == null) return null;
    final distance = date.epochDay - next.epochDay;
    return distance >= -windowDays && distance <= -1 ? distance : null;
  }
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
    required this.checkIns,
    required this.careRecords,
    required this.notes,
  });

  final List<SummaryPeriodDay> periodDays;
  final List<SummaryPredictionRange> predictions;
  final List<HealthRecord> healthRecords;
  final List<MomentCheckIn> checkIns;
  final List<CareRecord> careRecords;
  final List<SummarySelectableNote> notes;
}

final class SummaryHealthRow {
  const SummaryHealthRow({
    required this.id,
    required this.date,
    required this.recordedAt,
    required this.cycleStartDate,
    required this.cycleDay,
    required this.daysBeforeMenses,
    required this.symptom,
    required this.severity,
    required this.functionalImpacts,
    required this.provenance,
    required this.sourceLabel,
  });

  final String id;
  final LocalDate date;
  final DateTime recordedAt;
  final LocalDate? cycleStartDate;
  final int? cycleDay;
  final int? daysBeforeMenses;
  final SymptomType symptom;
  final SymptomSeverity severity;
  final Set<FunctionalImpact> functionalImpacts;
  final SummaryRecordProvenance provenance;
  final String sourceLabel;
}

final class SummaryCareRow {
  const SummaryCareRow({
    required this.id,
    required this.date,
    required this.recordedAt,
    required this.cycleStartDate,
    required this.cycleDay,
    required this.daysBeforeMenses,
    required this.actionLabel,
    required this.outcome,
    required this.provenance,
    required this.sourceLabel,
  });

  final String id;
  final LocalDate date;
  final DateTime recordedAt;
  final LocalDate? cycleStartDate;
  final int? cycleDay;
  final int? daysBeforeMenses;
  final String actionLabel;
  final CareOutcome outcome;
  final SummaryRecordProvenance provenance;
  final String sourceLabel;
}

/// A Today check-in is qualitative evidence, not a symptom severity rating.
///
/// It remains separate from [SummaryHealthRow] so a person who records both
/// "Anxious" and a 1–5 symptom on the same day is represented faithfully
/// without inventing a score or double-counting either observation.
final class SummaryCheckInRow {
  const SummaryCheckInRow({
    required this.id,
    required this.date,
    required this.recordedAt,
    required this.cycleStartDate,
    required this.cycleDay,
    required this.daysBeforeMenses,
    required this.state,
    required this.sourceLabel,
  });

  final String id;
  final LocalDate date;
  final DateTime recordedAt;
  final LocalDate? cycleStartDate;
  final int? cycleDay;
  final int? daysBeforeMenses;
  final MomentCheckInState state;
  final String sourceLabel;

  bool get isDifficult => state.isDifficult;
}

final class CycleAndCareSummary {
  const CycleAndCareSummary({
    required this.range,
    required this.periodDays,
    required this.predictions,
    required this.healthRows,
    required this.checkInRows,
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
  final List<SummaryCheckInRow> checkInRows;
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
  final cycleEvidence = SummaryCycleEvidence.fromPeriodDays(allPeriodDays);
  final latestDailyHealth = <String, HealthRecord>{};
  for (final record in input.healthRecords.where(
    (record) => record.userConfirmed && range.contains(record.experiencedDate),
  )) {
    final key = '${record.symptom.name}:${record.experiencedDate.epochDay}';
    final previous = latestDailyHealth[key];
    if (previous == null || record.updatedAt.isAfter(previous.updatedAt)) {
      latestDailyHealth[key] = record;
    }
  }
  final healthRows =
      latestDailyHealth.values
          .map(
            (record) => SummaryHealthRow(
              id: record.id,
              date: record.experiencedDate,
              recordedAt: record.recordedAt,
              cycleStartDate: cycleEvidence.cycleStartFor(
                record.experiencedDate,
              ),
              cycleDay: cycleEvidence.cycleDayFor(record.experiencedDate),
              daysBeforeMenses: cycleEvidence.daysBeforeNextPeriod(
                record.experiencedDate,
              ),
              symptom: record.symptom,
              severity: record.severity,
              functionalImpacts: Set.unmodifiable(record.functionalImpacts),
              provenance: record.provenance == HealthRecordProvenance.sameDay
                  ? SummaryRecordProvenance.sameDay
                  : SummaryRecordProvenance.laterRecall,
              sourceLabel: 'User-confirmed health record · local only',
            ),
          )
          .toList()
        ..sort(_compareHealthRows);
  final checkInRows =
      input.checkIns
          .where(
            (checkIn) => range.contains(
              LocalDate.fromDateTime(checkIn.occurredAt.toLocal()),
            ),
          )
          .map((checkIn) {
            final date = LocalDate.fromDateTime(checkIn.occurredAt.toLocal());
            return SummaryCheckInRow(
              id: checkIn.id,
              date: date,
              recordedAt: checkIn.occurredAt,
              cycleStartDate: cycleEvidence.cycleStartFor(date),
              cycleDay: cycleEvidence.cycleDayFor(date),
              daysBeforeMenses: cycleEvidence.daysBeforeNextPeriod(date),
              state: checkIn.state,
              sourceLabel: 'Today check-in · local only',
            );
          })
          .toList()
        ..sort(_compareCheckInRows);
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
              id: record.id,
              date: date,
              recordedAt: record.occurredAt,
              cycleStartDate: cycleEvidence.cycleStartFor(date),
              cycleDay: cycleEvidence.cycleDayFor(date),
              daysBeforeMenses: cycleEvidence.daysBeforeNextPeriod(date),
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
    checkInRows: List.unmodifiable(checkInRows),
    careRows: List.unmodifiable(careRows),
    notes: List.unmodifiable(notes),
    missingness: List.unmodifiable(missingness),
  );
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

int _compareCheckInRows(SummaryCheckInRow left, SummaryCheckInRow right) {
  final dateComparison = left.date.compareTo(right.date);
  if (dateComparison != 0) return dateComparison;
  final timeComparison = left.recordedAt.compareTo(right.recordedAt);
  return timeComparison != 0 ? timeComparison : left.id.compareTo(right.id);
}

String summaryDateLabel(LocalDate date) => _dateLabel(date);

String summaryDateTimeLabel(DateTime value) {
  final local = value.toLocal();
  return '${summaryDateLabel(LocalDate.fromDateTime(local))} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _dateLabel(LocalDate date) => '${date.month}/${date.day}/${date.year}';

extension on MomentCheckInState {
  bool get isDifficult => switch (this) {
    MomentCheckInState.low ||
    MomentCheckInState.irritable ||
    MomentCheckInState.anxious ||
    MomentCheckInState.overwhelmed ||
    MomentCheckInState.exhausted ||
    MomentCheckInState.physical => true,
    _ => false,
  };
}
