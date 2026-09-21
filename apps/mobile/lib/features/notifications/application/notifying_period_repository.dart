import '../../cycle/domain/bleeding_flow.dart';
import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_record.dart';
import '../../cycle/domain/period_repository.dart';

final class NotifyingPeriodRepository implements PeriodRepository {
  NotifyingPeriodRepository(this._delegate, this._onPeriodChanged);

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
