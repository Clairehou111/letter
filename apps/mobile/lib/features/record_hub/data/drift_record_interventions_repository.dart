import 'dart:math';
import 'package:drift/drift.dart';
import '../../cycle/data/letter_health_database.dart';
import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';
import '../domain/record_hub_facts.dart';
import '../domain/record_interventions.dart';
import 'drift_record_hub_repository.dart';

final class DriftRecordInterventionsRepository
    implements RecordInterventionsRepository {
  DriftRecordInterventionsRepository(
    this.database, {
    DateTime Function()? clock,
    this.zoneProvider,
    String Function()? idGenerator,
  }) : _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _randomId;
  final LetterHealthDatabase database;
  final DateTime Function() _clock;
  final String Function()? zoneProvider;
  final String Function() _idGenerator;

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on RecordHubException {
      rethrow;
    } catch (_) {
      throw const RecordHubException(RecordHubFailure.storageUnavailable);
    }
  }

  Future<T> _transaction<T>(Future<T> Function() operation) =>
      _guard(() => database.transaction(operation));

  void _date(LocalDate date, DateTime now) {
    if (date.isAfter(LocalDate.fromDateTime(now))) {
      throw const RecordHubException(RecordHubFailure.futureDate);
    }
  }

  RecordFactMetadata _metadata(
    LocalDate date,
    DateTime now, {
    RecordFactMetadata? previous,
  }) {
    _date(date, now);
    final timing = date == LocalDate.fromDateTime(now)
        ? HealthRecordProvenance.sameDay
        : HealthRecordProvenance.laterRecall;
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      now.millisecondsSinceEpoch,
      isUtc: true,
    );
    final zone = zoneProvider?.call() ?? now.timeZoneName;
    return RecordFactMetadata(
      id: previous?.id ?? _idGenerator(),
      experiencedDate: date,
      recordedAt: previous?.recordedAt ?? timestamp,
      updatedAt: timestamp,
      originalProvenance: previous?.originalProvenance ?? timing,
      provenance:
          previous?.provenance == HealthRecordProvenance.laterRecall &&
              previous?.experiencedDate == date
          ? HealthRecordProvenance.laterRecall
          : timing,
      originalWriteZoneId: previous == null
          ? zone
          : previous.originalWriteZoneId,
      writeZoneId: zone,
      originalUtcOffsetMinutes: previous == null
          ? now.timeZoneOffset.inMinutes
          : previous.originalUtcOffsetMinutes,
      utcOffsetMinutes: now.timeZoneOffset.inMinutes,
    );
  }

  Future<R?> _find<R extends DataClass>(
    TableInfo<Table, R> table,
    Expression<bool> condition,
  ) => (database.select(table)..where((_) => condition)).getSingleOrNull();
  Future<void> _write<R extends DataClass>(
    TableInfo<Table, R> table,
    Insertable<R> values,
    RecordFactMetadata metadata,
  ) async {
    await database
        .into(table)
        .insertOnConflictUpdate(
          RawValuesInsertable<R>({
            ...values.toColumns(false),
            ...recordFactMetadataColumns(metadata),
          }),
        );
  }

  Future<ProductEpisode> _episode(String id) async {
    final row = await _find(
      database.recordProductEpisodeRows,
      database.recordProductEpisodeRows.id.equals(id),
    );
    if (row == null) throw const RecordHubException(RecordHubFailure.notFound);
    final versions =
        await (database.select(database.recordProductVersionRows)
              ..where((row) => row.episodeId.equals(id))
              ..orderBy([(row) => OrderingTerm.asc(row.versionNumber)]))
            .get();
    return decodeProductEpisode(row, versions);
  }

  @override
  Future<List<ProductEpisode>> getEpisodes({bool includeArchived = false}) =>
      _transaction(() async {
        final query = database.select(database.recordProductEpisodeRows)
          ..orderBy([
            (row) => OrderingTerm.desc(row.startDay),
            (row) => OrderingTerm.asc(row.id),
          ]);
        if (!includeArchived) query.where((row) => row.archived.equals(false));
        return [for (final row in await query.get()) await _episode(row.id)];
      });

  @override
  Future<ProductEpisode> createEpisode(ProductEpisodeDraft draft) =>
      _transaction(() async {
        final now = _clock().toLocal();
        _date(draft.startDate, now);
        if (draft.endDate != null) _date(draft.endDate!, now);
        final metadata = _metadata(draft.startDate, now);
        await _write(
          database.recordProductEpisodeRows,
          RecordProductEpisodeRowsCompanion(
            family: Value(draft.details.family.name),
            startDay: Value(draft.startDate.epochDay),
            endDay: Value(draft.endDate?.epochDay),
            archived: const Value(false),
          ),
          metadata,
        );
        await _addVersion(metadata.id, draft.startDate, draft.details, now, 1);
        return _episode(metadata.id);
      });

  Future<void> _addVersion(
    String episodeId,
    LocalDate date,
    ProductDetails details,
    DateTime now,
    int versionNumber,
  ) => _write(
    database.recordProductVersionRows,
    RecordProductVersionRowsCompanion(
      episodeId: Value(episodeId),
      effectiveDay: Value(date.epochDay),
      versionNumber: Value(versionNumber),
      exactName: Value(details.exactName),
      medicationType: Value(details.medicationType?.name),
      supplementType: Value(details.supplementType?.name),
      birthControlMethod: Value(details.birthControlMethod?.name),
      dose: Value(details.dose),
      unit: Value(details.unit?.name),
      customUnit: Value(details.customUnit),
      route: Value(details.route?.name),
      customRoute: Value(details.customRoute),
      target: Value(details.target),
    ),
    _metadata(date, now),
  );

  @override
  Future<ProductEpisode> reviseEpisode(
    String id,
    ProductDetails details, {
    required LocalDate effectiveFrom,
  }) => _transaction(() async {
    final now = _clock().toLocal();
    _date(effectiveFrom, now);
    final previous = await _episode(id);
    _require(
      !previous.archived &&
          details.family == previous.family &&
          previous.includes(effectiveFrom),
    );
    _require(!effectiveFrom.isBefore(previous.versions.last.effectiveFrom));
    if (_sameDetails(previous.currentDetails, details)) return previous;
    await _addVersion(
      id,
      effectiveFrom,
      details,
      now,
      previous.versions.length + 1,
    );
    await _write(
      database.recordProductEpisodeRows,
      RecordProductEpisodeRowsCompanion(
        family: Value(previous.family.name),
        startDay: Value(previous.startDate.epochDay),
        endDay: Value(previous.endDate?.epochDay),
        archived: Value(previous.archived),
      ),
      _metadata(previous.startDate, now, previous: previous.metadata),
    );
    return _episode(id);
  });

  @override
  Future<ProductEpisode> stopEpisode(String id, LocalDate endDate) =>
      _transaction(() async {
        final now = _clock().toLocal();
        _date(endDate, now);
        final previous = await _episode(id);
        _require(!endDate.isBefore(previous.versions.last.effectiveFrom));
        if (previous.endDate == endDate) return previous;
        await _write(
          database.recordProductEpisodeRows,
          RecordProductEpisodeRowsCompanion(
            family: Value(previous.family.name),
            startDay: Value(previous.startDate.epochDay),
            endDay: Value(endDate.epochDay),
            archived: Value(previous.archived),
          ),
          _metadata(previous.startDate, now, previous: previous.metadata),
        );
        return _episode(id);
      });

  @override
  Future<void> archiveEpisode(String id) => _transaction(() async {
    final previous = await _episode(id);
    if (previous.archived) return;
    await _write(
      database.recordProductEpisodeRows,
      RecordProductEpisodeRowsCompanion(
        family: Value(previous.family.name),
        startDay: Value(previous.startDate.epochDay),
        endDay: Value(previous.endDate?.epochDay),
        archived: const Value(true),
      ),
      _metadata(
        previous.startDate,
        _clock().toLocal(),
        previous: previous.metadata,
      ),
    );
  });

  @override
  Future<List<ProductUseRecord>> getUses({
    LocalDate? date,
    String? episodeId,
  }) => _guard(() async {
    final query = database.select(database.recordProductUseRows)
      ..orderBy([
        (row) => OrderingTerm.desc(row.experiencedDay),
        (row) => OrderingTerm.asc(row.id),
      ]);
    if (date != null) {
      query.where((row) => row.experiencedDay.equals(date.epochDay));
    }
    if (episodeId != null) {
      query.where((row) => row.episodeId.equals(episodeId));
    }
    return (await query.get()).map(decodeProductUse).toList(growable: false);
  });

  @override
  Future<ProductUseRecord> saveUse(
    ProductUseDraft draft, {
    String? id,
    bool dailyShortcut = true,
  }) => _transaction(() async {
    final now = _clock().toLocal();
    _date(draft.experiencedDate, now);
    final episode = await _episode(draft.episodeId);
    _require(
      episode.family == ProductFamily.birthControl
          ? {
              ProductUseStatus.taken,
              ProductUseStatus.missed,
              ProductUseStatus.late,
              ProductUseStatus.emergency,
            }.contains(draft.status)
          : {
              ProductUseStatus.taken,
              ProductUseStatus.skipped,
              ProductUseStatus.asNeeded,
            }.contains(draft.status),
    );
    final dailyKey = dailyShortcut
        ? '${draft.episodeId.length}:${draft.episodeId}:${draft.experiencedDate.epochDay}'
        : null;
    RecordProductUseRow? row;
    if (id != null) {
      row = await _find(
        database.recordProductUseRows,
        database.recordProductUseRows.id.equals(id),
      );
      if (row == null) {
        throw const RecordHubException(RecordHubFailure.notFound);
      }
      _require(row.episodeId == draft.episodeId);
    } else if (dailyKey != null) {
      row = await _find(
        database.recordProductUseRows,
        database.recordProductUseRows.dailyKey.equals(dailyKey),
      );
    }
    _require(
      episode.includes(draft.experiencedDate) ||
          row != null && row.experiencedDay == draft.experiencedDate.epochDay,
    );
    _require(!episode.archived || row != null);
    if (dailyKey != null) {
      final conflict = await _find(
        database.recordProductUseRows,
        database.recordProductUseRows.dailyKey.equals(dailyKey),
      );
      if (conflict != null && row?.id != conflict.id) {
        throw const RecordHubException(RecordHubFailure.dateCollision);
      }
    }
    final previous = row == null ? null : decodeProductUse(row);
    if (previous != null &&
        previous.value.experiencedDate == draft.experiencedDate &&
        previous.value.status == draft.status &&
        previous.dailyShortcut == dailyShortcut) {
      return previous;
    }
    final versionId =
        previous != null &&
            previous.value.experiencedDate == draft.experiencedDate
        ? previous.versionId
        : episode.versionAt(draft.experiencedDate).id;
    final metadata = _metadata(
      draft.experiencedDate,
      now,
      previous: previous?.metadata,
    );
    await _write(
      database.recordProductUseRows,
      RecordProductUseRowsCompanion(
        episodeId: Value(draft.episodeId),
        versionId: Value(versionId),
        status: Value(draft.status.name),
        dailyKey: Value(dailyKey),
      ),
      metadata,
    );
    return ProductUseRecord(
      metadata: metadata,
      value: draft,
      versionId: versionId,
      dailyShortcut: dailyShortcut,
    );
  });

  @override
  Future<void> deleteUse(String id) => _remove(
    database.recordProductUseRows,
    database.recordProductUseRows.id.equals(id),
  );

  Future<TriedActionRecord> _action(RecordTriedActionRow row) async {
    final items =
        await (database.select(database.recordTriedActionItemRows)
              ..where((item) => item.actionId.equals(row.id))
              ..orderBy([(item) => OrderingTerm.asc(item.position)]))
            .get();
    return decodeTriedAction(row, items);
  }

  @override
  Future<List<TriedActionRecord>> getActions({LocalDate? date}) =>
      _transaction(() async {
        final query = database.select(database.recordTriedActionRows)
          ..orderBy([
            (row) => OrderingTerm.desc(row.experiencedDay),
            (row) => OrderingTerm.asc(row.id),
          ]);
        if (date != null) {
          query.where((row) => row.experiencedDay.equals(date.epochDay));
        }
        return [for (final row in await query.get()) await _action(row)];
      });

  @override
  Future<TriedActionRecord> saveAction(TriedActionDraft draft, {String? id}) =>
      _transaction(() async {
        final now = _clock().toLocal();
        _date(draft.experiencedDate, now);
        RecordTriedActionRow? row;
        if (id != null) {
          row = await _find(
            database.recordTriedActionRows,
            database.recordTriedActionRows.id.equals(id),
          );
          if (row == null) {
            throw const RecordHubException(RecordHubFailure.notFound);
          }
        } else if (draft.completionToken != null) {
          row = await _find(
            database.recordTriedActionRows,
            database.recordTriedActionRows.completionToken.equals(
              draft.completionToken!,
            ),
          );
        }
        final previous = row == null ? null : await _action(row);
        if (draft.source == TriedActionSource.inAppCare && previous == null) {
          _require(!draft.completionOccurredAt!.isAfter(now));
        }
        if (previous != null) {
          _require(
            previous.value.source == draft.source &&
                previous.value.completionToken == draft.completionToken &&
                previous.value.careSourceId == draft.careSourceId &&
                previous.value.completionOccurredAt?.millisecondsSinceEpoch ==
                    draft.completionOccurredAt?.millisecondsSinceEpoch &&
                previous.value.completionUtcOffsetMinutes ==
                    draft.completionUtcOffsetMinutes,
          );
          if (_sameAction(previous.value, draft)) return previous;
          if (id == null && draft.completionToken != null) _invalid();
          final outcome = await _find(
            database.recordActionCheckbackRows,
            database.recordActionCheckbackRows.actionId.equals(previous.id),
          );
          _require(
            outcome == null ||
                previous.value.groupingIdentity == draft.groupingIdentity &&
                    previous.value.status == draft.status &&
                    outcome.experiencedDay >= draft.experiencedDate.epochDay,
          );
        }
        final metadata = _metadata(
          draft.experiencedDate,
          now,
          previous: previous?.metadata,
        );
        await _write(
          database.recordTriedActionRows,
          RecordTriedActionRowsCompanion(
            bundle: Value(draft.bundle),
            status: Value(draft.status.name),
            target: Value(draft.target),
            source: Value(draft.source.name),
            completionToken: Value(draft.completionToken),
            careSourceId: Value(draft.careSourceId),
            completionOccurredAtMillis: Value(
              draft.completionOccurredAt?.millisecondsSinceEpoch,
            ),
            completionUtcOffsetMinutes: Value(draft.completionUtcOffsetMinutes),
            durationBucket: Value(draft.duration?.bucket?.name),
            durationLabel: Value(draft.duration?.label),
            durationCatalogVersion: Value(draft.duration?.catalogVersion),
            exactMinutes: Value(draft.duration?.exactMinutes),
          ),
          metadata,
        );
        await (database.delete(
          database.recordTriedActionItemRows,
        )..where((row) => row.actionId.equals(metadata.id))).go();
        for (var position = 0; position < draft.actions.length; position++) {
          final action = draft.actions[position];
          await database
              .into(database.recordTriedActionItemRows)
              .insert(
                RecordTriedActionItemRowsCompanion.insert(
                  actionId: metadata.id,
                  position: position,
                  kind: action.kind.name,
                  customName: Value(action.customName),
                ),
              );
        }
        return TriedActionRecord(metadata: metadata, value: draft);
      });

  @override
  Future<void> deleteAction(String id) => _transaction(() async {
    if (await _find(
          database.recordTriedActionRows,
          database.recordTriedActionRows.id.equals(id),
        ) ==
        null) {
      throw const RecordHubException(RecordHubFailure.notFound);
    }
    await (database.delete(
      database.recordActionCheckbackRows,
    )..where((row) => row.actionId.equals(id))).go();
    await (database.delete(
      database.recordTriedActionItemRows,
    )..where((row) => row.actionId.equals(id))).go();
    await (database.delete(
      database.recordTriedActionRows,
    )..where((row) => row.id.equals(id))).go();
  });

  @override
  Future<List<ActionCheckbackRecord>> getCheckbacks() => _guard(
    () async =>
        (await (database.select(database.recordActionCheckbackRows)..orderBy([
                  (row) => OrderingTerm.desc(row.experiencedDay),
                  (row) => OrderingTerm.asc(row.id),
                ]))
                .get())
            .map(decodeActionCheckback)
            .toList(growable: false),
  );

  @override
  Future<ActionCheckbackRecord> saveCheckback(ActionCheckbackDraft draft) =>
      _transaction(() async {
        final now = _clock().toLocal();
        _date(draft.experiencedDate, now);
        final actionRow = await _find(
          database.recordTriedActionRows,
          database.recordTriedActionRows.id.equals(draft.actionId),
        );
        if (actionRow == null) {
          throw const RecordHubException(RecordHubFailure.notFound);
        }
        final action = await _action(actionRow);
        _require(!draft.experiencedDate.isBefore(action.experiencedDate));
        _require(draft.targetDegree == null || action.value.target != null);
        final row = await _find(
          database.recordActionCheckbackRows,
          database.recordActionCheckbackRows.actionId.equals(draft.actionId),
        );
        final previous = row == null ? null : decodeActionCheckback(row);
        if (previous != null &&
            previous.value.experiencedDate == draft.experiencedDate &&
            previous.value.outcome == draft.outcome &&
            previous.value.targetDegree == draft.targetDegree &&
            previous.value.unexpected == draft.unexpected &&
            previous.value.reflection == draft.reflection) {
          return previous;
        }
        final metadata = _metadata(
          draft.experiencedDate,
          now,
          previous: previous?.metadata,
        );
        await _write(
          database.recordActionCheckbackRows,
          RecordActionCheckbackRowsCompanion(
            actionId: Value(draft.actionId),
            outcome: Value(draft.outcome.name),
            targetDegree: Value(draft.targetDegree),
            unexpected: Value(draft.unexpected?.name),
            reflection: Value(draft.reflection),
          ),
          metadata,
        );
        return ActionCheckbackRecord(metadata: metadata, value: draft);
      });
  @override
  Future<void> deleteCheckback(String actionId) => _remove(
    database.recordActionCheckbackRows,
    database.recordActionCheckbackRows.actionId.equals(actionId),
  );
  Future<void> _remove<R extends DataClass>(
    TableInfo<Table, R> table,
    Expression<bool> condition,
  ) => _guard(() async {
    if (await (database.delete(table)..where((_) => condition)).go() == 0) {
      throw const RecordHubException(RecordHubFailure.notFound);
    }
  });
  static String _randomId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

