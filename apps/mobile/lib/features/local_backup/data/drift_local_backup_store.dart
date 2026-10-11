import 'dart:convert';

import 'package:drift/drift.dart';

import '../../care/domain/care_memory.dart';
import '../../care/domain/care_mode.dart';
import '../../capture/domain/capture_models.dart';
import '../../check_in/domain/moment_check_in.dart';
import '../../comfort_kit/domain/comfort_kit.dart';
import '../../cycle/domain/local_date.dart';
import '../../cycle/data/letter_health_database.dart';
import '../../health_records/domain/health_record.dart';
import '../../record_hub/domain/record_hub_facts.dart';

import '../../record_hub/data/drift_record_interventions_repository.dart';
import '../../record_hub/data/drift_record_programme_repository.dart';

import '../../record_hub/data/drift_record_hub_repository.dart';
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
        final comfortKitOverrides = await _database
            .select(_database.comfortKitOverrideRows)
            .get();
        final comfortReminderPreferences = await _database
            .select(_database.comfortReminderPreferenceRows)
            .get();
        final hubImpact = await _database
            .select(_database.recordHubImpactRows)
            .get();
        final hubBleeding = await _database
            .select(_database.recordHubBleedingRows)
            .get();
        final hubSleep = await _database
            .select(_database.recordHubSleepRows)
            .get();
        final hubAppetite = await _database
            .select(_database.recordHubAppetiteRows)
            .get();
        final hubActivity = await _database
            .select(_database.recordHubActivityRows)
            .get();
        final hubEvent = await _database
            .select(_database.recordHubEventRows)
            .get();
        final hubTemperature = await _database
            .select(_database.recordHubTemperatureRows)
            .get();
        final hubPins = await (_database.select(
          _database.recordHubPinRows,
        )..orderBy([(row) => OrderingTerm.asc(row.position)])).get();
        final savedProductEpisode = await _database
            .select(_database.recordProductEpisodeRows)
            .get();
        final savedProductVersion = await _database
            .select(_database.recordProductVersionRows)
            .get();
        final savedProductUse = await _database
            .select(_database.recordProductUseRows)
            .get();
        final savedTriedAction = await _database
            .select(_database.recordTriedActionRows)
            .get();
        final savedTriedActionItem = await _database
            .select(_database.recordTriedActionItemRows)
            .get();
        final savedActionCheckback = await _database
            .select(_database.recordActionCheckbackRows)
            .get();
        final savedProgramme = await _database
            .select(_database.recordProgrammeRows)
            .get();
        final savedProgrammeConfig = await _database
            .select(_database.recordProgrammeConfigRows)
            .get();
        final savedProgrammePause = await _database
            .select(_database.recordProgrammePauseRows)
            .get();
        return LocalBackupSnapshot(
          createdAt: _clock().toUtc(),
          collections: [
            LocalBackupCollection(
              name: _savedProductEpisode,
              schemaVersion: 1,
              records: savedProductEpisode.map(
                (row) => _record(row.id, row.updatedAtMillis, row.toJson()),
              ),
            ),
            LocalBackupCollection(
              name: _savedProductVersion,
              schemaVersion: 1,
              records: savedProductVersion.map(
                (row) => _record(row.id, row.updatedAtMillis, row.toJson()),
              ),
            ),
            LocalBackupCollection(
              name: _savedProductUse,
              schemaVersion: 1,
              records: savedProductUse.map(
                (row) => _record(row.id, row.updatedAtMillis, row.toJson()),
              ),
            ),
            LocalBackupCollection(
              name: _savedTriedAction,
              schemaVersion: 1,
              records: savedTriedAction.map(
                (row) => _record(row.id, row.updatedAtMillis, row.toJson()),
              ),
            ),
            LocalBackupCollection(
              name: _savedTriedActionItem,
              schemaVersion: 1,
              records: savedTriedActionItem.map(
                (row) => _record(
                  '${row.actionId}:${row.position}',
                  savedTriedAction
                      .firstWhere((action) => action.id == row.actionId)
                      .updatedAtMillis,
                  row.toJson(),
                ),
              ),
            ),
            LocalBackupCollection(
              name: _savedActionCheckback,
              schemaVersion: 1,
              records: savedActionCheckback.map(
                (row) => _record(row.id, row.updatedAtMillis, row.toJson()),
              ),
            ),
            LocalBackupCollection(
              name: _savedProgramme,
              schemaVersion: 1,
              records: savedProgramme.map(
                (row) => _record(row.id, row.updatedAtMillis, row.toJson()),
              ),
            ),
            LocalBackupCollection(
              name: _savedProgrammeConfig,
              schemaVersion: 1,
              records: savedProgrammeConfig.map(
                (row) => _record(
                  row.id,
                  savedProgramme
                      .firstWhere(
                        (programme) => programme.id == row.programmeId,
                      )
                      .updatedAtMillis,
                  row.toJson(),
                ),
              ),
            ),
            LocalBackupCollection(
              name: _savedProgrammePause,
              schemaVersion: 1,
              records: savedProgrammePause.map(
                (row) => _record(
                  row.id,
                  savedProgramme
                      .firstWhere(
                        (programme) => programme.id == row.programmeId,
                      )
                      .updatedAtMillis,
                  row.toJson(),
                ),
              ),
            ),
            LocalBackupCollection(
              name: _hubImpact,
              schemaVersion: 1,
              records: hubImpact.map(
                (row) => _record(row.id, row.updatedAtMillis, row.toJson()),
              ),
            ),
            LocalBackupCollection(
              name: _hubBleeding,
              schemaVersion: 1,
              records: hubBleeding.map(
                (row) => _record(row.id, row.updatedAtMillis, row.toJson()),
              ),
            ),
            LocalBackupCollection(
              name: _hubSleep,
              schemaVersion: 1,
              records: hubSleep.map(
                (row) => _record(row.id, row.updatedAtMillis, row.toJson()),
              ),
            ),
            LocalBackupCollection(
              name: _hubAppetite,
              schemaVersion: 1,
              records: hubAppetite.map(
                (row) => _record(row.id, row.updatedAtMillis, row.toJson()),
              ),
            ),
            LocalBackupCollection(
              name: _hubActivity,
              schemaVersion: 1,
              records: hubActivity.map(
                (row) => _record(row.id, row.updatedAtMillis, row.toJson()),
              ),
            ),
            LocalBackupCollection(
              name: _hubEvent,
              schemaVersion: 1,
              records: hubEvent.map(
                (row) => _record(row.id, row.updatedAtMillis, row.toJson()),
              ),
            ),
            LocalBackupCollection(
              name: _hubTemperature,
              schemaVersion: 1,
              records: hubTemperature.map(
                (row) => _record(row.id, row.updatedAtMillis, row.toJson()),
              ),
            ),
            LocalBackupCollection(
              name: _hubPins,
              schemaVersion: 1,
              records: hubPins.isEmpty
                  ? const []
                  : [
                      _record('symptom-pins', 0, {
                        'symptoms': hubPins.map((row) => row.symptom).toList(),
                      }),
                    ],
            ),
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
              schemaVersion: 3,
              records: healthRecords.map(
                (row) => _record(row.id, row.updatedAtMillis, {
                  'symptom': row.symptom,
                  'severity': row.severity,
                  'functionalImpactsJson': row.functionalImpactsJson,
                  'experiencedDay': row.experiencedDay,
                  'recordedAtMillis': row.recordedAtMillis,
                  'updatedAtMillis': row.updatedAtMillis,
                  'provenance': row.provenance,
                  'originalProvenance': row.originalProvenance,
                  'writeZoneOffsetMinutes': row.writeZoneOffsetMinutes,
                  'writeZoneName': row.writeZoneName,
                  'updatedZoneOffsetMinutes': row.updatedZoneOffsetMinutes,
                  'updatedZoneName': row.updatedZoneName,
                  'userConfirmed': row.userConfirmed,
                  'vocabularyVersion': row.vocabularyVersion,
                }),
              ),
            ),
            LocalBackupCollection(
              name: _captureNotes,
              schemaVersion: 3,
              records: captureNotes.map(
                (row) => _record(
                  row.id,
                  row.updatedAtMillis == 0
                      ? row.createdAtMillis
                      : row.updatedAtMillis,
                  {
                    'keepInComfortKit': row.keepInComfortKit,
                    'content': row.content,
                    'experiencedDay': row.experiencedDay,
                    'updatedAtMillis': row.updatedAtMillis == 0
                        ? row.createdAtMillis
                        : row.updatedAtMillis,
                    'provenance': row.provenance,
                    'originalProvenance': row.originalProvenance,
                    'writeZoneOffsetMinutes': row.writeZoneOffsetMinutes,
                    'writeZoneName': row.writeZoneName,
                    'source': row.source,
                    'createdAtMillis': row.createdAtMillis,
                  },
                ),
              ),
            ),
            LocalBackupCollection(
              name: _momentCheckIns,
              schemaVersion: 3,
              records: momentCheckIns.map(
                (row) => _record(
                  row.id,
                  row.updatedAtMillis ?? row.createdAtMillis,
                  {
                    'state': row.state,
                    'occurredAtMillis': row.occurredAtMillis,
                    'createdAtMillis': row.createdAtMillis,
                    'experiencedDay': row.experiencedDay,
                    'provenance': row.experiencedDay == null
                        ? 'timing_unknown'
                        : row.provenance,
                    'writeZoneOffsetMinutes': row.writeZoneOffsetMinutes,
                    'writeZoneName': row.writeZoneName,
                    'updatedAtMillis':
                        row.updatedAtMillis ?? row.createdAtMillis,
                    'originalProvenance': row.experiencedDay == null
                        ? 'timing_unknown'
                        : row.originalProvenance ??
                              (row.updatedAtMillis == null ||
                                      row.updatedAtMillis == row.createdAtMillis
                                  ? row.provenance
                                  : 'timing_unknown'),
                    'updatedZoneOffsetMinutes':
                        row.updatedZoneOffsetMinutes ??
                        (row.updatedAtMillis == null ||
                                row.updatedAtMillis == row.createdAtMillis
                            ? row.writeZoneOffsetMinutes
                            : null),
                    'updatedZoneName':
                        row.updatedZoneName ??
                        (row.updatedAtMillis == null ||
                                row.updatedAtMillis == row.createdAtMillis
                            ? row.writeZoneName
                            : null),
                  },
                ),
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
            LocalBackupCollection(
              name: _comfortKitOverrides,
              schemaVersion: 1,
              records: comfortKitOverrides.map(
                (row) => _record(row.sourceId, row.updatedAtMillis, {
                  'action': row.action,
                  'sourceVersion': row.sourceVersion,
                  'updatedAtMillis': row.updatedAtMillis,
                }),
              ),
            ),
            LocalBackupCollection(
              name: _comfortReminderPreferences,
              schemaVersion: 1,
              records: comfortReminderPreferences.map(
                (row) => _record(row.id, row.updatedAtMillis, {
                  'enabled': row.enabled,
                  'leadDays': row.leadDays,
                  'hour': row.hour,
                  'minute': row.minute,
                  'updatedAtMillis': row.updatedAtMillis,
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

const _hubImpact = 'record_hub_impact';
const _hubBleeding = 'record_hub_bleeding';
const _hubSleep = 'record_hub_sleep';
const _hubAppetite = 'record_hub_appetite';
const _hubActivity = 'record_hub_activity';
const _hubEvent = 'record_hub_event';
const _hubTemperature = 'record_hub_temperature';
const _hubPins = 'record_hub_pins';
const _savedProductEpisode = 'record_product_episodes';
const _savedProductVersion = 'record_product_versions';
const _savedProductUse = 'record_product_uses';
const _savedTriedAction = 'record_tried_actions';
const _savedTriedActionItem = 'record_tried_action_items';
const _savedActionCheckback = 'record_action_checkbacks';
const _savedProgramme = 'record_programmes';
const _savedProgrammeConfig = 'record_programme_configs';
const _savedProgrammePause = 'record_programme_pauses';
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
const _comfortKitOverrides = 'comfort_kit_overrides';
const _comfortReminderPreferences = 'comfort_reminder_preferences';
const _requiredCollections = {
  _periods,
  _careRecords,
  _careReflections,
  _healthRecords,
  _captureNotes,
};
const _supportedCollections = {
  _savedProductEpisode,
  _savedProductVersion,
  _savedProductUse,
  _savedTriedAction,
  _savedTriedActionItem,
  _savedActionCheckback,
  _savedProgramme,
  _savedProgrammeConfig,
  _savedProgrammePause,

  _hubPins,
  _hubImpact,
  _hubBleeding,
  _hubSleep,
  _hubAppetite,
  _hubActivity,
  _hubEvent,
  _hubTemperature,

  ..._requiredCollections,
  _periodFlows,
  _cycleReflections,
  _momentCheckIns,
  _preparationPlans,
  _preparationDismissals,
  _comfortKitOverrides,
  _comfortReminderPreferences,
};

void _validateHubBackup(
  LocalBackupRecord source,
  Map<String, Object?> decoded,
  int updatedAtMillis,
) {
  if (source.data.length != decoded.length ||
      !source.data.keys.every(decoded.containsKey) ||
      source.data['id'] != source.id) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  _matchesUpdatedAt(source, updatedAtMillis);
}

List<RecordHubPinRowsCompanion> _hubPinRecords(
  LocalBackupCollection? collection,
) {
  if (collection == null || collection.records.isEmpty) return const [];
  if (collection.records.length != 1 ||
      collection.records.single.id != 'symptom-pins') {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  final data = _data(collection.records.single, {'symptoms'});
  final values = data['symptoms'];
  if (values is! List || values.any((v) => v is! String)) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  final pins = SymptomPins(
    values.map((v) => SymptomType.values.byName(v as String)),
  );
  return [
    for (var i = 0; i < pins.symptoms.length; i++)
      RecordHubPinRowsCompanion.insert(
        symptom: pins.symptoms[i].name,
        position: i,
      ),
  ];
}

RecordHubImpactRowsCompanion _hubImpactRecord(LocalBackupRecord record) {
  final row = RecordHubImpactRow.fromJson(record.data);
  _validateHubBackup(record, row.toJson(), row.updatedAtMillis);
  decodeRecordHubImpact(row);
  return row.toCompanion(false);
}

RecordHubBleedingRowsCompanion _hubBleedingRecord(LocalBackupRecord record) {
  final row = RecordHubBleedingRow.fromJson(record.data);
  _validateHubBackup(record, row.toJson(), row.updatedAtMillis);
  decodeRecordHubBleeding(row);
  return row.toCompanion(false);
}

RecordHubSleepRowsCompanion _hubSleepRecord(LocalBackupRecord record) {
  final row = RecordHubSleepRow.fromJson(record.data);
  _validateHubBackup(record, row.toJson(), row.updatedAtMillis);
  decodeRecordHubSleep(row);
  return row.toCompanion(false);
}

RecordHubAppetiteRowsCompanion _hubAppetiteRecord(LocalBackupRecord record) {
  final row = RecordHubAppetiteRow.fromJson(record.data);
  _validateHubBackup(record, row.toJson(), row.updatedAtMillis);
  decodeRecordHubAppetite(row);
  return row.toCompanion(false);
}

RecordHubActivityRowsCompanion _hubActivityRecord(LocalBackupRecord record) {
  final row = RecordHubActivityRow.fromJson(record.data);
  _validateHubBackup(record, row.toJson(), row.updatedAtMillis);
  decodeRecordHubActivity(row);
  return row.toCompanion(false);
}

RecordHubEventRowsCompanion _hubEventRecord(LocalBackupRecord record) {
  final row = RecordHubEventRow.fromJson(record.data);
  _validateHubBackup(record, row.toJson(), row.updatedAtMillis);
  decodeRecordHubEvent(row);
  return row.toCompanion(false);
}

RecordHubTemperatureRowsCompanion _hubTemperatureRecord(
  LocalBackupRecord record,
) {
  final row = RecordHubTemperatureRow.fromJson(record.data);
  _validateHubBackup(record, row.toJson(), row.updatedAtMillis);
  decodeRecordHubTemperature(row);
  return row.toCompanion(false);
}

void _validateExtendedFields(
  LocalBackupRecord record,
  Map<String, Object?> normalized, {
  String? compositeId,
}) {
  if (record.data.length != normalized.length ||
      !record.data.keys.every(normalized.containsKey) ||
      (compositeId ?? normalized['id']) != record.id) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  final updated = normalized['updatedAtMillis'];
  if (updated is int) _matchesUpdatedAt(record, updated);
}

RecordProductEpisodeRowsCompanion _savedProductEpisodeRecord(
  LocalBackupRecord record,
) {
  final row = RecordProductEpisodeRow.fromJson(record.data);
  _validateExtendedFields(record, row.toJson());
  return row.toCompanion(false);
}

RecordProductVersionRowsCompanion _savedProductVersionRecord(
  LocalBackupRecord record,
) {
  final row = RecordProductVersionRow.fromJson(record.data);
  _validateExtendedFields(record, row.toJson());
  return row.toCompanion(false);
}

RecordProductUseRowsCompanion _savedProductUseRecord(LocalBackupRecord record) {
  final row = RecordProductUseRow.fromJson(record.data);
  _validateExtendedFields(record, row.toJson());
  return row.toCompanion(false);
}

RecordTriedActionRowsCompanion _savedTriedActionRecord(
  LocalBackupRecord record,
) {
  final row = RecordTriedActionRow.fromJson(record.data);
  _validateExtendedFields(record, row.toJson());
  return row.toCompanion(false);
}

RecordTriedActionItemRowsCompanion _savedTriedActionItemRecord(
  LocalBackupRecord record,
) {
  final row = RecordTriedActionItemRow.fromJson(record.data);
  _validateExtendedFields(
    record,
    row.toJson(),
    compositeId: '${row.actionId}:${row.position}',
  );
  return row.toCompanion(false);
}

RecordActionCheckbackRowsCompanion _savedActionCheckbackRecord(
  LocalBackupRecord record,
) {
  final row = RecordActionCheckbackRow.fromJson(record.data);
  _validateExtendedFields(record, row.toJson());
  return row.toCompanion(false);
}

RecordProgrammeRowsCompanion _savedProgrammeRecord(LocalBackupRecord record) {
  final row = RecordProgrammeRow.fromJson(record.data);
  _validateExtendedFields(record, row.toJson());
  return row.toCompanion(false);
}

RecordProgrammeConfigRowsCompanion _savedProgrammeConfigRecord(
  LocalBackupRecord record,
) {
  final row = RecordProgrammeConfigRow.fromJson(record.data);
  _validateExtendedFields(record, row.toJson());
  return row.toCompanion(false);
}

RecordProgrammePauseRowsCompanion _savedProgrammePauseRecord(
  LocalBackupRecord record,
) {
  final row = RecordProgrammePauseRow.fromJson(record.data);
  _validateExtendedFields(record, row.toJson());
  return row.toCompanion(false);
}

void _validateExtendedSources(Map<String, LocalBackupCollection> collections) {
  List<LocalBackupRecord> records(String name) =>
      collections[name]?.records ?? const [];
  final episodes = [
    for (final r in records(_savedProductEpisode))
      RecordProductEpisodeRow.fromJson(r.data),
  ];
  final versions = [
    for (final r in records(_savedProductVersion))
      RecordProductVersionRow.fromJson(r.data),
  ];
  final uses = [
    for (final r in records(_savedProductUse))
      RecordProductUseRow.fromJson(r.data),
  ];
  final actions = [
    for (final r in records(_savedTriedAction))
      RecordTriedActionRow.fromJson(r.data),
  ];
  final items = [
    for (final r in records(_savedTriedActionItem))
      RecordTriedActionItemRow.fromJson(r.data),
  ];
  final checkbacks = [
    for (final r in records(_savedActionCheckback))
      RecordActionCheckbackRow.fromJson(r.data),
  ];
  final programmes = [
    for (final r in records(_savedProgramme))
      RecordProgrammeRow.fromJson(r.data),
  ];
  final configs = [
    for (final r in records(_savedProgrammeConfig))
      RecordProgrammeConfigRow.fromJson(r.data),
  ];
  final pauses = [
    for (final r in records(_savedProgrammePause))
      RecordProgrammePauseRow.fromJson(r.data),
  ];
  bool episodeExists(String id) => episodes.any((e) => e.id == id);
  bool actionExists(String id) => actions.any((a) => a.id == id);
  bool programmeExists(String id) => programmes.any((p) => p.id == id);
  if (versions.any((v) => !episodeExists(v.episodeId)) ||
      uses.any(
        (u) =>
            !episodeExists(u.episodeId) ||
            !versions.any(
              (v) => v.id == u.versionId && v.episodeId == u.episodeId,
            ),
      ) ||
      items.any((i) => !actionExists(i.actionId)) ||
      checkbacks.any((c) => !actionExists(c.actionId)) ||
      configs.any((c) => !programmeExists(c.programmeId)) ||
      pauses.any((p) => !programmeExists(p.programmeId))) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  for (final episode in episodes) {
    decodeProductEpisode(
      episode,
      versions.where((v) => v.episodeId == episode.id).toList(),
    );
  }
  for (final use in uses) {
    decodeProductUse(use);
  }
  for (final action in actions) {
    decodeTriedAction(
      action,
      items.where((i) => i.actionId == action.id).toList(),
    );
  }
  for (final checkback in checkbacks) {
    decodeActionCheckback(checkback);
  }
  for (final programme in programmes) {
    decodeRecordProgramme(
      programme,
      configs.where((c) => c.programmeId == programme.id).toList(),
      pauses.where((p) => p.programmeId == programme.id).toList(),
    );
  }
}

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
    required this.savedProductEpisode,
    required this.savedProductVersion,
    required this.savedProductUse,
    required this.savedTriedAction,
    required this.savedTriedActionItem,
    required this.savedActionCheckback,
    required this.savedProgramme,
    required this.savedProgrammeConfig,
    required this.savedProgrammePause,

    required this.hubPins,
    required this.hubImpact,
    required this.hubBleeding,
    required this.hubSleep,
    required this.hubAppetite,
    required this.hubActivity,
    required this.hubEvent,
    required this.hubTemperature,

    required this.periodFlows,
    required this.careRecords,
    required this.careReflections,
    required this.cycleReflections,
    required this.healthRecords,
    required this.captureNotes,
    required this.momentCheckIns,
    required this.preparationPlans,
    required this.preparationDismissals,
    required this.comfortKitOverrides,
    required this.comfortReminderPreferences,
  });

  final List<PeriodRowsCompanion> periods;
  final List<RecordProductEpisodeRowsCompanion> savedProductEpisode;
  final List<RecordProductVersionRowsCompanion> savedProductVersion;
  final List<RecordProductUseRowsCompanion> savedProductUse;
  final List<RecordTriedActionRowsCompanion> savedTriedAction;
  final List<RecordTriedActionItemRowsCompanion> savedTriedActionItem;
  final List<RecordActionCheckbackRowsCompanion> savedActionCheckback;
  final List<RecordProgrammeRowsCompanion> savedProgramme;
  final List<RecordProgrammeConfigRowsCompanion> savedProgrammeConfig;
  final List<RecordProgrammePauseRowsCompanion> savedProgrammePause;

  final List<RecordHubPinRowsCompanion> hubPins;
  final List<RecordHubImpactRowsCompanion> hubImpact;
  final List<RecordHubBleedingRowsCompanion> hubBleeding;
  final List<RecordHubSleepRowsCompanion> hubSleep;
  final List<RecordHubAppetiteRowsCompanion> hubAppetite;
  final List<RecordHubActivityRowsCompanion> hubActivity;
  final List<RecordHubEventRowsCompanion> hubEvent;
  final List<RecordHubTemperatureRowsCompanion> hubTemperature;

  final List<PeriodFlowRowsCompanion> periodFlows;
  final List<CareRecordRowsCompanion> careRecords;
  final List<CareReflectionRowsCompanion> careReflections;
  final List<CycleReflectionRowsCompanion> cycleReflections;
  final List<HealthRecordRowsCompanion> healthRecords;
  final List<CaptureNoteRowsCompanion> captureNotes;
  final List<MomentCheckInRowsCompanion> momentCheckIns;
  final List<PreparationPlanRowsCompanion> preparationPlans;
  final List<PreparationDismissalRowsCompanion> preparationDismissals;
  final List<ComfortKitOverrideRowsCompanion> comfortKitOverrides;
  final List<ComfortReminderPreferenceRowsCompanion> comfortReminderPreferences;

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
    _validatePeriodRanges(byName);
    _validatePeriodFlowContainment(byName);
    _validateExtendedSources(byName);
    return _ParsedSnapshot(
      savedProductEpisode:
          byName[_savedProductEpisode]?.records
              .map(_savedProductEpisodeRecord)
              .toList(growable: false) ??
          const [],
      savedProductVersion:
          byName[_savedProductVersion]?.records
              .map(_savedProductVersionRecord)
              .toList(growable: false) ??
          const [],
      savedProductUse:
          byName[_savedProductUse]?.records
              .map(_savedProductUseRecord)
              .toList(growable: false) ??
          const [],
      savedTriedAction:
          byName[_savedTriedAction]?.records
              .map(_savedTriedActionRecord)
              .toList(growable: false) ??
          const [],
      savedTriedActionItem:
          byName[_savedTriedActionItem]?.records
              .map(_savedTriedActionItemRecord)
              .toList(growable: false) ??
          const [],
      savedActionCheckback:
          byName[_savedActionCheckback]?.records
              .map(_savedActionCheckbackRecord)
              .toList(growable: false) ??
          const [],
      savedProgramme:
          byName[_savedProgramme]?.records
              .map(_savedProgrammeRecord)
              .toList(growable: false) ??
          const [],
      savedProgrammeConfig:
          byName[_savedProgrammeConfig]?.records
              .map(_savedProgrammeConfigRecord)
              .toList(growable: false) ??
          const [],
      savedProgrammePause:
          byName[_savedProgrammePause]?.records
              .map(_savedProgrammePauseRecord)
              .toList(growable: false) ??
          const [],

      hubPins: _hubPinRecords(byName[_hubPins]),
      hubImpact:
          byName[_hubImpact]?.records
              .map(_hubImpactRecord)
              .toList(growable: false) ??
          const [],
      hubBleeding:
          byName[_hubBleeding]?.records
              .map(_hubBleedingRecord)
              .toList(growable: false) ??
          const [],
      hubSleep:
          byName[_hubSleep]?.records
              .map(_hubSleepRecord)
              .toList(growable: false) ??
          const [],
      hubAppetite:
          byName[_hubAppetite]?.records
              .map(_hubAppetiteRecord)
              .toList(growable: false) ??
          const [],
      hubActivity:
          byName[_hubActivity]?.records
              .map(_hubActivityRecord)
              .toList(growable: false) ??
          const [],
      hubEvent:
          byName[_hubEvent]?.records
              .map(_hubEventRecord)
              .toList(growable: false) ??
          const [],
      hubTemperature:
          byName[_hubTemperature]?.records
              .map(_hubTemperatureRecord)
              .toList(growable: false) ??
          const [],

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
          .map(
            (record) =>
                _healthRecord(record, byName[_healthRecords]!.schemaVersion),
          )
          .toList(growable: false),
      captureNotes: byName[_captureNotes]!.records
          .map(
            (record) =>
                _captureNote(record, byName[_captureNotes]!.schemaVersion),
          )
          .toList(growable: false),
      momentCheckIns:
          byName[_momentCheckIns]?.records
              .map(
                (record) => _momentCheckIn(
                  record,
                  byName[_momentCheckIns]!.schemaVersion,
                ),
              )
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
      comfortKitOverrides:
          byName[_comfortKitOverrides]?.records
              .map(_comfortKitOverride)
              .toList(growable: false) ??
          const [],
      comfortReminderPreferences:
          byName[_comfortReminderPreferences]?.records
              .map(_comfortReminderPreference)
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
        await database.delete(database.recordTriedActionItemRows).go();
        await database.delete(database.recordActionCheckbackRows).go();
        await database.delete(database.recordProductUseRows).go();
        await database.delete(database.recordProductVersionRows).go();
        await database.delete(database.recordProductEpisodeRows).go();
        await database.delete(database.recordTriedActionRows).go();
        await database.delete(database.recordProgrammePauseRows).go();
        await database.delete(database.recordProgrammeConfigRows).go();
        await database.delete(database.recordProgrammeRows).go();
        await database.delete(database.healthRecordRows).go();
        await database.delete(database.recordHubPinRows).go();
        await database.delete(database.recordHubImpactRows).go();
        await database.delete(database.recordHubBleedingRows).go();
        await database.delete(database.recordHubSleepRows).go();
        await database.delete(database.recordHubAppetiteRows).go();
        await database.delete(database.recordHubActivityRows).go();
        await database.delete(database.recordHubEventRows).go();
        await database.delete(database.recordHubTemperatureRows).go();

        await database.delete(database.captureNoteRows).go();
        await database.delete(database.momentCheckInRows).go();
        await database.delete(database.periodFlowRows).go();
        await database.delete(database.preparationDismissalRows).go();
        await database.delete(database.preparationPlanRows).go();
        await database.delete(database.comfortKitOverrideRows).go();
        await database.delete(database.comfortReminderPreferenceRows).go();
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
          batch.insertAll(
            database.recordProductEpisodeRows,
            parsed.savedProductEpisode,
          );
          batch.insertAll(
            database.recordProductVersionRows,
            parsed.savedProductVersion,
          );
          batch.insertAll(
            database.recordProductUseRows,
            parsed.savedProductUse,
          );
          batch.insertAll(
            database.recordTriedActionRows,
            parsed.savedTriedAction,
          );
          batch.insertAll(
            database.recordTriedActionItemRows,
            parsed.savedTriedActionItem,
          );
          batch.insertAll(
            database.recordActionCheckbackRows,
            parsed.savedActionCheckback,
          );
          batch.insertAll(database.recordProgrammeRows, parsed.savedProgramme);
          batch.insertAll(
            database.recordProgrammeConfigRows,
            parsed.savedProgrammeConfig,
          );
          batch.insertAll(
            database.recordProgrammePauseRows,
            parsed.savedProgrammePause,
          );

          batch.insertAll(database.recordHubPinRows, parsed.hubPins);
          batch.insertAll(database.recordHubImpactRows, parsed.hubImpact);
          batch.insertAll(database.recordHubBleedingRows, parsed.hubBleeding);
          batch.insertAll(database.recordHubSleepRows, parsed.hubSleep);
          batch.insertAll(database.recordHubAppetiteRows, parsed.hubAppetite);
          batch.insertAll(database.recordHubActivityRows, parsed.hubActivity);
          batch.insertAll(database.recordHubEventRows, parsed.hubEvent);
          batch.insertAll(
            database.recordHubTemperatureRows,
            parsed.hubTemperature,
          );

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
          batch.insertAll(
            database.comfortKitOverrideRows,
            parsed.comfortKitOverrides,
          );
          batch.insertAll(
            database.comfortReminderPreferenceRows,
            parsed.comfortReminderPreferences,
          );
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

void _validatePeriodRanges(Map<String, LocalBackupCollection> collections) {
  final ranges = <({String id, int start, int? end})>[];
  for (final record in collections[_periods]!.records) {
    final data = _data(record, {
      'startDay',
      'endDay',
      'createdAtMillis',
      'updatedAtMillis',
    });
    ranges.add((
      id: record.id,
      start: _int(data, 'startDay'),
      end: _nullableInt(data, 'endDay'),
    ));
  }
  ranges.sort((left, right) {
    final byStart = left.start.compareTo(right.start);
    return byStart != 0 ? byStart : left.id.compareTo(right.id);
  });
  for (var index = 1; index < ranges.length; index++) {
    final previous = ranges[index - 1];
    final current = ranges[index];
    if (previous.end == null || current.start <= previous.end!) {
      throw const LocalBackupException(LocalBackupFailure.malformedPayload);
    }
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

HealthRecordRowsCompanion _healthRecord(
  LocalBackupRecord record,
  int schemaVersion,
) {
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
    if (schemaVersion >= 3) ...{
      'originalProvenance',
      'writeZoneOffsetMinutes',
      'writeZoneName',
      'updatedZoneOffsetMinutes',
      'updatedZoneName',
    },
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
        severity < (schemaVersion >= 3 ? 0 : 1) ||
        severity > 5 ||
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
    originalProvenance: Value(
      schemaVersion >= 3
          ? _nullableString(data, 'originalProvenance')
          : provenance,
    ),
    writeZoneOffsetMinutes: Value(
      schemaVersion >= 3 ? _nullableInt(data, 'writeZoneOffsetMinutes') : null,
    ),
    writeZoneName: Value(
      schemaVersion >= 3 ? _nullableString(data, 'writeZoneName') : null,
    ),
    updatedZoneOffsetMinutes: Value(
      schemaVersion >= 3
          ? _nullableInt(data, 'updatedZoneOffsetMinutes')
          : null,
    ),
    updatedZoneName: Value(
      schemaVersion >= 3 ? _nullableString(data, 'updatedZoneName') : null,
    ),
    userConfirmed: _bool(data, 'userConfirmed'),
    vocabularyVersion: vocabularyVersion,
  );
}

CaptureNoteRowsCompanion _captureNote(
  LocalBackupRecord record,
  int schemaVersion,
) {
  // Build17 v2 contained the explicit Kit choice; Record Hub v2 contained
  // experienced-date metadata. Both prior schemas retain their exact shape.
  final hasKit =
      schemaVersion >= 3 ||
      (schemaVersion == 2 && record.data.containsKey('keepInComfortKit'));
  final hasTiming =
      schemaVersion >= 3 ||
      (schemaVersion == 2 && record.data.containsKey('experiencedDay'));
  if (schemaVersion == 2 && hasKit == hasTiming) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  final data = _data(record, {
    'content',
    'source',
    'createdAtMillis',
    if (schemaVersion >= 2) 'updatedAtMillis',
    if (hasKit) 'keepInComfortKit',
    if (hasTiming) ...{
      'experiencedDay',
      'provenance',
      'originalProvenance',
      'writeZoneOffsetMinutes',
      'writeZoneName',
    },
  });
  final created = _int(data, 'createdAtMillis');
  final updated = hasKit
      ? _int(data, 'updatedAtMillis')
      : schemaVersion >= 2
      ? _nullableInt(data, 'updatedAtMillis') ?? created
      : created;
  final content = _string(data, 'content');
  final source = _string(data, 'source');
  _matchesUpdatedAt(record, updated);
  if (content.length > captureTextLimit ||
      !CaptureSource.values.map((value) => value.name).contains(source) ||
      created > updated) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  final day = hasTiming ? _nullableInt(data, 'experiencedDay') : null;
  final provenance = hasTiming ? _nullableString(data, 'provenance') : null;
  final original = hasTiming
      ? _nullableString(data, 'originalProvenance')
      : null;
  final offset = hasTiming
      ? _nullableInt(data, 'writeZoneOffsetMinutes')
      : null;
  final zone = hasTiming ? _nullableString(data, 'writeZoneName') : null;
  if ((provenance != null &&
          !HealthRecordProvenance.values.any(
            (p) => p.storageKey == provenance,
          )) ||
      (original != null &&
          !HealthRecordProvenance.values.any(
            (p) => p.storageKey == original,
          )) ||
      (offset != null && (offset < -840 || offset > 840)) ||
      (zone != null && zone.length > 100)) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return CaptureNoteRowsCompanion.insert(
    id: record.id,
    content: content,
    source: source,
    createdAtMillis: created,
    updatedAtMillis: Value(updated),
    keepInComfortKit: Value(hasKit ? _bool(data, 'keepInComfortKit') : false),
    experiencedDay: Value(day),
    provenance: Value(provenance),
    originalProvenance: Value(original),
    writeZoneOffsetMinutes: Value(offset),
    writeZoneName: Value(zone),
  );
}

ComfortKitOverrideRowsCompanion _comfortKitOverride(LocalBackupRecord record) {
  final data = _data(record, {'action', 'sourceVersion', 'updatedAtMillis'});
  final action = _string(data, 'action');
  final updated = _int(data, 'updatedAtMillis');
  _matchesUpdatedAt(record, updated);
  if (!ComfortKitOverrideAction.values
      .map((value) => value.name)
      .contains(action)) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return ComfortKitOverrideRowsCompanion.insert(
    sourceId: record.id,
    action: action,
    sourceVersion: Value(_nullableString(data, 'sourceVersion')),
    updatedAtMillis: updated,
  );
}

ComfortReminderPreferenceRowsCompanion _comfortReminderPreference(
  LocalBackupRecord record,
) {
  final data = _data(record, {
    'enabled',
    'leadDays',
    'hour',
    'minute',
    'updatedAtMillis',
  });
  final leadDays = _int(data, 'leadDays');
  final hour = _int(data, 'hour');
  final minute = _int(data, 'minute');
  final updated = _int(data, 'updatedAtMillis');
  _matchesUpdatedAt(record, updated);
  if (record.id != 'active' ||
      leadDays < 0 ||
      leadDays > 2 ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return ComfortReminderPreferenceRowsCompanion.insert(
    id: record.id,
    enabled: Value(_bool(data, 'enabled')),
    leadDays: Value(leadDays),
    hour: Value(hour),
    minute: Value(minute),
    updatedAtMillis: updated,
  );
}

MomentCheckInRowsCompanion _momentCheckIn(
  LocalBackupRecord record,
  int schemaVersion,
) {
  final data = _data(record, {
    'state',
    'occurredAtMillis',
    'createdAtMillis',
    if (schemaVersion >= 2) ...{
      'experiencedDay',
      'provenance',
      'writeZoneOffsetMinutes',
      'writeZoneName',
    },
    if (schemaVersion >= 3) ...{
      'updatedAtMillis',
      'originalProvenance',
      'updatedZoneOffsetMinutes',
      'updatedZoneName',
    },
  });
  final created = _int(data, 'createdAtMillis');
  final updated = schemaVersion >= 3 ? _int(data, 'updatedAtMillis') : created;
  final state = _string(data, 'state');
  final occurred = _int(data, 'occurredAtMillis');
  final day = schemaVersion >= 2 ? _nullableInt(data, 'experiencedDay') : null;
  final provenance = schemaVersion >= 2
      ? _nullableString(data, 'provenance')
      : null;
  final original = schemaVersion >= 3
      ? _nullableString(data, 'originalProvenance')
      : provenance;
  final offset = schemaVersion >= 2
      ? _nullableInt(data, 'writeZoneOffsetMinutes')
      : null;
  final zone = schemaVersion >= 2
      ? _nullableString(data, 'writeZoneName')
      : null;
  final updatedOffset = schemaVersion >= 3
      ? _nullableInt(data, 'updatedZoneOffsetMinutes')
      : offset;
  final updatedZone = schemaVersion >= 3
      ? _nullableString(data, 'updatedZoneName')
      : zone;
  _matchesUpdatedAt(record, updated);
  bool invalidProvenance(String? value) =>
      value != null &&
      !HealthRecordProvenance.values
          .map((value) => value.storageKey)
          .contains(value);
  bool invalidOffset(int? value) =>
      value != null && (value < -840 || value > 840);
  bool invalidZone(String? value) => value != null && value.trim().isEmpty;
  if (!MomentCheckInState.values.map((value) => value.name).contains(state) ||
      occurred > created ||
      updated < created ||
      invalidProvenance(provenance) ||
      invalidProvenance(original) ||
      invalidOffset(offset) ||
      invalidOffset(updatedOffset) ||
      invalidZone(zone) ||
      invalidZone(updatedZone)) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  if (day != null) LocalDate.fromEpochDay(day);
  void validateTiming(String? timing, int timestamp, int? zoneOffset) {
    if (timing != HealthRecordProvenance.sameDay.storageKey &&
        timing != HealthRecordProvenance.laterRecall.storageKey) {
      return;
    }
    if (day == null || zoneOffset == null) {
      throw const LocalBackupException(LocalBackupFailure.malformedPayload);
    }
    final writeDay = LocalDate.fromDateTime(
      DateTime.fromMillisecondsSinceEpoch(
        timestamp,
        isUtc: true,
      ).add(Duration(minutes: zoneOffset)),
    );
    final experienced = LocalDate.fromEpochDay(day);
    if (timing == HealthRecordProvenance.sameDay.storageKey
        ? experienced != writeDay
        : !experienced.isBefore(writeDay)) {
      throw const LocalBackupException(LocalBackupFailure.malformedPayload);
    }
  }

  validateTiming(original, created, offset);
  validateTiming(provenance, updated, updatedOffset);
  return MomentCheckInRowsCompanion.insert(
    id: record.id,
    state: state,
    occurredAtMillis: occurred,
    createdAtMillis: created,
    updatedAtMillis: Value(updated),
    experiencedDay: Value(day),
    provenance: Value(
      day == null
          ? HealthRecordProvenance.timingUnknown.storageKey
          : provenance,
    ),
    originalProvenance: Value(
      day == null
          ? HealthRecordProvenance.timingUnknown.storageKey
          : original ?? HealthRecordProvenance.timingUnknown.storageKey,
    ),
    writeZoneOffsetMinutes: Value(offset),
    writeZoneName: Value(zone),
    updatedZoneOffsetMinutes: Value(updatedOffset),
    updatedZoneName: Value(updatedZone),
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
  if (collection.name == _captureNotes) {
    return collection.schemaVersion >= 1 && collection.schemaVersion <= 3;
  }
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
    return collection.schemaVersion == 2 || collection.schemaVersion == 3;
  }
  if (collection.name == _momentCheckIns) {
    return collection.schemaVersion >= 1 && collection.schemaVersion <= 3;
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
