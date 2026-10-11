import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../domain/bleeding_flow.dart';
import '../domain/local_date.dart';
import '../domain/period_record.dart';
import '../domain/period_repository.dart';
import '../domain/period_validation.dart';
import 'letter_health_database.dart';
import '../../record_hub/data/drift_record_hub_repository.dart';
import '../../record_hub/domain/record_hub_facts.dart';

final class DriftPeriodRepository implements ConfirmablePeriodRepository {
  DriftPeriodRepository(
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
  final PeriodReviewStore _reviews = PeriodReviewStore();

  @override
  Future<List<PeriodRecord>> getAll() async {
    final query = _database.select(_database.periodRows)
      ..orderBy([(row) => OrderingTerm.desc(row.startDay)]);
    return (await query.get()).map(_toDomain).toList(growable: false);
  }

  @override
  Future<PeriodRecord> create(PeriodDraft draft, {required LocalDate today}) =>
      _create(draft, today: today);

  Future<PeriodRecord> _create(
    PeriodDraft draft, {
    required LocalDate today,
    bool confirmed = false,
  }) {
    return _guardStorage(() {
      return _database.transaction(() async {
        final existing = await getAll();
        validatePeriodDraft(draft: draft, today: today, existing: existing);
        final now = _clock().toUtc();
        final adjacent = adjacentPeriodsForDraft(
          draft: draft,
          today: today,
          existing: existing,
        );
        if (adjacent.isNotEmpty) {
          if (!confirmed) {
            throw const PeriodWriteException(
              PeriodWriteFailure.confirmationRequired,
            );
          }
          final mergedDraft = mergeAdjacentPeriodDraft(draft, adjacent);
          final survivor = _earliestPeriod(adjacent);
          return _persistMergedPeriod(
            survivor: survivor,
            absorbed: adjacent.where((record) => record.id != survivor.id),
            draft: mergedDraft,
            updatedAt: now,
            today: today,
          );
        }
        final record = PeriodRecord(
          id: _idGenerator(),
          startDate: draft.startDate,
          endDate: draft.endDate,
          createdAt: now,
          updatedAt: now,
        );
        await _database.into(_database.periodRows).insert(_toCompanion(record));
        return record;
      });
    });
  }

  @override
  Future<PeriodRecord> update(
    String id,
    PeriodDraft draft, {
    required LocalDate today,
  }) => _update(id, draft, today: today);

  Future<PeriodRecord> _update(
    String id,
    PeriodDraft draft, {
    required LocalDate today,
    bool confirmed = false,
  }) {
    return _guardStorage(() {
      return _database.transaction(() async {
        final existing = await getAll();
        final previous = existing
            .where((record) => record.id == id)
            .firstOrNull;
        if (previous == null) {
          throw const PeriodWriteException(PeriodWriteFailure.notFound);
        }
        validatePeriodDraft(
          draft: draft,
          today: today,
          existing: existing,
          editingId: id,
        );
        final consequence = await _retentionConsequences(
          draft,
          today,
          existing,
          id,
        );
        if (!confirmed &&
            (consequence.bleeding > 0 || consequence.reflections > 0)) {
          throw const PeriodWriteException(
            PeriodWriteFailure.confirmationRequired,
          );
        }
        final adjacent = adjacentPeriodsForDraft(
          draft: draft,
          today: today,
          existing: existing,
          editingId: id,
        );
        if (adjacent.isNotEmpty) {
          if (!confirmed) {
            throw const PeriodWriteException(
              PeriodWriteFailure.confirmationRequired,
            );
          }
          final mergedDraft = mergeAdjacentPeriodDraft(draft, adjacent);
          final candidates = <PeriodRecord>[previous, ...adjacent];
          final survivor = _earliestPeriod(
            candidates,
            editedId: id,
            draft: draft,
          );
          return _persistMergedPeriod(
            survivor: survivor,
            absorbed: candidates.where((record) => record.id != survivor.id),
            draft: mergedDraft,
            updatedAt: _clock().toUtc(),
            today: today,
          );
        }
        final updatedAt = _clock().toUtc();
        final updated = PeriodRecord(
          id: id,
          startDate: draft.startDate,
          endDate: draft.endDate,
          createdAt: previous.createdAt,
          updatedAt: updatedAt,
        );
        await (_database.update(
          _database.periodRows,
        )..where((row) => row.id.equals(id))).write(_toCompanion(updated));
        await _preserveOutsideRange(id, draft, today);
        return updated;
      });
    });
  }

  Future<PeriodRecord> _persistMergedPeriod({
    required PeriodRecord survivor,
    required Iterable<PeriodRecord> absorbed,
    required PeriodDraft draft,
    required DateTime updatedAt,
    required LocalDate today,
  }) async {
    final merged = PeriodRecord(
      id: survivor.id,
      startDate: draft.startDate,
      endDate: draft.endDate,
      createdAt: survivor.createdAt,
      updatedAt: updatedAt,
    );
    final absorbedIds = absorbed.map((record) => record.id).toList();

    await (_database.update(
      _database.periodRows,
    )..where((row) => row.id.equals(survivor.id))).write(_toCompanion(merged));
    // Reflection anchors, IDs and both timestamps remain as originally saved.
    // Absorbed owners detach via the existing foreign key and remain readable.
    for (final sourceId in [survivor.id, ...absorbedIds]) {
      await _promoteLegacyFlows(sourceId);
    }
    for (final absorbedId in absorbedIds) {
      await (_database.update(_database.recordHubBleedingRows)
            ..where((row) => row.periodId.equals(absorbedId)))
          .write(RecordHubBleedingRowsCompanion(periodId: Value(survivor.id)));

      await (_database.delete(
        _database.periodRows,
      )..where((row) => row.id.equals(absorbedId))).go();
    }
    await _preserveOutsideRange(survivor.id, draft, today);
    return merged;
  }

  @override
  Future<PeriodWritePreview> previewWrite(
    PeriodDraft draft, {
    required LocalDate today,
    String? editingId,
  }) => _guardStorage(
    () => _database.transaction(() async {
      final existing = await getAll();
      final consequence = await _retentionConsequences(
        draft,
        today,
        existing,
        editingId,
      );
      return _reviews.preview(
        draft: draft,
        today: today,
        editingId: editingId,
        existing: existing,
        snapshot: await _sourceSnapshot(),
        detachedBleedingCount: consequence.bleeding,
        detachedReflectionCount: consequence.reflections,
      );
    }),
  );

  @override
  Future<PeriodRecord> confirmWrite(
    PeriodWritePreview preview, {
    required LocalDate today,
  }) async {
    final saved = await _guardStorage(
      () => _database.transaction(() async {
        final reviewed = _reviews.validate(preview, await _sourceSnapshot());
        return reviewed.editingId == null
            ? _create(reviewed.draft, today: today, confirmed: true)
            : _update(
                reviewed.editingId!,
                reviewed.draft,
                today: today,
                confirmed: true,
              );
      }),
    );
    _reviews.consume(preview);
    return saved;
  }

  Future<String> _sourceSnapshot() async {
    final periods = (await _database.select(_database.periodRows).get())
      ..sort((a, b) => a.id.compareTo(b.id));
    final flows = (await _database.select(_database.periodFlowRows).get())
      ..sort((a, b) {
        final id = a.periodId.compareTo(b.periodId);
        return id != 0 ? id : a.day.compareTo(b.day);
      });
    final bleeding =
        (await _database.select(_database.recordHubBleedingRows).get())
          ..sort((a, b) => a.id.compareTo(b.id));
    final reflections =
        (await _database.select(_database.cycleReflectionRows).get())
          ..sort((a, b) => a.id.compareTo(b.id));
    return jsonEncode([
      periods.map((row) => row.toJson()).toList(),
      flows.map((row) => row.toJson()).toList(),
      bleeding.map((row) => row.toJson()).toList(),
      reflections.map((row) => row.toJson()).toList(),
    ]);
  }

  Future<({int bleeding, int reflections})> _retentionConsequences(
    PeriodDraft draft,
    LocalDate today,
    List<PeriodRecord> existing,
    String? editingId,
  ) async {
    final adjacent = adjacentPeriodsForDraft(
      draft: draft,
      today: today,
      existing: existing,
      editingId: editingId,
    );
    final affected = <PeriodRecord>[
      if (editingId != null)
        ...existing.where((period) => period.id == editingId),
      ...adjacent,
    ];
    if (affected.isEmpty) return (bleeding: 0, reflections: 0);
    final sourceIds = affected.map((period) => period.id).toSet();
    final survivor = _earliestPeriod(
      affected,
      editedId: editingId,
      draft: draft,
    );
    final finalRange = mergeAdjacentPeriodDraft(draft, adjacent);
    bool outside(int day) =>
        day < finalRange.startDate.epochDay ||
        day > (finalRange.endDate ?? today).epochDay;
    final legacy = await (_database.select(
      _database.periodFlowRows,
    )..where((row) => row.periodId.isIn(sourceIds))).get();
    final typed = await (_database.select(
      _database.recordHubBleedingRows,
    )..where((row) => row.periodId.isIn(sourceIds))).get();
    final ids = <String>{
      for (final row in legacy)
        if (outside(row.day)) '${row.periodId}:${row.day}',
      for (final row in typed)
        if (outside(row.experiencedDay)) row.id,
    };
    final reflections = await (_database.select(
      _database.cycleReflectionRows,
    )..where((row) => row.startingPeriodId.isIn(sourceIds))).get();
    return (
      bleeding: ids.length,
      reflections: reflections
          .where(
            (row) =>
                row.startingPeriodId != survivor.id ||
                outside(row.cycleStartDay),
          )
          .length,
    );
  }

  Future<void> _promoteLegacyFlows(
    String periodId, {
    int? start,
    int? end,
  }) async {
    final legacy = await (_database.select(
      _database.periodFlowRows,
    )..where((row) => row.periodId.equals(periodId))).get();
    for (final row in legacy) {
      if (start != null && end != null && row.day >= start && row.day <= end) {
        continue;
      }
      final existing =
          await (_database.select(_database.recordHubBleedingRows)
                ..where((fact) => fact.experiencedDay.equals(row.day)))
              .getSingleOrNull();
      if (existing != null && existing.id != '$periodId:${row.day}') {
        // Retaining distinct IDs requires a separate source; never discard one
        // to satisfy the date singleton constraint during an implicit change.
        throw const PeriodWriteException(PeriodWriteFailure.storageUnavailable);
      }
      if (existing == null) {
        await _database
            .into(_database.recordHubBleedingRows)
            .insert(
              RecordHubBleedingRowsCompanion.insert(
                id: '$periodId:${row.day}',
                experiencedDay: row.day,
                recordedAtMillis: row.createdAtMillis,
                updatedAtMillis: row.updatedAtMillis,
                originalProvenance: 'timing_unknown',
                provenance: 'timing_unknown',
                periodId: Value(periodId),
                flow: Value(row.flow),
                color: Value(row.color),
              ),
            );
      }
      await (_database.delete(_database.periodFlowRows)..where(
            (fact) => fact.periodId.equals(periodId) & fact.day.equals(row.day),
          ))
          .go();
    }
  }

  Future<void> _preserveOutsideRange(
    String periodId,
    PeriodDraft draft,
    LocalDate today,
  ) async {
    final upper = (draft.endDate ?? today).epochDay;
    await _promoteLegacyFlows(
      periodId,
      start: draft.startDate.epochDay,
      end: upper,
    );
    await (_database.update(_database.recordHubBleedingRows)..where(
          (row) =>
              row.periodId.equals(periodId) &
              (row.experiencedDay.isSmallerThanValue(draft.startDate.epochDay) |
                  row.experiencedDay.isBiggerThanValue(upper)),
        ))
        .write(const RecordHubBleedingRowsCompanion(periodId: Value(null)));
  }

  PeriodRecord _earliestPeriod(
    Iterable<PeriodRecord> records, {
    String? editedId,
    PeriodDraft? draft,
  }) {
    final sorted = records.toList()
      ..sort((left, right) {
        final leftStart = left.id == editedId
            ? draft!.startDate
            : left.startDate;
        final rightStart = right.id == editedId
            ? draft!.startDate
            : right.startDate;
        final byStart = leftStart.compareTo(rightStart);
        if (byStart != 0) return byStart;
        final byUpdated = right.updatedAt.compareTo(left.updatedAt);
        return byUpdated != 0 ? byUpdated : left.id.compareTo(right.id);
      });
    return sorted.first;
  }

  @override
  Future<void> delete(String id) {
    return _guardStorage(() {
      return _database.transaction(() async {
        await _promoteLegacyFlows(id);
        await (_database.update(_database.recordHubBleedingRows)
              ..where((row) => row.periodId.equals(id)))
            .write(const RecordHubBleedingRowsCompanion(periodId: Value(null)));
        final deleted = await (_database.delete(
          _database.periodRows,
        )..where((row) => row.id.equals(id))).go();
        if (deleted == 0) {
          throw const PeriodWriteException(PeriodWriteFailure.notFound);
        }
        await (_database.delete(
          _database.periodFlowRows,
        )..where((row) => row.periodId.equals(id))).go();
      });
    });
  }

  @override
  Future<List<BleedingDayRecord>> getAllFlowDays() async {
    final legacy =
        await (_database.select(_database.periodFlowRows)..orderBy([
              (row) => OrderingTerm.desc(row.day),
              (row) => OrderingTerm.asc(row.periodId),
            ]))
            .get();
    final current = await _database
        .select(_database.recordHubBleedingRows)
        .get();
    final overriddenDays = current.map((row) => row.experiencedDay).toSet();
    final facts = <BleedingDayRecord>[
      ...legacy
          .where((row) => !overriddenDays.contains(row.day))
          .map(_flowToDomain),
      for (final row in current)
        if (row.periodId != null && row.flow != null)
          BleedingDayRecord(
            periodId: row.periodId!,
            date: LocalDate.fromEpochDay(row.experiencedDay),
            flow: BleedingFlow.values.byName(row.flow!),
            color: row.color == null
                ? null
                : BleedingColor.values.byName(row.color!),
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row.recordedAtMillis,
              isUtc: true,
            ),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              row.updatedAtMillis,
              isUtc: true,
            ),
          ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return facts;
  }

  @override
  Future<BleedingDayRecord> setFlow(
    String periodId,
    LocalDate date,
    BleedingFlow flow, {
    required LocalDate today,
  }) {
    return _guardStorage(() async {
      return _database.transaction(() async {
        final period = await (_database.select(
          _database.periodRows,
        )..where((row) => row.id.equals(periodId))).getSingleOrNull();
        if (period == null) {
          throw const PeriodWriteException(
            PeriodWriteFailure.flowPeriodNotFound,
          );
        }
        if (date.isAfter(today)) {
          throw const PeriodWriteException(PeriodWriteFailure.flowDateInFuture);
        }
        final upperBound = period.endDay ?? today.epochDay;
        if (date.epochDay < period.startDay || date.epochDay > upperBound) {
          throw const PeriodWriteException(
            PeriodWriteFailure.flowDateOutsidePeriod,
          );
        }
        final hub =
            await (_database.select(_database.recordHubBleedingRows)
                  ..where((row) => row.experiencedDay.equals(date.epochDay)))
                .getSingleOrNull();
        if (hub != null) {
          final saved = await DriftRecordHubRepository(_database, clock: _clock)
              .upsertBleeding(
                BleedingFactDraft(
                  experiencedDate: date,
                  periodId: periodId,
                  flow: flow,
                  color: hub.color == null
                      ? null
                      : BleedingColor.values.byName(hub.color!),
                  clots: hub.clots == null
                      ? null
                      : ClotObservation.values.byName(hub.clots!),
                ),
              );
          return _bleedingToFlow(saved);
        }
        final existing =
            await (_database.select(_database.periodFlowRows)..where(
                  (row) =>
                      row.periodId.equals(periodId) &
                      row.day.equals(date.epochDay),
                ))
                .getSingleOrNull();
        final now = _clock().toUtc();
        final record = BleedingDayRecord(
          periodId: periodId,
          date: date,
          flow: flow,
          color: existing?.color == null
              ? null
              : BleedingColor.values.byName(existing!.color!),
          createdAt: existing == null
              ? now
              : DateTime.fromMillisecondsSinceEpoch(
                  existing.createdAtMillis,
                  isUtc: true,
                ),
          updatedAt: now,
        );
        await _database
            .into(_database.periodFlowRows)
            .insert(_flowToCompanion(record), mode: InsertMode.insertOrReplace);
        return record;
      });
    });
  }

  @override
  Future<BleedingDayRecord> setBleedingColor(
    String periodId,
    LocalDate date,
    BleedingColor color,
  ) {
    return _guardStorage(() async {
      final hub =
          await (_database.select(_database.recordHubBleedingRows)
                ..where((row) => row.experiencedDay.equals(date.epochDay)))
              .getSingleOrNull();
      if (hub != null) {
        if (hub.flow == null) {
          throw const PeriodWriteException(
            PeriodWriteFailure.flowRequiredForColor,
          );
        }
        final saved = await DriftRecordHubRepository(_database, clock: _clock)
            .upsertBleeding(
              BleedingFactDraft(
                experiencedDate: date,
                periodId: periodId,
                flow: BleedingFlow.values.byName(hub.flow!),
                color: color,
                clots: hub.clots == null
                    ? null
                    : ClotObservation.values.byName(hub.clots!),
              ),
            );
        return _bleedingToFlow(saved);
      }
      final existing =
          await (_database.select(_database.periodFlowRows)..where(
                (row) =>
                    row.periodId.equals(periodId) &
                    row.day.equals(date.epochDay),
              ))
              .getSingleOrNull();
      if (existing == null) {
        throw const PeriodWriteException(
          PeriodWriteFailure.flowRequiredForColor,
        );
      }
      final now = _clock().toUtc();
      await (_database.update(_database.periodFlowRows)..where(
            (row) =>
                row.periodId.equals(periodId) & row.day.equals(date.epochDay),
          ))
          .write(
            PeriodFlowRowsCompanion(
              color: Value(color.name),
              updatedAtMillis: Value(now.millisecondsSinceEpoch),
            ),
          );
      return BleedingDayRecord(
        periodId: existing.periodId,
        date: LocalDate.fromEpochDay(existing.day),
        flow: BleedingFlow.values.byName(existing.flow),
        color: color,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          existing.createdAtMillis,
          isUtc: true,
        ),
        updatedAt: now,
      );
    });
  }

