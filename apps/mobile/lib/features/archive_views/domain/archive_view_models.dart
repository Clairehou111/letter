import '../../care/domain/care_memory.dart';
import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';
import 'archive_repository.dart';

enum ArchiveViewStatus { loading, ready, error }

enum ArchiveViewTab { story, clinical }

enum ArchiveEvidenceState { observed, limited, notRecorded }

enum ArchiveStoryItemKind { careMemory, reflection, futureSelfNote }

final class ArchiveStoryItem {
  const ArchiveStoryItem({
    required this.kind,
    required this.title,
    required this.body,
    required this.sourceLabel,
    required this.occurredAt,
  });

  final ArchiveStoryItemKind kind;
  final String title;
  final String body;
  final String sourceLabel;
  final DateTime occurredAt;
}

final class ArchiveStoryViewModel {
  const ArchiveStoryViewModel({
    required this.cycleId,
    required this.dateRange,
    required this.items,
    required this.evidence,
    required this.missingNote,
  });

  final String cycleId;
  final String dateRange;
  final List<ArchiveStoryItem> items;
  final ArchiveEvidenceState evidence;
  final String? missingNote;
}

final class ArchivePatternMetric {
  const ArchivePatternMetric({
    required this.label,
    required this.confirmedCount,
    required this.observedDays,
    required this.coverageLabel,
    required this.evidence,
    required this.sourceLabel,
    this.highestSeverity,
    this.painDays = 0,
  });

  final String label;
  final int confirmedCount;
  final int observedDays;
  final String coverageLabel;
  final ArchiveEvidenceState evidence;
  final String sourceLabel;
  final SymptomSeverity? highestSeverity;
  final int painDays;
}

final class ArchiveCareOutcomeSummary {
  const ArchiveCareOutcomeSummary({
    required this.actionLabel,
    required this.total,
    required this.better,
    required this.same,
    required this.worse,
    required this.sourceLabel,
  });

  final String actionLabel;
  final int total;
  final int better;
  final int same;
  final int worse;
  final String sourceLabel;
}

final class ArchivePatternViewModel {
  const ArchivePatternViewModel({
    required this.cycleId,
    required this.dateRange,
    required this.metrics,
    required this.careOutcomes,
    required this.evidence,
    required this.missingNote,
  });

  final String cycleId;
  final String dateRange;
  final List<ArchivePatternMetric> metrics;
  final List<ArchiveCareOutcomeSummary> careOutcomes;
  final ArchiveEvidenceState evidence;
  final String? missingNote;
}

final class ArchiveClinicalRecordRow {
  const ArchiveClinicalRecordRow({
    required this.dateLabel,
    required this.symptomLabel,
    required this.severityLabel,
    required this.severityScore,
    required this.painLabel,
    required this.locationLabel,
    required this.impactLabel,
    required this.provenanceLabel,
    required this.sourceLabel,
  });

  final String dateLabel;
  final String symptomLabel;
  final String severityLabel;
  final int severityScore;
  final String painLabel;
  final String locationLabel;
  final String impactLabel;
  final String provenanceLabel;
  final String sourceLabel;
}

final class ArchiveClinicalCareRow {
  const ArchiveClinicalCareRow({
    required this.dateLabel,
    required this.actionLabel,
    required this.outcomeLabel,
    required this.sourceLabel,
  });

  final String dateLabel;
  final String actionLabel;
  final String outcomeLabel;
  final String sourceLabel;
}

final class ArchiveClinicalViewModel {
  const ArchiveClinicalViewModel({
    required this.cycleId,
    required this.dateRange,
    required this.healthRows,
    required this.careRows,
    required this.evidence,
    required this.missingNote,
  });

  final String cycleId;
  final String dateRange;
  final List<ArchiveClinicalRecordRow> healthRows;
  final List<ArchiveClinicalCareRow> careRows;
  final ArchiveEvidenceState evidence;
  final String? missingNote;
}

final class ArchiveCycleSummaryViewModel {
  const ArchiveCycleSummaryViewModel({
    required this.id,
    required this.startDate,
    required this.title,
    required this.dateRange,
    required this.periodDatesLabel,
    required this.coverageLabel,
    required this.missingLabel,
    required this.isComplete,
    required this.searchText,
    required this.story,
    required this.pattern,
    required this.clinical,
  });

