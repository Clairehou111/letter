import 'dart:math';

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
       _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _randomId;

  final List<PeriodRecord> _records;
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
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    final index = _records.indexWhere((record) => record.id == id);
    if (index == -1) {
      throw const PeriodWriteException(PeriodWriteFailure.notFound);
    }
    _records.removeAt(index);
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
