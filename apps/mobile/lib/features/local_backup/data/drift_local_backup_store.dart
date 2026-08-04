import 'package:drift/drift.dart';

import '../../cycle/data/letter_health_database.dart';
import '../domain/local_backup_import.dart';
import '../domain/local_backup_models.dart';

/// Bridges the encrypted Drift database to the encrypted backup package.
///
/// Impulse drafts are deliberately excluded: a sealed draft must not gain an
/// export path before its lock expires. All other records here were explicitly
/// saved by the user and retain their stable IDs and timestamps.
final class DriftLocalBackupStore implements LocalBackupStore {
  DriftLocalBackupStore(this._database, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final LetterHealthDatabase _database;
  final DateTime Function() _clock;

  @override
  Future<LocalBackupSnapshot> captureSnapshot() async {
    try {
      final periods = await _database.select(_database.periodRows).get();
      final careRecords = await _database
          .select(_database.careRecordRows)
          .get();
      final careReflections = await _database
          .select(_database.careReflectionRows)
          .get();
      final cycleReflections = await _database
          .select(_database.cycleReflectionRows)
          .get();
      final healthRecords = await _database
          .select(_database.healthRecordRows)
          .get();
      final captureNotes = await _database
          .select(_database.captureNoteRows)
          .get();
      final momentCheckIns = await _database
          .select(_database.momentCheckInRows)
          .get();
      return LocalBackupSnapshot(
        createdAt: _clock().toUtc(),
        collections: [
          LocalBackupCollection(
            name: _periods,
            schemaVersion: 1,
            records: periods.map(
              (row) => _record(row.id, row.updatedAtMillis, {
                'startDay': row.startDay,
                'endDay': row.endDay,
                'createdAtMillis': row.createdAtMillis,
                'updatedAtMillis': row.updatedAtMillis,
              }),
            ),
          ),
          LocalBackupCollection(
            name: _careRecords,
            schemaVersion: 1,
            records: careRecords.map(
              (row) => _record(row.id, row.updatedAtMillis, {
                'mode': row.mode,
                'actionId': row.actionId,
                'actionLabel': row.actionLabel,
                'outcome': row.outcome,
                'occurredAtMillis': row.occurredAtMillis,
                'createdAtMillis': row.createdAtMillis,
                'updatedAtMillis': row.updatedAtMillis,
                'pinned': row.pinned,
              }),
            ),
          ),
          LocalBackupCollection(
            name: _careReflections,
            schemaVersion: 1,
            records: careReflections.map(
              (row) => _record(row.id, row.updatedAtMillis, {
                'careRecordId': row.careRecordId,
                'mode': row.mode,
                'observation': row.observation,
                'need': row.need,
                'whatHelped': row.whatHelped,
                'futureSelfNote': row.futureSelfNote,
                'createdAtMillis': row.createdAtMillis,
                'updatedAtMillis': row.updatedAtMillis,
              }),
            ),
          ),
          LocalBackupCollection(
            name: _cycleReflections,
            schemaVersion: 1,
            records: cycleReflections.map(
              (row) => _record(row.id, row.updatedAtMillis, {
                'cycleStartDay': row.cycleStartDay,
                'observation': row.observation,
                'need': row.need,
                'whatHelped': row.whatHelped,
                'futureSelfNote': row.futureSelfNote,
                'createdAtMillis': row.createdAtMillis,
                'updatedAtMillis': row.updatedAtMillis,
              }),
            ),
          ),
          LocalBackupCollection(
            name: _healthRecords,
            schemaVersion: 1,
            records: healthRecords.map(
              (row) => _record(row.id, row.updatedAtMillis, {
                'symptom': row.symptom,
                'severity': row.severity,
                'painRating': row.painRating,
                'painLocationsJson': row.painLocationsJson,
                'functionalImpactsJson': row.functionalImpactsJson,
                'experiencedDay': row.experiencedDay,
                'recordedAtMillis': row.recordedAtMillis,
                'updatedAtMillis': row.updatedAtMillis,
                'provenance': row.provenance,
                'userConfirmed': row.userConfirmed,
                'vocabularyVersion': row.vocabularyVersion,
              }),
            ),
          ),
          LocalBackupCollection(
            name: _captureNotes,
            schemaVersion: 1,
            records: captureNotes.map(
              (row) => _record(row.id, row.createdAtMillis, {
                'content': row.content,
                'source': row.source,
                'createdAtMillis': row.createdAtMillis,
              }),
            ),
          ),
          LocalBackupCollection(
            name: _momentCheckIns,
            schemaVersion: 1,
            records: momentCheckIns.map(
              (row) => _record(row.id, row.createdAtMillis, {
                'state': row.state,
                'occurredAtMillis': row.occurredAtMillis,
                'createdAtMillis': row.createdAtMillis,
              }),
            ),
          ),
        ],
      );
    } on LocalBackupException {
      rethrow;
    } on Object {
      throw const LocalBackupException(LocalBackupFailure.stagingFailed);
    }
  }

  @override
  Future<StagedLocalBackupImport> stage(LocalBackupImportPlan plan) async {
    try {
      final parsed = _ParsedSnapshot.fromSnapshot(plan.resultingSnapshot);
      return _DriftStagedLocalBackupImport(
        database: _database,
        plan: plan,
        parsed: parsed,
      );
    } on LocalBackupException {
      rethrow;
    } on Object {
      throw const LocalBackupException(LocalBackupFailure.stagingFailed);
    }
  }
}

const _periods = 'periods';
const _careRecords = 'care_records';
const _careReflections = 'care_reflections';
const _cycleReflections = 'cycle_reflections';
const _healthRecords = 'health_records';
const _captureNotes = 'capture_notes';
const _momentCheckIns = 'moment_check_ins';
const _requiredCollections = {
  _periods,
  _careRecords,
  _careReflections,
  _healthRecords,
  _captureNotes,
};
const _supportedCollections = {
  ..._requiredCollections,
  _cycleReflections,
  _momentCheckIns,
};

LocalBackupRecord _record(
  String id,
  int updatedAtMillis,
  Map<String, Object?> data,
) => LocalBackupRecord(
  id: id,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMillis, isUtc: true),
  data: data,
);