  final String id;
  final LocalDate startDate;
  final String title;
  final String dateRange;
  final String periodDatesLabel;
  final String coverageLabel;
  final String? missingLabel;
  final bool isComplete;
  final String searchText;
  final ArchiveStoryViewModel story;
  final ArchivePatternViewModel pattern;
  final ArchiveClinicalViewModel clinical;
}

final class ArchiveViewsViewModel {
  const ArchiveViewsViewModel({
    required this.status,
    required this.completedCycles,
    required this.currentCycle,
  });

  const ArchiveViewsViewModel.loading()
    : status = ArchiveViewStatus.loading,
      completedCycles = const [],
      currentCycle = null;

  const ArchiveViewsViewModel.error()
    : status = ArchiveViewStatus.error,
      completedCycles = const [],
      currentCycle = null;

  final ArchiveViewStatus status;
  final List<ArchiveCycleSummaryViewModel> completedCycles;
  final ArchiveCycleSummaryViewModel? currentCycle;
}

ArchiveViewsViewModel buildArchiveViewsViewModel(ArchiveInput input) {
  final confirmedRecords = input.healthRecords
      .where((record) => record.userConfirmed)
      .toList();
  final cycles =
      input.cycles
          .map(
            (cycle) => _buildCycleViewModel(
              cycle: cycle,
              healthRecords: confirmedRecords,
              careRecords: input.careRecords,
              reflections: input.reflections,
            ),
          )
          .toList()
        ..sort((left, right) => right.startDate.compareTo(left.startDate));

  return ArchiveViewsViewModel(
    status: ArchiveViewStatus.ready,
    completedCycles: [
      for (final cycle in cycles)
        if (cycle.isComplete) cycle,
    ],
    currentCycle: cycles.where((cycle) => !cycle.isComplete).firstOrNull,
  );
}

ArchiveCycleSummaryViewModel _buildCycleViewModel({
  required ArchiveCycleInput cycle,
  required List<HealthRecord> healthRecords,
  required List<CareRecord> careRecords,
  required List<CareReflection> reflections,
}) {
  final end = cycle.endDate;
  final inCycle = healthRecords.where(
    (record) => _isInRange(record.experiencedDate, cycle.startDate, end),
  );
  final careInCycle = careRecords.where(
    (record) => _isInRange(
      LocalDate.fromDateTime(record.occurredAt.toLocal()),
      cycle.startDate,
      end,
    ),
  );
  final careIds = careInCycle.map((record) => record.id).toSet();
  final reflectionsInCycle = reflections.where(
    (reflection) => careIds.contains(reflection.careRecordId),
  );
  final range = _dateRange(cycle.startDate, end);
  final periodDates = cycle.periodDates.map(_formatDate).join(', ');
  final story = _buildStory(cycle, careInCycle, reflectionsInCycle, range);
  final pattern = _buildPattern(cycle, inCycle, careInCycle, range);
  final clinical = _buildClinical(cycle, inCycle, careInCycle, range);
  final observedDays = {
    for (final record in inCycle) record.experiencedDate,
  }.length;
  final cycleDays = end == null
      ? null
      : end.epochDay - cycle.startDate.epochDay + 1;
  final missing = cycleDays == null
      ? 'Current cycle is still open; coverage is not a complete cycle.'
      : observedDays == 0
      ? 'No confirmed symptom records in this cycle.'
      : observedDays < cycleDays
      ? 'Only $observedDays of $cycleDays cycle days have confirmed symptom records.'
      : null;
  final coverage = cycleDays == null
      ? '$observedDays observed days'
      : '$observedDays/$cycleDays days with confirmed records';
  final searchable = [
    cycle.id,
    range,
    ...inCycle.map((record) => record.symptom.label),
    ...careInCycle.map((record) => record.actionLabel),
  ].join(' ').toLowerCase();

  return ArchiveCycleSummaryViewModel(
    id: cycle.id,
    startDate: cycle.startDate,
    title: cycle.isComplete
        ? 'Letter No. ${cycle.number ?? '—'}'
        : 'Current cycle',
    dateRange: range,
    periodDatesLabel: periodDates.isEmpty
        ? 'No period dates recorded'
        : 'Period days: $periodDates',
    coverageLabel: coverage,
    missingLabel: missing,
    isComplete: cycle.isComplete,
    searchText: searchable,
    story: story,
    pattern: pattern,
    clinical: clinical,
  );
}

