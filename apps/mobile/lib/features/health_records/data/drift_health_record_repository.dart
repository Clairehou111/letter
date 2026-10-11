import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../cycle/data/letter_health_database.dart';
import '../../cycle/domain/local_date.dart';
import '../domain/health_record.dart';
import '../domain/health_record_repository.dart';
import '../domain/health_record_write_policy.dart';

final class DriftHealthRecordRepository implements HealthRecordRepository {
  DriftHealthRecordRepository(
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
  Future<List<HealthRecord>> getAll() {
    return _guardStorage(() async {
      final query = _database.select(_database.healthRecordRows)
        ..orderBy([
          (row) => OrderingTerm.desc(row.experiencedDay),
          (row) => OrderingTerm.desc(row.recordedAtMillis),
        ]);
      return (await query.get()).map(_fromRow).toList(growable: false);
    });
  }

  @override
  Future<HealthRecord> create(HealthRecordDraft draft) => _guardStorage(
    () => _database.transaction(() async {
      final valid = validateHealthRecordDraft(draft);
      final query = _database.select(_database.healthRecordRows)
        ..where(
          (row) =>
              row.symptom.equals(valid.symptom.name) &
              row.experiencedDay.equals(valid.experiencedDate.epochDay),
        );
      final existing = await query.getSingleOrNull();
      final previous = existing == null ? null : _fromRow(existing);
      final record = buildHealthRecord(
        id: previous?.id ?? _idGenerator(),
        draft: valid,
        localNow: _clock().toLocal(),
        previous: previous,
      );
      if (identical(record, previous)) return record;
      if (previous == null) {
        await _database
            .into(_database.healthRecordRows)
            .insert(_toCompanion(record));
      } else {
        await (_database.update(_database.healthRecordRows)
              ..where((row) => row.id.equals(record.id)))
            .write(_toUpdateCompanion(record));
      }
      return record;
    }),
  );

  @override
  Future<HealthRecord> update(
    String id,
    HealthRecordDraft draft,
  ) => _guardStorage(
    () => _database.transaction(() async {
      final valid = validateHealthRecordDraft(draft);
      final previous = await _findRecord(id);
      final conflict =
          await (_database.select(_database.healthRecordRows)..where(
                (row) =>
                    row.symptom.equals(valid.symptom.name) &
                    row.experiencedDay.equals(valid.experiencedDate.epochDay) &
                    row.id.equals(id).not(),
              ))
              .getSingleOrNull();
      if (conflict != null) {
        throw const HealthRecordException(HealthRecordFailure.dateCollision);
      }
      final updated = buildHealthRecord(
        id: id,
        draft: valid,
        localNow: _clock().toLocal(),
        previous: previous,
      );
      if (!identical(updated, previous)) {
        await (_database.update(_database.healthRecordRows)
              ..where((row) => row.id.equals(id)))
            .write(_toUpdateCompanion(updated));
      }
      return updated;
    }),
  );

  @override
  Future<HealthRecord> restore(
    HealthRecord record, {
    HealthRecord? expectedCurrent,
  }) => _guardStorage(
    () => _database.transaction(() async {
      final rows =
          await (_database.select(_database.healthRecordRows)..where(
                (row) =>
                    row.id.equals(record.id) |
                    (row.symptom.equals(record.symptom.name) &
                        row.experiencedDay.equals(
                          record.experiencedDate.epochDay,
                        )),
              ))
              .get();
      if (expectedCurrent == null
          ? rows.isNotEmpty
          : rows.length != 1 ||
                !sameHealthRecordVersion(
                  _fromRow(rows.single),
                  expectedCurrent,
                )) {
        throw const HealthRecordException(HealthRecordFailure.undoConflict);
      }
      if (expectedCurrent != null) {
        await (_database.delete(
          _database.healthRecordRows,
        )..where((row) => row.id.equals(expectedCurrent.id))).go();
      }
      await _database
          .into(_database.healthRecordRows)
          .insert(_toCompanion(record));
      return record;
    }),
  );

  @override
  Future<void> delete(String id, {HealthRecord? expectedCurrent}) {
    return _guardStorage(
      () => _database.transaction(() async {
        if (expectedCurrent != null &&
            !sameHealthRecordVersion(await _findRecord(id), expectedCurrent)) {
          throw const HealthRecordException(HealthRecordFailure.undoConflict);
        }
        final deleted = await (_database.delete(
          _database.healthRecordRows,
        )..where((row) => row.id.equals(id))).go();
        if (deleted == 0) {
          throw const HealthRecordException(HealthRecordFailure.notFound);
        }
      }),
    );
  }

  @override
  Future<void> close() async {
    if (closeDatabase) {
      await _database.close();
    }
  }

  Future<HealthRecord> _findRecord(String id) async {
    final row = await (_database.select(
      _database.healthRecordRows,
    )..where((record) => record.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const HealthRecordException(HealthRecordFailure.notFound);
    }
    return _fromRow(row);
  }

  Future<T> _guardStorage<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on HealthRecordException {
      rethrow;
    } on Object {
      throw const HealthRecordException(HealthRecordFailure.storageUnavailable);
    }
  }

  static HealthRecord _fromRow(HealthRecordRow row) {
    try {
      return HealthRecord(
        id: row.id,
        symptom: SymptomType.values.byName(row.symptom),
        severity: SymptomSeverity.fromScore(row.severity),
        functionalImpacts: _decodeSet<FunctionalImpact>(
          row.functionalImpactsJson,
          FunctionalImpact.values.byName,
        ),
        experiencedDate: LocalDate.fromEpochDay(row.experiencedDay),
        recordedAt: _date(row.recordedAtMillis),
        updatedAt: _date(row.updatedAtMillis),
        provenance: _provenance(row.provenance),
        originalProvenance: _provenance(
          row.originalProvenance ?? row.provenance,
        ),
        writeZoneOffsetMinutes: row.writeZoneOffsetMinutes,
        writeZoneName: row.writeZoneName,
        updatedZoneOffsetMinutes: row.updatedZoneOffsetMinutes,
        updatedZoneName: row.updatedZoneName,
        userConfirmed: row.userConfirmed,
        vocabularyVersion: row.vocabularyVersion,
      );
    } on Object {
      throw const HealthRecordException(HealthRecordFailure.storageUnavailable);
    }
  }

  static HealthRecordRowsCompanion _toCompanion(HealthRecord record) {
    return HealthRecordRowsCompanion.insert(
      id: record.id,
      symptom: record.symptom.name,
      severity: record.severity.score,
      functionalImpactsJson: jsonEncode(
        record.functionalImpacts.map((impact) => impact.name).toList(),
      ),
      experiencedDay: record.experiencedDate.epochDay,
      recordedAtMillis: record.recordedAt.millisecondsSinceEpoch,
      updatedAtMillis: record.updatedAt.millisecondsSinceEpoch,
      provenance: record.provenance.storageKey,
      originalProvenance: Value(record.effectiveOriginalProvenance.storageKey),
      writeZoneOffsetMinutes: Value(record.writeZoneOffsetMinutes),
      writeZoneName: Value(record.writeZoneName),
      updatedZoneOffsetMinutes: Value(record.updatedZoneOffsetMinutes),
      updatedZoneName: Value(record.updatedZoneName),
      userConfirmed: record.userConfirmed,
      vocabularyVersion: record.vocabularyVersion,
    );
  }

  static HealthRecordRowsCompanion _toUpdateCompanion(HealthRecord record) {
    return HealthRecordRowsCompanion(
      symptom: Value(record.symptom.name),
      severity: Value(record.severity.score),
      functionalImpactsJson: Value(
        jsonEncode(
          record.functionalImpacts.map((impact) => impact.name).toList(),
        ),
      ),
      experiencedDay: Value(record.experiencedDate.epochDay),
      updatedAtMillis: Value(record.updatedAt.millisecondsSinceEpoch),
      provenance: Value(record.provenance.storageKey),
      originalProvenance: Value(record.effectiveOriginalProvenance.storageKey),
      writeZoneOffsetMinutes: Value(record.writeZoneOffsetMinutes),
      writeZoneName: Value(record.writeZoneName),
      updatedZoneOffsetMinutes: Value(record.updatedZoneOffsetMinutes),
      updatedZoneName: Value(record.updatedZoneName),
    );
  }

  static Set<T> _decodeSet<T>(String encoded, T Function(String) fromName) {
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('Expected a list.');
    }
    return Set.unmodifiable(
      decoded.map((value) {
        if (value is! String) {
          throw const FormatException('Expected a string.');
        }
        return fromName(value);
      }).cast<T>(),
    );
  }

  static HealthRecordProvenance _provenance(String value) {
    return HealthRecordProvenance.fromStorageKey(value);
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
