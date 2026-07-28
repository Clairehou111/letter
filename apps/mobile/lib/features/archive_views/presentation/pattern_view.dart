import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../domain/archive_view_models.dart';

class ArchivePatternView extends StatelessWidget {
  const ArchivePatternView({required this.viewModel, super.key});

  final ArchivePatternViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('archive-pattern-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const _PatternNote(),
        const SizedBox(height: LetterSpacing.md),
        if (viewModel.metrics.isEmpty && viewModel.careOutcomes.isEmpty)
          const _PatternEmpty()
        else ...[
          if (viewModel.metrics.isNotEmpty) ...[
            const Text(
              'Confirmed symptoms',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: LetterSpacing.xs),
            ...viewModel.metrics.map((metric) => _MetricTile(metric: metric)),
          ],
          if (viewModel.careOutcomes.isNotEmpty) ...[
            const SizedBox(height: LetterSpacing.md),
            const Text(
              'Care outcomes',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: LetterSpacing.xs),
            ...viewModel.careOutcomes.map(
              (outcome) => _CareOutcomeTile(outcome: outcome),
            ),
          ],
        ],
        if (viewModel.missingNote case final missing?) ...[
          const SizedBox(height: LetterSpacing.md),
          Text(
            missing,
            key: const Key('archive-pattern-missing'),
            style: const TextStyle(color: LetterColors.muted),
          ),
        ],
      ],
    );
  }
}

class _PatternNote extends StatelessWidget {
  const _PatternNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: const BoxDecoration(
        color: LetterColors.tealSoft,
        border: Border(left: BorderSide(color: LetterColors.teal, width: 4)),
      ),
      child: const Text(
        'Patterns are counts from confirmed local records. They are not a diagnosis, prediction, or phase label.',
        style: TextStyle(height: 1.45),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final ArchivePatternMetric metric;

  @override
  Widget build(BuildContext context) {
    final severity = metric.highestSeverity;
    return Container(
      key: Key('archive-pattern-${metric.label}'),
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
            metric.label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: LetterSpacing.xs),
          Text(
            '${metric.confirmedCount} confirmed record${metric.confirmedCount == 1 ? '' : 's'} · ${metric.coverageLabel}',
            style: const TextStyle(fontSize: 13),
          ),
          if (severity != null) ...[
            const SizedBox(height: LetterSpacing.xxs),
            Text(
              'Highest recorded severity: ${severity.label} (${severity.score}/6)',
            ),
          ],
          if (metric.painDays > 0) ...[
            const SizedBox(height: LetterSpacing.xxs),
            Text(
              'Pain rating recorded on ${metric.painDays} record${metric.painDays == 1 ? '' : 's'}.',
            ),
          ],
          const SizedBox(height: LetterSpacing.xs),
          Text(
            metric.sourceLabel,
            style: const TextStyle(color: LetterColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CareOutcomeTile extends StatelessWidget {
  const _CareOutcomeTile({required this.outcome});

  final ArchiveCareOutcomeSummary outcome;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LetterSpacing.md),
      margin: const EdgeInsets.only(bottom: LetterSpacing.xs),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            outcome.actionLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: LetterSpacing.xs),
          Text(
            '${outcome.total} check-back${outcome.total == 1 ? '' : 's'}: '
            '${outcome.better} better · ${outcome.same} same · ${outcome.worse} worse',
          ),
          const SizedBox(height: LetterSpacing.xs),
          Text(
            outcome.sourceLabel,
            style: const TextStyle(color: LetterColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PatternEmpty extends StatelessWidget {
  const _PatternEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('archive-pattern-empty'),
      padding: const EdgeInsets.all(LetterSpacing.lg),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: const Text(
        'No confirmed records or Care outcomes are available for this cycle.',
        style: TextStyle(color: LetterColors.muted, height: 1.45),
      ),
    );
  }
}
