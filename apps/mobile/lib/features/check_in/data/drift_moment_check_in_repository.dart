import 'dart:math';
import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';

import 'package:drift/drift.dart';

import '../../cycle/data/letter_health_database.dart';
import '../domain/moment_check_in.dart';
import '../domain/moment_check_in_repository.dart';

final class DriftMomentCheckInRepository
    implements CorrectableMomentRepository {
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
  final Map<String, MomentCheckIn> _deletedSources = {};

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
      final record = createMomentCheckIn(
        id: _idGenerator(),
        state: state,
        occurredAt: occurredAt,
        savedAt: _clock(),
      );
      await _database
          .into(_database.momentCheckInRows)
          .insert(_toCompanion(record));
      return record;
    });
  }

  @override
  Future<MomentCheckIn> update(
    String id,
    MomentCheckInState state, {
    MomentCheckIn? expected,
  }) => _guard(
    () => _database.transaction(() async {
      final row = await (_database.select(
        _database.momentCheckInRows,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (row == null) {
        throw const MomentCheckInException(MomentCheckInFailure.notFound);
      }
      final previous = _fromRow(row);
      if (expected != null && !momentCheckInsMatch(previous, expected)) {
        throw const MomentCheckInException(MomentCheckInFailure.staleWrite);
      }
      if (previous.state == state) return previous;
      final corrected = correctMomentCheckIn(
        previous: previous,
        state: state,
        savedAt: _clock(),
      );
      if (identical(corrected, previous)) return previous;
      await (_database.update(
        _database.momentCheckInRows,
      )..where((row) => row.id.equals(id))).write(_toCompanion(corrected));
      return corrected;
    }),
  );

  @override
  Future<bool> deleteIfUnchanged(MomentCheckIn expected) async {
    final deleted = await _guard(
      () => _database.transaction(() async {
        final row = await (_database.select(
          _database.momentCheckInRows,
        )..where((row) => row.id.equals(expected.id))).getSingleOrNull();
        if (row == null) return null;
        final current = _fromRow(row);
        if (!momentCheckInsMatch(current, expected)) return null;
        await (_database.delete(
          _database.momentCheckInRows,
        )..where((row) => row.id.equals(expected.id))).go();
        return current;
      }),
    );
    if (deleted == null) return false;
    _deletedSources[deleted.id] = deleted;
    return true;
  }

  @override
  Future<MomentCheckIn> restoreDeleted(MomentCheckIn deleted) async {
    final restored = await _guard(
      () => _database.transaction(() async {
        final trusted = _deletedSources[deleted.id];
        final existing = await (_database.select(
          _database.momentCheckInRows,
        )..where((row) => row.id.equals(deleted.id))).getSingleOrNull();
        if (trusted == null ||
            !momentCheckInsMatch(trusted, deleted) ||
            existing != null) {
          throw const MomentCheckInException(MomentCheckInFailure.staleWrite);
        }
        await _database
            .into(_database.momentCheckInRows)
            .insert(_toCompanion(trusted));
        return trusted;
      }),
    );
    _deletedSources.remove(deleted.id);
    return restored;
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
      _deletedSources.remove(id);
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
        experiencedDate: row.experiencedDay == null
            ? null
            : LocalDate.fromEpochDay(row.experiencedDay!),
        provenance: row.experiencedDay == null
            ? HealthRecordProvenance.timingUnknown
            : HealthRecordProvenance.fromStorageKey(row.provenance),
        originalProvenance: row.experiencedDay == null
            ? HealthRecordProvenance.timingUnknown
            : HealthRecordProvenance.fromStorageKey(
                row.originalProvenance ??
                    (row.updatedAtMillis == null ||
                            row.updatedAtMillis == row.createdAtMillis
                        ? row.provenance
                        : null),
              ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.updatedAtMillis ?? row.createdAtMillis,
          isUtc: true,
        ),
        updatedZoneOffsetMinutes:
            row.updatedZoneOffsetMinutes ??
            (row.updatedAtMillis == null ||
                    row.updatedAtMillis == row.createdAtMillis
                ? row.writeZoneOffsetMinutes
                : null),
        updatedZoneName:
            row.updatedZoneName ??
            (row.updatedAtMillis == null ||
                    row.updatedAtMillis == row.createdAtMillis
                ? row.writeZoneName
                : null),
        writeZoneOffsetMinutes: row.writeZoneOffsetMinutes,
        writeZoneName: row.writeZoneName,
      );
    } on Object {
      throw const MomentCheckInException(
        MomentCheckInFailure.storageUnavailable,
      );
    }
  }

  static MomentCheckInRowsCompanion _toCompanion(MomentCheckIn record) =>
      MomentCheckInRowsCompanion.insert(
        id: record.id,
        state: record.state.name,
        occurredAtMillis: record.occurredAt.millisecondsSinceEpoch,
        createdAtMillis: record.createdAt.millisecondsSinceEpoch,
        updatedAtMillis: Value(record.updatedAt.millisecondsSinceEpoch),
        experiencedDay: Value(record.experiencedDate?.epochDay),
        provenance: Value(record.provenance.storageKey),
        originalProvenance: Value(record.originalProvenance.storageKey),
        writeZoneOffsetMinutes: Value(record.writeZoneOffsetMinutes),
        writeZoneName: Value(record.writeZoneName),
        updatedZoneOffsetMinutes: Value(record.updatedZoneOffsetMinutes),
        updatedZoneName: Value(record.updatedZoneName),
      );

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
