import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/clinical/presentation/twin_matrix_view_model.dart';
import 'package:letter_mobile/features/cycle/domain/cycle_prediction.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/insights/presentation/gravity_horizon_view_model.dart';
import 'package:letter_mobile/features/insights/presentation/spectrum_log_view_model.dart';
import 'package:letter_mobile/features/patterns/domain/pattern_source.dart';

void main() {
  group('algorithm audit: cycle prediction', () {
    test(
      'stable four-interval history produces the documented narrow range',
      () {
        final prediction = _predictionForIntervals([28, 28, 28, 28]);

        expect(prediction, isNotNull);
        expect(prediction!.medianCycleDays, 28);
        expect(
          _offset(prediction.midpoint, prediction.predictedMensesStart),
          -2,
        );
        expect(_offset(prediction.midpoint, prediction.predictedMensesEnd), 2);
        expect(prediction.confidence, PredictionConfidence.higher);
        expect(_inclusiveLutealBandDays(prediction), 16);
      },
    );

    test('minimum history widens the range and derived luteal band', () {
      final prediction = _predictionForIntervals([28, 28]);

      expect(prediction, isNotNull);
      expect(
        _offset(prediction!.midpoint, prediction.predictedMensesStart),
        -4,
      );
      expect(_offset(prediction.midpoint, prediction.predictedMensesEnd), 4);
      expect(prediction.confidence, PredictionConfidence.low);
      expect(_inclusiveLutealBandDays(prediction), 16);
    });

    test('skewed history drops the interval far from the recent baseline', () {
      final prediction = _predictionForIntervals([21, 45, 45]);

      expect(prediction, isNotNull);
      expect(prediction!.minimumCycleDays, 45);
      expect(prediction.maximumCycleDays, 45);
      expect(prediction.medianCycleDays, 45);
      expect(_offsetFromLatest(prediction.predictedMensesStart), 41);
      expect(_offsetFromLatest(prediction.predictedMensesEnd), 49);
      expect(prediction.confidence, PredictionConfidence.low);
      expect(_inclusiveLutealBandDays(prediction), 16);
    });

    test('approved exceptional-cycle fixture remains unchanged', () {
      final prediction = _predictionForIntervals([69, 34, 31]);

      expect(prediction, isNotNull);
      expect(prediction!.intervalCount, 2);
      expect(prediction.medianCycleDays, 33);
      expect(_offsetFromLatest(prediction.predictedMensesStart), 29);
      expect(_offsetFromLatest(prediction.predictedMensesEnd), 37);
      expect(prediction.confidence, PredictionConfidence.low);
    });
  });

  test('algorithm audit: Gravity is entirely date-driven', () {
    final model = GravityHorizonViewModel.fromRecords(
      records: _recordsForIntervals([28, 28, 28, 28]),
      today: _latestStart.addDays(20),
    );

    expect(model.estimatedGravityLevel(_latestStart), closeTo(0.42, 0.0001));
    expect(
      model.estimatedGravityLevel(model.prediction!.estimatedPremenstrualStart),
      closeTo(1, 0.0001),
    );
    expect(
      model.estimatedGravityLevel(model.prediction!.predictedMensesStart),
      closeTo(0.1, 0.0001),
    );
  });

  test('algorithm audit: Spectrum uses the cross-cycle typical level', () {
    final data = SpectrumLogAdapter.fromSource(
      PatternSourceSnapshot(
        healthRecords: [
          _healthRecord(
            id: 'cycle-a-mild',
            date: const LocalDate(2026, 8, 10),
            severity: SymptomSeverity.minimal,
          ),
          _healthRecord(
            id: 'cycle-b-extreme',
            date: const LocalDate(2026, 9, 10),
            severity: SymptomSeverity.extreme,
          ),
        ],
        periods: [
          _period('aug', const LocalDate(2026, 8, 20)),
          _period('sep', const LocalDate(2026, 9, 20)),
        ],
      ),
    );

    expect(data.daysFor(SymptomKey.physical)[-10], 3);
    expect(data.summariesFor(SymptomKey.physical)[-10]!.minimum, 1);
    expect(data.summariesFor(SymptomKey.physical)[-10]!.maximum, 5);
    expect(data.confirmedCountFor(SymptomKey.physical), 2);
    expect(data.cyclesCoveredFor(SymptomKey.physical), 2);
    expect(data.records.map((record) => record.id), [
      'cycle-a-mild',
      'cycle-b-extreme',
    ]);
  });

  test('algorithm audit: one Twin Matrix record can populate both halves', () {
    final model = TwinMatrixViewModel.fromObservations(
      observations: [
        _twinObservation(
          id: 'overlap',
          daysBeforeMenses: -14,
          cycleDay: 14,
          severity: SymptomSeverity.moderate,
        ),
      ],
      cycleLabel: 'overlap audit',
      exportTimestamp: '2026-08-10',
    );
    final physical = model.clusters.singleWhere(
      (cluster) => cluster.label == 'physical symptoms',
    );

    expect(model.mappedObservations, 1);
    expect(model.beforePeriodMapped, 1);
    expect(model.cycleMapped, 1);
    expect(
      physical.beforePeriodCells.first.evidence.single.recordId,
      'overlap',
    );
    expect(physical.cycleCells.last.evidence.single.recordId, 'overlap');
  });

  test('algorithm audit: Twin Matrix balances cycles before averaging', () {
    final model = TwinMatrixViewModel.fromObservations(
      observations: [
        _twinObservation(
          id: 'a-one',
          cycleKey: 'a',
          daysBeforeMenses: -3,
          severity: SymptomSeverity.extreme,
        ),
        _twinObservation(
          id: 'a-two',
          cycleKey: 'a',
          daysBeforeMenses: -3,
          severity: SymptomSeverity.minimal,
        ),
        _twinObservation(
          id: 'b-one',
          cycleKey: 'b',
          daysBeforeMenses: -3,
          severity: SymptomSeverity.minimal,
        ),
      ],
      cycleLabel: 'balance audit',
      exportTimestamp: '2026-08-10',
    );
    final cell = model.clusters
        .singleWhere((cluster) => cluster.label == 'physical symptoms')
        .beforePeriodCells[11];

    expect(cell.severity, 2); // mean(mean(5, 1), mean(1))
    expect(cell.observationCount, 3);
    expect(cell.cycleCount, 2);
  });
}