ArchiveStoryViewModel _buildStory(
  ArchiveCycleInput cycle,
  Iterable<CareRecord> careRecords,
  Iterable<CareReflection> reflections,
  String range,
) {
  final items = <ArchiveStoryItem>[];
  final reflectionsByRecord = {
    for (final reflection in reflections) reflection.careRecordId: reflection,
  };
  for (final record
      in careRecords.toList()
        ..sort((left, right) => left.occurredAt.compareTo(right.occurredAt))) {
    items.add(
      ArchiveStoryItem(
        kind: ArchiveStoryItemKind.careMemory,
        title: record.actionLabel,
        body: 'Outcome recorded: ${_outcomeLabel(record.outcome)}.',
        sourceLabel: 'Care memory · saved locally',
        occurredAt: record.occurredAt,
      ),
    );
    final reflection = reflectionsByRecord[record.id];
    if (reflection == null) {
      continue;
    }
    if (reflection.observation case final observation?) {
      items.add(
        ArchiveStoryItem(
          kind: ArchiveStoryItemKind.reflection,
          title: 'Your reflection',
          body: observation,
          sourceLabel: 'Your words · saved locally',
          occurredAt: reflection.updatedAt,
        ),
      );
    }
    if (reflection.whatHelped case final whatHelped?) {
      items.add(
        ArchiveStoryItem(
          kind: ArchiveStoryItemKind.reflection,
          title: 'What helped',
          body: whatHelped,
          sourceLabel: 'Your words · saved locally',
          occurredAt: reflection.updatedAt,
        ),
      );
    }
    if (reflection.futureSelfNote case final futureSelfNote?) {
      items.add(
        ArchiveStoryItem(
          kind: ArchiveStoryItemKind.futureSelfNote,
          title: 'Note for a future self',
          body: futureSelfNote,
          sourceLabel: 'Your saved note · saved locally',
          occurredAt: reflection.updatedAt,
        ),
      );
    }
  }
  return ArchiveStoryViewModel(
    cycleId: cycle.id,
    dateRange: range,
    items: List.unmodifiable(items),
    evidence: items.isEmpty
        ? ArchiveEvidenceState.notRecorded
        : ArchiveEvidenceState.observed,
    missingNote: items.isEmpty
        ? 'No saved Care memories or reflections.'
        : null,
  );
}

ArchivePatternViewModel _buildPattern(
  ArchiveCycleInput cycle,
  Iterable<HealthRecord> records,
  Iterable<CareRecord> careRecords,
  String range,
) {
  final recordsBySymptom = <SymptomType, List<HealthRecord>>{};
  for (final record in records) {
    recordsBySymptom.putIfAbsent(record.symptom, () => []).add(record);
  }
  final cycleDays = cycle.endDate == null
      ? null
      : cycle.endDate!.epochDay - cycle.startDate.epochDay + 1;
  final metrics = SymptomType.values.where(recordsBySymptom.containsKey).map((
    symptom,
  ) {
    final symptomRecords = recordsBySymptom[symptom]!;
    final days = symptomRecords.map((record) => record.experiencedDate).toSet();
    final highest = symptomRecords
        .map((record) => record.severity)
        .reduce((left, right) => left.score >= right.score ? left : right);
    final painDays = symptomRecords
        .where((record) => record.painRating != null)
        .length;
    return ArchivePatternMetric(
      label: symptom.label,
      confirmedCount: symptomRecords.length,
      observedDays: days.length,
      coverageLabel: cycleDays == null
          ? '${days.length} observed days'
          : '${days.length}/$cycleDays days observed',
      evidence: cycleDays == null || days.length < cycleDays
          ? ArchiveEvidenceState.limited
          : ArchiveEvidenceState.observed,
      sourceLabel: 'Confirmed health records · local only',
      highestSeverity: highest,
      painDays: painDays,
    );
  }).toList();
  final outcomesByAction = <String, List<CareRecord>>{};
  for (final record in careRecords) {
    outcomesByAction.putIfAbsent(record.actionLabel, () => []).add(record);
  }
  final outcomes = outcomesByAction.entries.map((entry) {
    final records = entry.value;
    return ArchiveCareOutcomeSummary(
      actionLabel: entry.key,
      total: records.length,
      better: records
          .where((record) => record.outcome == CareOutcome.better)
          .length,
      same: records
          .where((record) => record.outcome == CareOutcome.same)
          .length,
      worse: records
          .where((record) => record.outcome == CareOutcome.worse)
          .length,
      sourceLabel: 'Care check-back outcomes · local only',
    );
  }).toList();
  final evidence = metrics.isEmpty && outcomes.isEmpty
      ? ArchiveEvidenceState.notRecorded
      : cycle.endDate == null
      ? ArchiveEvidenceState.limited
      : ArchiveEvidenceState.observed;
  return ArchivePatternViewModel(
    cycleId: cycle.id,
    dateRange: range,
    metrics: List.unmodifiable(metrics),
    careOutcomes: List.unmodifiable(outcomes),
    evidence: evidence,
    missingNote: metrics.isEmpty && outcomes.isEmpty
        ? 'No confirmed symptom records or Care outcomes in this cycle.'
        : cycle.endDate == null
        ? 'The current cycle is incomplete; observed counts may change.'
        : null,
  );
}

