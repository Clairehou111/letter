import 'local_date.dart';

final class PeriodDraft {
  const PeriodDraft({required this.startDate, this.endDate});

  final LocalDate startDate;
  final LocalDate? endDate;
}

final class PeriodRecord {
  const PeriodRecord({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final LocalDate startDate;
  final LocalDate? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOpen => endDate == null;

  int? get durationDays {
    final end = endDate;
    return end == null ? null : end.epochDay - startDate.epochDay + 1;
  }
}
