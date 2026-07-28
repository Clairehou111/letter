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
