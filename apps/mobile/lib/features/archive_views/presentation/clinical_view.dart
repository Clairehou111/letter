import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../../../design_system/lovable/letter_theme.dart' as lovable;
import '../domain/archive_view_models.dart';

class ArchiveClinicalView extends StatelessWidget {
  const ArchiveClinicalView({
    required this.viewModel,
    super.key,
    this.onCreateSummary,
    this.onEditHealthRecords,
  });

  final ArchiveClinicalViewModel viewModel;
  final VoidCallback? onCreateSummary;
  final VoidCallback? onEditHealthRecords;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('archive-clinical-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const _ClinicalNote(),
        const SizedBox(height: LetterSpacing.md),
        if (onCreateSummary != null) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('archive-create-summary'),
              style: LetterButtonStyles.filled,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Create Cycle and Care Summary'),
              onPressed: onCreateSummary,
            ),
          ),
          const SizedBox(height: LetterSpacing.xs),
          const Text(
            'Create a factual summary from the records confirmed for this cycle.',
            style: TextStyle(color: LetterColors.muted, height: 1.4),
          ),
          const SizedBox(height: LetterSpacing.md),
        ],
        if (viewModel.healthRows.isNotEmpty) ...[
          const _SectionHeading(
            eyebrow: 'CONFIRMED RECORDS',
            title: 'Health records',
          ),
          const SizedBox(height: LetterSpacing.xs),
          const Text(
            'A read-only view of what was recorded for this cycle.',
            style: TextStyle(color: LetterColors.muted, height: 1.4),
          ),
          const SizedBox(height: LetterSpacing.sm),
          _HealthCards(rows: viewModel.healthRows),
          if (onEditHealthRecords != null) ...[
            const SizedBox(height: LetterSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('archive-edit-health-records'),
                style: LetterButtonStyles.outlined,
                onPressed: onEditHealthRecords,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit health records'),
              ),
            ),
          ],
        ],
        if (viewModel.careRows.isNotEmpty) ...[
          const SizedBox(height: LetterSpacing.xl),
          const _SectionHeading(eyebrow: 'CARE', title: 'Care events'),
          const SizedBox(height: LetterSpacing.sm),
          _CareGroup(rows: viewModel.careRows),
        ],
        if (viewModel.healthRows.isEmpty && viewModel.careRows.isEmpty)
          const _ClinicalEmpty(),
        if (viewModel.missingNote case final missing?) ...[
          const SizedBox(height: LetterSpacing.md),
          _MissingNote(text: missing),
        ],
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: LetterColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: LetterSpacing.xxs),
        Text(title, style: lovable.letterSerif(size: 25)),
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
      decoration: BoxDecoration(
        color: LetterColors.blueSoft,
        borderRadius: BorderRadius.circular(LetterRadius.panel),
        border: Border.all(color: LetterColors.blue.withValues(alpha: .24)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: LetterColors.blue),
          SizedBox(width: LetterSpacing.sm),
          Expanded(
            child: Text(
              'Clinical view is a plain record of what was confirmed and when. Provenance and missing fields stay visible.',
              style: TextStyle(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthCards extends StatelessWidget {
  const _HealthCards({required this.rows});

  final List<ArchiveClinicalRecordRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('archive-clinical-health-cards'),
      children: [for (final row in rows) _HealthCard(row: row)],
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.row});

  final ArchiveClinicalRecordRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: LetterSpacing.sm),
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
        boxShadow: LetterShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  row.symptomLabel,
                  style: lovable.letterSerif(size: 20, weight: FontWeight.w600),
                ),
              ),
              Container(
                constraints: const BoxConstraints(
                  minHeight: LetterDimensions.tapTarget,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: LetterSpacing.sm,
                  vertical: LetterSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: LetterColors.blueSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  row.provenanceLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: LetterColors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LetterSpacing.xs),
          Text(
            row.dateLabel,
            style: const TextStyle(color: LetterColors.muted),
          ),
          const Divider(height: LetterSpacing.lg),
          _RecordField(
            label: 'Severity',
            value: '${row.severityLabel} · ${row.severityScore}/5',
          ),
          _RecordField(label: 'Impact', value: row.impactLabel),
          _RecordField(label: 'Recorded', value: row.recordedAtLabel),
          _RecordField(label: 'Source', value: row.sourceLabel),
        ],
      ),
    );
  }
}

class _RecordField extends StatelessWidget {
  const _RecordField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LetterSpacing.xs),
      child: Wrap(
        spacing: LetterSpacing.xs,
        runSpacing: LetterSpacing.xxs,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(value),
        ],
      ),
    );
  }
}

class _CareGroup extends StatelessWidget {
  const _CareGroup({required this.rows});

  final List<ArchiveClinicalCareRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LetterSpacing.xs),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Column(children: [for (final row in rows) _CareRow(row: row)]),
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
      padding: const EdgeInsets.all(LetterSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LetterColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.actionLabel,
            style: lovable.letterSerif(size: 18, weight: FontWeight.w600),
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

class _MissingNote extends StatelessWidget {
  const _MissingNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: BoxDecoration(
        color: LetterColors.amberSoft,
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Text(
        text,
        key: const Key('archive-clinical-missing'),
        style: const TextStyle(height: 1.45),
      ),
    );
  }
}

/*
  The old table implementation was intentionally removed: a two-column table
  cannot remain readable at 320px or with enlarged text. The record-card
  fields above retain every factual value supplied by ArchiveClinicalViewModel.
*/
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
