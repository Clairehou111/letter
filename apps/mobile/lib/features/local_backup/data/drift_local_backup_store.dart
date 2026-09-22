import 'dart:convert';

import 'package:drift/drift.dart';

import '../../care/domain/care_memory.dart';
import '../../care/domain/care_mode.dart';
import '../../capture/domain/capture_models.dart';
import '../../check_in/domain/moment_check_in.dart';
import '../../cycle/data/letter_health_database.dart';
import '../../health_records/domain/health_record.dart';
import '../domain/local_backup_import.dart';
import '../domain/local_backup_models.dart';

/// Bridges the encrypted Drift database to the encrypted backup package.
///
/// Every record here was explicitly saved by the user and retains its stable
/// ID and timestamps.
final class DriftLocalBackupStore implements LocalBackupStore {
  DriftLocalBackupStore(this._database, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final LetterHealthDatabase _database;
  final DateTime Function() _clock;

  @override
  Future<LocalBackupSnapshot> captureSnapshot() async {
    try {
      return await _database.transaction(() async {
        final periods = await _database.select(_database.periodRows).get();
        final periodFlows = await _database
            .select(_database.periodFlowRows)
            .get();
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
        final preparationPlans = await _database
            .select(_database.preparationPlanRows)
            .get();
        final preparationDismissals = await _database
            .select(_database.preparationDismissalRows)
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
              name: _periodFlows,
              schemaVersion: 2,
              records: periodFlows.map(
                (row) =>
                    _record('${row.periodId}:${row.day}', row.updatedAtMillis, {
                      'periodId': row.periodId,
                      'day': row.day,
                      'flow': row.flow,
                      'color': row.color,
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
              schemaVersion: 2,
              records: cycleReflections.map(
                (row) => _record(row.id, row.updatedAtMillis, {
                  'cycleStartDay': row.cycleStartDay,
                  'startingPeriodId': row.startingPeriodId,
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
              schemaVersion: 2,
              records: healthRecords.map(
                (row) => _record(row.id, row.updatedAtMillis, {
                  'symptom': row.symptom,
                  'severity': row.severity,
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
            LocalBackupCollection(
              name: _preparationPlans,
              schemaVersion: 2,
              records: preparationPlans.map(
                (row) => _record(row.id, row.updatedAtMillis, {
                  'status': row.status,
                  'evidenceFingerprint': row.evidenceFingerprint,
                  'sourceRecordIdsJson': row.sourceRecordIdsJson,
                  'includeCare': row.includeCare,
                  'careActionId': row.careActionId,
                  'careActionLabel': row.careActionLabel,
                  'careMode': row.careMode,
                  'betterCount': row.betterCount,
                  'sameCount': row.sameCount,
                  'worseCount': row.worseCount,
                  'noteText': row.noteText,
                  'personalText': row.personalText,
                  'createdAtMillis': row.createdAtMillis,
                  'updatedAtMillis': row.updatedAtMillis,
                }),
              ),
            ),
            LocalBackupCollection(
              name: _preparationDismissals,
              schemaVersion: 1,
              records: preparationDismissals.map(
                (row) => _record(row.fingerprint, row.dismissedAtMillis, {
                  'evidenceLine': row.evidenceLine,
                  'dismissedAtMillis': row.dismissedAtMillis,
                }),
              ),
            ),
          ],
        );
      });
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
const _periodFlows = 'period_flows';
const _careRecords = 'care_records';
const _careReflections = 'care_reflections';
const _cycleReflections = 'cycle_reflections';
const _healthRecords = 'health_records';
const _captureNotes = 'capture_notes';
const _momentCheckIns = 'moment_check_ins';
const _preparationPlans = 'preparation_plans';
const _preparationDismissals = 'preparation_dismissals';
const _requiredCollections = {
  _periods,
  _careRecords,
  _careReflections,
  _healthRecords,
  _captureNotes,
};
const _supportedCollections = {
  ..._requiredCollections,
  _periodFlows,
  _cycleReflections,
  _momentCheckIns,
  _preparationPlans,
  _preparationDismissals,
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
    required this.periodFlows,
    required this.careRecords,
    required this.careReflections,
    required this.cycleReflections,
    required this.healthRecords,
    required this.captureNotes,
    required this.momentCheckIns,
    required this.preparationPlans,
    required this.preparationDismissals,
  });

  final List<PeriodRowsCompanion> periods;
  final List<PeriodFlowRowsCompanion> periodFlows;
  final List<CareRecordRowsCompanion> careRecords;
  final List<CareReflectionRowsCompanion> careReflections;
  final List<CycleReflectionRowsCompanion> cycleReflections;
  final List<HealthRecordRowsCompanion> healthRecords;
  final List<CaptureNoteRowsCompanion> captureNotes;
  final List<MomentCheckInRowsCompanion> momentCheckIns;
  final List<PreparationPlanRowsCompanion> preparationPlans;
  final List<PreparationDismissalRowsCompanion> preparationDismissals;

  factory _ParsedSnapshot.fromSnapshot(LocalBackupSnapshot snapshot) {
    validateLocalBackupReferentialIntegrity(snapshot);
    final byName = {
      for (final collection in snapshot.collections)
        collection.name: collection,
    };
    if (!byName.keys.toSet().containsAll(_requiredCollections) ||
        !byName.keys.every(_supportedCollections.contains) ||
        byName.values.any((collection) => !_supportsSchema(collection))) {
      throw const LocalBackupException(LocalBackupFailure.unsupportedFormat);
    }
    _validatePeriodFlowContainment(byName);
    return _ParsedSnapshot(
      periods: byName[_periods]!.records.map(_period).toList(growable: false),
      periodFlows:
          byName[_periodFlows]?.records
              .map(
                (record) =>
                    _periodFlow(record, byName[_periodFlows]!.schemaVersion),
              )
              .toList(growable: false) ??
          const [],
      careRecords: byName[_careRecords]!.records
          .map(_careRecord)
          .toList(growable: false),
      careReflections: byName[_careReflections]!.records
          .map(_careReflection)
          .toList(growable: false),
      cycleReflections:
          byName[_cycleReflections]?.records
              .map(
                (record) => _cycleReflection(
                  record,
                  byName[_cycleReflections]!.schemaVersion,
                ),
              )
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
      preparationPlans:
          byName[_preparationPlans]?.records
              .map(
                (record) => _preparationPlan(
                  record,
                  byName[_preparationPlans]!.schemaVersion,
                ),
              )
              .toList(growable: false) ??
          const [],
      preparationDismissals:
          byName[_preparationDismissals]?.records
              .map(_preparationDismissal)
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
        await database.delete(database.periodFlowRows).go();
        await database.delete(database.preparationDismissalRows).go();
        await database.delete(database.preparationPlanRows).go();
        await database.delete(database.periodRows).go();
        await database.batch((batch) {
          batch.insertAll(database.periodRows, parsed.periods);
          batch.insertAll(database.periodFlowRows, parsed.periodFlows);
          batch.insertAll(database.careRecordRows, parsed.careRecords);
          batch.insertAll(database.careReflectionRows, parsed.careReflections);
          batch.insertAll(
            database.cycleReflectionRows,
            parsed.cycleReflections,
          );
          batch.insertAll(database.healthRecordRows, parsed.healthRecords);
          batch.insertAll(database.captureNoteRows, parsed.captureNotes);
          batch.insertAll(database.momentCheckInRows, parsed.momentCheckIns);
          batch.insertAll(
            database.preparationPlanRows,
            parsed.preparationPlans,
          );
          batch.insertAll(
            database.preparationDismissalRows,
            parsed.preparationDismissals,
          );
        });
        await database.normalizeContinuousPeriods();
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

void _validatePeriodFlowContainment(
  Map<String, LocalBackupCollection> collections,
) {
  final bounds = <String, ({int start, int? end})>{};
  for (final record in collections[_periods]!.records) {
    final data = _data(record, {
      'startDay',
      'endDay',
      'createdAtMillis',
      'updatedAtMillis',
    });
    bounds[record.id] = (
      start: _int(data, 'startDay'),
      end: _nullableInt(data, 'endDay'),
    );
  }
  final flows = collections[_periodFlows];
  if (flows == null) return;
  for (final record in flows.records) {
    final data = _data(record, {
      'periodId',
      'day',
      'flow',
      if (flows.schemaVersion >= 2) 'color',
      'createdAtMillis',
      'updatedAtMillis',
    });
    final period = bounds[_string(data, 'periodId')];
    final day = _int(data, 'day');
    if (period == null ||
        day < period.start ||
        (period.end != null && day > period.end!)) {
      throw const LocalBackupException(LocalBackupFailure.malformedPayload);
    }
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
  final start = _int(data, 'startDay');
  final end = _nullableInt(data, 'endDay');
  final created = _int(data, 'createdAtMillis');
  _matchesUpdatedAt(record, updated);
  if (record.id.trim().isEmpty ||
      (end != null && end < start) ||
      created > updated) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return PeriodRowsCompanion.insert(
    id: record.id,
    startDay: start,
    endDay: Value(end),
    createdAtMillis: created,
    updatedAtMillis: updated,
  );
}

PeriodFlowRowsCompanion _periodFlow(
  LocalBackupRecord record,
  int schemaVersion,
) {
  final data = _data(record, {
    'periodId',
    'day',
    'flow',
    if (schemaVersion >= 2) 'color',
    'createdAtMillis',
    'updatedAtMillis',
  });
  final periodId = _string(data, 'periodId');
  final day = _int(data, 'day');
  final updated = _int(data, 'updatedAtMillis');
  final created = _int(data, 'createdAtMillis');
  _matchesUpdatedAt(record, updated);
  if (record.id != '$periodId:$day') {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  final flow = _string(data, 'flow');
  if (!const {'spotting', 'light', 'medium', 'heavy'}.contains(flow)) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  final color = schemaVersion >= 2 ? _nullableString(data, 'color') : null;
  if (color != null &&
      !const {'pink', 'brightRed', 'darkRed', 'brown'}.contains(color)) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  if (created > updated) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return PeriodFlowRowsCompanion.insert(
    periodId: periodId,
    day: day,
    flow: flow,
    color: Value(color),
    createdAtMillis: created,
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
  final mode = _string(data, 'mode');
  final outcome = _string(data, 'outcome');
  final actionId = _string(data, 'actionId');
  final actionLabel = _string(data, 'actionLabel');
  final occurred = _int(data, 'occurredAtMillis');
  final created = _int(data, 'createdAtMillis');
  _matchesUpdatedAt(record, updated);
  if (!CareMode.values.map((value) => value.name).contains(mode) ||
      !CareOutcome.values.map((value) => value.name).contains(outcome) ||
      actionId.trim().isEmpty ||
      actionLabel.trim().isEmpty ||
      occurred > created ||
      created > updated) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return CareRecordRowsCompanion.insert(
    id: record.id,
    mode: mode,
    actionId: actionId,
    actionLabel: actionLabel,
    outcome: outcome,
    occurredAtMillis: occurred,
    createdAtMillis: created,
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
  final mode = _string(data, 'mode');
  final need = _nullableString(data, 'need');
  final created = _int(data, 'createdAtMillis');
  _matchesUpdatedAt(record, updated);
  if (!CareMode.values.map((value) => value.name).contains(mode) ||
      (need != null &&
          !ReflectionNeed.values.map((value) => value.name).contains(need)) ||
      created > updated) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return CareReflectionRowsCompanion.insert(
    id: record.id,
    careRecordId: _string(data, 'careRecordId'),
    mode: mode,
    observation: Value(_nullableString(data, 'observation')),
    need: Value(need),
    whatHelped: Value(_nullableString(data, 'whatHelped')),
    futureSelfNote: Value(_nullableString(data, 'futureSelfNote')),
    createdAtMillis: created,
    updatedAtMillis: updated,
  );
}

CycleReflectionRowsCompanion _cycleReflection(
  LocalBackupRecord record,
  int schemaVersion,
) {
  final data = _data(record, {
    'cycleStartDay',
    if (schemaVersion >= 2) 'startingPeriodId',
    'observation',
    'need',
    'whatHelped',
    'futureSelfNote',
    'createdAtMillis',
    'updatedAtMillis',
  });
  final updated = _int(data, 'updatedAtMillis');
  final need = _nullableString(data, 'need');
  final created = _int(data, 'createdAtMillis');
  _matchesUpdatedAt(record, updated);
  if ((need != null &&
          !ReflectionNeed.values.map((value) => value.name).contains(need)) ||
      created > updated) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return CycleReflectionRowsCompanion.insert(
    id: record.id,
    startingPeriodId: Value(
      schemaVersion >= 2 ? _nullableString(data, 'startingPeriodId') : null,
    ),
    cycleStartDay: _int(data, 'cycleStartDay'),
    observation: Value(_nullableString(data, 'observation')),
    need: Value(need),
    whatHelped: Value(_nullableString(data, 'whatHelped')),
    futureSelfNote: Value(_nullableString(data, 'futureSelfNote')),
    createdAtMillis: created,
    updatedAtMillis: updated,
  );
}

HealthRecordRowsCompanion _healthRecord(LocalBackupRecord record) {
  final data = _data(record, {
    'symptom',
    'severity',
    'functionalImpactsJson',
    'experiencedDay',
    'recordedAtMillis',
    'updatedAtMillis',
    'provenance',
    'userConfirmed',
    'vocabularyVersion',
  });
  final updated = _int(data, 'updatedAtMillis');
  final symptom = _string(data, 'symptom');
  final severity = _int(data, 'severity');
  final impactsJson = _string(data, 'functionalImpactsJson');
  final recorded = _int(data, 'recordedAtMillis');
  final provenance = _string(data, 'provenance');
  final vocabularyVersion = _int(data, 'vocabularyVersion');
  _matchesUpdatedAt(record, updated);
  try {
    final impacts = jsonDecode(impactsJson);
    if (!SymptomType.values.map((value) => value.name).contains(symptom) ||
        severity < 1 ||
        severity > SymptomSeverity.values.length ||
        impacts is! List ||
        impacts.any(
          (value) =>
              value is! String ||
              !FunctionalImpact.values.map((item) => item.name).contains(value),
        ) ||
        !HealthRecordProvenance.values
            .map((value) => value.storageKey)
            .contains(provenance) ||
        recorded > updated ||
        vocabularyVersion < 1) {
      throw const FormatException();
    }
  } on Object {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return HealthRecordRowsCompanion.insert(
    id: record.id,
    symptom: symptom,
    severity: severity,
    functionalImpactsJson: impactsJson,
    experiencedDay: _int(data, 'experiencedDay'),
    recordedAtMillis: recorded,
    updatedAtMillis: updated,
    provenance: provenance,
    userConfirmed: _bool(data, 'userConfirmed'),
    vocabularyVersion: vocabularyVersion,
  );
}

CaptureNoteRowsCompanion _captureNote(LocalBackupRecord record) {
  final data = _data(record, {'content', 'source', 'createdAtMillis'});
  final created = _int(data, 'createdAtMillis');
  final content = _string(data, 'content');
  final source = _string(data, 'source');
  _matchesUpdatedAt(record, created);
  if (content.length > captureTextLimit ||
      !CaptureSource.values.map((value) => value.name).contains(source)) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return CaptureNoteRowsCompanion.insert(
    id: record.id,
    content: content,
    source: source,
    createdAtMillis: created,
  );
}

MomentCheckInRowsCompanion _momentCheckIn(LocalBackupRecord record) {
  final data = _data(record, {'state', 'occurredAtMillis', 'createdAtMillis'});
  final created = _int(data, 'createdAtMillis');
  final state = _string(data, 'state');
  final occurred = _int(data, 'occurredAtMillis');
  _matchesUpdatedAt(record, created);
  if (!MomentCheckInState.values.map((value) => value.name).contains(state) ||
      occurred > created) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return MomentCheckInRowsCompanion.insert(
    id: record.id,
    state: state,
    occurredAtMillis: occurred,
    createdAtMillis: created,
  );
}

PreparationPlanRowsCompanion _preparationPlan(
  LocalBackupRecord record,
  int schemaVersion,
) {
  final keys = {
    'status',
    'evidenceFingerprint',
    'sourceRecordIdsJson',
    'includeCare',
    'careActionId',
    'careActionLabel',
    'careMode',
    'betterCount',
    'sameCount',
    'worseCount',
    'noteText',
    'createdAtMillis',
    'updatedAtMillis',
    if (schemaVersion >= 2) 'personalText',
  };
  final data = _data(record, keys);
  final updated = _int(data, 'updatedAtMillis');
  _matchesUpdatedAt(record, updated);
  final status = _string(data, 'status');
  final careMode = _string(data, 'careMode');
  final sourceIdsJson = _string(data, 'sourceRecordIdsJson');
  final counts = [
    _int(data, 'betterCount'),
    _int(data, 'sameCount'),
    _int(data, 'worseCount'),
  ];
  try {
    final sourceIds = jsonDecode(sourceIdsJson);
    if (!const {'current', 'privateReference'}.contains(status) ||
        !const {
          'explode',
          'heavy',
          'racing',
          'space',
          'physical',
        }.contains(careMode) ||
        sourceIds is! List ||
        sourceIds.any((value) => value is! String) ||
        counts.any((value) => value < 0)) {
      throw const FormatException();
    }
  } on Object {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return PreparationPlanRowsCompanion.insert(
    id: record.id,
    status: status,
    evidenceFingerprint: _string(data, 'evidenceFingerprint'),
    sourceRecordIdsJson: sourceIdsJson,
    includeCare: _bool(data, 'includeCare'),
    careActionId: _string(data, 'careActionId'),
    careActionLabel: _string(data, 'careActionLabel'),
    careMode: careMode,
    betterCount: counts[0],
    sameCount: counts[1],
    worseCount: counts[2],
    noteText: Value(_nullableString(data, 'noteText')),
    personalText: Value(
      schemaVersion >= 2 ? _nullableString(data, 'personalText') : null,
    ),
    createdAtMillis: _int(data, 'createdAtMillis'),
    updatedAtMillis: updated,
  );
}

bool _supportsSchema(LocalBackupCollection collection) {
  if (collection.name == _periodFlows) {
    return collection.schemaVersion == 1 || collection.schemaVersion == 2;
  }
  if (collection.name == _cycleReflections) {
    return collection.schemaVersion == 1 || collection.schemaVersion == 2;
  }
  if (collection.name == _preparationPlans) {
    return collection.schemaVersion == 1 || collection.schemaVersion == 2;
  }
  if (collection.name == _healthRecords) {
    return collection.schemaVersion == 2;
  }
  return collection.schemaVersion == 1;
}

PreparationDismissalRowsCompanion _preparationDismissal(
  LocalBackupRecord record,
) {
  final data = _data(record, {'evidenceLine', 'dismissedAtMillis'});
  final dismissedAt = _int(data, 'dismissedAtMillis');
  _matchesUpdatedAt(record, dismissedAt);
  return PreparationDismissalRowsCompanion.insert(
    fingerprint: record.id,
    evidenceLine: _string(data, 'evidenceLine'),
    dismissedAtMillis: dismissedAt,
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
