import 'local_date.dart';
import 'bleeding_flow.dart';
import 'period_record.dart';

enum PeriodWriteFailure {
  futureDate,
  endBeforeStart,
  overlap,
  anotherPeriodOpen,
  notFound,
  flowPeriodNotFound,
  flowDateInFuture,
  flowDateOutsidePeriod,
  flowRequiredForColor,
  confirmationRequired,
  staleConfirmation,
  storageUnavailable,
}

final class PeriodWriteException implements Exception {
  const PeriodWriteException(this.failure);

  final PeriodWriteFailure failure;

  String get userMessage => switch (failure) {
    PeriodWriteFailure.futureDate => 'Period dates cannot be later than today.',
    PeriodWriteFailure.endBeforeStart =>
      'The end date must be the same as or later than the start date.',
    PeriodWriteFailure.overlap =>
      'These dates overlap another period. Edit one of the date ranges first.',
    PeriodWriteFailure.anotherPeriodOpen =>
      'End your current period before starting another one.',
    PeriodWriteFailure.notFound =>
      'This period is no longer in your history. Refresh and try again.',
    PeriodWriteFailure.flowPeriodNotFound =>
      'This period is no longer in your history. Refresh and try again.',
    PeriodWriteFailure.flowDateInFuture =>
      'Bleeding flow cannot be recorded for a future date.',
    PeriodWriteFailure.flowDateOutsidePeriod =>
      'Bleeding flow must be recorded within this period.',
    PeriodWriteFailure.flowRequiredForColor =>
      'Choose a flow before adding its color.',
    PeriodWriteFailure.confirmationRequired =>
      'Review and confirm this period change before saving.',
    PeriodWriteFailure.staleConfirmation =>
      'Your cycle records changed. Review the merge again before saving.',
    PeriodWriteFailure.storageUnavailable =>
      'Letter Within could not open private cycle storage. Try again.',
  };

  @override
  String toString() => 'PeriodWriteException($failure)';
}

abstract interface class PeriodRepository {
  Future<List<PeriodRecord>> getAll();

  Future<PeriodRecord> create(PeriodDraft draft, {required LocalDate today});

  Future<PeriodRecord> update(
    String id,
    PeriodDraft draft, {
    required LocalDate today,
  });

  Future<void> delete(String id);

  Future<List<BleedingDayRecord>> getAllFlowDays();

  Future<BleedingDayRecord> setFlow(
    String periodId,
    LocalDate date,
    BleedingFlow flow, {
    required LocalDate today,
  });

  Future<BleedingDayRecord> setBleedingColor(
    String periodId,
    LocalDate date,
    BleedingColor color,
  );

  Future<void> clearBleedingColor(String periodId, LocalDate date);

  Future<void> clearFlow(String periodId, LocalDate date);

  Future<void> close();
}

/// Optional capability: existing read/write adapters and test doubles retain
/// the base interface, while durable repositories require explicit merge review.
abstract interface class ConfirmablePeriodRepository
    implements PeriodRepository {
  Future<PeriodWritePreview> previewWrite(
    PeriodDraft draft, {
    required LocalDate today,
    String? editingId,
  });

  Future<PeriodRecord> confirmWrite(
    PeriodWritePreview preview, {
    required LocalDate today,
  });
}

/// The opaque token is bound to the repository's source snapshot. Confirmation
/// writes its cached draft only after re-reading those sources atomically.
final class PeriodWritePreview {
  PeriodWritePreview({
    required this.reviewToken,
    required this.draft,
    required this.editingId,
    required Iterable<PeriodRecord> adjacentPeriods,
    this.detachedBleedingCount = 0,
    this.detachedReflectionCount = 0,
  }) : adjacentPeriods = List.unmodifiable(adjacentPeriods);

  final String reviewToken;
  final PeriodDraft draft;
  final String? editingId;
  final List<PeriodRecord> adjacentPeriods;
  final int detachedBleedingCount;
  final int detachedReflectionCount;
  bool get requiresConfirmation =>
      adjacentPeriods.isNotEmpty ||
      detachedBleedingCount > 0 ||
      detachedReflectionCount > 0;
}
