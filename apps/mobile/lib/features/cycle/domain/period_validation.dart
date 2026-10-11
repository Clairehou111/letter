import 'dart:math';

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

/// Source snapshots remain private to the repository. Tokens never contain
/// health data and cannot authorize a changed draft or stale source state.
final class PeriodReviewStore {
  final Map<String, ({PeriodWritePreview preview, String snapshot})> _pending =
      {};

  PeriodWritePreview preview({
    required PeriodDraft draft,
    required LocalDate today,
    required List<PeriodRecord> existing,
    required String snapshot,
    String? editingId,
    int detachedBleedingCount = 0,
    int detachedReflectionCount = 0,
  }) {
    if (editingId != null &&
        !existing.any((record) => record.id == editingId)) {
      throw const PeriodWriteException(PeriodWriteFailure.notFound);
    }
    validatePeriodDraft(
      draft: draft,
      today: today,
      existing: existing,
      editingId: editingId,
    );
    final random = Random.secure();
    final token = List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    final preview = PeriodWritePreview(
      reviewToken: token,
      draft: draft,
      editingId: editingId,
      detachedBleedingCount: detachedBleedingCount,
      detachedReflectionCount: detachedReflectionCount,
      adjacentPeriods: adjacentPeriodsForDraft(
        draft: draft,
        today: today,
        existing: existing,
        editingId: editingId,
      ),
    );
    if (_pending.length >= 32) _pending.remove(_pending.keys.first);
    _pending[token] = (preview: preview, snapshot: snapshot);
    return preview;
  }

  PeriodWritePreview validate(PeriodWritePreview preview, String snapshot) {
    final stored = _pending[preview.reviewToken];
    if (stored == null ||
        !identical(stored.preview, preview) ||
        stored.snapshot != snapshot) {
      throw const PeriodWriteException(PeriodWriteFailure.staleConfirmation);
    }
    return stored.preview;
  }

  void consume(PeriodWritePreview preview) =>
      _pending.remove(preview.reviewToken);
}