final class _ParsedSnapshot {
  const _ParsedSnapshot({
    required this.periods,
    required this.careRecords,
    required this.careReflections,
    required this.cycleReflections,
    required this.healthRecords,
    required this.captureNotes,
    required this.momentCheckIns,
  });

  final List<PeriodRowsCompanion> periods;
  final List<CareRecordRowsCompanion> careRecords;
  final List<CareReflectionRowsCompanion> careReflections;
  final List<CycleReflectionRowsCompanion> cycleReflections;
  final List<HealthRecordRowsCompanion> healthRecords;
  final List<CaptureNoteRowsCompanion> captureNotes;
  final List<MomentCheckInRowsCompanion> momentCheckIns;

  factory _ParsedSnapshot.fromSnapshot(LocalBackupSnapshot snapshot) {
    final byName = {
      for (final collection in snapshot.collections)
        collection.name: collection,
    };
    if (!byName.keys.toSet().containsAll(_requiredCollections) ||
        !byName.keys.every(_supportedCollections.contains) ||
        byName.values.any((collection) => collection.schemaVersion != 1)) {
      throw const LocalBackupException(LocalBackupFailure.unsupportedFormat);
    }
    return _ParsedSnapshot(
      periods: byName[_periods]!.records.map(_period).toList(growable: false),
      careRecords: byName[_careRecords]!.records
          .map(_careRecord)
          .toList(growable: false),
      careReflections: byName[_careReflections]!.records
          .map(_careReflection)
          .toList(growable: false),
      cycleReflections:
          byName[_cycleReflections]?.records
              .map(_cycleReflection)
              .toList(growable: false) ??
          const [],
      healthRecords: byName[_healthRecords]!.records
          .map(_healthRecord)
          .toList(growable: false),
      captureNotes: byName[_captureNotes]!.records
          .map(_captureNote)
          .toList(growable: false),
      momentCheckIns:
          byName[_momentCheckIns]?.records
              .map(_momentCheckIn)
              .toList(growable: false) ??
          const [],
    );
  }
}