Never _invalid() =>
    throw const RecordHubException(RecordHubFailure.invalidValue);
void _require(bool condition) {
  if (!condition) _invalid();
}

T _enum<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return _invalid();
}

T? _optional<T extends Enum>(List<T> values, String? name) =>
    name == null ? null : _enum(values, name);
bool _sameAction(TriedActionDraft a, TriedActionDraft b) =>
    a.experiencedDate == b.experiencedDate &&
    a.groupingIdentity == b.groupingIdentity &&
    a.status == b.status &&
    a.source == b.source &&
    a.careSourceId == b.careSourceId &&
    a.completionOccurredAt?.millisecondsSinceEpoch ==
        b.completionOccurredAt?.millisecondsSinceEpoch &&
    a.completionUtcOffsetMinutes == b.completionUtcOffsetMinutes &&
    a.completionToken == b.completionToken &&
    a.duration?.bucket == b.duration?.bucket &&
    a.duration?.exactMinutes == b.duration?.exactMinutes &&
    a.duration?.catalogVersion == b.duration?.catalogVersion;

bool _sameDetails(ProductDetails a, ProductDetails b) =>
    a.family == b.family &&
    a.exactName == b.exactName &&
    a.medicationType == b.medicationType &&
    a.supplementType == b.supplementType &&
    a.birthControlMethod == b.birthControlMethod &&
    a.dose == b.dose &&
    a.unit == b.unit &&
    a.customUnit == b.customUnit &&
    a.route == b.route &&
    a.customRoute == b.customRoute &&
    a.target == b.target;

