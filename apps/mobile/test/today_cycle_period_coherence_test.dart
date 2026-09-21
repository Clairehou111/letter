import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/today/today_visual_port.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/check_in/data/in_memory_moment_check_in_repository.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/bleeding_flow.dart';
import 'package:letter_mobile/features/cycle/domain/cycle_prediction.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/cycle/domain/period_repository.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/today/today_cycle_context.dart';
import 'package:letter_mobile/features/today/today_cycle_ring_model.dart';

const _today = LocalDate(2026, 8, 15);
final _clock = DateTime.utc(2026, 8, 15, 12);

PeriodRecord _period(
  String id,
  LocalDate start, {
  int duration = 5,
  bool open = false,
}) => PeriodRecord(
  id: id,
  startDate: start,
  endDate: open ? null : start.addDays(duration - 1),
  createdAt: _clock,
  updatedAt: _clock,
);

InMemoryPeriodRepository _periods({Iterable<PeriodRecord> seed = const []}) =>
    InMemoryPeriodRepository(
      seed: seed,
      clock: () => _clock,
      idGenerator: () => 'new-period',
    );

RepositoryTodayVisualPort _port(InMemoryPeriodRepository periods) {
  return RepositoryTodayVisualPort(
    periodRepository: periods,
    checkInRepository: InMemoryMomentCheckInRepository(clock: () => _clock),
    healthRecordRepository: InMemoryHealthRecordRepository(clock: () => _clock),
    captureNoteStore: InMemoryCaptureNoteStore(),
    today: () => _today,
    now: () => _clock,
    onCycleDataChanged: () {},
    onOpenCare: () {},
  );
}

List<PeriodRecord> _regularHistory() => [
  _period('mar-1', const LocalDate(2026, 3, 1)),
  _period('mar-2', const LocalDate(2026, 3, 29)),
  _period('apr', const LocalDate(2026, 4, 26)),
  _period('may', const LocalDate(2026, 5, 24)),
  _period('jun', const LocalDate(2026, 6, 21)),
  _period('jul', const LocalDate(2026, 7, 19)),
];

