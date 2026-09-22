import 'local_date.dart';
import 'period_record.dart';
import 'period_repository.dart';

void validatePeriodDraft({
  required PeriodDraft draft,
  required LocalDate today,
  required Iterable<PeriodRecord> existing,
  String? editingId,
}) {
  final endDate = draft.endDate;
  if (draft.startDate.isAfter(today) ||
      (endDate != null && endDate.isAfter(today))) {
    throw const PeriodWriteException(PeriodWriteFailure.futureDate);
  }
  if (endDate != null && endDate.isBefore(draft.startDate)) {
    throw const PeriodWriteException(PeriodWriteFailure.endBeforeStart);
  }

  final otherRecords = existing.where((record) => record.id != editingId);
  if (endDate == null && otherRecords.any((record) => record.isOpen)) {
    throw const PeriodWriteException(PeriodWriteFailure.anotherPeriodOpen);
  }

  for (final record in otherRecords) {
    final existingEnd = record.endDate?.epochDay ?? today.epochDay;
    final draftEnd = endDate?.epochDay ?? today.epochDay;
    final overlaps =
        draft.startDate.epochDay <= existingEnd &&
        record.startDate.epochDay <= draftEnd;
    if (overlaps) {
      throw const PeriodWriteException(PeriodWriteFailure.overlap);
    }
  }
}

/// Returns every saved period connected to [draft] by a directly adjacent
/// date boundary. The search expands until both sides are exhausted, so a new
/// range that bridges two saved ranges produces one continuous episode.
///
/// Overlap remains a validation error. Call this only after
/// [validatePeriodDraft] succeeds.
List<PeriodRecord> adjacentPeriodsForDraft({
  required PeriodDraft draft,
  required LocalDate today,
  required Iterable<PeriodRecord> existing,
  String? editingId,
}) {
  var start = draft.startDate;
  var end = draft.endDate ?? today;
  final remaining = existing
      .where((record) => record.id != editingId)
      .toList(growable: true);
  final adjacent = <PeriodRecord>[];

  var foundAnother = true;
  while (foundAnother) {
    foundAnother = false;
    for (final record in List<PeriodRecord>.of(remaining)) {
      final recordEnd = record.endDate ?? today;
      final touchesBefore = recordEnd.epochDay + 1 == start.epochDay;
      final touchesAfter = end.epochDay + 1 == record.startDate.epochDay;
      if (!touchesBefore && !touchesAfter) continue;

      adjacent.add(record);
      remaining.remove(record);
      if (record.startDate.isBefore(start)) start = record.startDate;
      if (recordEnd.isAfter(end)) end = recordEnd;
      foundAnother = true;
    }
  }

  return List.unmodifiable(adjacent);
}

/// Combines [draft] with its adjacent saved records without manufacturing a
/// closed end for an episode that is still open.
PeriodDraft mergeAdjacentPeriodDraft(
  PeriodDraft draft,
  Iterable<PeriodRecord> adjacent,
) {
  var start = draft.startDate;
  var end = draft.endDate;
  var remainsOpen = end == null;

  for (final record in adjacent) {
    if (record.startDate.isBefore(start)) start = record.startDate;
    if (record.endDate == null) {
      remainsOpen = true;
    } else if (end == null || record.endDate!.isAfter(end)) {
      end = record.endDate;
    }
  }

  return PeriodDraft(startDate: start, endDate: remainsOpen ? null : end);
}
