import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../domain/archive_view_models.dart';

class ArchiveClinicalView extends StatelessWidget {
  const ArchiveClinicalView({
    required this.viewModel,
    super.key,
    this.onCreateSummary,
  });

  final ArchiveClinicalViewModel viewModel;
  final VoidCallback? onCreateSummary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('archive-clinical-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const _ClinicalNote(),
        const SizedBox(height: LetterSpacing.md),
        if (onCreateSummary != null) ...[
          OutlinedButton.icon(
            key: const Key('archive-create-summary'),
            onPressed: onCreateSummary,
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Create Cycle and Care Summary'),
          ),
          const SizedBox(height: LetterSpacing.md),
        ],
        if (viewModel.healthRows.isNotEmpty) ...[
          const Text(
            'Confirmed health records',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: LetterSpacing.xs),
          _HealthTable(rows: viewModel.healthRows),
        ],
        if (viewModel.careRows.isNotEmpty) ...[
          const SizedBox(height: LetterSpacing.md),
          const Text(
            'Care events',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: LetterSpacing.xs),
          ...viewModel.careRows.map((row) => _CareRow(row: row)),
        ],
        if (viewModel.healthRows.isEmpty && viewModel.careRows.isEmpty)
          const _ClinicalEmpty(),
        if (viewModel.missingNote case final missing?) ...[
          const SizedBox(height: LetterSpacing.md),
          Text(
            missing,
            key: const Key('archive-clinical-missing'),
            style: const TextStyle(color: LetterColors.muted),
          ),
        ],
      ],
    );
  }
}

class _ClinicalNote extends StatelessWidget {
  const _ClinicalNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: const BoxDecoration(
        color: LetterColors.blueSoft,
        border: Border(left: BorderSide(color: LetterColors.blue, width: 4)),
      ),
      child: const Text(
        'Clinical view is a plain record of what was confirmed and when. Provenance and missing fields stay visible.',
        style: TextStyle(height: 1.45),
      ),
    );
  }
}

class _HealthTable extends StatelessWidget {
  const _HealthTable({required this.rows});

  final List<ArchiveClinicalRecordRow> rows;

  @override
  Widget build(BuildContext context) {
    return Table(
      key: const Key('archive-clinical-health-table'),
      columnWidths: const {0: FlexColumnWidth(1.1), 1: FlexColumnWidth(1.4)},
      border: TableBorder.all(color: LetterColors.line),
      children: [
        const TableRow(
          decoration: BoxDecoration(color: LetterColors.blueSoft),
          children: [_TableCell('Date'), _TableCell('Record')],
        ),
        for (final row in rows)
          TableRow(
            children: [
              _TableCell(row.dateLabel),
              _TableCell(
                '${row.symptomLabel}: ${row.severityLabel} (${row.severityScore}/6)\n'
                'Pain: ${row.painLabel}\n'
                'Location: ${row.locationLabel}\n'
                'Impact: ${row.impactLabel}\n'
                'Provenance: ${row.provenanceLabel}\n'
                '${row.sourceLabel}',
              ),
            ],
          ),
      ],
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(LetterSpacing.xs),
      child: Text(text, style: const TextStyle(fontSize: 12, height: 1.35)),
    );
  }
}

class _CareRow extends StatelessWidget {
  const _CareRow({required this.row});

  final ArchiveClinicalCareRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('archive-clinical-care-${row.dateLabel}-${row.actionLabel}'),
      margin: const EdgeInsets.only(bottom: LetterSpacing.xs),
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.actionLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: LetterSpacing.xxs),
          Text('${row.dateLabel} · ${row.outcomeLabel}'),
          const SizedBox(height: LetterSpacing.xs),
          Text(
            row.sourceLabel,
            style: const TextStyle(color: LetterColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ClinicalEmpty extends StatelessWidget {
  const _ClinicalEmpty();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'No confirmed health or Care records are available for this cycle.',
      key: Key('archive-clinical-empty'),
      style: TextStyle(color: LetterColors.muted, height: 1.45),
    );
  }
}
