import '../../../experience/experience_release_ports.dart';
import '../../cycle/domain/local_date.dart';
import 'cycle_care_summary.dart';

enum RecordReportKind { visitSummary, clinicalPattern }

const recordReportClinicalCategories = <RecordReportCategory>{
  RecordReportCategory.periods,
  RecordReportCategory.symptoms,
  RecordReportCategory.moments,
  RecordReportCategory.careOutcomes,
  RecordReportCategory.privateNotes,
};
const _clinicalSourceTypes = <String>{
  'period_range',
  'symptom_rating',
  'moment_check_in',
  'legacy_care_outcome',
  'capture_note',
};

/// Every exportable category is declared here. New health categories therefore
/// stay excluded until their fields and consent boundary are deliberately added.
enum RecordReportCategory {
  periods('Period dates'),
  bleeding('Bleeding observations'),
  symptoms('Symptom degrees'),
  dailyImpact('Daily impact'),
  moments('Moment check-ins'),
  sleep('Sleep'),
  activity('Activity and rest'),
  appetite('Appetite and cravings'),
  careActions('What I tried'),
  careOutcomes('Self-reported checkbacks'),
  medication('Medication', sensitive: true),
  supplement('Supplements', sensitive: true),
  birthControl('Birth-control methods', sensitive: true),
  emergencyContraception('Emergency contraception', sensitive: true),
  temperature('Manual BBT', sensitive: true),
  contextEvents('Significant events', sensitive: true),
  privateNotes('Private notes and custom context text', sensitive: true),
  careReflections('Care reflections', sensitive: true),
  cycleLetters('Cycle letters', sensitive: true),
  adverseText('Unexpected observations', sensitive: true);

  const RecordReportCategory(this.label, {this.sensitive = false});
  final String label;
  final bool sensitive;
}

const recordReportMetadataFields = <String>{
  'recorded_at_utc',
  'updated_at_utc',
  'timing',
  'original_timing',
  'write_zone',
  'utc_offset_minutes',
  'original_write_zone',
  'original_utc_offset_minutes',
  'vocabulary_version',
};

const _durationFields = <String>{
  'duration_bucket',
  'duration_label',
  'duration_catalog_version',
  'duration_exact_minutes',
};

/// Exact field allowlists apply both to the preview and to native files.
const recordReportValueFields = <RecordReportCategory, Set<String>>{
  RecordReportCategory.periods: {'start_date', 'end_date', 'open'},
  RecordReportCategory.bleeding: {'flow', 'color', 'clots', 'period_id'},
  RecordReportCategory.symptoms: {'symptom', 'degree', 'functional_impacts'},
  RecordReportCategory.dailyImpact: {'overall_degree', 'domains'},
  RecordReportCategory.moments: {'state', 'occurred_at_utc'},
  RecordReportCategory.sleep: {
    'quality_degree',
    'quality_label',
    'signals',
    ..._durationFields,
  },
  RecordReportCategory.activity: {'type', 'intensity', ..._durationFields},
  RecordReportCategory.appetite: {'appetite', 'craving_degree', 'craving_type'},
  RecordReportCategory.careActions: {
    'actions',
    'bundle',
    'status',
    'source',
    'care_source_id',
    'completion_occurred_at_utc',
    'completion_utc_offset_minutes',
    ..._durationFields,
  },
  RecordReportCategory.careOutcomes: {'action_id', 'outcome', 'target_degree'},
  RecordReportCategory.medication: {
    'family',
    'start_date',
    'end_date',
    'archived',
    'episode_id',
    'version_id',
    'version_number',
    'effective_from',
    'exact_name',
    'type',
    'dose',
    'unit',
    'custom_unit',
    'route',
    'custom_route',
    'target',
    'use_status',
    'daily_shortcut',
  },
  RecordReportCategory.supplement: {
    'family',
    'start_date',
    'end_date',
    'archived',
    'episode_id',
    'version_id',
    'version_number',
    'effective_from',
    'exact_name',
    'type',
    'dose',
    'unit',
    'custom_unit',
    'route',
    'custom_route',
    'target',
    'use_status',
    'daily_shortcut',
  },
  RecordReportCategory.birthControl: {
    'family',
    'start_date',
    'end_date',
    'archived',
    'episode_id',
    'version_id',
    'version_number',
    'effective_from',
    'exact_name',
    'method',
    'dose',
    'unit',
    'custom_unit',
    'route',
    'custom_route',
    'target',
    'use_status',
    'daily_shortcut',
  },
  RecordReportCategory.emergencyContraception: {
    'family',
    'start_date',
    'end_date',
    'archived',
    'episode_id',
    'version_id',
    'version_number',
    'effective_from',
    'exact_name',
    'method',
    'dose',
    'unit',
    'custom_unit',
    'route',
    'custom_route',
    'target',
    'use_status',
    'daily_shortcut',
  },
  RecordReportCategory.temperature: {
    'entered_value',
    'unit',
    'method',
    'measured_local_time',
    'quality_flags',
  },
  RecordReportCategory.contextEvents: {'type', 'intensity'},
  RecordReportCategory.privateNotes: {'text', 'source', 'owner_id'},
  RecordReportCategory.careReflections: {
    'observation',
    'need',
    'what_helped',
    'future_self_note',
    'owner_id',
    'reflection',
  },
  RecordReportCategory.cycleLetters: {
    'observation',
    'need',
    'what_helped',
    'future_self_note',
    'starting_period_id',
  },
  RecordReportCategory.adverseText: {'action_id', 'unexpected'},
};

