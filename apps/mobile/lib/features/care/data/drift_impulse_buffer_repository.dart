import 'dart:math';

import 'package:drift/drift.dart';

import '../../cycle/data/letter_health_database.dart';
import '../domain/impulse_buffer_repository.dart';
import '../domain/impulse_draft_record.dart';

final class DriftImpulseBufferRepository implements ImpulseBufferRepository {
  DriftImpulseBufferRepository(
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
  Future<ImpulseDraftRecord?> getActive() {
    return _guardStorage(() async {
      final query = _database.select(_database.impulseDraftRows)
        ..orderBy([(row) => OrderingTerm.desc(row.updatedAtMillis)])
        ..limit(1);
      return (await query.getSingleOrNull())?.let(_toDomain);
    });
  }

  @override
  Future<ImpulseDraftRecord> saveDraft(String content) {
    final value = validateImpulseDraftContent(content);
    return _guardStorage(() {
      return _database.transaction(() async {
        final existing = await getActive();
        final now = _clock().toUtc();
        if (existing != null &&
            existing.stateAt(now) != ImpulseDraftState.draft) {
          throw const ImpulseBufferException(ImpulseBufferFailure.activeSealed);
        }
        final record = ImpulseDraftRecord(
          id: existing?.id ?? _idGenerator(),
          content: value,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
          sealedAt: null,
          unlockAt: null,
        );
        await _database
            .into(_database.impulseDraftRows)
            .insertOnConflictUpdate(_toCompanion(record));
        return record;
      });
    });
  }

  @override
  Future<ImpulseDraftRecord> sealDraft(String id, {required DateTime now}) {
    return _updateSealed(id, now: now, requiredState: ImpulseDraftState.draft);
  }

  @override
  Future<ImpulseDraftRecord> keepReadySealed(
    String id, {
    required DateTime now,
  }) {
    return _updateSealed(id, now: now, requiredState: ImpulseDraftState.ready);
  }

  @override
  Future<ImpulseDraftRecord> resealReady(
    String id,
    String content, {
    required DateTime now,
  }) {
    return _updateSealed(
      id,
      now: now,
      requiredState: ImpulseDraftState.ready,
      replacementContent: validateImpulseDraftContent(content),
    );
  }

  @override
  Future<void> delete(String id) {
    return _guardStorage(() async {
      final deleted = await (_database.delete(
        _database.impulseDraftRows,
      )..where((row) => row.id.equals(id))).go();
      if (deleted == 0) {
        throw const ImpulseBufferException(ImpulseBufferFailure.notFound);
      }
    });
  }

  @override
  Future<void> close() async {
    if (closeDatabase) {
      await _database.close();
    }
  }

  Future<ImpulseDraftRecord> _updateSealed(
    String id, {
    required DateTime now,
    required ImpulseDraftState requiredState,
    String? replacementContent,
  }) {
    return _guardStorage(() {
      return _database.transaction(() async {
        final existing = await _find(id);
        if (existing.stateAt(now) != requiredState) {
          throw ImpulseBufferException(
            requiredState == ImpulseDraftState.draft
                ? ImpulseBufferFailure.notDraft
                : ImpulseBufferFailure.notReady,
          );
        }
        final sealedAt = now.toUtc();
        final record = ImpulseDraftRecord(
          id: existing.id,
          content: replacementContent ?? existing.content,
          createdAt: existing.createdAt,
          updatedAt: sealedAt,
          sealedAt: sealedAt,
          unlockAt: sealedAt.add(impulseCooldown),
        );
        await (_database.update(
          _database.impulseDraftRows,
        )..where((row) => row.id.equals(id))).write(_toCompanion(record));
        return record;
      });
    });
  }

  Future<ImpulseDraftRecord> _find(String id) async {
    final row = await (_database.select(
      _database.impulseDraftRows,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const ImpulseBufferException(ImpulseBufferFailure.notFound);
    }
    return _toDomain(row);
  }

  Future<T> _guardStorage<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on ImpulseBufferException {
      rethrow;
    } on Object {
      throw const ImpulseBufferException(
        ImpulseBufferFailure.storageUnavailable,
      );
    }
  }

  static ImpulseDraftRecord _toDomain(ImpulseDraftRow row) {
    return ImpulseDraftRecord(
      id: row.id,
      content: row.content,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAtMillis,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAtMillis,
        isUtc: true,
      ),
      sealedAt: _fromMillis(row.sealedAtMillis),
      unlockAt: _fromMillis(row.unlockAtMillis),
    );
  }

  static ImpulseDraftRowsCompanion _toCompanion(ImpulseDraftRecord record) {
    return ImpulseDraftRowsCompanion(
      id: Value(record.id),
      content: Value(record.content),
      createdAtMillis: Value(record.createdAt.millisecondsSinceEpoch),
      updatedAtMillis: Value(record.updatedAt.millisecondsSinceEpoch),
      sealedAtMillis: Value(record.sealedAt?.millisecondsSinceEpoch),
      unlockAtMillis: Value(record.unlockAt?.millisecondsSinceEpoch),
    );
  }

  static DateTime? _fromMillis(int? value) {
    return value == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
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

extension _NullableLet<T> on T? {
  R? let<R>(R Function(T value) transform) {
    final value = this;
    return value == null ? null : transform(value);
  }
}
