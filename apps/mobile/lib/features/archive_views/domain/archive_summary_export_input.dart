import '../../summary_export/domain/cycle_care_summary.dart';
import '../../care/domain/care_memory.dart';
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
  for (final reflection in input.cycleReflections) {
    final date = reflection.updatedAt.toLocal();
    final localDate = LocalDate(date.year, date.month, date.day);
    void add(String field, String? value) {
      if (value == null || value.trim().isEmpty) return;
      notes.add(
        SummarySelectableNote(
          id: '${reflection.id}.$field',
          date: localDate,
          label: switch (field) {
            'observation' => 'Cycle reflection — what stood out',
            'need' => 'Cycle reflection — what you needed',
            'whatHelped' => 'Cycle reflection — what helped',
            _ => 'Cycle reflection — for next time',
          },
          text: value,
          sourceLabel: 'Saved cycle reflection · local only',
        ),
      );
    }

    add('observation', reflection.observation);
    add('need', reflection.need == null ? null : _needLabel(reflection.need!));
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

String _needLabel(ReflectionNeed need) {
  return switch (need) {
    ReflectionNeed.boundaries => 'Boundaries',
    ReflectionNeed.connection => 'Connection',
    ReflectionNeed.autonomy => 'Autonomy',
    ReflectionNeed.restOrPhysicalCapacity => 'Rest or physical capacity',
    ReflectionNeed.somethingElse => 'Something else',
    ReflectionNeed.notSure => 'Not sure',
  };
}
