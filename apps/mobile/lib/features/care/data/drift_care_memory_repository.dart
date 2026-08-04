import 'dart:math';

import 'package:drift/drift.dart';

import '../../cycle/data/letter_health_database.dart';
import '../domain/care_memory.dart';
import '../domain/care_memory_repository.dart';
import '../domain/care_mode.dart';

final class DriftCareMemoryRepository implements CareMemoryRepository {
  DriftCareMemoryRepository(
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
  Future<List<CareRecord>> getRecords() {
    return _guardStorage(() async {
      final query = _database.select(_database.careRecordRows)
        ..orderBy([(row) => OrderingTerm.desc(row.occurredAtMillis)]);
      return (await query.get()).map(_recordFromRow).toList(growable: false);
    });
  }

  @override
  Future<CareRecord> saveOutcome(
    CareActionCompletion completion,
    CareOutcome outcome,
  ) {
    final valid = validateCareCompletion(completion);
    return _guardStorage(() async {
      final now = _clock().toUtc();
      final record = CareRecord(
        id: _idGenerator(),
        mode: valid.mode,
        actionId: valid.actionId,
        actionLabel: valid.actionLabel,
        outcome: outcome,
        occurredAt: valid.occurredAt,
        createdAt: now,
        updatedAt: now,
        pinned: false,
      );
      await _database
          .into(_database.careRecordRows)
          .insert(_recordCompanion(record));
      return record;
    });
  }

  @override
  Future<CareRecord> setPinned(String recordId, {required bool pinned}) {
    return _guardStorage(() async {
      final existing = await _findRecord(recordId);
      final updated = existing.copyWith(
        pinned: pinned,
        updatedAt: _clock().toUtc(),
      );
      await (_database.update(
        _database.careRecordRows,
      )..where((row) => row.id.equals(recordId))).write(
        CareRecordRowsCompanion(
          pinned: Value(pinned),
          updatedAtMillis: Value(updated.updatedAt.millisecondsSinceEpoch),
        ),
      );
      return updated;
    });
  }

  @override
  Future<void> deleteRecord(String recordId) {
    return _guardStorage(() {
      return _database.transaction(() async {
        final deleted = await (_database.delete(
          _database.careRecordRows,
        )..where((row) => row.id.equals(recordId))).go();
        if (deleted == 0) {
          throw const CareMemoryException(CareMemoryFailure.notFound);
        }
        await (_database.delete(
          _database.careReflectionRows,
        )..where((row) => row.careRecordId.equals(recordId))).go();
      });
    });
  }

  @override
  Future<List<CareReflection>> getReflections() {
    return _guardStorage(() async {
      final query = _database.select(_database.careReflectionRows)
        ..orderBy([(row) => OrderingTerm.desc(row.updatedAtMillis)]);
      return (await query.get())
          .map(_reflectionFromRow)
          .toList(growable: false);
    });
  }

  @override
  Future<CareReflection?> getReflectionForRecord(String recordId) {
    return _guardStorage(() async {
      final row = await (_database.select(
        _database.careReflectionRows,
      )..where((row) => row.careRecordId.equals(recordId))).getSingleOrNull();
      return row == null ? null : _reflectionFromRow(row);
    });
  }

  @override
  Future<CareReflection> saveReflection(
    String recordId,
    CareReflectionDraft draft,
  ) {
    final valid = validateCareReflection(draft);
    return _guardStorage(() {
      return _database.transaction(() async {
        final record = await _findRecord(recordId);
        final existing = await getReflectionForRecord(recordId);
        final now = _clock().toUtc();
        final reflection = CareReflection(
          id: existing?.id ?? _idGenerator(),
          careRecordId: recordId,
          mode: record.mode,
          observation: valid.observation,
          need: valid.need,
          whatHelped: valid.whatHelped,
          futureSelfNote: valid.futureSelfNote,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        );
        await _database
            .into(_database.careReflectionRows)
            .insertOnConflictUpdate(_reflectionCompanion(reflection));
        return reflection;
      });
    });
  }

  @override
  Future<void> deleteReflection(String reflectionId) {
    return _guardStorage(() async {
      final deleted = await (_database.delete(
        _database.careReflectionRows,
      )..where((row) => row.id.equals(reflectionId))).go();
      if (deleted == 0) {
        throw const CareMemoryException(CareMemoryFailure.notFound);
      }
    });
  }

  @override
  Future<List<CycleReflection>> getCycleReflections() {
    return _guardStorage(() async {
      final query = _database.select(_database.cycleReflectionRows)
        ..orderBy([(row) => OrderingTerm.desc(row.cycleStartDay)]);
      return (await query.get())
          .map(_cycleReflectionFromRow)
          .toList(growable: false);
    });
  }

  @override
  Future<CycleReflection?> getCycleReflection(int cycleStartDay) {
    return _guardStorage(() async {
      final row =
          await (_database.select(_database.cycleReflectionRows)
                ..where((row) => row.cycleStartDay.equals(cycleStartDay)))
              .getSingleOrNull();
      return row == null ? null : _cycleReflectionFromRow(row);
    });
  }

  @override
  Future<CycleReflection> saveCycleReflection(
    int cycleStartDay,
    CycleReflectionDraft draft,
  ) {
    final valid = validateCycleReflection(draft);
    return _guardStorage(() async {
      final existing = await getCycleReflection(cycleStartDay);
      final now = _clock().toUtc();
      final reflection = CycleReflection(
        id: existing?.id ?? _idGenerator(),
        cycleStartDay: cycleStartDay,
        observation: valid.observation,
        need: valid.need,
        whatHelped: valid.whatHelped,
        futureSelfNote: valid.futureSelfNote,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      await _database
          .into(_database.cycleReflectionRows)
          .insertOnConflictUpdate(_cycleReflectionCompanion(reflection));
      return reflection;
    });
  }

  @override
  Future<void> deleteCycleReflection(String reflectionId) {
    return _guardStorage(() async {
      final deleted = await (_database.delete(
        _database.cycleReflectionRows,
      )..where((row) => row.id.equals(reflectionId))).go();
      if (deleted == 0) {
        throw const CareMemoryException(CareMemoryFailure.notFound);
      }
    });
  }

  @override
  Future<void> close() async {
    if (closeDatabase) {
      await _database.close();
    }
  }

  Future<CareRecord> _findRecord(String id) async {
    final row = await (_database.select(
      _database.careRecordRows,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const CareMemoryException(CareMemoryFailure.notFound);
    }
    return _recordFromRow(row);
  }

  Future<T> _guardStorage<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on CareMemoryException {
      rethrow;
    } on Object {
      throw const CareMemoryException(CareMemoryFailure.storageUnavailable);
    }
  }

  static CareRecord _recordFromRow(CareRecordRow row) {
    return CareRecord(
      id: row.id,
      mode: _careMode(row.mode),
      actionId: row.actionId,
      actionLabel: row.actionLabel,
      outcome: CareOutcome.values.byName(row.outcome),
      occurredAt: _date(row.occurredAtMillis),
      createdAt: _date(row.createdAtMillis),
      updatedAt: _date(row.updatedAtMillis),
      pinned: row.pinned,
    );
  }

  static CareRecordRowsCompanion _recordCompanion(CareRecord record) {
    return CareRecordRowsCompanion.insert(
      id: record.id,
      mode: record.mode.name,
      actionId: record.actionId,
      actionLabel: record.actionLabel,
      outcome: record.outcome.name,
      occurredAtMillis: record.occurredAt.millisecondsSinceEpoch,
      createdAtMillis: record.createdAt.millisecondsSinceEpoch,
      updatedAtMillis: record.updatedAt.millisecondsSinceEpoch,
      pinned: Value(record.pinned),
    );
  }

  static CareReflection _reflectionFromRow(CareReflectionRow row) {
    return CareReflection(
      id: row.id,
      careRecordId: row.careRecordId,
      mode: _careMode(row.mode),
      observation: row.observation,
      need: row.need == null ? null : ReflectionNeed.values.byName(row.need!),
      whatHelped: row.whatHelped,
      futureSelfNote: row.futureSelfNote,
      createdAt: _date(row.createdAtMillis),
      updatedAt: _date(row.updatedAtMillis),
    );
  }

  static CareReflectionRowsCompanion _reflectionCompanion(
    CareReflection reflection,
  ) {
    return CareReflectionRowsCompanion.insert(
      id: reflection.id,
      careRecordId: reflection.careRecordId,
      mode: reflection.mode.name,
      observation: Value(reflection.observation),
      need: Value(reflection.need?.name),
      whatHelped: Value(reflection.whatHelped),
      futureSelfNote: Value(reflection.futureSelfNote),
      createdAtMillis: reflection.createdAt.millisecondsSinceEpoch,
      updatedAtMillis: reflection.updatedAt.millisecondsSinceEpoch,
    );
  }

  static CycleReflection _cycleReflectionFromRow(CycleReflectionRow row) {
    return CycleReflection(
      id: row.id,
      cycleStartDay: row.cycleStartDay,
      observation: row.observation,
      need: row.need == null ? null : ReflectionNeed.values.byName(row.need!),
      whatHelped: row.whatHelped,
      futureSelfNote: row.futureSelfNote,
      createdAt: _date(row.createdAtMillis),
      updatedAt: _date(row.updatedAtMillis),
    );
  }

  static CycleReflectionRowsCompanion _cycleReflectionCompanion(
    CycleReflection reflection,
  ) {
    return CycleReflectionRowsCompanion.insert(
      id: reflection.id,
      cycleStartDay: reflection.cycleStartDay,
      observation: Value(reflection.observation),
      need: Value(reflection.need?.name),
      whatHelped: Value(reflection.whatHelped),
      futureSelfNote: Value(reflection.futureSelfNote),
      createdAtMillis: reflection.createdAt.millisecondsSinceEpoch,
      updatedAtMillis: reflection.updatedAt.millisecondsSinceEpoch,
    );
  }

  static CareMode _careMode(String value) {
    try {
      return CareMode.values.byName(value);
    } on ArgumentError {
      throw const CareMemoryException(CareMemoryFailure.storageUnavailable);
    }
  }

  static DateTime _date(int millis) {
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
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
