import 'package:flutter/material.dart';

import '../domain/local_date.dart';
import '../domain/period_record.dart';
import '../domain/period_repository.dart';
import '../domain/period_validation.dart';

/// Review precedes mutation. The durable capability revalidates the exact
/// source snapshot, so an old dialog cannot approve a newly changed merge.
Future<PeriodRecord?> writePeriodWithReview({
  required BuildContext context,
  required PeriodRepository repository,
  required PeriodDraft draft,
  required LocalDate today,
  String? editingId,
}) async {
  if (repository is! ConfirmablePeriodRepository) {
    return editingId == null
        ? repository.create(draft, today: today)
        : repository.update(editingId, draft, today: today);
  }
  final preview = await repository.previewWrite(
    draft,
    today: today,
    editingId: editingId,
  );
  if (!context.mounted) return null;
  if (preview.requiresConfirmation) {
    final range = mergeAdjacentPeriodDraft(draft, preview.adjacentPeriods);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          preview.adjacentPeriods.isEmpty
              ? 'Review changed period dates'
              : 'Merge adjacent period dates?',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${range.startDate} → ${range.endDate ?? 'Still bleeding'}'),
              const SizedBox(height: 12),
              if (preview.adjacentPeriods.isNotEmpty)
                Text(
                  'This joins ${preview.adjacentPeriods.length} adjacent saved period ${preview.adjacentPeriods.length == 1 ? 'range' : 'ranges'} into one episode.',
                ),
              const Text(
                'Saved bleeding stays recorded. Original letters and reflections keep their words and dates and remain available in the Cycle letter archive.',
              ),
              if (preview.detachedBleedingCount > 0)
                Text(
                  '${preview.detachedBleedingCount} bleeding sources outside the new dates will remain as independent dated records.',
                ),
              if (preview.detachedReflectionCount > 0)
                Text(
                  '${preview.detachedReflectionCount} original reflections will remain in the archive.',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm dates'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return null;
  }
  return repository.confirmWrite(preview, today: today);
}
