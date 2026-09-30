import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/comfort_window/domain/comfort_window.dart';
import 'package:letter_mobile/features/comfort_window/domain/comfort_window_engine.dart';
import 'package:letter_mobile/features/cycle/domain/cycle_prediction.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/patterns/domain/pattern_source.dart';

void main() {
  const engine = ComfortWindowEngine();

  test('finds one deterministic clearer window from four usable cycles', () {
    final fixture = _fixture(cycleCount: 4);
    final result = engine.calculate(
      source: fixture.source,
      periodPrediction: fixture.prediction,
      today: fixture.today,
    );

    expect(result, isNotNull);
    expect(result!.algorithmVersion, comfortWindowAlgorithmVersion);
    expect(result.confidence, ComfortWindowConfidence.clearer);
    expect(result.candidate.offsetStart, -5);
    expect(result.candidate.offsetEnd, -3);
    expect(result.candidate.votingCycleCount, 4);
    expect(result.candidate.supportingCycleCount, 4);
    expect(result.sourceCycleIds, hasLength(4));
    expect(
      result.candidate.cycles,
      everyElement(
        isA<ComfortWindowCycleEvidence>()
            .having((cycle) => cycle.observedInsideDays, 'inside coverage', 3)
            .having((cycle) => cycle.observedOutsideDays, 'outside coverage', 6)
            .having((cycle) => cycle.harderInsideDays, 'harder inside', 3)
            .having((cycle) => cycle.supports, 'supports', isTrue),
      ),
    );
    expect(
      result.forecastStart,
      fixture.prediction.predictedMensesStart.addDays(-5),
    );
    expect(
      result.forecastEnd,
      fixture.prediction.predictedMensesEnd.addDays(-3),
    );
  });

  test('labels two supporting cycles emerging and suppresses reminders', () {
    final fixture = _fixture(cycleCount: 2);
    final result = engine.calculate(
      source: fixture.source,
      periodPrediction: fixture.prediction,
      today: fixture.today,
    );

    expect(result?.confidence, ComfortWindowConfidence.emerging);
    expect(result?.canOfferReminder, isFalse);
  });

  test('requires nine observations and three non-hard comparison days', () {
    final fixture = _fixture(cycleCount: 3, outsideOffsets: const [-14, -13]);
    final result = engine.calculate(
      source: fixture.source,
      periodPrediction: fixture.prediction,
      today: fixture.today,
    );

    expect(result, isNull);
  });

  test('difficult mood wins over a positive mood on the same day', () {
    final fixture = _fixture(
      cycleCount: 3,
      extraStatesByOffset: const {
        -8: [MomentCheckInState.good, MomentCheckInState.irritable],
      },
    );
    final classifications = engine.classifyObservedDays(fixture.source);
    final testedDate = fixture.source.periods[1].startDate.addDays(-8);

    expect(classifications[testedDate], ObservedDayClassification.harder);
  });

  test('does not use observations in the current unfinished cycle', () {
    final fixture = _fixture(cycleCount: 1, addCurrentCyclePattern: true);
    final result = engine.calculate(
      source: fixture.source,
      periodPrediction: fixture.prediction,
      today: fixture.today,
    );

    expect(result, isNull);
  });

  test('low cycle confidence and wide composed ranges suppress reminders', () {
    final fixture = _fixture(cycleCount: 4);
    final low = engine.calculate(
      source: fixture.source,
      periodPrediction: _prediction(
        start: fixture.prediction.predictedMensesStart,
        end: fixture.prediction.predictedMensesEnd,
        confidence: PredictionConfidence.low,
      ),
      today: fixture.today,
    );
    final wide = engine.calculate(
      source: fixture.source,
      periodPrediction: _prediction(
        start: fixture.prediction.predictedMensesStart,
        end: fixture.prediction.predictedMensesStart.addDays(8),
        confidence: PredictionConfidence.medium,
      ),
      today: fixture.today,
    );

    expect(low?.canOfferReminder, isFalse);
    expect(wide?.canOfferReminder, isFalse);
  });

  test('preparation visibility begins two days before forecast', () {
    final fixture = _fixture(cycleCount: 4);
    final result = engine.calculate(
      source: fixture.source,
      periodPrediction: fixture.prediction,
      today: fixture.today,
    )!;

    expect(
      result.isPreparationVisibleOn(result.forecastStart.addDays(-3)),
      isFalse,
    );
    expect(
      result.isPreparationVisibleOn(result.forecastStart.addDays(-2)),
      isTrue,
    );
    expect(result.isPreparationVisibleOn(result.forecastEnd), isTrue);
    expect(
      result.isPreparationVisibleOn(result.forecastEnd.addDays(1)),
      isFalse,
    );
  });

  test('uses only the six most recent completed cycles', () {
    final fixture = _fixture(cycleCount: 7);
    final result = engine.calculate(
      source: fixture.source,
      periodPrediction: fixture.prediction,
      today: fixture.today,
    );

    expect(result, isNotNull);
    expect(result!.sourceCycleIds, <String>[
      'period-1',
      'period-2',
      'period-3',
      'period-4',
      'period-5',
      'period-6',
    ]);
  });

  test('record edits and deletions recompute without cached evidence', () {
    final fixture = _fixture(cycleCount: 4);
    expect(
      engine.calculate(
        source: fixture.source,
        periodPrediction: fixture.prediction,
        today: fixture.today,
      ),
      isNotNull,
    );

    final edited = PatternSourceSnapshot(
      periods: fixture.source.periods,
      momentCheckIns: <MomentCheckIn>[
        for (final checkIn in fixture.source.momentCheckIns)
          MomentCheckIn(
            id: checkIn.id,
            state: checkIn.state == MomentCheckInState.irritable
                ? MomentCheckInState.steady
                : checkIn.state,
            occurredAt: checkIn.occurredAt,
            createdAt: checkIn.createdAt,
          ),
      ],
    );
    final deleted = PatternSourceSnapshot(
      periods: fixture.source.periods,
      momentCheckIns: fixture.source.momentCheckIns
          .where((checkIn) => checkIn.state != MomentCheckInState.irritable)
          .toList(growable: false),
    );

    expect(
      engine.calculate(
        source: edited,
        periodPrediction: fixture.prediction,
        today: fixture.today,
      ),
      isNull,
    );
    expect(
      engine.calculate(
        source: deleted,
        periodPrediction: fixture.prediction,
        today: fixture.today,
      ),
      isNull,
    );
  });
}