Set<String> recordReportFields(RecordReportCategory category) =>
    Set.unmodifiable({
      ...recordReportMetadataFields,
      ...recordReportValueFields[category]!,
    });

final class RecordReportSource {
  RecordReportSource({
    required this.id,
    required this.category,
    required this.sourceType,
    required this.date,
    required Map<String, String> fields,
    this.intervalEnd,
    this.consentId,
    this.requiredCategory,
  }) : fields = Map.unmodifiable(fields) {
    if (id.isEmpty ||
        sourceType.isEmpty ||
        !recordReportFields(category).containsAll(fields.keys)) {
      throw const FormatException('Undeclared report source fields.');
    }
  }

  final String id;
  final RecordReportCategory category;
  final String sourceType;

  /// Null is unknown. It is never replaced by a save time or current zone.
  final LocalDate? date;
  final LocalDate? intervalEnd;
  final String? consentId;
  final RecordReportCategory? requiredCategory;
  final Map<String, String> fields;
  String get identity => '${category.name}:$sourceType:$id';
}

final class RecordReportSnapshot {
  RecordReportSnapshot({
    required this.summaryInput,
    required Iterable<RecordReportSource> sources,
  }) : sources = List.unmodifiable(sources) {
    if (this.sources.map((s) => s.identity).toSet().length !=
        this.sources.length) {
      throw const FormatException('Duplicate report source.');
    }
  }
  final SummaryExportInput summaryInput;
  final List<RecordReportSource> sources;
}

final class RecordReportSelection {
  RecordReportSelection({
    required this.range,
    this.kind = RecordReportKind.visitSummary,
    this.customRange = false,
    this.allRecords = false,
    Set<RecordReportCategory>? categories,
    Map<RecordReportCategory, Set<String>> fields = const {},
    Set<String> selectedNoteIds = const {},
  }) : categories = Set.unmodifiable(
         categories ?? RecordReportCategory.values.where((c) => !c.sensitive),
       ),
       fields = Map.unmodifiable(
         fields.map((c, v) => MapEntry(c, Set<String>.unmodifiable(v))),
       ),
       selectedNoteIds = Set.unmodifiable(selectedNoteIds) {
    if (range.start.isAfter(range.end) ||
        fields.entries.any(
          (e) => !recordReportFields(e.key).containsAll(e.value),
        )) {
      throw const FormatException('Invalid report selection.');
    }
  }
  final SummaryDateRange range;
  final RecordReportKind kind;
  final bool customRange;
  final bool allRecords;
  final Set<RecordReportCategory> categories;
  final Map<RecordReportCategory, Set<String>> fields;
  final Set<String> selectedNoteIds;
  Set<String> fieldsFor(RecordReportCategory c) =>
      fields[c] ?? recordReportFields(c);
}

final class RecordReportPreview {
  RecordReportPreview({
    required this.selection,
    required Iterable<RecordReportSource> rows,
  }) : rows = List.unmodifiable(rows);
  final RecordReportSelection selection;
  final List<RecordReportSource> rows;

  /// Exact, deterministic content evidence; never sent outside this device.
  /// Export reloads the selected sources and refuses silently changed content.
  String get contentEvidence => rows
      .map((row) {
        final keys = row.fields.keys.toList()..sort();
        String part(String v) => '${v.length}:$v';
        return [
          row.identity,
          row.date?.toString() ?? '',
          ...keys.expand((k) => [k, row.fields[k]!]),
        ].map(part).join();
      })
      .join('\n');
}

