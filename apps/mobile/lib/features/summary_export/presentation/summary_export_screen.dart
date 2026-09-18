import 'package:flutter/material.dart';

import '../../../design_system/lovable/health_record_kit.dart' as health_kit;
import '../../../design_system/lovable/letter_kit.dart' as lovable_kit;
import '../../../design_system/lovable/letter_theme.dart' as lovable_theme;
import '../../../design_system/letter_theme.dart';
import '../../care/domain/care_memory.dart';
import '../../clinical/presentation/twin_matrix_report.dart';
import '../../clinical/presentation/twin_matrix_view_model.dart';
import '../../cycle/domain/local_date.dart';
import '../domain/cycle_care_summary.dart';
import '../domain/cycle_care_pdf.dart';
import '../domain/local_file_share_adapter.dart';
import '../domain/summary_export_repository.dart';
import 'twin_matrix_summary_adapter.dart';

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
  LocalFileShareResult? _shareResult;
  String? _shareFormat;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
      _shareResult = null;
      _shareFormat = null;
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
      _shareResult = null;
      _shareFormat = null;
      _selectedNoteIds.removeWhere(
        (id) => !input.notes.any(
          (note) => id == note.id && _range!.contains(note.date),
        ),
      );
    });
  }

  Future<void> _exportCsv(CycleAndCareSummary summary) async {
    _beginExport('CSV');
    try {
      await _shareFile(buildCycleAndCareCsv(summary), 'CSV');
    } on Object {
      _finishExport('CSV', const LocalFileShareResult.failed());
    }
  }

  Future<void> _exportPdf(CycleAndCareSummary summary) async {
    _beginExport('PDF');
    try {
      final generatedAt = (widget.now ?? DateTime.now)().toLocal();
      final pdf = await buildCycleAndCarePdf(
        summary: summary,
        matrix: _buildMatrix(summary, generatedAt: generatedAt),
        generatedAt: _dateStamp(generatedAt),
      );
      await _shareFile(pdf, 'PDF');
    } on Object {
      _finishExport('PDF', const LocalFileShareResult.failed());
    }
  }

  void _beginExport(String format) {
    setState(() {
      _exporting = true;
      _shareResult = null;
      _shareFormat = format;
    });
  }

  Future<void> _shareFile(LocalExportFile file, String format) async {
    late final LocalFileShareResult result;
    try {
      result = await widget.fileShareAdapter.share(file);
    } on Object {
      result = const LocalFileShareResult.failed();
    }
    if (!mounted) return;
    _finishExport(format, result);
  }

  void _finishExport(String format, LocalFileShareResult result) {
    if (!mounted) return;
    setState(() {
      _exporting = false;
      _shareResult = result;
      _shareFormat = format;
    });
  }

  void _dismissShareResult() {
    setState(() {
      _shareResult = null;
      _shareFormat = null;
    });
  }

  TwinMatrixViewModel _buildMatrix(
    CycleAndCareSummary summary, {
    DateTime? generatedAt,
  }) {
    final stamp = generatedAt ?? (widget.now ?? DateTime.now)().toLocal();
    return TwinMatrixSummaryAdapter.fromSummary(
      summary: summary,
      exportTimestamp: _dateStamp(stamp),
    );
  }

  Widget _buildClinicalMatrix(CycleAndCareSummary summary) {
    final viewModel = _buildMatrix(summary);
    return lovable_kit.LetterCard(
      padding: const EdgeInsets.all(LetterSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LetterEyebrow('Twin Matrix', color: LetterColors.teal),
          const SizedBox(height: LetterSpacing.xs),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Tap an observed day to inspect its source records.',
              key: Key('twin-matrix-source-hint'),
              style: TextStyle(color: Color(0xFF777777), fontSize: 12),
            ),
          ),
          TwinMatrixReport(viewModel: viewModel),
          const SizedBox(height: 8),
          Text(
            summary.healthRows.isEmpty
                ? 'No confirmed ratings in this range. Blank cells are missing data.'
                : '${viewModel.mappedObservations} of ${summary.healthRows.length} confirmed ratings map to at least one displayed timing window. Unmapped ratings remain in the detailed list below.',
            style: const TextStyle(
              color: Color(0xFF777777),
              fontSize: 11,
              height: 1.4,
              fontFamily: 'Courier',
            ),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _SummaryShell(
        child: Center(
          child: CircularProgressIndicator(color: LetterColors.teal),
        ),
      );
    }
    if (_failed || _input == null || _range == null) {
      return _SummaryShell(
        child: Center(
          child: health_kit.FailureState(
            title: 'Your summary could not be opened',
            cause:
                'Your local records are still private. Letter Within could not read them just now.',
            action: health_kit.RetryAction(onRetry: _load),
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
    return _SummaryShell(child: _buildPreview(summary, availableNotes));
  }

  Widget _buildPreview(
    CycleAndCareSummary summary,
    List<SummarySelectableNote> availableNotes,
  ) {
    final noRecords =
        summary.periodDays.isEmpty &&
        summary.predictions.isEmpty &&
        summary.healthRows.isEmpty &&
        summary.careRows.isEmpty &&
        availableNotes.isEmpty;
    return SingleChildScrollView(
      key: const Key('summary-export-preview'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          lovable_theme.LetterTokens.gutter,
          lovable_theme.LetterTokens.s20,
          lovable_theme.LetterTokens.gutter,
          lovable_theme.LetterTokens.s28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LetterPageHeader(
              eyebrow: 'Cycle + Care summary',
              title: 'Review every included record',
              support:
                  'A readable report for a chosen range—not a backup. Review what Letter Within has recorded before sharing it.',
            ),
            const SizedBox(height: LetterSpacing.md),
            _Disclosure(text: CycleAndCareSummary.nonDiagnosticDisclosure),
            const SizedBox(height: LetterSpacing.xs),
            _Disclosure(text: CycleAndCareSummary.exclusionDisclosure),
            const SizedBox(height: LetterSpacing.md),
            _RangeCard(range: summary.range, onChoose: _chooseRange),
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
            if (noRecords) ...[
              const SizedBox(height: LetterSpacing.lg),
              const health_kit.EmptyState(
                title: 'Nothing recorded yet',
                body:
                    'Add a period, confirmed health record, Care outcome, or optional note to make this range readable.',
              ),
            ],
            const SizedBox(height: LetterSpacing.lg),
            _buildClinicalMatrix(summary),
            const SizedBox(height: LetterSpacing.xl),
            _PeriodSection(summary: summary),
            const SizedBox(height: LetterSpacing.lg),
            _HealthSection(rows: summary.healthRows),
            const SizedBox(height: LetterSpacing.lg),
            _CareSection(rows: summary.careRows),
            const SizedBox(height: LetterSpacing.lg),
            _ChosenNotesSection(notes: summary.notes),
            const SizedBox(height: LetterSpacing.lg),
            _MissingnessSection(values: summary.missingness),
            const SizedBox(height: LetterSpacing.xl),
            if (_shareResult case final result?) ...[
              _ShareResultCard(
                format: _shareFormat ?? 'File',
                result: result,
                onBackToPreview: _dismissShareResult,
                onDone: _goBack,
              ),
              const SizedBox(height: LetterSpacing.md),
            ],
            _ExportActions(
              exporting: _exporting,
              onPdf: () => _exportPdf(summary),
              onCsv: () => _exportCsv(summary),
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

String _dateStamp(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

class _SummaryShell extends StatelessWidget {
  const _SummaryShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return health_kit.ScreenScaffold(
      showHeader: false,
      child: Column(
        children: [
          const _PageTopBar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _PageTopBar extends StatelessWidget {
  const _PageTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(bottom: lovable_theme.LetterTokens.hairline),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: lovable_theme.LetterTokens.gutter,
        vertical: lovable_theme.LetterTokens.s8,
      ),
      child: Row(
        children: [
          IconButton(
            key: const Key('summary-export-back'),
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            constraints: const BoxConstraints(
              minWidth: lovable_theme.LetterTokens.tapTarget,
              minHeight: lovable_theme.LetterTokens.tapTarget,
            ),
          ),
          const SizedBox(width: lovable_theme.LetterTokens.s8),
          Expanded(
            child: Text(
              'Cycle + Care summary',
              style: lovable_theme.letterSerif(
                size: 20,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeCard extends StatelessWidget {
  const _RangeCard({required this.range, required this.onChoose});

  final SummaryDateRange range;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return lovable_kit.LetterCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LetterEyebrow('Report range', color: LetterColors.teal),
          const SizedBox(height: LetterSpacing.xs),
          Text(range.label, style: lovable_theme.letterSerif(size: 19)),
          const SizedBox(height: LetterSpacing.sm),
          const Text(
            'Inclusive dates. Notes are optional and selected separately below.',
            style: TextStyle(color: LetterColors.muted, height: 1.45),
          ),
          const SizedBox(height: LetterSpacing.md),
          health_kit.QuietButton(
            key: const Key('summary-select-range'),
            label: 'Choose different dates',
            onPressed: onChoose,
            expand: true,
          ),
        ],
      ),
    );
  }
}

class _ExportActions extends StatelessWidget {
  const _ExportActions({
    required this.exporting,
    required this.onPdf,
    required this.onCsv,
  });

  final bool exporting;
  final VoidCallback onPdf;
  final VoidCallback onCsv;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(16) > 22;
        final pdf = lovable_kit.PrimaryButton(
          key: const Key('summary-export-pdf'),
          label: exporting ? 'Preparing PDF' : 'Export PDF',
          onPressed: exporting ? null : onPdf,
          expand: stacked,
        );
        final csv = health_kit.QuietButton(
          key: const Key('summary-export-csv'),
          label: exporting ? 'Preparing CSV' : 'Export CSV',
          onPressed: exporting ? null : onCsv,
          expand: stacked,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LetterEyebrow('Share this report', color: LetterColors.teal),
            const SizedBox(height: LetterSpacing.xs),
            const Text(
              'PDF includes the Twin Matrix and the complete readable packet. CSV contains source records only.',
              style: TextStyle(color: LetterColors.muted, height: 1.45),
            ),
            const SizedBox(height: LetterSpacing.md),
            if (stacked)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  pdf,
                  const SizedBox(height: LetterSpacing.sm),
                  csv,
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: pdf),
                  const SizedBox(width: LetterSpacing.sm),
                  Expanded(child: csv),
                ],
              ),
            if (exporting) ...[
              const SizedBox(height: LetterSpacing.sm),
              const Text(
                'Saving to Letter Within’s dedicated letter folder. Stay here until the native destination sheet opens.',
                style: TextStyle(color: LetterColors.muted, fontSize: 12),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ShareResultCard extends StatelessWidget {
  const _ShareResultCard({
    required this.format,
    required this.result,
    required this.onBackToPreview,
    required this.onDone,
  });

  final String format;
  final LocalFileShareResult result;
  final VoidCallback onBackToPreview;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final failed = result.status == LocalFileShareStatus.failed;
    final message = switch (result.status) {
      LocalFileShareStatus.shared when result.savedPath != null =>
        '$format saved in Letter Within’s local letter folder. The native destination sheet lets you choose an installed cloud provider or none.',
      LocalFileShareStatus.shared =>
        '$format sent to the local share destination.',
      LocalFileShareStatus.unavailable =>
        '$format is ready, but this device has no local share destination connected yet.',
      LocalFileShareStatus.failed =>
        'Letter Within could not create the local $format.',
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('summary-share-result'),
        padding: const EdgeInsets.all(LetterSpacing.md),
        decoration: BoxDecoration(
          color: failed ? LetterColors.amberSoft : LetterColors.tealSoft,
          border: Border.all(
            color: failed ? LetterColors.amber : LetterColors.teal,
          ),
          borderRadius: BorderRadius.circular(LetterRadius.panel),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  failed ? Icons.error_outline : Icons.check_circle_outline,
                  color: failed ? LetterColors.amber : LetterColors.teal,
                ),
                const SizedBox(width: LetterSpacing.sm),
                Expanded(child: Text(message)),
              ],
            ),
            if (result.savedPath case final path?) ...[
              const SizedBox(height: LetterSpacing.xs),
              Text(
                'Saved path: $path',
                style: const TextStyle(
                  color: LetterColors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: LetterSpacing.md),
            Wrap(
              spacing: LetterSpacing.sm,
              runSpacing: LetterSpacing.sm,
              children: [
                health_kit.QuietButton(
                  label: 'Back to preview',
                  onPressed: onBackToPreview,
                ),
                health_kit.QuietButton(label: 'Done', onPressed: onDone),
              ],
            ),
          ],
        ),
      ),
    );
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
    final periodRanges = observedPeriodRanges(summary.periodDays);
    return _Section(
      title: 'Observed periods and estimate ranges',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (periodRanges.isEmpty)
            const Text(
              'No observed period days.',
              key: Key('summary-no-period-days'),
            )
          else
            for (final range in periodRanges)
              Text(
                'Observed period: ${summaryDateLabel(range.start)} to '
                '${summaryDateLabel(range.end)} · ${range.dayCount} days',
              ),
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
      title: 'Confirmed health records and provenance',
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
                    '${summaryDateLabel(row.date)} · ${row.symptom.label} · ${row.severity.label} (${row.severity.score}/5)',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text('Cycle day: ${row.cycleDay ?? 'Not available'}'),
                  if (row.provenance == SummaryRecordProvenance.laterRecall)
                    Text('Recorded: ${summaryDateTimeLabel(row.recordedAt)}'),
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
      title: 'Care outcomes',
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
      title: 'Selected notes',
      child: notes.isEmpty
          ? const Text('No saved notes in this date range.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Optional. Select only the notes you want to share in this report.',
                  style: TextStyle(color: LetterColors.muted, height: 1.45),
                ),
                const SizedBox(height: LetterSpacing.sm),
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

class _ChosenNotesSection extends StatelessWidget {
  const _ChosenNotesSection({required this.notes});

  final List<SummarySelectableNote> notes;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Chosen notes',
      child: notes.isEmpty
          ? const Text('No notes selected for this report.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final note in notes) ...[
                  Text(
                    '${note.label} · ${summaryDateLabel(note.date)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(note.text),
                  Text(
                    note.sourceLabel,
                    style: const TextStyle(
                      color: LetterColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  if (note != notes.last) const Divider(),
                ],
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
      title: 'Missingness',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gaps are shown as gaps; Letter Within does not estimate or interpret them.',
            style: TextStyle(color: LetterColors.muted, height: 1.45),
          ),
          const SizedBox(height: LetterSpacing.sm),
          for (final value in values) Text('• $value'),
        ],
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
    return lovable_kit.LetterCard(
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
