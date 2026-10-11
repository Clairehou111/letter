import 'dart:math';

import 'package:drift/drift.dart';

import '../../cycle/data/letter_health_database.dart';
import '../../cycle/domain/bleeding_flow.dart';
import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';
import '../domain/record_hub_facts.dart';
import '../domain/record_hub_repository.dart';

final class DriftRecordHubRepository implements RecordHubRepository {
  DriftRecordHubRepository(
    this._database, {
    DateTime Function()? clock,
    this.zoneProvider,
    String Function()? idGenerator,
  }) : _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _randomId;

  final LetterHealthDatabase _database;
  final DateTime Function() _clock;
  final String Function()? zoneProvider;
  final String Function() _idGenerator;

  @override
  Future<RecordHubDateFacts> getDateFacts(LocalDate date) =>
      _guard(() => _database.transaction(() => _readDate(date)));

  Future<RecordHubDateFacts> _readDate(LocalDate date) async {
    final impact = await _find(
      _database.recordHubImpactRows,
      _database.recordHubImpactRows.experiencedDay.equals(date.epochDay),
    );
    final bleeding = await _find(
      _database.recordHubBleedingRows,
      _database.recordHubBleedingRows.experiencedDay.equals(date.epochDay),
    );
    final sleep = await _find(
      _database.recordHubSleepRows,
      _database.recordHubSleepRows.experiencedDay.equals(date.epochDay),
    );
    final appetite = await _find(
      _database.recordHubAppetiteRows,
      _database.recordHubAppetiteRows.experiencedDay.equals(date.epochDay),
    );
    final activities =
        await (_database.select(_database.recordHubActivityRows)
              ..where((row) => row.experiencedDay.equals(date.epochDay))
              ..orderBy([(row) => OrderingTerm.asc(row.id)]))
            .get();
    final events =
        await (_database.select(_database.recordHubEventRows)
              ..where((row) => row.experiencedDay.equals(date.epochDay))
              ..orderBy([(row) => OrderingTerm.asc(row.id)]))
            .get();
    final temperatures =
        await (_database.select(_database.recordHubTemperatureRows)
              ..where((row) => row.experiencedDay.equals(date.epochDay))
              ..orderBy([(row) => OrderingTerm.asc(row.id)]))
            .get();
    return RecordHubDateFacts(
      date: date,
      impact: impact == null ? null : decodeRecordHubImpact(impact),
      bleeding: bleeding == null ? await _legacyBleeding(date) : decodeRecordHubBleeding(bleeding),
      sleep: sleep == null ? null : decodeRecordHubSleep(sleep),
      appetite: appetite == null ? null : decodeRecordHubAppetite(appetite),
      activities: activities.map(decodeRecordHubActivity),
      events: events.map(decodeRecordHubEvent),
      temperatures: temperatures.map(decodeRecordHubTemperature),
    );
  }

  Future<BleedingFactRecord?> _legacyBleeding(LocalDate date) async {
    final query = _database.select(_database.periodFlowRows)..where((row) => row.day.equals(date.epochDay))
      ..orderBy([(row) => OrderingTerm.desc(row.updatedAtMillis), (row) => OrderingTerm.asc(row.periodId)])..limit(1);
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return BleedingFactRecord(metadata: RecordFactMetadata(id: '${row.periodId}:${row.day}',
      experiencedDate: date, recordedAt: DateTime.fromMillisecondsSinceEpoch(row.createdAtMillis, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAtMillis, isUtc: true),
      originalProvenance: HealthRecordProvenance.timingUnknown, provenance: HealthRecordProvenance.timingUnknown),
      value: BleedingFactDraft(experiencedDate: date, periodId: row.periodId,
        flow: BleedingFlow.values.byName(row.flow), color: row.color == null ? null : BleedingColor.values.byName(row.color!)));
  }

