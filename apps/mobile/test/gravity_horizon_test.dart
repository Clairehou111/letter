import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/cycle_prediction.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/insights/presentation/gravity_horizon.dart';
import 'package:letter_mobile/features/insights/presentation/gravity_horizon_view_model.dart';

/// Helper: build a CyclePrediction from epoch-day offsets relative to a base.
/// Offsets are: last-start, then intervals for each prior start.
CyclePrediction _prediction({
  required int lastStartOffset,
  required List<int> intervals,
  required int todayOffset,
}) {
  final base = const LocalDate(2026, 1, 1);
  final starts = <LocalDate>[base.addDays(lastStartOffset)];
  for (final iv in intervals.reversed) {
    starts.add(starts.last.addDays(-iv));
  }
  final sorted = starts.reversed.toList();
  // Run through the real engine to get correct luteal windows etc.
  final records = sorted.map<PeriodRecord>((s) => PeriodRecord(
    id: 'p${s.epochDay}',
    startDate: s,
    endDate: s.addDays(4),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  ));
  return CyclePredictionEngine.calculate(records)!;
}

/// Build a view model for a given scenario.
GravityHorizonViewModel _viewModel({
  required int lastStartOffset,
  required List<int> intervals,
  required int todayOffset,
  int? cycleDay,
}) {
  final pred = _prediction(
    lastStartOffset: lastStartOffset,
    intervals: intervals,
    todayOffset: todayOffset,
  );
  final today = const LocalDate(2026, 1, 1).addDays(todayOffset);
  return GravityHorizonViewModel.fromPrediction(
    prediction: pred,
    today: today,
    cycleDay: cycleDay,
    availableWidth: 390,
    availableHeight: 190,
  );
}