RecordReportPreview projectRecordReport(
  RecordReportSnapshot snapshot,
  RecordReportSelection selection,
) {
  final included = <RecordReportSource>[];
  final selected = snapshot.sources.where(
    (s) => selection.categories.contains(s.category),
  );
  for (final source in selected) {
    if (selection.kind == RecordReportKind.clinicalPattern &&
        (!_clinicalSourceTypes.contains(source.sourceType) ||
            source.date == null)) {
      continue;
    }
    if (source.requiredCategory != null &&
        !selection.categories.contains(source.requiredCategory)) {
      continue;
    }
    if (source.consentId != null &&
        !selection.selectedNoteIds.contains(source.consentId)) {
      continue;
    }
    final date = source.date;
    final inRange =
        selection.allRecords ||
        date != null &&
            (selection.range.contains(date) ||
                (source.intervalEnd != null &&
                    !date.isAfter(selection.range.end) &&
                    !source.intervalEnd!.isBefore(selection.range.start)));
    // Selected undated notes are explicit; undated factual events are included
    // only in All records and carry the literal unknown-date label.
    if (!inRange &&
        !(date == null && (source.consentId != null || selection.allRecords))) {
      continue;
    }
    final allowed = selection.fieldsFor(source.category);
    included.add(
      RecordReportSource(
        id: source.id,
        category: source.category,
        sourceType: source.sourceType,
        date: source.date,
        intervalEnd: source.intervalEnd,
        consentId: source.consentId,
        requiredCategory: source.requiredCategory,
        fields: {
          for (final e in source.fields.entries)
            if (allowed.contains(e.key)) e.key: e.value,
        },
      ),
    );
  }
  included.sort((a, b) {
    final date = (a.date?.epochDay ?? 0x7fffffff).compareTo(
      b.date?.epochDay ?? 0x7fffffff,
    );
    return date != 0 ? date : a.identity.compareTo(b.identity);
  });
  return RecordReportPreview(selection: selection, rows: included);
}

LocalDate recordReportMonthsBefore(LocalDate date, int months) {
  final first = DateTime(date.year, date.month - months, 1);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  return LocalDate(
    first.year,
    first.month,
    date.day > lastDay ? lastDay : date.day,
  );
}

bool recordReportRequiresPlus(
  RecordReportSelection selection,
  ReportExportFormat format,
  LocalDate today,
) {
  if (format == ReportExportFormat.csv || format == ReportExportFormat.rawCsv) {
    return false;
  }
  return format == ReportExportFormat.patternReportPdf ||
      selection.kind == RecordReportKind.clinicalPattern ||
      selection.customRange ||
      selection.allRecords ||
      selection.range.start.isBefore(recordReportMonthsBefore(today, 3)) ||
      selection.range.end.isAfter(today);
}

SummaryExportInput recordReportClinicalInput(
  RecordReportSnapshot snapshot,
  RecordReportPreview preview,
) {
  final ids = <String, Set<String>>{};
  for (final row in preview.rows) {
    ids.putIfAbsent(row.sourceType, () => {}).add(row.id);
  }
  final base = snapshot.summaryInput;
  return SummaryExportInput(
    periodDays:
        preview.selection.categories.contains(RecordReportCategory.periods)
        ? base.periodDays
              .map((day) => SummaryPeriodDay(day.date))
              .toList(growable: false)
        : const [],
    predictions: const [],
    healthRecords: base.healthRecords
        .where((r) => ids['symptom_rating']?.contains(r.id) ?? false)
        .toList(),
    checkIns: base.checkIns
        .where((r) => ids['moment_check_in']?.contains(r.id) ?? false)
        .toList(),
    careRecords: base.careRecords
        .where((r) => ids['legacy_care_outcome']?.contains(r.id) ?? false)
        .toList(),
    notes: base.notes
        .where((r) => ids['capture_note']?.contains(r.id) ?? false)
        .toList(),
  );
}

/// Existing ports and test doubles retain their small original contract.
abstract interface class SelectableReportExperiencePort
    implements ReportExperiencePort {
  Future<RecordReportSnapshot> loadRecordSources();
  Future<ExperienceFileReceipt> exportSelected({
    required RecordReportPreview preview,
    required ReportExportFormat format,
    required bool hasPlus,
  });
}