final class _Fixture {
  const _Fixture({
    required this.source,
    required this.prediction,
    required this.today,
  });

  final PatternSourceSnapshot source;
  final CyclePrediction prediction;
  final LocalDate today;
}

_Fixture _fixture({
  required int cycleCount,
  // Comparison evidence belongs to the same completed cycle and therefore
  // stays before its next period start. A positive offset would already be
  // part of the current, unfinished cycle and must not train the forecast.
  List<int> outsideOffsets = const [-14, -12, -10, -8, -2, -1],
  Map<int, List<MomentCheckInState>> extraStatesByOffset = const {},
  bool addCurrentCyclePattern = false,
}) {
  const first = LocalDate(2026, 1, 1);
  final periods = <PeriodRecord>[];
  for (var index = 0; index <= cycleCount; index++) {
    final start = first.addDays(index * 30);
    periods.add(
      PeriodRecord(
        id: 'period-$index',
        startDate: start,
        endDate: start.addDays(4),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
  }
  final checkIns = <MomentCheckIn>[];
  var id = 0;
  for (var index = 0; index < cycleCount; index++) {
    final anchor = periods[index + 1].startDate;
    for (final offset in const [-5, -4, -3]) {
      checkIns.add(
        _checkIn(
          'check-${id++}',
          anchor.addDays(offset),
          MomentCheckInState.irritable,
        ),
      );
    }
    for (final offset in outsideOffsets) {
      checkIns.add(
        _checkIn(
          'check-${id++}',
          anchor.addDays(offset),
          MomentCheckInState.steady,
        ),
      );
    }
    for (final entry in extraStatesByOffset.entries) {
      for (final state in entry.value) {
        checkIns.add(
          _checkIn('check-${id++}', anchor.addDays(entry.key), state),
        );
      }
    }
  }
  if (addCurrentCyclePattern) {
    final currentStart = periods.last.startDate;
    for (final offset in const [16, 17, 18]) {
      checkIns.add(
        _checkIn(
          'check-${id++}',
          currentStart.addDays(offset),
          MomentCheckInState.irritable,
        ),
      );
    }
  }
  final today = periods.last.startDate.addDays(20);
  final predictedStart = periods.last.startDate.addDays(30);
  return _Fixture(
    source: PatternSourceSnapshot(periods: periods, momentCheckIns: checkIns),
    prediction: _prediction(
      start: predictedStart,
      end: predictedStart.addDays(2),
      confidence: PredictionConfidence.higher,
    ),
    today: today,
  );
}

MomentCheckIn _checkIn(String id, LocalDate date, MomentCheckInState state) =>
    MomentCheckIn(
      id: id,
      state: state,
      occurredAt: DateTime(date.year, date.month, date.day, 12),
      createdAt: DateTime(date.year, date.month, date.day, 12),
    );

CyclePrediction _prediction({
  required LocalDate start,
  required LocalDate end,
  required PredictionConfidence confidence,
}) => CyclePrediction(
  predictedMensesStart: start,
  predictedMensesEnd: end,
  midpoint: start.addDays((end.epochDay - start.epochDay) ~/ 2),
  medianCycleDays: 30,
  minimumCycleDays: 29,
  maximumCycleDays: 31,
  intervalCount: 4,
  confidence: confidence,
  predictedLutealStart: start.addDays(-16),
  predictedLutealEnd: end.addDays(-12),
);
