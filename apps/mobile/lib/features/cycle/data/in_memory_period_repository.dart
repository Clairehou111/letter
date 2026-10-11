import 'dart:convert';
import 'dart:math';

import '../../health_records/domain/health_record.dart';
import '../../care/domain/care_memory.dart';
import '../../record_hub/domain/record_hub_facts.dart';

import '../domain/bleeding_flow.dart';
import '../domain/local_date.dart';
import '../domain/period_record.dart';
import '../domain/period_repository.dart';
import '../domain/period_validation.dart';

final class InMemoryPeriodRepository implements ConfirmablePeriodRepository {
  InMemoryPeriodRepository({
    Iterable<PeriodRecord> seed = const [],
    DateTime Function()? clock,
    String Function()? idGenerator,
    this.cycleReflectionSourceReader,
  }) : _records = [...seed],
       _flowDays = [],
       _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _randomId;

  /// Optional source adapter for memory fixtures that retain Care letters in
  /// a separate repository. Their content participates in optimistic review.
  final Iterable<CycleReflection> Function()? cycleReflectionSourceReader;
  final List<PeriodRecord> _records;
  final List<BleedingDayRecord> _flowDays;
  final Map<int, BleedingFactRecord> _independentBleeding = {};
  final Map<int, String> _flowSourceIds = {};
  final PeriodReviewStore _reviews = PeriodReviewStore();

  /// Promoted facts retain original metadata and remain readable after their
  /// period is shortened or deleted. Test fixtures may project these into Hub.
  List<BleedingFactRecord> get independentBleedingFacts =>
      List.unmodifiable(_independentBleeding.values);

  final DateTime Function() _clock;
  final String Function() _idGenerator;

  @override
  Future<List<PeriodRecord>> getAll() async {
    return [..._records]
      ..sort((left, right) => right.startDate.compareTo(left.startDate));
  }

  @override
  Future<PeriodRecord> create(PeriodDraft draft, {required LocalDate today}) =>
      _create(draft, today: today);

