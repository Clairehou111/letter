import '../../summary_export/domain/cycle_care_summary.dart';
import '../../cycle/domain/local_date.dart';
import 'archive_repository.dart';

/// Adapts the Archive's already-filtered local facts for a one-time export.
/// It intentionally has no database or network dependency.
SummaryExportInput summaryExportInputFromArchive(ArchiveInput input) {
  final periodDates = {
    for (final cycle in input.cycles)
      for (final date in cycle.periodDates) date,
  }.toList()..sort();
  final notes = <SummarySelectableNote>[];
  for (final reflection in input.reflections) {
    final date = reflection.updatedAt.toLocal();
    final localDate = LocalDate(date.year, date.month, date.day);
    void add(String field, String? value) {
      if (value == null || value.trim().isEmpty) return;
      notes.add(
        SummarySelectableNote(
          id: '${reflection.id}.$field',
          date: localDate,
          label: switch (field) {
            'observation' => 'Your reflection',
            'whatHelped' => 'What helped',
            _ => 'Note for a future self',
          },
          text: value,
          sourceLabel: 'Saved Care reflection · local only',
        ),
      );
    }

    add('observation', reflection.observation);
    add('whatHelped', reflection.whatHelped);
    add('futureSelfNote', reflection.futureSelfNote);
  }
  return SummaryExportInput(
    periodDays: [for (final date in periodDates) SummaryPeriodDay(date)],
    predictions: const [],
    healthRecords: input.healthRecords,
    careRecords: input.careRecords,
    notes: notes,
  );
}