final class _DriftStagedLocalBackupImport implements StagedLocalBackupImport {
  _DriftStagedLocalBackupImport({
    required this.database,
    required this.plan,
    required this.parsed,
  });

  final LetterHealthDatabase database;
  final LocalBackupImportPlan plan;
  final _ParsedSnapshot parsed;
  var _used = false;

  @override
  LocalBackupImportPreview get preview => plan.preview;

  @override
  Future<void> commit() async {
    if (_used) {
      throw const LocalBackupException(LocalBackupFailure.stagingFailed);
    }
    try {
      await database.transaction(() async {
        await database.delete(database.careReflectionRows).go();
        await database.delete(database.cycleReflectionRows).go();
        await database.delete(database.careRecordRows).go();
        await database.delete(database.healthRecordRows).go();
        await database.delete(database.captureNoteRows).go();
        await database.delete(database.momentCheckInRows).go();
        await database.delete(database.periodRows).go();
        await database.batch((batch) {
          batch.insertAll(database.periodRows, parsed.periods);
          batch.insertAll(database.careRecordRows, parsed.careRecords);
          batch.insertAll(database.careReflectionRows, parsed.careReflections);
          batch.insertAll(
            database.cycleReflectionRows,
            parsed.cycleReflections,
          );
          batch.insertAll(database.healthRecordRows, parsed.healthRecords);
          batch.insertAll(database.captureNoteRows, parsed.captureNotes);
          batch.insertAll(database.momentCheckInRows, parsed.momentCheckIns);
        });
      });
      _used = true;
    } on LocalBackupException {
      rethrow;
    } on Object {
      throw const LocalBackupException(LocalBackupFailure.stagingFailed);
    }
  }

  @override
  Future<void> discard() async {
    _used = true;
  }
}

PeriodRowsCompanion _period(LocalBackupRecord record) {
  final data = _data(record, {
    'startDay',
    'endDay',
    'createdAtMillis',
    'updatedAtMillis',
  });
  final updated = _int(data, 'updatedAtMillis');
  _matchesUpdatedAt(record, updated);
  return PeriodRowsCompanion.insert(
    id: record.id,
    startDay: _int(data, 'startDay'),
    endDay: Value(_nullableInt(data, 'endDay')),
    createdAtMillis: _int(data, 'createdAtMillis'),
    updatedAtMillis: updated,
  );
}

CareRecordRowsCompanion _careRecord(LocalBackupRecord record) {
  final data = _data(record, {
    'mode',
    'actionId',
    'actionLabel',
    'outcome',
    'occurredAtMillis',
    'createdAtMillis',
    'updatedAtMillis',
    'pinned',
  });
  final updated = _int(data, 'updatedAtMillis');
  _matchesUpdatedAt(record, updated);
  return CareRecordRowsCompanion.insert(
    id: record.id,
    mode: _string(data, 'mode'),
    actionId: _string(data, 'actionId'),
    actionLabel: _string(data, 'actionLabel'),
    outcome: _string(data, 'outcome'),
    occurredAtMillis: _int(data, 'occurredAtMillis'),
    createdAtMillis: _int(data, 'createdAtMillis'),
    updatedAtMillis: updated,
    pinned: Value(_bool(data, 'pinned')),
  );
}

CareReflectionRowsCompanion _careReflection(LocalBackupRecord record) {
  final data = _data(record, {
    'careRecordId',
    'mode',
    'observation',
    'need',
    'whatHelped',
    'futureSelfNote',
    'createdAtMillis',
    'updatedAtMillis',
  });
  final updated = _int(data, 'updatedAtMillis');
  _matchesUpdatedAt(record, updated);
  return CareReflectionRowsCompanion.insert(
    id: record.id,
    careRecordId: _string(data, 'careRecordId'),
    mode: _string(data, 'mode'),
    observation: Value(_nullableString(data, 'observation')),
    need: Value(_nullableString(data, 'need')),
    whatHelped: Value(_nullableString(data, 'whatHelped')),
    futureSelfNote: Value(_nullableString(data, 'futureSelfNote')),
    createdAtMillis: _int(data, 'createdAtMillis'),
    updatedAtMillis: updated,
  );
}