ArchiveClinicalViewModel _buildClinical(
  ArchiveCycleInput cycle,
  Iterable<HealthRecord> records,
  Iterable<CareRecord> careRecords,
  String range,
) {
  final healthRows = records.toList()
    ..sort(
      (left, right) => left.experiencedDate.compareTo(right.experiencedDate),
    );
  final careRows = careRecords.toList()
    ..sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
  return ArchiveClinicalViewModel(
    cycleId: cycle.id,
    dateRange: range,
    healthRows: List.unmodifiable([
      for (final record in healthRows)
        ArchiveClinicalRecordRow(
          dateLabel: _formatDate(record.experiencedDate),
          symptomLabel: record.symptom.label,
          severityLabel: record.severity.label,
          severityScore: record.severity.score,
          painLabel: record.painRating == null
              ? 'Not recorded'
              : '${record.painRating}/10',
          locationLabel: _labels(
            record.painLocations.map((item) => item.label),
          ),
          impactLabel: _labels(
            record.functionalImpacts.map((item) => item.label),
          ),
          provenanceLabel: record.provenance.label,
          sourceLabel: 'User-confirmed health record · local only',
        ),
    ]),
    careRows: List.unmodifiable([
      for (final record in careRows)
        ArchiveClinicalCareRow(
          dateLabel: _formatDateTime(record.occurredAt),
          actionLabel: record.actionLabel,
          outcomeLabel: _outcomeLabel(record.outcome),
          sourceLabel: 'Saved Care event · local only',
        ),
    ]),
    evidence: healthRows.isEmpty && careRows.isEmpty
        ? ArchiveEvidenceState.notRecorded
        : cycle.endDate == null
        ? ArchiveEvidenceState.limited
        : ArchiveEvidenceState.observed,
    missingNote: healthRows.isEmpty && careRows.isEmpty
        ? 'No confirmed health or Care records in this cycle.'
        : cycle.endDate == null
        ? 'The current cycle is incomplete; this table is not a complete history.'
        : null,
  );
}

bool _isInRange(LocalDate value, LocalDate start, LocalDate? end) {
  return !value.isBefore(start) && (end == null || !value.isAfter(end));
}

String _dateRange(LocalDate start, LocalDate? end) {
  return end == null
      ? '${_formatDate(start)} - In progress'
      : '${_formatDate(start)} - ${_formatDate(end)}';
}

String _formatDate(LocalDate value) =>
    '${value.month}/${value.day}/${value.year}';

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${_formatDate(LocalDate.fromDateTime(local))} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _labels(Iterable<String> values) {
  final list = values.toList();
  return list.isEmpty ? 'Not recorded' : list.join(', ');
}

String _outcomeLabel(CareOutcome outcome) => switch (outcome) {
  CareOutcome.better => 'Better after the action',
  CareOutcome.same => 'About the same after the action',
  CareOutcome.worse => 'Worse after the action',
};
