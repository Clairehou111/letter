import 'dart:math';

import 'package:drift/drift.dart';

import '../../cycle/data/letter_health_database.dart';
import '../domain/moment_check_in.dart';
import '../domain/moment_check_in_repository.dart';

final class DriftMomentCheckInRepository implements MomentCheckInRepository {
  DriftMomentCheckInRepository(
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
  Future<List<MomentCheckIn>> getAll() {
    return _guard(() async {
      final query = _database.select(_database.momentCheckInRows)
        ..orderBy([(row) => OrderingTerm.desc(row.occurredAtMillis)]);
      return (await query.get()).map(_fromRow).toList(growable: false);
    });
  }

  @override
  Future<MomentCheckIn> create(
    MomentCheckInState state, {
    required DateTime occurredAt,
  }) {
    return _guard(() async {
      final record = MomentCheckIn(
        id: _idGenerator(),
        state: state,
        occurredAt: occurredAt.toUtc(),
        createdAt: _clock().toUtc(),
      );
      await _database
          .into(_database.momentCheckInRows)
          .insert(
            MomentCheckInRowsCompanion.insert(
              id: record.id,
              state: record.state.name,
              occurredAtMillis: record.occurredAt.millisecondsSinceEpoch,
              createdAtMillis: record.createdAt.millisecondsSinceEpoch,
            ),
          );
      return record;
    });
  }

  @override
  Future<void> delete(String id) {
    return _guard(() async {
      final deleted = await (_database.delete(
        _database.momentCheckInRows,
      )..where((row) => row.id.equals(id))).go();
      if (deleted == 0) {
        throw const MomentCheckInException(MomentCheckInFailure.notFound);
      }
    });
  }

  @override
  Future<void> close() async {
    if (closeDatabase) {
      await _database.close();
    }
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on MomentCheckInException {
      rethrow;
    } on Object {
      throw const MomentCheckInException(
        MomentCheckInFailure.storageUnavailable,
      );
    }
  }

  static MomentCheckIn _fromRow(MomentCheckInRow row) {
    try {
      return MomentCheckIn(
        id: row.id,
        state: MomentCheckInState.values.byName(row.state),
        occurredAt: DateTime.fromMillisecondsSinceEpoch(
          row.occurredAtMillis,
          isUtc: true,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.createdAtMillis,
          isUtc: true,
        ),
      );
    } on Object {
      throw const MomentCheckInException(
        MomentCheckInFailure.storageUnavailable,
      );
    }
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