ProductVersion decodeProductVersion(
  RecordProductVersionRow row,
  ProductFamily family,
) {
  final metadata = decodeRecordFactMetadata(row.toJson());
  _require(metadata.experiencedDate.epochDay == row.effectiveDay);
  return ProductVersion(
    metadata: metadata,
    episodeId: row.episodeId,
    effectiveFrom: LocalDate.fromEpochDay(row.effectiveDay),
    versionNumber: row.versionNumber,
    details: ProductDetails(
      family: family,
      exactName: row.exactName,
      medicationType: _optional(MedicationType.values, row.medicationType),
      supplementType: _optional(SupplementType.values, row.supplementType),
      birthControlMethod: _optional(
        BirthControlMethod.values,
        row.birthControlMethod,
      ),
      dose: row.dose,
      unit: _optional(DoseUnit.values, row.unit),
      customUnit: row.customUnit,
      route: _optional(ProductRoute.values, row.route),
      customRoute: row.customRoute,
      target: row.target,
    ),
  );
}

ProductEpisode decodeProductEpisode(
  RecordProductEpisodeRow row,
  List<RecordProductVersionRow> versions,
) {
  final metadata = decodeRecordFactMetadata(row.toJson());
  _require(metadata.experiencedDate.epochDay == row.startDay);
  final family = _enum(ProductFamily.values, row.family);
  final sorted = [...versions]
    ..sort((a, b) => a.versionNumber.compareTo(b.versionNumber));
  return ProductEpisode(
    metadata: metadata,
    family: family,
    startDate: LocalDate.fromEpochDay(row.startDay),
    endDate: row.endDay == null ? null : LocalDate.fromEpochDay(row.endDay!),
    archived: row.archived,
    versions: sorted.map((version) => decodeProductVersion(version, family)),
  );
}

