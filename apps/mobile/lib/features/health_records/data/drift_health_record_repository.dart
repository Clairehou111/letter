import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../cycle/data/letter_health_database.dart';
import '../../cycle/domain/local_date.dart';
import '../domain/health_record.dart';
import '../domain/health_record_repository.dart';

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
  Future<HealthRecord> create(HealthRecordDraft draft) {
    final valid = validateHealthRecordDraft(draft);
    return _guardStorage(() async {
      final now = _clock().toUtc();
      final existingQuery = _database.select(_database.healthRecordRows)
        ..where(
          (row) =>
              row.symptom.equals(valid.symptom.name) &
              row.experiencedDay.equals(valid.experiencedDate.epochDay),
        )
        ..orderBy([(row) => OrderingTerm.desc(row.updatedAtMillis)])
        ..limit(1);
      final existingRow = await existingQuery.getSingleOrNull();
      if (existingRow != null) {
        final updated = _fromRow(
          existingRow,
        ).copyWith(draft: valid, updatedAt: now);
        await (_database.update(_database.healthRecordRows)
              ..where((row) => row.id.equals(updated.id)))
            .write(_toUpdateCompanion(updated));
        return updated;
      }
      final record = _fromDraft(
        id: _idGenerator(),
        draft: valid,
        recordedAt: now,
        updatedAt: now,
      );
      await _database
          .into(_database.healthRecordRows)
          .insert(_toCompanion(record));
      return record;
    });
  }

  @override
  Future<HealthRecord> update(String id, HealthRecordDraft draft) {
    final valid = validateHealthRecordDraft(draft);
    return _guardStorage(() async {
      final previous = await _findRecord(id);
      final updated = previous.copyWith(
        draft: valid,
        updatedAt: _clock().toUtc(),
      );
      await (_database.update(
        _database.healthRecordRows,
      )..where((row) => row.id.equals(id))).write(_toUpdateCompanion(updated));
      return updated;
    });
  }

  @override
  Future<void> delete(String id) {
    return _guardStorage(() async {
      final deleted = await (_database.delete(
        _database.healthRecordRows,
      )..where((row) => row.id.equals(id))).go();
      if (deleted == 0) {
        throw const HealthRecordException(HealthRecordFailure.notFound);
      }
    });
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
        severity: SymptomSeverity.values[row.severity - 1],
        painRating: row.painRating,
        painLocations: _decodeSet<PainLocation>(
          row.painLocationsJson,
          PainLocation.values.byName,
        ),
        functionalImpacts: _decodeSet<FunctionalImpact>(
          row.functionalImpactsJson,
          FunctionalImpact.values.byName,
        ),
        experiencedDate: LocalDate.fromEpochDay(row.experiencedDay),
        recordedAt: _date(row.recordedAtMillis),
        updatedAt: _date(row.updatedAtMillis),
        provenance: _provenance(row.provenance),
        userConfirmed: row.userConfirmed,
        vocabularyVersion: row.vocabularyVersion,
      );
    } on Object {
      throw const HealthRecordException(HealthRecordFailure.storageUnavailable);
    }
  }

  static HealthRecord _fromDraft({
    required String id,
    required HealthRecordDraft draft,
    required DateTime recordedAt,
    required DateTime updatedAt,
  }) {
    return HealthRecord(
      id: id,
      symptom: draft.symptom,
      severity: draft.severity,
      painRating: draft.painRating,
      painLocations: Set.unmodifiable(draft.painLocations),
      functionalImpacts: Set.unmodifiable(draft.functionalImpacts),
      experiencedDate: draft.experiencedDate,
      recordedAt: recordedAt,
      updatedAt: updatedAt,
      provenance: draft.provenance,
      userConfirmed: true,
      vocabularyVersion: healthRecordVocabularyVersion,
    );
  }

  static HealthRecordRowsCompanion _toCompanion(HealthRecord record) {
    return HealthRecordRowsCompanion.insert(
      id: record.id,
      symptom: record.symptom.name,
      severity: record.severity.score,
      painRating: Value(record.painRating),
      painLocationsJson: jsonEncode(
        record.painLocations.map((location) => location.name).toList(),
      ),
      functionalImpactsJson: jsonEncode(
        record.functionalImpacts.map((impact) => impact.name).toList(),
      ),
      experiencedDay: record.experiencedDate.epochDay,
      recordedAtMillis: record.recordedAt.millisecondsSinceEpoch,
      updatedAtMillis: record.updatedAt.millisecondsSinceEpoch,
      provenance: record.provenance.storageKey,
      userConfirmed: record.userConfirmed,
      vocabularyVersion: record.vocabularyVersion,
    );
  }

  static HealthRecordRowsCompanion _toUpdateCompanion(HealthRecord record) {
    return HealthRecordRowsCompanion(
      symptom: Value(record.symptom.name),
      severity: Value(record.severity.score),
      painRating: Value(record.painRating),
      painLocationsJson: Value(
        jsonEncode(
          record.painLocations.map((location) => location.name).toList(),
        ),
      ),
      functionalImpactsJson: Value(
        jsonEncode(
          record.functionalImpacts.map((impact) => impact.name).toList(),
        ),
      ),
      experiencedDay: Value(record.experiencedDate.epochDay),
      updatedAtMillis: Value(record.updatedAt.millisecondsSinceEpoch),
      provenance: Value(record.provenance.storageKey),
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
    return HealthRecordProvenance.values.firstWhere(
      (entry) => entry.storageKey == value,
    );
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