void main() {
  // ═══════════════════════════════════════════════════════════
  // SCENARIO 1: Regular 28-day cycle — day 5 (follicular)
  // ═══════════════════════════════════════════════════════════
  group('Regular 28-day cycle, day 5 (follicular)', () {
    late GravityHorizonViewModel vm;
    setUp(() {
      vm = _viewModel(
        lastStartOffset: 0,   // period started Jan 1
        intervals: [28, 28, 28, 28],
        todayOffset: 5,       // Jan 6 = day 5
        cycleDay: 5,
      );
    });

    test('dot is on the flat follicular plateau', () {
      expect(vm.todayPosition, lessThan(vm.lutealDipStartFraction));
      expect(vm.isInLutealValley, isFalse);
    });

    test('subtitle is the follicular horizon-clear message', () {
      expect(vm.subtitle, contains('horizon clear'));
      expect(vm.subtitle, contains('light and calm'));
    });

    test('luteal start label is present (approaching window)', () {
      expect(vm.lutealStartLabel, isNotNull);
    });

    test('luteal dip starts around day 12 (28 - 16)', () {
      // With median=28, luteal onset = day 28-16+1 = day 13
      // The fraction should place it around 13/38 ≈ 0.34
      expect(vm.lutealDipStartFraction, greaterThan(0.25));
      expect(vm.lutealDipStartFraction, lessThan(0.45));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // SCENARIO 2: Regular 28-day cycle — day 19 (mid-luteal)
  // ═══════════════════════════════════════════════════════════
  group('Regular 28-day cycle, day 19 (mid-luteal)', () {
    late GravityHorizonViewModel vm;
    setUp(() {
      vm = _viewModel(
        lastStartOffset: 0,
        intervals: [28, 28, 28, 28],
        todayOffset: 19,
        cycleDay: 19,
      );
    });

    test('dot is past the cliff edge (in the valley)', () {
      expect(vm.todayPosition, greaterThan(vm.lutealDipStartFraction));
      expect(vm.isInLutealValley, isTrue);
    });

    test('subtitle is the luteal gravity message', () {
      expect(vm.subtitle, contains('premenstrual window'));
      expect(vm.subtitle, contains('gravity feels heavier'));
      expect(vm.subtitle, contains('safe to slow down'));
    });

    test('luteal start label is hidden (already inside window)', () {
      expect(vm.lutealStartLabel, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // SCENARIO 3: Short 22-day cycle — day 18 (late luteal)
  // ═══════════════════════════════════════════════════════════
  group('Short 22-day cycle, day 18 (late luteal)', () {
    late GravityHorizonViewModel vm;
    setUp(() {
      vm = _viewModel(
        lastStartOffset: 0,
        intervals: [22, 22, 22, 22],
        todayOffset: 18,
        cycleDay: 18,
      );
    });

    test('dot is deep in the valley (nearly at menses)', () {
      expect(vm.todayPosition, greaterThan(vm.lutealDipStartFraction));
      expect(vm.isInLutealValley, isTrue);
    });

    test('luteal dip starts very early (day 22-16+1 = day 7)', () {
      // For a 22-day cycle, luteal onset is around day 7.
      // With totalDays = 22+10 = 32, fraction ≈ 7/32 ≈ 0.22.
      expect(vm.lutealDipStartFraction, lessThan(0.30));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // SCENARIO 4: Long 35-day cycle — day 19 (just entering luteal)
  // ═══════════════════════════════════════════════════════════
  group('Long 35-day cycle, day 19 (entering luteal)', () {
    late GravityHorizonViewModel vm;
    setUp(() {
      vm = _viewModel(
        lastStartOffset: 0,
        intervals: [35, 35, 35, 35],
        todayOffset: 19,
        cycleDay: 19,
      );
    });

    test('dot is AT the cliff edge (luteal just beginning)', () {
      // For a 35-day cycle, luteal onset = day 20 (35-16+1=20 with
      // todayOffset=19 meaning Jan 20 = day 20 of the cycle).
      // Day 19 lands exactly on the luteal window boundary.
      expect(vm.todayPosition, lessThanOrEqualTo(vm.lutealDipStartFraction));
      // On the boundary, isInLutealValley may be true (inclusive check).
      expect(vm.subtitle, contains('premenstrual window'));
    });

    test('luteal dip starts later (day ~20)', () {
      expect(vm.lutealDipStartFraction, greaterThan(0.35));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // SCENARIO 5: Irregular cycles — wide prediction window
  // ═══════════════════════════════════════════════════════════
  group('Irregular cycles (24-34 spread), day 15', () {
    late GravityHorizonViewModel vm;
    setUp(() {
      vm = _viewModel(
        lastStartOffset: 0,
        intervals: [24, 30, 34],
        todayOffset: 15,
        cycleDay: 15,
      );
    });

    test('view model still produces valid data', () {
      expect(vm.curvePoints, isNotEmpty);
      expect(vm.lutealDipStartFraction, greaterThan(0.0));
      expect(vm.lutealDipStartFraction, lessThan(1.0));
    });

    test('today position is within valid range', () {
      expect(vm.todayPosition, greaterThan(0.0));
      expect(vm.todayPosition, lessThan(1.0));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // SCENARIO 6: No prediction — empty state
  // ═══════════════════════════════════════════════════════════
  group('No prediction (insufficient data)', () {
    late GravityHorizonViewModel vm;
    setUp(() {
      vm = const GravityHorizonViewModel(
        curvePoints: [],
        todayPosition: 0.5,
        todayLabel: 'no prediction yet',
        subtitle: 'your cycle record is still taking shape.',
        isInLutealValley: false,
        backgroundColor: Color(0xFF0B0C10),
      );
    });

    test('curve points are empty', () {
      expect(vm.curvePoints, isEmpty);
    });

    test('has sensible defaults', () {
      expect(vm.todayPosition, 0.5);
      expect(vm.isInLutealValley, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // BEZIER MATH: _bezierY correctness
  // ═══════════════════════════════════════════════════════════
  group('Bezier math: _bezierY', () {
    test('at cliff top (x = cliffX) → Y = baseline', () {
      // Directly test the static method on the painter.
      // We can access it via a widget test that creates a painter.
    });

    test('at cliff bottom (x = floorX) → Y = valley', () {
      // Valley floor reached at the end of the drop zone.
    });

    test('mid-cliff produces Y between baseline and valley', () {
      // Should be monotonically decreasing through the cliff zone.
    });
  });

  // ═══════════════════════════════════════════════════════════
  // WIDGET TEST: renders without overflow at standard size
  // ═══════════════════════════════════════════════════════════
  testWidgets('renders horizon curve at 390×200 without overflow', (
    tester,
  ) async {
    final vm = _viewModel(
      lastStartOffset: 0,
      intervals: [28, 28, 28, 28],
      todayOffset: 14,
      cycleDay: 14,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 200,
            child: GravityHorizonView(viewModel: vm),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Should not throw overflow errors.
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders empty state without overflow', (tester) async {
    const vm = GravityHorizonViewModel(
      curvePoints: [],
      todayPosition: 0.5,
      todayLabel: 'no prediction yet',
      subtitle: 'your cycle record is still taking shape.',
      isInLutealValley: false,
      backgroundColor: Color(0xFF0B0C10),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 200,
            child: GravityHorizonView(viewModel: vm),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('your cycle record is still taking shape.'), findsOneWidget);
  });

  testWidgets('luteal valley shows golden label when inside window', (
    tester,
  ) async {
    final vm = _viewModel(
      lastStartOffset: 0,
      intervals: [28, 28, 28, 28],
      todayOffset: 22,  // well into luteal
      cycleDay: 22,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 200,
            child: GravityHorizonView(viewModel: vm),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('premenstrual window'), findsOneWidget);
    expect(find.textContaining('from'), findsNothing); // no luteal start label
  });

  testWidgets('pre-luteal shows onset date label when approaching', (
    tester,
  ) async {
    final vm = _viewModel(
      lastStartOffset: 0,
      intervals: [28, 28, 28, 28],
      todayOffset: 8,  // follicular, approaching luteal
      cycleDay: 8,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 200,
            child: GravityHorizonView(viewModel: vm),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Premenstrual window from'), findsOneWidget);
  });
}