void main() {
  test(
    'empty Today state has no current period or invented prediction',
    () async {
      final snapshot = await _port(_periods()).load();

      expect(snapshot.containingPeriod, isNull);
      expect(snapshot.openPeriod, isNull);
      expect(snapshot.flowRecord, isNull);
      expect(snapshot.cycleContext.kind, TodayCycleKind.noHistory);
      expect(snapshot.cycleContext.dayNumber, isNull);
      expect(snapshot.cycleContext.prediction, isNull);
    },
  );

  test('Today and Cycle use identical cycle facts and date window', () async {
    final periods = _periods(seed: _regularHistory());
    final snapshot = await _port(periods).load();
    final records = await periods.getAll();
    final ring = TodayCycleRingModel.fromRecords(
      records: records,
      today: _today,
    );
    final prediction = CyclePredictionEngine.calculate(records);

    expect(prediction, isNotNull);
    expect(snapshot.cycleContext.kind, TodayCycleKind.betweenPeriods);
    expect(snapshot.cycleContext.dayNumber, 28);
    expect(snapshot.cycleContext.prediction!.medianCycleDays, 28);
    expect(
      snapshot.cycleContext.prediction!.predictedMensesStart,
      const LocalDate(2026, 8, 14),
    );
    expect(
      snapshot.cycleContext.prediction!.predictedMensesEnd,
      const LocalDate(2026, 8, 18),
    );
    expect(ring.currentDay, snapshot.cycleContext.dayNumber);
    expect(
      ring.predictedPeriodStart,
      snapshot.cycleContext.prediction!.predictedMensesStart,
    );
    expect(
      ring.predictedPeriodEnd,
      snapshot.cycleContext.prediction!.predictedMensesEnd,
    );
  });

  test(
    'starting, closing, and deleting a new period refreshes both pages',
    () async {
      final periods = _periods(seed: _regularHistory());
      final port = _port(periods);

      final started = await port.startPeriod();
      final startedId = started.openPeriod!.id;
      expect(started.openPeriod, isNotNull);
      expect(started.containingPeriod!.startDate, _today);
      expect(started.cycleContext.kind, TodayCycleKind.periodInProgress);
      expect(started.cycleContext.dayNumber, 1);

      final ringAfterStart = TodayCycleRingModel.fromRecords(
        records: await periods.getAll(),
        today: _today,
      );
      expect(ringAfterStart.currentDay, 1);

      await port.setFlow(BleedingFlow.medium);
      expect((await port.load()).flowRecord!.flow, BleedingFlow.medium);

      final closed = await port.endOpenPeriodToday();
      expect(closed.openPeriod, isNull);
      expect(closed.containingPeriod, isNotNull);
      expect(closed.containingPeriod!.endDate, _today);
      expect(closed.cycleContext.kind, TodayCycleKind.periodInProgress);
      expect(closed.cycleContext.dayNumber, 1);

      await periods.delete(startedId);
      final afterDelete = await port.load();
      expect(afterDelete.containingPeriod, isNull);
      expect(afterDelete.openPeriod, isNull);
      expect(afterDelete.flowRecord, isNull);
      expect(afterDelete.cycleContext.dayNumber, 28);
    },
  );

  test('deleting a same-day record removes the overlap blocker', () async {
    final existing = _period('same-day', _today, duration: 1);
    final periods = _periods(seed: [existing]);
    final port = _port(periods);

    await expectLater(
      port.startPeriod(),
      throwsA(
        isA<PeriodWriteException>().having(
          (error) => error.failure,
          'failure',
          PeriodWriteFailure.overlap,
        ),
      ),
    );

    await periods.delete(existing.id);
    final replacement = await port.startPeriod();
    expect(replacement.openPeriod, isNotNull);
    expect(replacement.openPeriod!.startDate, _today);
  });

  test(
    'adding a new start refreshes prediction input and deleting it restores it',
    () async {
      final periods = _periods(seed: _regularHistory());
      final port = _port(periods);
      final before = await port.load();
      final beforePrediction = before.cycleContext.prediction!;
      final beforeRecords = await periods.getAll();
      expect(beforeRecords, hasLength(6));

      final afterStart = await port.startPeriod();
      final afterStartRecords = await periods.getAll();
      final afterStartPrediction = afterStart.cycleContext.prediction!;
      expect(afterStartRecords, hasLength(7));
      expect(afterStart.cycleContext.dayNumber, 1);
      expect(afterStartPrediction.intervalCount, 6);
      expect(afterStartPrediction.midpoint, _today.addDays(28));

      final newPeriod = afterStart.openPeriod!;
      await periods.delete(newPeriod.id);
      final restored = await port.load();
      expect(restored.cycleContext.dayNumber, 28);
      expect(
        restored.cycleContext.prediction!.midpoint,
        beforePrediction.midpoint,
      );
      expect(restored.openPeriod, isNull);
    },
  );

  test(
    'editing a cycle range removes out-of-range flow seen by Today',
    () async {
      final period = _period(
        'editable',
        const LocalDate(2026, 8, 10),
        duration: 6,
      );
      final periods = _periods(seed: [period]);
      await periods.setFlow(
        period.id,
        _today,
        BleedingFlow.heavy,
        today: _today,
      );

      final port = _port(periods);
      expect((await port.load()).flowRecord!.flow, BleedingFlow.heavy);

      await periods.update(
        period.id,
        const PeriodDraft(
          startDate: LocalDate(2026, 8, 10),
          endDate: LocalDate(2026, 8, 14),
        ),
        today: _today,
      );
      final afterEdit = await port.load();
      expect(afterEdit.containingPeriod, isNull);
      expect(afterEdit.flowRecord, isNull);
      expect(await periods.getAllFlowDays(), isEmpty);
    },
  );
}
