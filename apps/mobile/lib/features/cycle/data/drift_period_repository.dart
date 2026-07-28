import 'dart:math';

import 'package:drift/drift.dart';

import '../domain/local_date.dart';
import '../domain/period_record.dart';
import '../domain/period_repository.dart';
import '../domain/period_validation.dart';
import 'letter_health_database.dart';

final class DriftPeriodRepository implements PeriodRepository {
  DriftPeriodRepository(
    this._database, {
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _randomId;

  final LetterHealthDatabase _database;
  final DateTime Function() _clock;
  final String Function() _idGenerator;

  @override
  Future<List<PeriodRecord>> getAll() async {
    final query = _database.select(_database.periodRows)
      ..orderBy([(row) => OrderingTerm.desc(row.startDay)]);
    return (await query.get()).map(_toDomain).toList(growable: false);
  }

  @override
  Future<PeriodRecord> create(PeriodDraft draft, {required LocalDate today}) {
    return _guardStorage(() {
      return _database.transaction(() async {
        final existing = await getAll();
        validatePeriodDraft(draft: draft, today: today, existing: existing);
        final now = _clock().toUtc();
        final record = PeriodRecord(
          id: _idGenerator(),
          startDate: draft.startDate,
          endDate: draft.endDate,
          createdAt: now,
          updatedAt: now,
        );
        await _database.into(_database.periodRows).insert(_toCompanion(record));
        return record;
      });
    });
  }

  @override
  Future<PeriodRecord> update(
    String id,
    PeriodDraft draft, {
    required LocalDate today,
  }) {
    return _guardStorage(() {
      return _database.transaction(() async {
        final existing = await getAll();
        final previous = existing
            .where((record) => record.id == id)
            .firstOrNull;
        if (previous == null) {
          throw const PeriodWriteException(PeriodWriteFailure.notFound);
        }
        validatePeriodDraft(
          draft: draft,
          today: today,
          existing: existing,
          editingId: id,
        );
        final updated = PeriodRecord(
          id: id,
          startDate: draft.startDate,
          endDate: draft.endDate,
          createdAt: previous.createdAt,
          updatedAt: _clock().toUtc(),
        );
        await (_database.update(
          _database.periodRows,
        )..where((row) => row.id.equals(id))).write(_toCompanion(updated));
        return updated;
      });
    });
  }

  @override
  Future<void> delete(String id) {
    return _guardStorage(() async {
      final deleted = await (_database.delete(
        _database.periodRows,
      )..where((row) => row.id.equals(id))).go();
      if (deleted == 0) {
        throw const PeriodWriteException(PeriodWriteFailure.notFound);
      }
    });
  }

  @override
  Future<void> close() => _database.close();

  Future<T> _guardStorage<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PeriodWriteException {
      rethrow;
    } on Object {
      throw const PeriodWriteException(PeriodWriteFailure.storageUnavailable);
    }
  }

  static PeriodRecord _toDomain(PeriodRow row) {
    return PeriodRecord(
      id: row.id,
      startDate: LocalDate.fromEpochDay(row.startDay),
      endDate: row.endDay == null ? null : LocalDate.fromEpochDay(row.endDay!),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAtMillis,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAtMillis,
        isUtc: true,
      ),
    );
  }

  static PeriodRowsCompanion _toCompanion(PeriodRecord record) {
    return PeriodRowsCompanion(
      id: Value(record.id),
      startDay: Value(record.startDate.epochDay),
      endDay: Value(record.endDate?.epochDay),
      createdAtMillis: Value(record.createdAt.millisecondsSinceEpoch),
      updatedAtMillis: Value(record.updatedAt.millisecondsSinceEpoch),
    );
  }

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