  @override
  Future<void> clearBleedingColor(String periodId, LocalDate date) {
    return _guardStorage(() async {
      final hub =
          await (_database.select(_database.recordHubBleedingRows)
                ..where((row) => row.experiencedDay.equals(date.epochDay)))
              .getSingleOrNull();
      if (hub != null && hub.flow != null) {
        await DriftRecordHubRepository(_database, clock: _clock).upsertBleeding(
          BleedingFactDraft(
            experiencedDate: date,
            periodId: periodId,
            flow: BleedingFlow.values.byName(hub.flow!),
            clots: hub.clots == null
                ? null
                : ClotObservation.values.byName(hub.clots!),
          ),
        );
        return;
      }
      await (_database.update(_database.periodFlowRows)..where(
            (row) =>
                row.periodId.equals(periodId) & row.day.equals(date.epochDay),
          ))
          .write(
            PeriodFlowRowsCompanion(
              color: const Value(null),
              updatedAtMillis: Value(_clock().toUtc().millisecondsSinceEpoch),
            ),
          );
    });
  }

  @override
  Future<void> clearFlow(String periodId, LocalDate date) {
    return _guardStorage(
      () => _database.transaction(() async {
        await (_database.delete(
          _database.recordHubBleedingRows,
        )..where((row) => row.experiencedDay.equals(date.epochDay))).go();
        await (_database.delete(_database.periodFlowRows)..where(
              (row) =>
                  row.periodId.equals(periodId) & row.day.equals(date.epochDay),
            ))
            .go();
      }),
    );
  }

