import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../../care/domain/care_memory.dart';
import '../../clinical/presentation/twin_matrix_report.dart';
import '../../clinical/presentation/twin_matrix_view_model.dart';
import '../../cycle/domain/local_date.dart';
import '../domain/cycle_care_summary.dart';
import '../domain/local_file_share_adapter.dart';
import '../domain/summary_export_repository.dart';

class SummaryExportScreen extends StatefulWidget {
  const SummaryExportScreen({
    required this.repository,
    required this.fileShareAdapter,
    super.key,
    this.now,
  });

  final SummaryExportRepository repository;
  final LocalFileShareAdapter fileShareAdapter;
  final DateTime Function()? now;

  @override
  State<SummaryExportScreen> createState() => _SummaryExportScreenState();
}

class _SummaryExportScreenState extends State<SummaryExportScreen> {
  SummaryExportInput? _input;
  SummaryDateRange? _range;
  final Set<String> _selectedNoteIds = {};
  var _loading = true;
  var _failed = false;
  var _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final input = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _input = input;
        _range = _initialRange(input);
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _chooseRange() async {
    final input = _input;
    final range = _range;
    if (input == null || range == null) return;
    final bounds = _inputBounds(input);
    final chosen = await showDateRangePicker(
      context: context,
      firstDate: bounds.start.asLocalDateTime,
      lastDate: bounds.end.asLocalDateTime,
      initialDateRange: DateTimeRange(
        start: range.start.asLocalDateTime,
        end: range.end.asLocalDateTime,
      ),
      helpText: 'Choose report dates',
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _range = SummaryDateRange(
        start: LocalDate.fromDateTime(chosen.start),
        end: LocalDate.fromDateTime(chosen.end),
      );
      _selectedNoteIds.removeWhere(
        (id) => !input.notes.any(
          (note) => id == note.id && _range!.contains(note.date),
        ),
      );
    });
  }

  Future<void> _export(CycleAndCareSummary summary) async {
    setState(() => _exporting = true);
    final result = await widget.fileShareAdapter.share(
      buildCycleAndCareCsv(summary),
    );
    if (!mounted) return;
    setState(() => _exporting = false);
    final message = switch (result.status) {
      LocalFileShareStatus.shared => 'CSV sent to the local share destination.',
      LocalFileShareStatus.unavailable =>
        'CSV is ready, but this device has no local share destination connected yet.',
      LocalFileShareStatus.failed => 'Letter could not create the local CSV.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildClinicalMatrix() {
    return Container(
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C10),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'clinical matrix preview',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 10,
              fontFamily: 'Courier',
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: TwinMatrixReport(
              viewModel: TwinMatrixViewModel(
                clusters: const [
                  TwinMatrixCluster(
                    label: 'irritability/anger',
                    lutealSeverities: [],
                    mensesSeverities: [],
                  ),
                  TwinMatrixCluster(
                    label: 'depressed mood/anxiety',
                    lutealSeverities: [],
                    mensesSeverities: [],
                  ),
                  TwinMatrixCluster(
                    label: 'social withdrawal',
                    lutealSeverities: [],
                    mensesSeverities: [],
                  ),
                  TwinMatrixCluster(
                    label: 'physical cramps/pain',
                    lutealSeverities: [],
                    mensesSeverities: [],
                  ),
                ],
                cycleLabel: 'enable doctor mode for full matrix',
                exportTimestamp: '',
                totalDays: 28,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'complete two diary cycles to populate the clinical matrix.',
            style: TextStyle(
              color: Color(0xFF555555),
              fontSize: 8,
              fontFamily: 'Courier',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: LetterColors.teal),
        ),
      );
    }
    if (_failed || _input == null || _range == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cycle and Care Summary')),
        body: Center(
          child: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ),
      );
    }
    final summary = buildCycleAndCareSummary(
      input: _input!,
      range: _range!,
      selectedNoteIds: _selectedNoteIds,
    );
    final availableNotes =
        _input!.notes.where((note) => _range!.contains(note.date)).toList()
          ..sort((left, right) => left.date.compareTo(right.date));
    return Scaffold(
      appBar: AppBar(title: const Text('Cycle and Care Summary')),
      body: SafeArea(
        child: ListView(
          key: const Key('summary-export-preview'),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            const LetterSectionTitle(
              eyebrow: 'Local report preview',
              title: 'Review every included record',
            ),
            const SizedBox(height: LetterSpacing.md),
            _Disclosure(text: CycleAndCareSummary.nonDiagnosticDisclosure),
            const SizedBox(height: LetterSpacing.xs),
            _Disclosure(text: CycleAndCareSummary.exclusionDisclosure),
            const SizedBox(height: LetterSpacing.md),
            OutlinedButton.icon(
              key: const Key('summary-select-range'),
              onPressed: _chooseRange,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(summary.range.label),
            ),
            const SizedBox(height: LetterSpacing.lg),
            _PeriodSection(summary: summary),
            const SizedBox(height: LetterSpacing.lg),
            _HealthSection(rows: summary.healthRows),
            const SizedBox(height: LetterSpacing.lg),
            _CareSection(rows: summary.careRows),
            const SizedBox(height: LetterSpacing.lg),
            _NotesSection(
              notes: availableNotes,
              selectedIds: _selectedNoteIds,
              onChanged: (note, selected) => setState(() {
                if (selected) {
                  _selectedNoteIds.add(note.id);
                } else {
                  _selectedNoteIds.remove(note.id);
                }
              }),
            ),
            const SizedBox(height: LetterSpacing.lg),
            _MissingnessSection(values: summary.missingness),
            const SizedBox(height: LetterSpacing.xl),
            _buildClinicalMatrix(),
            const SizedBox(height: LetterSpacing.xl),
            FilledButton.icon(
              key: const Key('summary-export-csv'),
              onPressed: _exporting ? null : () => _export(summary),
              icon: const Icon(Icons.ios_share_outlined),
              label: Text(_exporting ? 'Preparing CSV' : 'Export CSV'),
            ),
          ],
        ),
      ),
    );
  }

  SummaryDateRange _initialRange(SummaryExportInput input) =>
      _inputBounds(input);

  SummaryDateRange _inputBounds(SummaryExportInput input) {
    final dates = <LocalDate>[
      for (final day in input.periodDays) day.date,
      for (final prediction in input.predictions) ...[
        prediction.start,
        prediction.end,
      ],
      for (final record in input.healthRecords) record.experiencedDate,
      for (final record in input.careRecords)
        LocalDate.fromDateTime(record.occurredAt.toLocal()),
      for (final note in input.notes) note.date,
    ]..sort();
    if (dates.isNotEmpty) {
      return SummaryDateRange(start: dates.first, end: dates.last);
    }
    final now = (widget.now ?? DateTime.now)().toLocal();
    final today = LocalDate(now.year, now.month, now.day);
    return SummaryDateRange(start: today, end: today);
  }
}