  Future<PeriodRecord> _create(
    PeriodDraft draft, {
    required LocalDate today,
    bool confirmed = false,
  }) async {
    validatePeriodDraft(draft: draft, today: today, existing: _records);
    final adjacent = adjacentPeriodsForDraft(
      draft: draft,
      today: today,
      existing: _records,
    );
    final now = _clock().toUtc();
    if (adjacent.isNotEmpty) {
      if (!confirmed) {
        throw const PeriodWriteException(
          PeriodWriteFailure.confirmationRequired,
        );
      }
      final mergedDraft = mergeAdjacentPeriodDraft(draft, adjacent);
      final survivor = _earliestPeriod(adjacent);
      return _replaceMergedPeriod(
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
    _records.add(record);
    return record;
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
  }) async {
    final index = _records.indexWhere((record) => record.id == id);
    if (index == -1) {
      throw const PeriodWriteException(PeriodWriteFailure.notFound);
    }
    validatePeriodDraft(
      draft: draft,
      today: today,
      existing: _records,
      editingId: id,
    );
    final adjacent = adjacentPeriodsForDraft(
      draft: draft,
      today: today,
      existing: _records,
      editingId: id,
    );
    final consequence = _retentionConsequences(draft, today, id);
    if (!confirmed &&
        (consequence.bleeding > 0 || consequence.reflections > 0)) {
      throw const PeriodWriteException(PeriodWriteFailure.confirmationRequired);
    }
    final previous = _records[index];
    if (adjacent.isNotEmpty) {
      if (!confirmed) {
        throw const PeriodWriteException(
          PeriodWriteFailure.confirmationRequired,
        );
      }
      final mergedDraft = mergeAdjacentPeriodDraft(draft, adjacent);
      final candidates = <PeriodRecord>[previous, ...adjacent];
      final survivor = _earliestPeriod(candidates, editedId: id, draft: draft);
      return _replaceMergedPeriod(
        survivor: survivor,
        absorbed: candidates.where((record) => record.id != survivor.id),
        draft: mergedDraft,
        updatedAt: _clock().toUtc(),
        today: today,
      );
    }
    final updated = PeriodRecord(
      id: previous.id,
      startDate: draft.startDate,
      endDate: draft.endDate,
      createdAt: previous.createdAt,
      updatedAt: _clock().toUtc(),
    );
    _records[index] = updated;
    _preserveOutsideRange(id, draft, today);
    return updated;
  }

  PeriodRecord _replaceMergedPeriod({
    required PeriodRecord survivor,
    required Iterable<PeriodRecord> absorbed,
    required PeriodDraft draft,
    required DateTime updatedAt,
    required LocalDate today,
  }) {
    final absorbedIds = absorbed.map((record) => record.id).toSet();
    final merged = PeriodRecord(
      id: survivor.id,
      startDate: draft.startDate,
      endDate: draft.endDate,
      createdAt: survivor.createdAt,
      updatedAt: updatedAt,
    );
    _records.removeWhere(
      (record) => record.id == survivor.id || absorbedIds.contains(record.id),
    );
    _records.add(merged);
    for (var index = 0; index < _flowDays.length; index += 1) {
      final flow = _flowDays[index];
      if (!absorbedIds.contains(flow.periodId)) continue;
      _flowDays[index] = BleedingDayRecord(
        periodId: survivor.id,
        date: flow.date,
        flow: flow.flow,
        color: flow.color,
        createdAt: flow.createdAt,
        updatedAt: flow.updatedAt,
      );
    }
    _preserveOutsideRange(survivor.id, draft, today);
    return merged;
  }

  @override
  Future<PeriodWritePreview> previewWrite(
    PeriodDraft draft, {
    required LocalDate today,
    String? editingId,
  }) async {
    final consequence = _retentionConsequences(draft, today, editingId);
    return _reviews.preview(
      draft: draft,
      today: today,
      editingId: editingId,
      existing: _records,
      snapshot: _sourceSnapshot(),
      detachedBleedingCount: consequence.bleeding,
      detachedReflectionCount: consequence.reflections,
    );
  }

  ({int bleeding, int reflections}) _retentionConsequences(
    PeriodDraft draft,
    LocalDate today,
    String? editingId,
  ) {
    final adjacent = adjacentPeriodsForDraft(
      draft: draft,
      today: today,
      existing: _records,
      editingId: editingId,
    );
    final affected = <PeriodRecord>[
      if (editingId != null)
        ..._records.where((period) => period.id == editingId),
      ...adjacent,
    ];
    if (affected.isEmpty) return (bleeding: 0, reflections: 0);
    final ids = affected.map((period) => period.id).toSet();
    final survivor = _earliestPeriod(
      affected,
      editedId: editingId,
      draft: draft,
    );
    final finalRange = mergeAdjacentPeriodDraft(draft, adjacent);
    bool outside(int day) =>
        day < finalRange.startDate.epochDay ||
        day > (finalRange.endDate ?? today).epochDay;
    return (
      bleeding: _flowDays
          .where(
            (flow) =>
                ids.contains(flow.periodId) && outside(flow.date.epochDay),
          )
          .length,
      reflections:
          (cycleReflectionSourceReader?.call() ?? const <CycleReflection>[])
              .where(
                (reflection) =>
                    ids.contains(reflection.startingPeriodId) &&
                    (reflection.startingPeriodId != survivor.id ||
                        outside(reflection.cycleStartDay)),
              )
              .length,
    );
  }

  @override
  Future<PeriodRecord> confirmWrite(
    PeriodWritePreview preview, {
    required LocalDate today,
  }) async {
    final reviewed = _reviews.validate(preview, _sourceSnapshot());
    final saved = reviewed.editingId == null
        ? await _create(reviewed.draft, today: today, confirmed: true)
        : await _update(
            reviewed.editingId!,
            reviewed.draft,
            today: today,
            confirmed: true,
          );
    _reviews.consume(preview);
    return saved;
  }

  String _sourceSnapshot() {
    final records = [..._records]..sort((a, b) => a.id.compareTo(b.id));
    final flows = [..._flowDays]
      ..sort((a, b) {
        final id = a.periodId.compareTo(b.periodId);
        return id != 0 ? id : a.date.compareTo(b.date);
      });
    final letters =
        (cycleReflectionSourceReader?.call() ?? const <CycleReflection>[])
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    return jsonEncode([
      for (final record in records)
        [
          record.id,
          record.startDate.epochDay,
          record.endDate?.epochDay,
          record.createdAt.microsecondsSinceEpoch,
          record.updatedAt.microsecondsSinceEpoch,
        ],
      for (final flow in flows)
        [
          flow.periodId,
          flow.date.epochDay,
          flow.flow.name,
          flow.color?.name,
          flow.createdAt.microsecondsSinceEpoch,
          flow.updatedAt.microsecondsSinceEpoch,
        ],
      for (final fact in independentBleedingFacts)
        [fact.metadata.id, fact.metadata.updatedAt.microsecondsSinceEpoch],
      for (final reflection in letters)
        [
          reflection.id,
          reflection.startingPeriodId,
          reflection.cycleStartDay,
          reflection.observation,
          reflection.need?.name,
          reflection.whatHelped,
          reflection.futureSelfNote,
          reflection.createdAt.microsecondsSinceEpoch,
          reflection.updatedAt.microsecondsSinceEpoch,
        ],
    ]);
  }

  void _preserveOutsideRange(String id, PeriodDraft draft, LocalDate today) {
    _preserveFlows(
      _flowDays
          .where(
            (flow) =>
                flow.periodId == id &&
                (flow.date.isBefore(draft.startDate) ||
                    flow.date.isAfter(draft.endDate ?? today)),
          )
          .toList(),
    );
  }

  void _preserveFlows(List<BleedingDayRecord> sources) {
    for (final source in sources) {
      _independentBleeding.putIfAbsent(
        source.date.epochDay,
        () => BleedingFactRecord(
          metadata: RecordFactMetadata(
            id:
                _flowSourceIds[source.date.epochDay] ??
                '${source.periodId}:${source.date.epochDay}',
            experiencedDate: source.date,
            recordedAt: source.createdAt,
            updatedAt: source.updatedAt,
            originalProvenance: HealthRecordProvenance.timingUnknown,
            provenance: HealthRecordProvenance.timingUnknown,
          ),
          value: BleedingFactDraft(
            experiencedDate: source.date,
            flow: source.flow,
            color: source.color,
          ),
        ),
      );
      _flowDays.remove(source);
    }
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
  Future<void> delete(String id) async {
    final index = _records.indexWhere((record) => record.id == id);
    if (index == -1) {
      throw const PeriodWriteException(PeriodWriteFailure.notFound);
    }
    _records.removeAt(index);
    _preserveFlows(_flowDays.where((flow) => flow.periodId == id).toList());
  }

  @override
  Future<List<BleedingDayRecord>> getAllFlowDays() async {
    return [..._flowDays]..sort((left, right) {
      final dateOrder = right.date.compareTo(left.date);
      return dateOrder != 0
          ? dateOrder
          : left.periodId.compareTo(right.periodId);
    });
  }

  @override
  Future<BleedingDayRecord> setFlow(
    String periodId,
    LocalDate date,
    BleedingFlow flow, {
    required LocalDate today,
  }) async {
    final period = _periodForFlow(periodId, date: date, today: today);
    _flowSourceIds.putIfAbsent(
      date.epochDay,
      () => '$periodId:${date.epochDay}',
    );
    final now = _clock().toUtc();
    final index = _flowDays.indexWhere(
      (record) => record.periodId == period.id && record.date == date,
    );
    final previous = index == -1 ? null : _flowDays[index];
    final promoted = _independentBleeding[date.epochDay];
    final updated = BleedingDayRecord(
      periodId: period.id,
      date: date,
      flow: flow,
      color: previous?.color ?? promoted?.value.color,
      createdAt: previous?.createdAt ?? promoted?.metadata.recordedAt ?? now,
      updatedAt: now,
    );
    _independentBleeding.remove(date.epochDay);
    if (index == -1) {
      _flowDays.add(updated);
    } else {
      _flowDays[index] = updated;
    }
    return updated;
  }

  @override
  Future<BleedingDayRecord> setBleedingColor(
    String periodId,
    LocalDate date,
    BleedingColor color,
  ) async {
    final index = _flowDays.indexWhere(
      (record) => record.periodId == periodId && record.date == date,
    );
    if (index == -1) {
      throw const PeriodWriteException(PeriodWriteFailure.flowRequiredForColor);
    }
    final previous = _flowDays[index];
    final updated = BleedingDayRecord(
      periodId: previous.periodId,
      date: previous.date,
      flow: previous.flow,
      color: color,
      createdAt: previous.createdAt,
      updatedAt: _clock().toUtc(),
    );
    _flowDays[index] = updated;
    return updated;
  }

  @override
  Future<void> clearBleedingColor(String periodId, LocalDate date) async {
    final index = _flowDays.indexWhere(
      (record) => record.periodId == periodId && record.date == date,
    );
    if (index == -1) return;
    final previous = _flowDays[index];
    _flowDays[index] = BleedingDayRecord(
      periodId: previous.periodId,
      date: previous.date,
      flow: previous.flow,
      createdAt: previous.createdAt,
      updatedAt: _clock().toUtc(),
    );
  }

  @override
  Future<void> clearFlow(String periodId, LocalDate date) async {
    if (_flowDays.any(
      (record) => record.periodId == periodId && record.date == date,
    )) {
      _flowSourceIds.remove(date.epochDay);
    }
    _flowDays.removeWhere(
      (record) => record.periodId == periodId && record.date == date,
    );
  }

  PeriodRecord _periodForFlow(
    String periodId, {
    required LocalDate date,
    required LocalDate today,
  }) {
    final period = _records
        .where((record) => record.id == periodId)
        .firstOrNull;
    if (period == null) {
      throw const PeriodWriteException(PeriodWriteFailure.flowPeriodNotFound);
    }
    if (date.isAfter(today)) {
      throw const PeriodWriteException(PeriodWriteFailure.flowDateInFuture);
    }
    final upperBound = period.endDate ?? today;
    if (date.isBefore(period.startDate) || date.isAfter(upperBound)) {
      throw const PeriodWriteException(
        PeriodWriteFailure.flowDateOutsidePeriod,
      );
    }
    return period;
  }

  @override
  Future<void> close() async {}

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
