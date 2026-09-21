import 'dart:math';

import '../domain/bleeding_flow.dart';
import '../domain/local_date.dart';
import '../domain/period_record.dart';
import '../domain/period_repository.dart';
import '../domain/period_validation.dart';

final class InMemoryPeriodRepository implements PeriodRepository {
  InMemoryPeriodRepository({
    Iterable<PeriodRecord> seed = const [],
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _records = [...seed],
       _flowDays = [],
       _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _randomId;

  final List<PeriodRecord> _records;
  final List<BleedingDayRecord> _flowDays;
  final DateTime Function() _clock;
  final String Function() _idGenerator;

  @override
  Future<List<PeriodRecord>> getAll() async {
    return [..._records]
      ..sort((left, right) => right.startDate.compareTo(left.startDate));
  }

  @override
  Future<PeriodRecord> create(
    PeriodDraft draft, {
    required LocalDate today,
  }) async {
    validatePeriodDraft(draft: draft, today: today, existing: _records);
    final now = _clock().toUtc();
    final record = PeriodRecord(
      id: _idGenerator(),
      startDate: draft.startDate,
      endDate: draft.endDate,
      createdAt: now,
      updatedAt: now,
    );
    _records.add(record);
    return record;
  }

  @override
  Future<PeriodRecord> update(
    String id,
    PeriodDraft draft, {
    required LocalDate today,
  }) async {
    final index = _records.indexWhere((record) => record.id == id);
    if (index == -1) {
      throw const PeriodWriteException(PeriodWriteFailure.notFound);
    }
    validatePeriodDraft(
      draft: draft,
      today: today,
      existing: _records,
      editingId: id,
    );
    final previous = _records[index];
    final updated = PeriodRecord(
      id: previous.id,
      startDate: draft.startDate,
      endDate: draft.endDate,
      createdAt: previous.createdAt,
      updatedAt: _clock().toUtc(),
    );
    _records[index] = updated;
    final upperBound = draft.endDate ?? today;
    _flowDays.removeWhere(
      (flow) =>
          flow.periodId == id &&
          (flow.date.isBefore(draft.startDate) ||
              flow.date.isAfter(upperBound)),
    );
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    final index = _records.indexWhere((record) => record.id == id);
    if (index == -1) {
      throw const PeriodWriteException(PeriodWriteFailure.notFound);
    }
    _records.removeAt(index);
    _flowDays.removeWhere((flow) => flow.periodId == id);
  }

  @override
  Future<List<BleedingDayRecord>> getAllFlowDays() async {
    return [..._flowDays]..sort((left, right) {
      final dateOrder = right.date.compareTo(left.date);
      return dateOrder != 0
          ? dateOrder
          : left.periodId.compareTo(right.periodId);
    });
  }

  @override
  Future<BleedingDayRecord> setFlow(
    String periodId,
    LocalDate date,
    BleedingFlow flow, {
    required LocalDate today,
  }) async {
    final period = _periodForFlow(periodId, date: date, today: today);
    final now = _clock().toUtc();
    final index = _flowDays.indexWhere(
      (record) => record.periodId == period.id && record.date == date,
    );
    final previous = index == -1 ? null : _flowDays[index];
    final updated = BleedingDayRecord(
      periodId: period.id,
      date: date,
      flow: flow,
      color: previous?.color,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
    if (index == -1) {
      _flowDays.add(updated);
    } else {
      _flowDays[index] = updated;
    }
    return updated;
  }

  @override
  Future<BleedingDayRecord> setBleedingColor(
    String periodId,
    LocalDate date,
    BleedingColor color,
  ) async {
    final index = _flowDays.indexWhere(
      (record) => record.periodId == periodId && record.date == date,
    );
    if (index == -1) {
      throw const PeriodWriteException(PeriodWriteFailure.flowRequiredForColor);
    }
    final previous = _flowDays[index];
    final updated = BleedingDayRecord(
      periodId: previous.periodId,
      date: previous.date,
      flow: previous.flow,
      color: color,
      createdAt: previous.createdAt,
      updatedAt: _clock().toUtc(),
    );
    _flowDays[index] = updated;
    return updated;
  }

  @override
  Future<void> clearBleedingColor(String periodId, LocalDate date) async {
    final index = _flowDays.indexWhere(
      (record) => record.periodId == periodId && record.date == date,
    );
    if (index == -1) return;
    final previous = _flowDays[index];
    _flowDays[index] = BleedingDayRecord(
      periodId: previous.periodId,
      date: previous.date,
      flow: previous.flow,
      createdAt: previous.createdAt,
      updatedAt: _clock().toUtc(),
    );
  }

  @override
  Future<void> clearFlow(String periodId, LocalDate date) async {
    _flowDays.removeWhere(
      (record) => record.periodId == periodId && record.date == date,
    );
  }

  PeriodRecord _periodForFlow(
    String periodId, {
    required LocalDate date,
    required LocalDate today,
  }) {
    final period = _records
        .where((record) => record.id == periodId)
        .firstOrNull;
    if (period == null) {
      throw const PeriodWriteException(PeriodWriteFailure.flowPeriodNotFound);
    }
    if (date.isAfter(today)) {
      throw const PeriodWriteException(PeriodWriteFailure.flowDateInFuture);
    }
    final upperBound = period.endDate ?? today;
    if (date.isBefore(period.startDate) || date.isAfter(upperBound)) {
      throw const PeriodWriteException(
        PeriodWriteFailure.flowDateOutsidePeriod,
      );
    }
    return period;
  }

  @override
  Future<void> close() async {}

  static String _randomId() {
    final random = Random.secure();
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final suffix = List.generate(
      12,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '$timestamp-$suffix';
  }
}