CycleReflectionRowsCompanion _cycleReflection(LocalBackupRecord record) {
  final data = _data(record, {
    'cycleStartDay',
    'observation',
    'need',
    'whatHelped',
    'futureSelfNote',
    'createdAtMillis',
    'updatedAtMillis',
  });
  final updated = _int(data, 'updatedAtMillis');
  _matchesUpdatedAt(record, updated);
  return CycleReflectionRowsCompanion.insert(
    id: record.id,
    cycleStartDay: _int(data, 'cycleStartDay'),
    observation: Value(_nullableString(data, 'observation')),
    need: Value(_nullableString(data, 'need')),
    whatHelped: Value(_nullableString(data, 'whatHelped')),
    futureSelfNote: Value(_nullableString(data, 'futureSelfNote')),
    createdAtMillis: _int(data, 'createdAtMillis'),
    updatedAtMillis: updated,
  );
}

HealthRecordRowsCompanion _healthRecord(LocalBackupRecord record) {
  final data = _data(record, {
    'symptom',
    'severity',
    'painRating',
    'painLocationsJson',
    'functionalImpactsJson',
    'experiencedDay',
    'recordedAtMillis',
    'updatedAtMillis',
    'provenance',
    'userConfirmed',
    'vocabularyVersion',
  });
  final updated = _int(data, 'updatedAtMillis');
  _matchesUpdatedAt(record, updated);
  return HealthRecordRowsCompanion.insert(
    id: record.id,
    symptom: _string(data, 'symptom'),
    severity: _int(data, 'severity'),
    painRating: Value(_nullableInt(data, 'painRating')),
    painLocationsJson: _string(data, 'painLocationsJson'),
    functionalImpactsJson: _string(data, 'functionalImpactsJson'),
    experiencedDay: _int(data, 'experiencedDay'),
    recordedAtMillis: _int(data, 'recordedAtMillis'),
    updatedAtMillis: updated,
    provenance: _string(data, 'provenance'),
    userConfirmed: _bool(data, 'userConfirmed'),
    vocabularyVersion: _int(data, 'vocabularyVersion'),
  );
}

CaptureNoteRowsCompanion _captureNote(LocalBackupRecord record) {
  final data = _data(record, {'content', 'source', 'createdAtMillis'});
  final created = _int(data, 'createdAtMillis');
  _matchesUpdatedAt(record, created);
  return CaptureNoteRowsCompanion.insert(
    id: record.id,
    content: _string(data, 'content'),
    source: _string(data, 'source'),
    createdAtMillis: created,
  );
}

MomentCheckInRowsCompanion _momentCheckIn(LocalBackupRecord record) {
  final data = _data(record, {'state', 'occurredAtMillis', 'createdAtMillis'});
  final created = _int(data, 'createdAtMillis');
  _matchesUpdatedAt(record, created);
  return MomentCheckInRowsCompanion.insert(
    id: record.id,
    state: _string(data, 'state'),
    occurredAtMillis: _int(data, 'occurredAtMillis'),
    createdAtMillis: created,
  );
}

Map<String, Object?> _data(LocalBackupRecord record, Set<String> keys) {
  if (record.data.length != keys.length ||
      !record.data.keys.toSet().containsAll(keys)) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return record.data;
}

int _int(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! int) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return value;
}

int? _nullableInt(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value != null && value is! int) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return value as int?;
}

String _string(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! String) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return value;
}

String? _nullableString(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value != null && value is! String) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return value as String?;
}

bool _bool(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! bool) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return value;
}

void _matchesUpdatedAt(LocalBackupRecord record, int millis) {
  if (record.updatedAt.millisecondsSinceEpoch != millis) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
}
