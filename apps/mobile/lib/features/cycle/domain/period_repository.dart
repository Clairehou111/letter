import 'local_date.dart';
import 'period_record.dart';

enum PeriodWriteFailure {
  futureDate,
  endBeforeStart,
  overlap,
  anotherPeriodOpen,
  notFound,
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
    PeriodWriteFailure.storageUnavailable =>
      'Letter could not open private cycle storage. Try again.',
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

  Future<void> close();
}