  @override
  Future<List<RecordHubDateFacts>> getAllFacts() => _guard(
    () => _database.transaction(() async {
      final days = <int>{};
      days.addAll((await _database.select(_database.periodFlowRows).get()).map((row) => row.day));
      days.addAll(
        (await _database.select(_database.recordHubImpactRows).get()).map(
          (row) => row.experiencedDay,
        ),
      );
      days.addAll(
        (await _database.select(_database.recordHubBleedingRows).get()).map(
          (row) => row.experiencedDay,
        ),
      );
      days.addAll(
        (await _database.select(_database.recordHubSleepRows).get()).map(
          (row) => row.experiencedDay,
        ),
      );
      days.addAll(
        (await _database.select(_database.recordHubAppetiteRows).get()).map(
          (row) => row.experiencedDay,
        ),
      );
      days.addAll(
        (await _database.select(_database.recordHubActivityRows).get()).map(
          (row) => row.experiencedDay,
        ),
      );
      days.addAll(
        (await _database.select(_database.recordHubEventRows).get()).map(
          (row) => row.experiencedDay,
        ),
      );
      days.addAll(
        (await _database.select(_database.recordHubTemperatureRows).get()).map(
          (row) => row.experiencedDay,
        ),
      );
      final ordered = days.toList()..sort((a, b) => b.compareTo(a));
      return [
        for (final day in ordered) await _readDate(LocalDate.fromEpochDay(day)),
      ];
    }),
  );

  @override
  Future<SymptomPins?> getPins() => _guard(() async {
    final rows = await (_database.select(
      _database.recordHubPinRows,
    )..orderBy([(row) => OrderingTerm.asc(row.position)])).get();
    if (rows.isEmpty) return null;
    for (var position = 0; position < rows.length; position++) {
      if (rows[position].position != position) _invalid();
    }
    return SymptomPins(
      rows.map((row) => _enum(SymptomType.values, row.symptom)),
    );
  });

  @override
  Future<void> setPins(SymptomPins pins) => _guard(
    () => _database.transaction(() async {
      await _database.delete(_database.recordHubPinRows).go();
      for (var position = 0; position < pins.symptoms.length; position++) {
        await _database
            .into(_database.recordHubPinRows)
            .insert(
              RecordHubPinRowsCompanion.insert(
                symptom: pins.symptoms[position].name,
                position: position,
              ),
            );
      }
    }),
  );

  @override
  Future<DailyImpactRecord> upsertImpact(DailyImpactDraft draft) => _save(
    draft,
    load: () async {
      final row = await _find(
        _database.recordHubImpactRows,
        _database.recordHubImpactRows.experiencedDay.equals(
          draft.experiencedDate.epochDay,
        ),
      );
      return row == null ? null : decodeRecordHubImpact(row);
    },
    values: (value) => RecordHubImpactRowsCompanion(
      overall: Value(value.overall),
      workOrSchool: Value(
        value.domains.contains(DailyImpactDomain.workOrSchool),
      ),
      homeResponsibilities: Value(
        value.domains.contains(DailyImpactDomain.homeResponsibilities),
      ),
      relationships: Value(
        value.domains.contains(DailyImpactDomain.relationships),
      ),
      socialActivity: Value(
        value.domains.contains(DailyImpactDomain.socialActivity),
      ),
      sleep: Value(value.domains.contains(DailyImpactDomain.sleep)),
      hobbiesOrInterests: Value(
        value.domains.contains(DailyImpactDomain.hobbiesOrInterests),
      ),
    ),
    table: _database.recordHubImpactRows,
  );

  @override
  Future<BleedingFactRecord> upsertBleeding(BleedingFactDraft draft) => _guard(() => _database.transaction(() async {
    final saved = await _upsertBleeding(draft);
    final promoted = await (_database.select(_database.recordHubBleedingRows)..where((row) => row.experiencedDay.equals(draft.experiencedDate.epochDay))).getSingleOrNull();
    if (promoted != null) await (_database.delete(_database.periodFlowRows)..where((row) => row.day.equals(draft.experiencedDate.epochDay))).go();
    return saved;
  }));

  Future<BleedingFactRecord> _upsertBleeding(BleedingFactDraft draft) => _save(
    draft,
    load: () async {
      if (draft.periodId != null) {
        final period = await _find(
          _database.periodRows,
          _database.periodRows.id.equals(draft.periodId!),
        );
        if (period == null ||
            draft.experiencedDate.epochDay < period.startDay ||
            (period.endDay != null &&
                draft.experiencedDate.epochDay > period.endDay!)) {
          _invalid();
        }
      }
      final row = await _find(
        _database.recordHubBleedingRows,
        _database.recordHubBleedingRows.experiencedDay.equals(
          draft.experiencedDate.epochDay,
        ),
      );
      return row == null ? await _legacyBleeding(draft.experiencedDate) : decodeRecordHubBleeding(row);
    },
    values: (value) => RecordHubBleedingRowsCompanion(
      flow: Value(value.flow?.name),
      periodId: Value(value.periodId),
      color: Value(value.color?.name),
      clots: Value(value.clots?.name),
    ),
    table: _database.recordHubBleedingRows,
  );

