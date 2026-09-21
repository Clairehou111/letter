import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/insights/presentation/gravity_horizon_view_model.dart';

PeriodRecord _period(String id, LocalDate start, {LocalDate? end}) =>
    PeriodRecord(
      id: id,
      startDate: start,
      endDate: end,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

GravityHorizonViewModel _vm({
  required LocalDate today,
  required Iterable<PeriodRecord> records,
}) => GravityHorizonViewModel.fromRecords(records: records, today: today);

List<PeriodRecord> _history(List<int> intervals) {
  var start = LocalDate(2026, 1, 1);
  final records = <PeriodRecord>[];
  for (var index = 0; index <= intervals.length; index += 1) {
    records.add(_period('period-$index', start, end: start.addDays(4)));
    if (index < intervals.length) start = start.addDays(intervals[index]);
  }
  return records;
}

void main() {
  group('Gravity Horizon geometry', () {
    test('no history uses a neutral window and never invents depth', () {
      final today = LocalDate(2026, 2, 10);
      final vm = _vm(today: today, records: const []);

      expect(vm.chartPrediction, isNull);
      expect(vm.chartWindow.start, today.addDays(-7));
      expect(vm.chartWindow.end, today.addDays(7));
      expect(vm.dateFraction(vm.chartWindow.start), 0);
      expect(vm.dateFraction(vm.chartWindow.end), 1);
      expect(vm.estimatedGravityLevel(today), isNull);
      expect(vm.isTodayInEstimatedPremenstrualWindow, isFalse);
    });

    test('one period has no prediction and a flat zero-depth chart', () {
      final start = LocalDate(2026, 2, 1);
      final vm = _vm(
        today: LocalDate(2026, 2, 10),
        records: [_period('one', start, end: start.addDays(4))],
      );

      expect(vm.chartPrediction, isNull);
      expect(vm.estimatedGravityLevel(start), isNull);
      expect(vm.estimatedGravityLevel(LocalDate(2026, 2, 10)), isNull);
      expect(vm.isTodayInEstimatedPremenstrualWindow, isFalse);
    });

    test('regular 28-day history exposes prediction and monotonic X', () {
      final vm = _vm(today: LocalDate(2026, 3, 1), records: _history([28, 28]));
      final prediction = vm.chartPrediction!;
      final window = vm.chartWindow;

      expect(prediction.medianCycleDays, 28);
      expect(prediction.predictedMensesStart, LocalDate(2026, 3, 22));
      expect(prediction.predictedMensesEnd, LocalDate(2026, 3, 30));
      expect(window.start, LocalDate(2026, 2, 22));
      expect(window.end, LocalDate(2026, 4, 3));
      expect(vm.dateFraction(window.start), 0);
      expect(vm.dateFraction(window.end), 1);
      expect(
        vm.dateFraction(LocalDate(2026, 3, 1)),
        lessThan(vm.dateFraction(LocalDate(2026, 3, 10))),
      );
      expect(
        vm.dateFraction(LocalDate(2026, 3, 10)),
        lessThan(vm.dateFraction(LocalDate(2026, 3, 30))),
      );
      expect(vm.isTodayInEstimatedPremenstrualWindow, isFalse);
    });

    test('short 22-day history keeps the prediction date-based', () {
      final vm = _vm(
        today: LocalDate(2026, 2, 15),
        records: _history([22, 22]),
      );

      expect(vm.chartPrediction, isNotNull);
      expect(vm.chartPrediction!.medianCycleDays, 22);
      expect(vm.chartPrediction!.predictedMensesStart, LocalDate(2026, 3, 4));
      expect(vm.chartPrediction!.predictedMensesEnd, LocalDate(2026, 3, 12));
    });

    test('long 35-day history keeps the prediction date-based', () {
      final vm = _vm(
        today: LocalDate(2026, 3, 13),
        records: _history([35, 35]),
      );

      expect(vm.chartPrediction, isNotNull);
      expect(vm.chartPrediction!.medianCycleDays, 35);
      expect(vm.chartPrediction!.predictedMensesStart, LocalDate(2026, 4, 12));
      expect(vm.chartPrediction!.predictedMensesEnd, LocalDate(2026, 4, 20));
    });

    test('irregular 24/30/34 history retains its median prediction', () {
      final vm = _vm(
        today: LocalDate(2026, 3, 31),
        records: _history([24, 30, 34]),
      );

      expect(vm.chartPrediction, isNotNull);
      expect(vm.chartPrediction!.medianCycleDays, 30);
      expect(vm.chartPrediction!.predictedMensesStart, LocalDate(2026, 4, 23));
      expect(vm.chartPrediction!.predictedMensesEnd, LocalDate(2026, 5, 3));
    });

    test(
      'short, long, and irregular histories use central pre-period timing',
      () {
        for (final intervals in <List<int>>[
          [22, 22],
          [35, 35],
          [24, 30, 34],
        ]) {
          final records = _history(intervals);
          final vm = _vm(
            today: records.last.startDate.addDays(1),
            records: records,
          );
          final prediction = vm.chartPrediction!;
          final start = prediction.estimatedPremenstrualStart;
          final end = prediction.predictedMensesStart;
          final firstQuarter = start.addDays(
            (end.epochDay - start.epochDay) ~/ 4,
          );
          final midpoint = start.addDays((end.epochDay - start.epochDay) ~/ 2);
          final lastQuarter = start.addDays(
            ((end.epochDay - start.epochDay) * 3) ~/ 4,
          );

          expect(vm.estimatedGravityLevel(start), closeTo(1, 0.001));
          expect(
            vm.estimatedGravityLevel(firstQuarter),
            greaterThan(vm.estimatedGravityLevel(midpoint)!),
          );
          expect(
            vm.estimatedGravityLevel(midpoint),
            greaterThan(vm.estimatedGravityLevel(lastQuarter)!),
          );
          expect(vm.estimatedGravityLevel(end), closeTo(0.1, 0.001));
        }
      },
    );

    test('gravity follows recovery, lighter, luteal, and range stages', () {
      final vm = _vm(today: LocalDate(2026, 3, 1), records: _history([28, 28]));
      final prediction = vm.chartPrediction!;
      final anchor = vm.lastPeriodStart!;
      final lutealMidpoint = prediction.estimatedPremenstrualStart.addDays(
        (prediction.predictedMensesStart.epochDay -
                prediction.estimatedPremenstrualStart.epochDay) ~/
            2,
      );

      expect(vm.estimatedGravityLevel(anchor.addDays(-4)), closeTo(0.1, 0.001));
      expect(vm.estimatedGravityLevel(anchor), closeTo(0.42, 0.001));
      expect(vm.estimatedGravityLevel(anchor.addDays(5)), closeTo(1, 0.001));
      expect(
        vm.estimatedGravityLevel(prediction.estimatedPremenstrualStart),
        closeTo(1, 0.001),
      );
      expect(
        vm.estimatedGravityLevel(lutealMidpoint),
        allOf(greaterThan(0.1), lessThan(1)),
      );
      expect(
        vm.estimatedGravityLevel(prediction.predictedLutealEnd),
        allOf(greaterThan(0.1), lessThan(1)),
      );
      expect(
        vm.estimatedGravityLevel(prediction.predictedMensesStart),
        closeTo(0.1, 0.001),
      );
      expect(
        vm.estimatedGravityLevel(prediction.predictedMensesEnd),
        closeTo(0.1, 0.001),
      );
    });

    test(
      'today is inside the estimated premenstrual window only when contained',
      () {
        final inside = _vm(
          today: LocalDate(2026, 3, 10),
          records: _history([28, 28]),
        );
        final outside = _vm(
          today: LocalDate(2026, 2, 10),
          records: _history([28, 28]),
        );

        expect(inside.isTodayInEstimatedPremenstrualWindow, isTrue);
        expect(outside.isTodayInEstimatedPremenstrualWindow, isFalse);
      },
    );

    test(
      'open period suppresses chartPrediction even with sufficient history',
      () {
        final history = _history([28, 28]);
        final openStart = LocalDate(2026, 2, 26);
        final vm = _vm(
          today: openStart,
          records: [...history, _period('open', openStart)],
        );

        expect(vm.prediction, isNotNull);
        expect(vm.chartPrediction, isNull);
        expect(vm.estimatedGravityLevel(openStart), isNull);
        expect(vm.isTodayInEstimatedPremenstrualWindow, isFalse);
      },
    );
  });
}