class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: const BoxDecoration(
        color: LetterColors.blueSoft,
        border: Border(left: BorderSide(color: LetterColors.blue, width: 4)),
      ),
      child: Text(text, style: const TextStyle(height: 1.45)),
    );
  }
}

class _PeriodSection extends StatelessWidget {
  const _PeriodSection({required this.summary});

  final CycleAndCareSummary summary;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Period dates and prediction ranges',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary.periodDays.isEmpty)
            const Text(
              'No observed period days.',
              key: Key('summary-no-period-days'),
            )
          else
            for (final day in summary.periodDays)
              Text('Observed period day: ${summaryDateLabel(day.date)}'),
          if (summary.predictions.isNotEmpty) ...[
            const SizedBox(height: LetterSpacing.xs),
            for (final prediction in summary.predictions)
              Text(
                'Prediction range: ${summaryDateLabel(prediction.start)} to ${summaryDateLabel(prediction.end)} · ${prediction.sourceLabel}',
              ),
          ],
        ],
      ),
    );
  }
}

class _HealthSection extends StatelessWidget {
  const _HealthSection({required this.rows});

  final List<SummaryHealthRow> rows;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Confirmed health records',
      child: rows.isEmpty
          ? const Text(
              'No confirmed health records.',
              key: Key('summary-no-health'),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final row in rows) ...[
                  Text(
                    '${summaryDateLabel(row.date)} · ${row.symptom.label} · ${row.severity.label} (${row.severity.score}/6)',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text('Cycle day: ${row.cycleDay ?? 'Not available'}'),
                  Text('Pain: ${row.painRating?.toString() ?? 'Not recorded'}'),
                  Text(
                    'Location: ${_labels(row.painLocations.map((item) => item.label))}',
                  ),
                  Text(
                    'Impact: ${_labels(row.functionalImpacts.map((item) => item.label))}',
                  ),
                  Text(
                    'Provenance: ${row.provenance.label} · ${row.sourceLabel}',
                  ),
                  const Divider(),
                ],
              ],
            ),
    );
  }
}

class _CareSection extends StatelessWidget {
  const _CareSection({required this.rows});

  final List<SummaryCareRow> rows;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Care events and outcomes',
      child: rows.isEmpty
          ? const Text('No saved Care events.', key: Key('summary-no-care'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final row in rows) ...[
                  Text(
                    row.actionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${summaryDateLabel(row.date)} · Cycle day: ${row.cycleDay ?? 'Not available'}',
                  ),
                  Text(
                    'Outcome: ${_outcomeLabel(row.outcome)} · ${row.provenance.label}',
                  ),
                  Text(row.sourceLabel),
                  const Divider(),
                ],
              ],
            ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({
    required this.notes,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<SummarySelectableNote> notes;
  final Set<String> selectedIds;
  final void Function(SummarySelectableNote note, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Choose notes to include',
      child: notes.isEmpty
          ? const Text('No saved notes in this date range.')
          : Column(
              children: [
                for (final note in notes)
                  Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      key: Key('summary-note-${note.id}'),
                      contentPadding: EdgeInsets.zero,
                      value: selectedIds.contains(note.id),
                      onChanged: (selected) =>
                          onChanged(note, selected ?? false),
                      title: Text(
                        '${note.label} · ${summaryDateLabel(note.date)}',
                      ),
                      subtitle: Text(note.text),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MissingnessSection extends StatelessWidget {
  const _MissingnessSection({required this.values});

  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Missing or not included',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final value in values) Text('• $value')],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: LetterSpacing.sm),
          child,
        ],
      ),
    );
  }
}

String _labels(Iterable<String> labels) {
  final values = labels.toList()..sort();
  return values.isEmpty ? 'Not recorded' : values.join(', ');
}

String _outcomeLabel(CareOutcome outcome) => switch (outcome) {
  CareOutcome.better => 'Better',
  CareOutcome.same => 'Same',
  CareOutcome.worse => 'Worse',
};