  @override
  Future<SleepRecord> upsertSleep(SleepDraft draft) => _save(
    draft,
    load: () async {
      final row = await _find(
        _database.recordHubSleepRows,
        _database.recordHubSleepRows.experiencedDay.equals(
          draft.experiencedDate.epochDay,
        ),
      );
      return row == null ? null : decodeRecordHubSleep(row);
    },
    values: (value) => RecordHubSleepRowsCompanion(
      durationBucket: Value(value.duration?.bucket?.name),
      durationLabel: Value(value.duration?.label),
      durationCatalogVersion: Value(value.duration?.catalogVersion),
      exactMinutes: Value(value.duration?.exactMinutes),
      quality: Value(value.quality?.score),
      troubleFallingAsleep: Value(
        value.signals.contains(SleepSignal.troubleFallingAsleep),
      ),
      wakingDuringNight: Value(
        value.signals.contains(SleepSignal.wakingDuringNight),
      ),
      muchMoreThanUsual: Value(
        value.signals.contains(SleepSignal.muchMoreThanUsual),
      ),
      muchLessThanUsual: Value(
        value.signals.contains(SleepSignal.muchLessThanUsual),
      ),
    ),
    table: _database.recordHubSleepRows,
  );

  @override
  Future<AppetiteRecord> upsertAppetite(AppetiteDraft draft) => _save(
    draft,
    load: () async {
      final row = await _find(
        _database.recordHubAppetiteRows,
        _database.recordHubAppetiteRows.experiencedDay.equals(
          draft.experiencedDate.epochDay,
        ),
      );
      return row == null ? null : decodeRecordHubAppetite(row);
    },
    values: (value) => RecordHubAppetiteRowsCompanion(
      appetite: Value(value.appetite?.name),
      cravingScore: Value(value.cravingScore),
      cravingType: Value(value.cravingType?.name),
      customCraving: Value(value.customCraving),
    ),
    table: _database.recordHubAppetiteRows,
  );

  @override
  Future<ActivityRecord> saveActivity(ActivityDraft draft, {String? id}) =>
      _save(
        draft,
        requireExisting: id != null,
        load: () async {
          if (id == null) return null;
          final row = await _find(
            _database.recordHubActivityRows,
            _database.recordHubActivityRows.id.equals(id),
          );
          return row == null ? null : decodeRecordHubActivity(row);
        },
        values: (value) => RecordHubActivityRowsCompanion(
          type: Value(value.type.name),
          durationBucket: Value(value.duration?.bucket?.name),
          durationLabel: Value(value.duration?.label),
          durationCatalogVersion: Value(value.duration?.catalogVersion),
          exactMinutes: Value(value.duration?.exactMinutes),
          intensity: Value(value.intensity?.name),
          customName: Value(value.customName),
        ),
        table: _database.recordHubActivityRows,
      );

  @override
  Future<ContextEventRecord> saveEvent(ContextEventDraft draft, {String? id}) =>
      _save(
        draft,
        requireExisting: id != null,
        load: () async {
          if (id == null) return null;
          final row = await _find(
            _database.recordHubEventRows,
            _database.recordHubEventRows.id.equals(id),
          );
          return row == null ? null : decodeRecordHubEvent(row);
        },
        values: (value) => RecordHubEventRowsCompanion(
          type: Value(value.type.name),
          intensity: Value(value.intensity?.name),
          customName: Value(value.customName),
          note: Value(value.note),
        ),
        table: _database.recordHubEventRows,
      );

  @override
  Future<TemperatureRecord> saveTemperature(
    TemperatureDraft draft, {
    String? id,
  }) => _save(
    draft,
    requireExisting: id != null,
    load: () async {
      if (id == null) return null;
      final row = await _find(
        _database.recordHubTemperatureRows,
        _database.recordHubTemperatureRows.id.equals(id),
      );
      return row == null ? null : decodeRecordHubTemperature(row);
    },
    values: (value) => RecordHubTemperatureRowsCompanion(
      enteredValue: Value(value.enteredValue),
      unit: Value(value.unit.name),
      method: Value(value.method.name),
      measuredHour: Value(value.measuredAt?.hour),
      measuredMinute: Value(value.measuredAt?.minute),
      feverOrIllness: Value(
        value.flags.contains(TemperatureQualityFlag.feverOrIllness),
      ),
      poorSleep: Value(value.flags.contains(TemperatureQualityFlag.poorSleep)),
      alcohol: Value(value.flags.contains(TemperatureQualityFlag.alcohol)),
      travelOrTimeZoneChange: Value(
        value.flags.contains(TemperatureQualityFlag.travelOrTimeZoneChange),
      ),
    ),
    table: _database.recordHubTemperatureRows,
  );

