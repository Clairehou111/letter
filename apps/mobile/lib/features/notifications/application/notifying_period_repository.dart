import '../../cycle/domain/bleeding_flow.dart';
import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_record.dart';
import '../../cycle/domain/period_repository.dart';
import '../../cycle/domain/period_validation.dart';

final class NotifyingPeriodRepository implements ConfirmablePeriodRepository {
  NotifyingPeriodRepository(this._delegate, this._onPeriodChanged);

  int _reviewSequence = 0;
  final Map<String, ({PeriodWritePreview preview, List<PeriodRecord> sources})>
  _fallbackReviews = {};

  @override
  Future<PeriodWritePreview> previewWrite(
    PeriodDraft draft, {
    required LocalDate today,
    String? editingId,
  }) async {
    final delegate = _delegate;
    if (delegate is ConfirmablePeriodRepository) {
      return delegate.previewWrite(draft, today: today, editingId: editingId);
    }
    final sources = List<PeriodRecord>.of(await delegate.getAll());
    validatePeriodDraft(
      draft: draft,
      today: today,
      existing: sources,
      editingId: editingId,
    );
    final preview = PeriodWritePreview(
      reviewToken: 'adapter-review-${_reviewSequence++}',
      draft: draft,
      editingId: editingId,
      adjacentPeriods: adjacentPeriodsForDraft(
        draft: draft,
        today: today,
        existing: sources,
        editingId: editingId,
      ),
    );
    _fallbackReviews[preview.reviewToken] = (
      preview: preview,
      sources: sources,
    );
    return preview;
  }

  @override
  Future<PeriodRecord> confirmWrite(
    PeriodWritePreview preview, {
    required LocalDate today,
  }) async {
    final delegate = _delegate;
    PeriodRecord record;
    if (delegate is ConfirmablePeriodRepository) {
      record = await delegate.confirmWrite(preview, today: today);
    } else {
      final cached = _fallbackReviews.remove(preview.reviewToken);
      final sources = List<PeriodRecord>.of(await delegate.getAll());
      if (cached == null ||
          !identical(cached.preview, preview) ||
          sources.length != cached.sources.length ||
          sources.any(
            (source) => !cached.sources.any(
              (old) =>
                  old.id == source.id &&
                  old.startDate == source.startDate &&
                  old.endDate == source.endDate &&
                  old.updatedAt == source.updatedAt,
            ),
          )) {
        throw const PeriodWriteException(PeriodWriteFailure.staleConfirmation);
      }
      record = preview.editingId == null
          ? await delegate.create(preview.draft, today: today)
          : await delegate.update(
              preview.editingId!,
              preview.draft,
              today: today,
            );
    }
    await _notifyWithoutBreakingTheWrite();
    return record;
  }

  final PeriodRepository _delegate;
  final Future<void> Function() _onPeriodChanged;

  Future<void> _notifyWithoutBreakingTheWrite() async {
    try {
      await _onPeriodChanged();
    } on Object {
      // A reminder is optional; cycle data must remain successfully saved.
    }
  }

  @override
  Future<PeriodRecord> create(
    PeriodDraft draft, {
    required LocalDate today,
  }) async {
    final record = await _delegate.create(draft, today: today);
    await _notifyWithoutBreakingTheWrite();
    return record;
  }

  @override
  Future<PeriodRecord> update(
    String id,
    PeriodDraft draft, {
    required LocalDate today,
  }) async {
    final record = await _delegate.update(id, draft, today: today);
    await _notifyWithoutBreakingTheWrite();
    return record;
  }

  @override
  Future<void> delete(String id) async {
    await _delegate.delete(id);
    await _notifyWithoutBreakingTheWrite();
  }

  @override
  Future<void> clearFlow(String periodId, LocalDate date) =>
      _delegate.clearFlow(periodId, date);

  @override
  Future<void> clearBleedingColor(String periodId, LocalDate date) =>
      _delegate.clearBleedingColor(periodId, date);

  @override
  Future<void> close() => _delegate.close();

  @override
  Future<List<PeriodRecord>> getAll() => _delegate.getAll();

  @override
  Future<List<BleedingDayRecord>> getAllFlowDays() =>
      _delegate.getAllFlowDays();

  @override
  Future<BleedingDayRecord> setFlow(
    String periodId,
    LocalDate date,
    BleedingFlow flow, {
    required LocalDate today,
  }) => _delegate.setFlow(periodId, date, flow, today: today);

  @override
  Future<BleedingDayRecord> setBleedingColor(
    String periodId,
    LocalDate date,
    BleedingColor color,
  ) => _delegate.setBleedingColor(periodId, date, color);
}