  static BleedingDayRecord _bleedingToFlow(BleedingFactRecord saved) =>
      BleedingDayRecord(
        periodId: saved.value.periodId!,
        date: saved.experiencedDate,
        flow: saved.value.flow!,
        color: saved.value.color,
        createdAt: saved.metadata.recordedAt,
        updatedAt: saved.metadata.updatedAt,
      );

  @override
  Future<void> close() async {
    if (closeDatabase) {
      await _database.close();
    }
  }

  Future<T> _guardStorage<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PeriodWriteException {
      rethrow;
    } on Object {
      throw const PeriodWriteException(PeriodWriteFailure.storageUnavailable);
    }
  }

  static PeriodRecord _toDomain(PeriodRow row) {
    return PeriodRecord(
      id: row.id,
      startDate: LocalDate.fromEpochDay(row.startDay),
      endDate: row.endDay == null ? null : LocalDate.fromEpochDay(row.endDay!),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAtMillis,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAtMillis,
        isUtc: true,
      ),
    );
  }

  static PeriodRowsCompanion _toCompanion(PeriodRecord record) {
    return PeriodRowsCompanion(
      id: Value(record.id),
      startDay: Value(record.startDate.epochDay),
      endDay: Value(record.endDate?.epochDay),
      createdAtMillis: Value(record.createdAt.millisecondsSinceEpoch),
      updatedAtMillis: Value(record.updatedAt.millisecondsSinceEpoch),
    );
  }

  static BleedingDayRecord _flowToDomain(PeriodFlowRow row) {
    return BleedingDayRecord(
      periodId: row.periodId,
      date: LocalDate.fromEpochDay(row.day),
      flow: BleedingFlow.values.byName(row.flow),
      color: row.color == null ? null : BleedingColor.values.byName(row.color!),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAtMillis,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAtMillis,
        isUtc: true,
      ),
    );
  }

  static PeriodFlowRowsCompanion _flowToCompanion(BleedingDayRecord record) {
    return PeriodFlowRowsCompanion(
      periodId: Value(record.periodId),
      day: Value(record.date.epochDay),
      flow: Value(record.flow.name),
      color: Value(record.color?.name),
      createdAtMillis: Value(record.createdAt.millisecondsSinceEpoch),
      updatedAtMillis: Value(record.updatedAt.millisecondsSinceEpoch),
    );
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