  Future<RecordHubFact<D>>
  _save<D extends DatedRecordDraft, R extends DataClass>(
    D draft, {
    required Future<RecordHubFact<D>?> Function() load,
    required Insertable<R> Function(D) values,
    required TableInfo<Table, R> table,
    bool requireExisting = false,
  }) => _guard(
    () => _database.transaction(() async {
      final localNow = _clock().toLocal();
      final today = LocalDate.fromDateTime(localNow);
      if (draft.experiencedDate.isAfter(today)) {
        throw const RecordHubException(RecordHubFailure.futureDate);
      }
      final previous = await load();
      if (requireExisting && previous == null) {
        throw const RecordHubException(RecordHubFailure.notFound);
      }
      final columns = values(draft).toColumns(false);
      if (previous != null &&
          previous.experiencedDate == draft.experiencedDate &&
          _sameColumns(columns, values(previous.value).toColumns(false))) {
        return previous;
      }
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        localNow.millisecondsSinceEpoch,
        isUtc: true,
      );
      final timing = draft.experiencedDate == today
          ? HealthRecordProvenance.sameDay
          : HealthRecordProvenance.laterRecall;
      final zone = zoneProvider?.call() ?? localNow.timeZoneName;
      final metadata = RecordFactMetadata(
        id: previous?.id ?? _idGenerator(),
        experiencedDate: draft.experiencedDate,
        recordedAt: previous?.metadata.recordedAt ?? timestamp,
        updatedAt: timestamp,
        originalProvenance: previous?.metadata.originalProvenance ?? timing,
        provenance:
            previous?.metadata.provenance ==
                    HealthRecordProvenance.laterRecall &&
                previous?.experiencedDate == draft.experiencedDate
            ? HealthRecordProvenance.laterRecall
            : timing,
        originalWriteZoneId: previous == null
            ? zone
            : previous.metadata.originalWriteZoneId,
        writeZoneId: zone,
        originalUtcOffsetMinutes: previous == null
            ? localNow.timeZoneOffset.inMinutes
            : previous.metadata.originalUtcOffsetMinutes,
        utcOffsetMinutes: localNow.timeZoneOffset.inMinutes,
        vocabularyVersion:
            previous?.metadata.vocabularyVersion ?? recordHubVocabularyVersion,
      );
      await _database
          .into(table)
          .insertOnConflictUpdate(
            RawValuesInsertable<R>({
              ...columns,
              ...recordFactMetadataColumns(metadata),
            }),
          );
      return RecordHubFact(metadata: metadata, value: draft);
    }),
  );

  @override
  Future<void> clearImpact(LocalDate date) => _remove(
    _database.recordHubImpactRows,
    _database.recordHubImpactRows.experiencedDay.equals(date.epochDay),
  );
  @override
  Future<void> clearBleeding(LocalDate date) => _guard(() => _database.transaction(() async {
    final removed = await (_database.delete(_database.recordHubBleedingRows)..where((row) => row.experiencedDay.equals(date.epochDay))).go();
    final old = await (_database.delete(_database.periodFlowRows)..where((row) => row.day.equals(date.epochDay))).go();
    if (removed + old == 0) throw const RecordHubException(RecordHubFailure.notFound);
  }));
  @override
  Future<void> clearSleep(LocalDate date) => _remove(
    _database.recordHubSleepRows,
    _database.recordHubSleepRows.experiencedDay.equals(date.epochDay),
  );
  @override
  Future<void> clearAppetite(LocalDate date) => _remove(
    _database.recordHubAppetiteRows,
    _database.recordHubAppetiteRows.experiencedDay.equals(date.epochDay),
  );
  @override
  Future<void> deleteActivity(String id) => _remove(
    _database.recordHubActivityRows,
    _database.recordHubActivityRows.id.equals(id),
  );
  @override
  Future<void> deleteEvent(String id) => _remove(
    _database.recordHubEventRows,
    _database.recordHubEventRows.id.equals(id),
  );
  @override
  Future<void> deleteTemperature(String id) => _remove(
    _database.recordHubTemperatureRows,
    _database.recordHubTemperatureRows.id.equals(id),
  );

  Future<void> _remove<R extends DataClass>(
    TableInfo<Table, R> table,
    Expression<bool> condition,
  ) => _guard(() async {
    final count = await (_database.delete(table)..where((_) => condition)).go();
    if (count == 0) throw const RecordHubException(RecordHubFailure.notFound);
  });

  Future<R?> _find<R extends DataClass>(
    TableInfo<Table, R> table,
    Expression<bool> condition,
  ) => (_database.select(table)..where((_) => condition)).getSingleOrNull();

  static Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on RecordHubException {
      rethrow;
    } catch (_) {
      throw const RecordHubException(RecordHubFailure.storageUnavailable);
    }
  }

  static String _randomId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