ProductUseRecord decodeProductUse(RecordProductUseRow row) {
  final metadata = decodeRecordFactMetadata(row.toJson());
  _require(row.versionId.isNotEmpty);
  if (row.dailyKey != null) {
    _require(
      row.dailyKey ==
          '${row.episodeId.length}:${row.episodeId}:${row.experiencedDay}',
    );
  }
  return ProductUseRecord(
    metadata: metadata,
    versionId: row.versionId,
    dailyShortcut: row.dailyKey != null,
    value: ProductUseDraft(
      experiencedDate: metadata.experiencedDate,
      episodeId: row.episodeId,
      status: _enum(ProductUseStatus.values, row.status),
    ),
  );
}

TriedActionRecord decodeTriedAction(
  RecordTriedActionRow row,
  List<RecordTriedActionItemRow> items,
) {
  _require(
    (row.completionOccurredAtMillis == null) ==
        (row.completionUtcOffsetMinutes == null),
  );
  _require(
    row.completionOccurredAtMillis == null ||
        row.completionOccurredAtMillis! <= row.recordedAtMillis,
  );
  final sorted = [...items]..sort((a, b) => a.position.compareTo(b.position));
  for (var position = 0; position < sorted.length; position++) {
    _require(
      sorted[position].position == position &&
          sorted[position].actionId == row.id,
    );
  }
  final metadata = decodeRecordFactMetadata(row.toJson());
  return TriedActionRecord(
    metadata: metadata,
    value: TriedActionDraft(
      experiencedDate: metadata.experiencedDate,
      actions: sorted.map(
        (item) => TriedActionSelection(
          _enum(TriedActionKind.values, item.kind),
          customName: item.customName,
        ),
      ),
      bundle: row.bundle,
      status: _enum(TriedActionStatus.values, row.status),
      target: row.target,
      source: _enum(TriedActionSource.values, row.source),
      completionToken: row.completionToken,
      careSourceId: row.careSourceId,
      completionOccurredAt: row.completionOccurredAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              row.completionOccurredAtMillis!,
              isUtc: true,
            ),
      completionUtcOffsetMinutes: row.completionUtcOffsetMinutes,
      duration: decodeRecordedDuration(
        bucket: row.durationBucket,
        label: row.durationLabel,
        catalogVersion: row.durationCatalogVersion,
        exactMinutes: row.exactMinutes,
      ),
    ),
  );
}

ActionCheckbackRecord decodeActionCheckback(RecordActionCheckbackRow row) {
  final metadata = decodeRecordFactMetadata(row.toJson());
  return ActionCheckbackRecord(
    metadata: metadata,
    value: ActionCheckbackDraft(
      experiencedDate: metadata.experiencedDate,
      actionId: row.actionId,
      outcome: _enum(ActionOutcome.values, row.outcome),
      targetDegree: row.targetDegree,
      unexpected: _optional(UnexpectedObservation.values, row.unexpected),
      reflection: row.reflection,
    ),
  );
}