const _latestStart = LocalDate(2026, 7, 1);

CyclePrediction? _predictionForIntervals(List<int> intervals) =>
    CyclePredictionEngine.calculate(_recordsForIntervals(intervals));

List<PeriodRecord> _recordsForIntervals(List<int> intervals) {
  var start = _latestStart;
  final reverseStarts = <LocalDate>[start];
  for (final interval in intervals.reversed) {
    start = start.addDays(-interval);
    reverseStarts.add(start);
  }
  return [
    for (var index = 0; index < reverseStarts.length; index++)
      _period('period-$index', reverseStarts[index]),
  ];
}

int _offset(LocalDate origin, LocalDate target) =>
    target.epochDay - origin.epochDay;

int _offsetFromLatest(LocalDate target) => _offset(_latestStart, target);

int _inclusiveLutealBandDays(CyclePrediction prediction) =>
    prediction.predictedLutealEnd.epochDay -
    prediction.predictedLutealStart.epochDay +
    1;

PeriodRecord _period(String id, LocalDate start) => PeriodRecord(
  id: id,
  startDate: start,
  endDate: start.addDays(4),
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

HealthRecord _healthRecord({
  required String id,
  required LocalDate date,
  required SymptomSeverity severity,
}) => HealthRecord(
  id: id,
  symptom: SymptomType.headache,
  severity: severity,
  functionalImpacts: const {},
  experiencedDate: date,
  recordedAt: DateTime.utc(date.year, date.month, date.day, 12),
  updatedAt: DateTime.utc(date.year, date.month, date.day, 12),
  provenance: HealthRecordProvenance.sameDay,
  userConfirmed: true,
  vocabularyVersion: healthRecordVocabularyVersion,
);

TwinMatrixObservation _twinObservation({
  required String id,
  required int? daysBeforeMenses,
  int? cycleDay,
  String cycleKey = 'cycle-a',
  required SymptomSeverity severity,
}) => TwinMatrixObservation(
  recordId: id,
  experiencedDate: const LocalDate(2026, 7, 1),
  symptom: SymptomType.cramps,
  severity: severity,
  daysBeforeMenses: daysBeforeMenses,
  cycleDay: cycleDay,
  cycleKey: cycleKey,
  provenance: HealthRecordProvenance.sameDay,
  userConfirmed: true,
);