bool _sameColumns(
  Map<String, Expression<Object>> left,
  Map<String, Expression<Object>> right,
) =>
    left.length == right.length &&
    left.keys.every((key) => left[key] == right[key]);

Map<String, Expression<Object>> recordFactMetadataColumns(
  RecordFactMetadata metadata,
) => {
  'id': Variable(metadata.id),
  'experienced_day': Variable(metadata.experiencedDate.epochDay),
  'recorded_at_millis': Variable(metadata.recordedAt.millisecondsSinceEpoch),
  'updated_at_millis': Variable(metadata.updatedAt.millisecondsSinceEpoch),
  'original_provenance': Variable(metadata.originalProvenance.storageKey),
  'provenance': Variable(metadata.provenance.storageKey),
  'original_write_zone_id': Variable(metadata.originalWriteZoneId),
  'write_zone_id': Variable(metadata.writeZoneId),
  'original_utc_offset_minutes': Variable(metadata.originalUtcOffsetMinutes),
  'utc_offset_minutes': Variable(metadata.utcOffsetMinutes),
  'vocabulary_version': Variable(metadata.vocabularyVersion),
};

Never _invalid() =>
    throw const RecordHubException(RecordHubFailure.invalidValue);

T _enum<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return _invalid();
}

T? _optionalEnum<T extends Enum>(List<T> values, String? name) =>
    name == null ? null : _enum(values, name);

HealthRecordProvenance _provenance(String key) {
  for (final value in HealthRecordProvenance.values) {
    if (value.storageKey == key) return value;
  }
  return _invalid();
}

RecordFactMetadata decodeRecordFactMetadata(Map<String, Object?> row) {
  if (row['vocabularyVersion'] != recordHubVocabularyVersion) _invalid();
  return RecordFactMetadata(
    id: row['id']! as String,
    experiencedDate: LocalDate.fromEpochDay(row['experiencedDay']! as int),
    recordedAt: DateTime.fromMillisecondsSinceEpoch(
      row['recordedAtMillis']! as int,
      isUtc: true,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row['updatedAtMillis']! as int,
      isUtc: true,
    ),
    originalProvenance: _provenance(row['originalProvenance']! as String),
    provenance: _provenance(row['provenance']! as String),
    originalWriteZoneId: row['originalWriteZoneId'] as String?,
    writeZoneId: row['writeZoneId'] as String?,
    originalUtcOffsetMinutes: row['originalUtcOffsetMinutes'] as int?,
    utcOffsetMinutes: row['utcOffsetMinutes'] as int?,
    vocabularyVersion: row['vocabularyVersion']! as int,
  );
}

RecordedDuration? decodeRecordedDuration({
  required String? bucket,
  required String? label,
  required int? catalogVersion,
  required int? exactMinutes,
}) {
  if (bucket == null && exactMinutes == null) {
    if (label != null || catalogVersion != null) _invalid();
    return null;
  }
  if (catalogVersion == null ||
      catalogVersion != 1 ||
      label == null ||
      (bucket != null && exactMinutes != null)) {
    _invalid();
  }
  final value = bucket == null
      ? RecordedDuration.exact(exactMinutes!, catalogVersion: catalogVersion)
      : RecordedDuration.bucket(
          _enum(DurationBucket.values, bucket),
          catalogVersion: catalogVersion,
        );
  if (value.label != label) _invalid();
  return value;
}

DailyImpactRecord decodeRecordHubImpact(RecordHubImpactRow row) =>
    DailyImpactRecord(
      metadata: decodeRecordFactMetadata(row.toJson()),
      value: DailyImpactDraft(
        experiencedDate: LocalDate.fromEpochDay(row.experiencedDay),
        overall: row.overall,
        domains: {
          if (row.workOrSchool) DailyImpactDomain.workOrSchool,
          if (row.homeResponsibilities) DailyImpactDomain.homeResponsibilities,
          if (row.relationships) DailyImpactDomain.relationships,
          if (row.socialActivity) DailyImpactDomain.socialActivity,
          if (row.sleep) DailyImpactDomain.sleep,
          if (row.hobbiesOrInterests) DailyImpactDomain.hobbiesOrInterests,
        },
      ),
    );

