import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../domain/bleeding_flow.dart';
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
    this.closeDatabase = true,
  }) : _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _randomId;

  final LetterHealthDatabase _database;
  final DateTime Function() _clock;
  final String Function() _idGenerator;
  final bool closeDatabase;

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
        final upperBound = draft.endDate?.epochDay ?? today.epochDay;
        await (_database.delete(_database.periodFlowRows)..where(
              (row) =>
                  row.periodId.equals(id) &
                  (row.day.isSmallerThanValue(draft.startDate.epochDay) |
                      row.day.isBiggerThanValue(upperBound)),
            ))
            .go();
        return updated;
      });
    });
  }

  @override
  Future<void> delete(String id) {
    return _guardStorage(() {
      return _database.transaction(() async {
        final deleted = await (_database.delete(
          _database.periodRows,
        )..where((row) => row.id.equals(id))).go();
        if (deleted == 0) {
          throw const PeriodWriteException(PeriodWriteFailure.notFound);
        }
        await (_database.delete(
          _database.periodFlowRows,
        )..where((row) => row.periodId.equals(id))).go();
      });
    });
  }

  @override
  Future<List<BleedingDayRecord>> getAllFlowDays() async {
    final query = _database.select(_database.periodFlowRows)
      ..orderBy([
        (row) => OrderingTerm.desc(row.day),
        (row) => OrderingTerm.asc(row.periodId),
      ]);
    return (await query.get()).map(_flowToDomain).toList(growable: false);
  }

  @override
  Future<BleedingDayRecord> setFlow(
    String periodId,
    LocalDate date,
    BleedingFlow flow, {
    required LocalDate today,
  }) {
    return _guardStorage(() async {
      return _database.transaction(() async {
        final period = await (_database.select(
          _database.periodRows,
        )..where((row) => row.id.equals(periodId))).getSingleOrNull();
        if (period == null) {
          throw const PeriodWriteException(
            PeriodWriteFailure.flowPeriodNotFound,
          );
        }
        if (date.isAfter(today)) {
          throw const PeriodWriteException(PeriodWriteFailure.flowDateInFuture);
        }
        final upperBound = period.endDay ?? today.epochDay;
        if (date.epochDay < period.startDay || date.epochDay > upperBound) {
          throw const PeriodWriteException(
            PeriodWriteFailure.flowDateOutsidePeriod,
          );
        }
        final existing =
            await (_database.select(_database.periodFlowRows)..where(
                  (row) =>
                      row.periodId.equals(periodId) &
                      row.day.equals(date.epochDay),
                ))
                .getSingleOrNull();
        final now = _clock().toUtc();
        final record = BleedingDayRecord(
          periodId: periodId,
          date: date,
          flow: flow,
          color: existing?.color == null
              ? null
              : BleedingColor.values.byName(existing!.color!),
          createdAt: existing == null
              ? now
              : DateTime.fromMillisecondsSinceEpoch(
                  existing.createdAtMillis,
                  isUtc: true,
                ),
          updatedAt: now,
        );
        await _database
            .into(_database.periodFlowRows)
            .insert(_flowToCompanion(record), mode: InsertMode.insertOrReplace);
        return record;
      });
    });
  }

  @override
  Future<BleedingDayRecord> setBleedingColor(
    String periodId,
    LocalDate date,
    BleedingColor color,
  ) {
    return _guardStorage(() async {
      final existing =
          await (_database.select(_database.periodFlowRows)..where(
                (row) =>
                    row.periodId.equals(periodId) &
                    row.day.equals(date.epochDay),
              ))
              .getSingleOrNull();
      if (existing == null) {
        throw const PeriodWriteException(
          PeriodWriteFailure.flowRequiredForColor,
        );
      }
      final now = _clock().toUtc();
      await (_database.update(_database.periodFlowRows)..where(
            (row) =>
                row.periodId.equals(periodId) & row.day.equals(date.epochDay),
          ))
          .write(
            PeriodFlowRowsCompanion(
              color: Value(color.name),
              updatedAtMillis: Value(now.millisecondsSinceEpoch),
            ),
          );
      return BleedingDayRecord(
        periodId: existing.periodId,
        date: LocalDate.fromEpochDay(existing.day),
        flow: BleedingFlow.values.byName(existing.flow),
        color: color,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          existing.createdAtMillis,
          isUtc: true,
        ),
        updatedAt: now,
      );
    });
  }

  @override
  Future<void> clearBleedingColor(String periodId, LocalDate date) {
    return _guardStorage(() async {
      await (_database.update(_database.periodFlowRows)..where(
            (row) =>
                row.periodId.equals(periodId) & row.day.equals(date.epochDay),
          ))
          .write(
            PeriodFlowRowsCompanion(
              color: const Value(null),
              updatedAtMillis: Value(_clock().toUtc().millisecondsSinceEpoch),
            ),
          );
    });
  }

  @override
  Future<void> clearFlow(String periodId, LocalDate date) {
    return _guardStorage(() async {
      await (_database.delete(_database.periodFlowRows)..where(
            (row) =>
                row.periodId.equals(periodId) & row.day.equals(date.epochDay),
          ))
          .go();
    });
  }

  @override
  Future<void> close() async {
    if (closeDatabase) {
      await _database.close();
    }
  }

  Future<T> _guardStorage<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PeriodWriteException {
      rethrow;
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Period storage failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
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

  static BleedingDayRecord _flowToDomain(PeriodFlowRow row) {
    return BleedingDayRecord(
      periodId: row.periodId,
      date: LocalDate.fromEpochDay(row.day),
      flow: BleedingFlow.values.byName(row.flow),
      color: row.color == null ? null : BleedingColor.values.byName(row.color!),
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

  static PeriodFlowRowsCompanion _flowToCompanion(BleedingDayRecord record) {
    return PeriodFlowRowsCompanion(
      periodId: Value(record.periodId),
      day: Value(record.date.epochDay),
      flow: Value(record.flow.name),
      color: Value(record.color?.name),
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
