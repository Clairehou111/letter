import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/cycle_prediction.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/insights/presentation/gravity_horizon.dart';
import 'package:letter_mobile/features/insights/presentation/gravity_horizon_view_model.dart';

PeriodRecord _period(String id, LocalDate start, {LocalDate? end}) {
  return PeriodRecord(
    id: id,
    startDate: start,
    endDate: end,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

GravityHorizonViewModel _viewModel({
  required LocalDate today,
  required Iterable<PeriodRecord> records,
}) {
  return GravityHorizonViewModel.fromRecords(records: records, today: today);
}

final _may22 = LocalDate(2026, 5, 22);
final _jun20 = LocalDate(2026, 6, 20);
final _jul19 = LocalDate(2026, 7, 19);

List<PeriodRecord> _predictionHistory() => [
  _period('may-22', _may22, end: _may22.addDays(4)),
  _period('jun-20', _jun20, end: _jun20.addDays(4)),
  _period('jul-19', _jul19, end: _jul19.addDays(4)),
];

Widget _harness(
  GravityHorizonViewModel viewModel, {
  VoidCallback? onOpenCycle,
  double width = 390,
  double textScale = 1,
}) {
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: width,
            child: GravityHorizonView(
              viewModel: viewModel,
              onOpenCycle: onOpenCycle ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Gravity Horizon production adapter states', () {
    test('no history on 2026-08-05', () {
      final vm = _viewModel(today: LocalDate(2026, 8, 5), records: const []);

      expect(vm.stateId, HorizonStateId.noHistory);
      expect(vm.hasHistory, isFalse);
      expect(vm.prediction, isNull);
      expect(vm.cycleDay, isNull);
      expect(vm.lastObservedDate, isNull);
    });

    test('one Jul19-23 record is insufficient and today is cycle day 18', () {
      final vm = _viewModel(
        today: LocalDate(2026, 8, 5),
        records: [_period('jul-19', _jul19, end: _jul19.addDays(4))],
      );

      expect(vm.stateId, HorizonStateId.insufficientHistory);
      expect(vm.prediction, isNull);
      expect(vm.cycleDay, 18);
      expect(vm.lastObservedDate, LocalDate(2026, 7, 23));
    });

    test('May22, Jun20, Jul19 predicts Aug13-21 with low confidence', () {
      final vm = _viewModel(
        today: LocalDate(2026, 8, 5),
        records: _predictionHistory(),
      );
      final prediction = vm.prediction;

      expect(vm.stateId, HorizonStateId.predictionAvailable);
      expect(prediction, isNotNull);
      expect(prediction!.predictedMensesStart, LocalDate(2026, 8, 13));
      expect(prediction.predictedMensesEnd, LocalDate(2026, 8, 21));
      expect(prediction.midpoint, LocalDate(2026, 8, 17));
      expect(prediction.confidence, PredictionConfidence.low);
      expect(prediction.intervalCount, 2);
      expect(vm.estimatedRangeWidthDays, 9);
      expect(vm.cycleDay, 18);
    });

    test('open Aug16 record on Aug18 is an active period, day 3', () {
      final start = LocalDate(2026, 8, 16);
      final vm = _viewModel(
        today: LocalDate(2026, 8, 18),
        records: [_period('aug-16-open', start)],
      );

      expect(vm.stateId, HorizonStateId.periodInProgress);
      expect(vm.openPeriod?.id, 'aug-16-open');
      expect(vm.recordedPeriodDay, 3);
      expect(vm.cycleDay, 3);
      expect(vm.prediction, isNull);
    });

    test('Aug23 is two days past the Aug13-21 estimated range', () {
      final vm = _viewModel(
        today: LocalDate(2026, 8, 23),
        records: _predictionHistory(),
      );
      final prediction = vm.prediction!;

      expect(vm.stateId, HorizonStateId.pastEstimatedRange);
      expect(
        prediction.timingFor(vm.today),
        PredictionTiming.laterThanEstimate,
      );
      expect(vm.today.epochDay - prediction.predictedMensesEnd.epochDay, 2);
    });
  });

  group('Gravity Horizon factual presentation', () {
    testWidgets('renders state status and evidence copy', (tester) async {
      final vm = _viewModel(
        today: LocalDate(2026, 8, 23),
        records: _predictionHistory(),
      );
      await tester.pumpWidget(_harness(vm));

      expect(find.text('GRAVITY HORIZON · ESTIMATED'), findsOneWidget);
      expect(
        find.textContaining('2 days later than the estimated range.'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'This is a date comparison, not a health conclusion.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Low confidence'), findsOneWidget);
      expect(find.textContaining('Estimated range width'), findsNothing);
      expect(find.textContaining('Recorded cycle lengths'), findsNothing);
      expect(find.text(GravityHorizonView.disclosure), findsOneWidget);
      expect(find.textContaining('cosmic'), findsNothing);
      expect(find.textContaining('estimated cycle gravity'), findsWidgets);
      expect(find.textContaining('hormone'), findsNothing);
    });

    testWidgets('open period uses active factual status and evidence', (
      tester,
    ) async {
      final start = LocalDate(2026, 8, 16);
      final vm = _viewModel(
        today: LocalDate(2026, 8, 18),
        records: [_period('aug-16-open', start)],
      );
      await tester.pumpWidget(_harness(vm));

      expect(
        find.textContaining('Period day 3 · 3 bleeding days recorded'),
        findsOneWidget,
      );
      expect(find.textContaining('Started Aug 16'), findsOneWidget);
      expect(find.textContaining('Confidence:'), findsNothing);
      expect(
        find.text('Not enough recorded periods to estimate a range yet.'),
        findsNothing,
      );
    });

    testWidgets('shows cycle day inside the estimated premenstrual window', (
      tester,
    ) async {
      final vm = _viewModel(
        today: LocalDate(2026, 8, 5),
        records: _predictionHistory(),
      );
      await tester.pumpWidget(_harness(vm));

      expect(
        find.text('Cycle day 18 · in the estimated premenstrual window.'),
        findsOneWidget,
      );
      expect(find.text('Estimated next period: Aug 13–21.'), findsOneWidget);
    });

    testWidgets('distinguishes the estimated period range from the window', (
      tester,
    ) async {
      final vm = _viewModel(
        today: LocalDate(2026, 8, 15),
        records: _predictionHistory(),
      );
      await tester.pumpWidget(_harness(vm));

      expect(
        find.text('Cycle day 28 · inside the estimated period range.'),
        findsOneWidget,
      );
      expect(
        find.text('Aug 13–21 was calculated from your recorded period starts.'),
        findsOneWidget,
      );
    });

    testWidgets('chart and Open Cycle both invoke the navigation callback', (
      tester,
    ) async {
      var taps = 0;
      final vm = _viewModel(
        today: LocalDate(2026, 8, 5),
        records: _predictionHistory(),
      );
      await tester.pumpWidget(_harness(vm, onOpenCycle: () => taps++));

      await tester.tap(find.byKey(const Key('today-gravity-horizon')));
      await tester.ensureVisible(find.byKey(const Key('today-open-cycle')));
      await tester.tap(find.byKey(const Key('today-open-cycle')));

      expect(taps, 2);
    });

    testWidgets('chart exposes an accessible factual summary', (tester) async {
      final vm = _viewModel(
        today: LocalDate(2026, 8, 5),
        records: _predictionHistory(),
      );
      await tester.pumpWidget(_harness(vm));

      final semantics = tester.getSemantics(
        find.byKey(const Key('today-gravity-horizon')),
      );
      expect(semantics.label, contains('Gravity Horizon chart'));
      expect(semantics.label, contains('Estimated range'));
      expect(semantics.label, contains('lighter estimated cycle gravity'));
      expect(semantics.label, contains('heavier estimated cycle gravity'));
      expect(semantics.label, contains('Double tap to open Cycle'));
    });
  });

  testWidgets('320px wide at 200% text has no overflow', (tester) async {
    final vm = _viewModel(
      today: LocalDate(2026, 8, 5),
      records: _predictionHistory(),
    );
    await tester.pumpWidget(_harness(vm, width: 320, textScale: 2));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('today-open-cycle')), findsOneWidget);
  });
}