BleedingFactRecord decodeRecordHubBleeding(RecordHubBleedingRow row) =>
    BleedingFactRecord(
      metadata: decodeRecordFactMetadata(row.toJson()),
      value: BleedingFactDraft(
        experiencedDate: LocalDate.fromEpochDay(row.experiencedDay),
        flow: _optionalEnum(BleedingFlow.values, row.flow),
        periodId: row.periodId,
        color: _optionalEnum(BleedingColor.values, row.color),
        clots: _optionalEnum(ClotObservation.values, row.clots),
      ),
    );

SleepRecord decodeRecordHubSleep(RecordHubSleepRow row) => SleepRecord(
  metadata: decodeRecordFactMetadata(row.toJson()),
  value: SleepDraft(
    experiencedDate: LocalDate.fromEpochDay(row.experiencedDay),
    duration: decodeRecordedDuration(
      bucket: row.durationBucket,
      label: row.durationLabel,
      catalogVersion: row.durationCatalogVersion,
      exactMinutes: row.exactMinutes,
    ),
    quality: row.quality == null ? null : SleepQuality.fromScore(row.quality!),
    signals: {
      if (row.troubleFallingAsleep) SleepSignal.troubleFallingAsleep,
      if (row.wakingDuringNight) SleepSignal.wakingDuringNight,
      if (row.muchMoreThanUsual) SleepSignal.muchMoreThanUsual,
      if (row.muchLessThanUsual) SleepSignal.muchLessThanUsual,
    },
  ),
);

AppetiteRecord decodeRecordHubAppetite(RecordHubAppetiteRow row) =>
    AppetiteRecord(
      metadata: decodeRecordFactMetadata(row.toJson()),
      value: AppetiteDraft(
        experiencedDate: LocalDate.fromEpochDay(row.experiencedDay),
        appetite: _optionalEnum(AppetiteLevel.values, row.appetite),
        cravingScore: row.cravingScore,
        cravingType: _optionalEnum(CravingType.values, row.cravingType),
        customCraving: row.customCraving,
      ),
    );

ActivityRecord decodeRecordHubActivity(RecordHubActivityRow row) =>
    ActivityRecord(
      metadata: decodeRecordFactMetadata(row.toJson()),
      value: ActivityDraft(
        experiencedDate: LocalDate.fromEpochDay(row.experiencedDay),
        type: _enum(ActivityType.values, row.type),
        duration: decodeRecordedDuration(
          bucket: row.durationBucket,
          label: row.durationLabel,
          catalogVersion: row.durationCatalogVersion,
          exactMinutes: row.exactMinutes,
        ),
        intensity: _optionalEnum(ActivityIntensity.values, row.intensity),
        customName: row.customName,
      ),
    );

ContextEventRecord decodeRecordHubEvent(RecordHubEventRow row) =>
    ContextEventRecord(
      metadata: decodeRecordFactMetadata(row.toJson()),
      value: ContextEventDraft(
        experiencedDate: LocalDate.fromEpochDay(row.experiencedDay),
        type: _enum(ContextEventType.values, row.type),
        intensity: _optionalEnum(ContextEventIntensity.values, row.intensity),
        customName: row.customName,
        note: row.note,
      ),
    );

TemperatureRecord decodeRecordHubTemperature(RecordHubTemperatureRow row) {
  if ((row.measuredHour == null) != (row.measuredMinute == null)) _invalid();
  return TemperatureRecord(
    metadata: decodeRecordFactMetadata(row.toJson()),
    value: TemperatureDraft(
      experiencedDate: LocalDate.fromEpochDay(row.experiencedDay),
      enteredValue: row.enteredValue,
      unit: _enum(TemperatureUnit.values, row.unit),
      method: _enum(TemperatureMethod.values, row.method),
      measuredAt: row.measuredHour == null
          ? null
          : LocalMeasurementTime(row.measuredHour!, row.measuredMinute!),
      flags: {
        if (row.feverOrIllness) TemperatureQualityFlag.feverOrIllness,
        if (row.poorSleep) TemperatureQualityFlag.poorSleep,
        if (row.alcohol) TemperatureQualityFlag.alcohol,
        if (row.travelOrTimeZoneChange)
          TemperatureQualityFlag.travelOrTimeZoneChange,
      },
    ),
  );
}
