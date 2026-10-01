import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/cycle/cycle_experience.dart';
import 'package:letter_mobile/experience/cycle/cycle_estimate_copy.dart';
import 'package:letter_mobile/experience/today/today_cycle_ring.dart';
import 'package:letter_mobile/experience/today/today_experience_visual_baseline.dart';
import 'package:letter_mobile/experience/today/today_visual_port.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/check_in/data/in_memory_moment_check_in_repository.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/cycle_prediction.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/cycle/domain/period_repository.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/today/today_cycle_context.dart';
import 'package:letter_mobile/features/today/today_cycle_ring_model.dart';

// Expected dates were separately calculated with Python datetime from
// synthetic start dates and the release policy recorded in the spec.
const today = LocalDate(2026, 10, 1);
final now = DateTime.utc(2026, 10, 1, 12);

PeriodRecord period(String id, LocalDate start, {LocalDate? end}) =>
    PeriodRecord(
      id: id,
      startDate: start,
      endDate: end,
      createdAt: now,
      updatedAt: now,
    );

List<PeriodRecord> regular() => [
  period(
    'july',
    const LocalDate(2026, 7, 6),
    end: const LocalDate(2026, 7, 10),
  ),
  period(
    'august',
    const LocalDate(2026, 8, 3),
    end: const LocalDate(2026, 8, 7),
  ),
  period(
    'latest',
    const LocalDate(2026, 8, 31),
    end: const LocalDate(2026, 9, 4),
  ),
];

void expectBoth(
  List<PeriodRecord> records,
  LocalDate date,
  int? day,
  LocalDate? start,
  LocalDate? end,
) {
  final context = TodayCycleContext.fromRecords(records: records, today: date);
  expect(context.dayNumber, day);
  expect(context.prediction?.predictedMensesStart, start);
  expect(context.prediction?.predictedMensesEnd, end);
  if (start == null) {
    expect(
      () => TodayCycleRingModel.fromRecords(records: records, today: date),
      throwsA(isA<TodayCycleRingException>()),
    );
    return;
  }
  final ring = TodayCycleRingModel.fromRecords(records: records, today: date);
  expect(ring.currentDay, day);
  expect(ring.predictedPeriodStart, start);
  expect(ring.predictedPeriodEnd, end);
  expect(ring.segments.where((s) => s.containsDay(day!)), hasLength(1));
  expect(
    ring.segmentFor(CycleRingPhase.period)!.certainty,
    CycleRingCertainty.observed,
  );
  expect(
    ring.segments
        .skip(1)
        .every((s) => s.certainty == CycleRingCertainty.estimated),
    isTrue,
  );
}

void expectRingParts(
  List<PeriodRecord> records,
  LocalDate date, {
  required int periodEnd,
  required int ovulationStart,
  required int ovulationEnd,
  required int displayEnd,
  required CycleRingPhase todayPhase,
}) {
  final ring = TodayCycleRingModel.fromRecords(records: records, today: date);
  expect(ring.displayCycleDays, displayEnd);
  expect(ring.currentPhase, todayPhase);
  expect(
    ring.segments.map((s) => (s.phase, s.startDay, s.endDay, s.certainty)),
    [
      (CycleRingPhase.period, 1, periodEnd, CycleRingCertainty.observed),
      (
        CycleRingPhase.follicular,
        periodEnd + 1,
        ovulationStart - 1,
        CycleRingCertainty.estimated,
      ),
      (
        CycleRingPhase.estimatedOvulation,
        ovulationStart,
        ovulationEnd,
        CycleRingCertainty.estimated,
      ),
      (
        CycleRingPhase.luteal,
        ovulationEnd + 1,
        displayEnd,
        CycleRingCertainty.estimated,
      ),
    ],
  );
}

void main() {
  test('no history and one start retain factual context without estimate', () {
    expectBoth([], today, null, null, null);
    expect(
      TodayCycleContext.fromRecords(records: [], today: today).kind,
      TodayCycleKind.noHistory,
    );
    final one = [period('one', const LocalDate(2026, 9, 20))];
    expectBoth(one, today, 12, null, null);
    expect(
      TodayCycleContext.fromRecords(records: one, today: today).kind,
      TodayCycleKind.periodInProgress,
    );
  });

  test('two starts yield only a clearly early visual estimate', () {
    final records = [
      period(
        'a',
        const LocalDate(2026, 8, 1),
        end: const LocalDate(2026, 8, 5),
      ),
      period(
        'b',
        const LocalDate(2026, 8, 29),
        end: const LocalDate(2026, 9, 2),
      ),
    ];
    expectBoth(
      records,
      today,
      34,
      const LocalDate(2026, 9, 19),
      const LocalDate(2026, 10, 3),
    );
    expect(CyclePredictionEngine.calculate(records), isNull);
    expectRingParts(
      records,
      today,
      periodEnd: 5,
      ovulationStart: 13,
      ovulationEnd: 15,
      displayEnd: 34,
      todayPhase: CycleRingPhase.luteal,
    );
    final prediction = TodayCycleContext.fromRecords(
      records: records,
      today: today,
    ).prediction!;
    expect(prediction.isEarlyEstimate, isTrue);
    expect(
      TodayCycleRing.describeModel(
        TodayCycleRingModel.fromRecords(records: records, today: today),
      ),
      allOf(
        contains('Period days 1 to 5'),
        contains('early estimate from one observed interval'),
      ),
    );
    expect(
      cycleEstimateContextLabel(prediction, today),
      'early estimate from one observed interval · estimate window is current',
    );
  });

  test(
    'regular cycle ring locates today and distinguishes observed segments',
    () {
      expectBoth(
        regular(),
        today,
        32,
        const LocalDate(2026, 9, 24),
        const LocalDate(2026, 10, 2),
      );
      final ring = TodayCycleRingModel.fromRecords(
        records: regular(),
        today: today,
      );
      expect(ring.displayCycleDays, 32);
      expectRingParts(
        regular(),
        today,
        periodEnd: 5,
        ovulationStart: 13,
        ovulationEnd: 15,
        displayEnd: 32,
        todayPhase: CycleRingPhase.luteal,
      );
      expect(ring.typicalCycleDays, 28);
      expect(ring.currentPhase, CycleRingPhase.luteal);
      expect(ring.segmentFor(CycleRingPhase.period)!.endDay, 5);
      expect(ring.segmentFor(CycleRingPhase.follicular)!.startDay, 6);
      expect(ring.segmentFor(CycleRingPhase.follicular)!.endDay, 12);
      expect(ring.segmentFor(CycleRingPhase.estimatedOvulation)!.startDay, 13);
      expect(ring.segmentFor(CycleRingPhase.estimatedOvulation)!.endDay, 15);
      expect(ring.segmentFor(CycleRingPhase.luteal)!.startDay, 16);
      expect(TodayCycleRing.describeModel(ring), contains('Day 32'));
      expect(
        TodayCycleRing.describeModel(ring),
        contains('Luteal phase, estimated'),
      );
      expect(
        TodayCycleRing.describeModel(ring),
        contains('Observed on the ring: Period'),
      );
    },
  );

  test('variable history widens the range asymmetrically', () {
    final records = [
      period(
        'a',
        const LocalDate(2026, 6, 1),
        end: const LocalDate(2026, 6, 5),
      ),
      period(
        'b',
        const LocalDate(2026, 6, 29),
        end: const LocalDate(2026, 7, 3),
      ),
      period(
        'c',
        const LocalDate(2026, 7, 23),
        end: const LocalDate(2026, 7, 27),
      ),
      period(
        'd',
        const LocalDate(2026, 8, 30),
        end: const LocalDate(2026, 9, 3),
      ),
    ];
    expectBoth(
      records,
      today,
      33,
      const LocalDate(2026, 9, 23),
      const LocalDate(2026, 10, 7),
    );
    final prediction = TodayCycleContext.fromRecords(
      records: records,
      today: today,
    ).prediction!;
    expect(prediction.confidence, PredictionConfidence.low);
    expect(
      TodayCycleRing.describeModel(
        TodayCycleRingModel.fromRecords(records: records, today: today),
      ),
      contains('Recorded cycles vary; this estimate is wider.'),
    );
    expectRingParts(
      records,
      today,
      periodEnd: 5,
      ovulationStart: 13,
      ovulationEnd: 15,
      displayEnd: 33,
      todayPhase: CycleRingPhase.luteal,
    );
    expect(
      cycleEstimateContextLabel(prediction, today),
      'recorded cycles vary; wider estimate · estimate window is current',
    );
  });

  test(
    'open and ended-today bleeding both occupy an observed ring segment',
    () {
      final prior = [
        period(
          'a',
          const LocalDate(2026, 8, 3),
          end: const LocalDate(2026, 8, 7),
        ),
        period(
          'b',
          const LocalDate(2026, 8, 31),
          end: const LocalDate(2026, 9, 4),
        ),
      ];
      for (final end in <LocalDate?>[null, today]) {
        final records = [
          ...prior,
          period('current', const LocalDate(2026, 9, 29), end: end),
        ];
        expectBoth(
          records,
          today,
          3,
          const LocalDate(2026, 10, 24),
          const LocalDate(2026, 11, 1),
        );
        expect(
          TodayCycleContext.fromRecords(records: records, today: today).kind,
          TodayCycleKind.periodInProgress,
        );
        final ring = TodayCycleRingModel.fromRecords(
          records: records,
          today: today,
        );
        expect(ring.currentPhase, CycleRingPhase.period);
        expectRingParts(
          records,
          today,
          periodEnd: 3,
          ovulationStart: 14,
          ovulationEnd: 16,
          displayEnd: 29,
          todayPhase: CycleRingPhase.period,
        );
        expect(ring.segmentFor(CycleRingPhase.period)!.endDay, 3);
      }
    },
  );

  test('before, inside and after retain the same forecast range', () {
    for (final (date, day, label) in [
      (const LocalDate(2026, 9, 20), 21, 'upcoming'),
      (today, 32, 'estimate window is current'),
      (const LocalDate(2026, 10, 3), 34, 'later than this estimate'),
    ]) {
      expectBoth(
        regular(),
        date,
        day,
        const LocalDate(2026, 9, 24),
        const LocalDate(2026, 10, 2),
      );
      final prediction = TodayCycleContext.fromRecords(
        records: regular(),
        today: date,
      ).prediction!;
      expect(cycleEstimateContextLabel(prediction, date), contains(label));
      expectRingParts(
        regular(),
        date,
        periodEnd: 5,
        ovulationStart: 13,
        ovulationEnd: 15,
        displayEnd: day > 28 ? day : 28,
        todayPhase: CycleRingPhase.luteal,
      );
    }
  });

  test('month, year and leap-day rollover use calendar days', () {
    final records = [
      period(
        'a',
        const LocalDate(2023, 12, 31),
        end: const LocalDate(2024, 1, 4),
      ),
      period(
        'b',
        const LocalDate(2024, 1, 31),
        end: const LocalDate(2024, 2, 4),
      ),
      period(
        'c',
        const LocalDate(2024, 2, 29),
        end: const LocalDate(2024, 3, 4),
      ),
      period(
        'd',
        const LocalDate(2024, 3, 31),
        end: const LocalDate(2024, 4, 4),
      ),
    ];
    expectBoth(
      records,
      const LocalDate(2024, 4, 10),
      11,
      const LocalDate(2024, 4, 28),
      const LocalDate(2024, 5, 4),
    );
    expectRingParts(
      records,
      const LocalDate(2024, 4, 10),
      periodEnd: 5,
      ovulationStart: 16,
      ovulationEnd: 18,
      displayEnd: 31,
      todayPhase: CycleRingPhase.follicular,
    );
  });

  test('future start is ignored, and a historical edit recalculates', () async {
    expectBoth(
      [...regular(), period('future', const LocalDate(2026, 10, 2))],
      today,
      32,
      const LocalDate(2026, 9, 24),
      const LocalDate(2026, 10, 2),
    );
    final repository = InMemoryPeriodRepository(
      seed: [
        period(
          'a',
          const LocalDate(2026, 6, 8),
          end: const LocalDate(2026, 6, 12),
        ),
        period(
          'b',
          const LocalDate(2026, 7, 6),
          end: const LocalDate(2026, 7, 10),
        ),
        period(
          'c',
          const LocalDate(2026, 8, 3),
          end: const LocalDate(2026, 8, 7),
        ),
        period(
          'd',
          const LocalDate(2026, 8, 31),
          end: const LocalDate(2026, 9, 4),
        ),
      ],
      clock: () => now,
    );
    await expectLater(
      repository.create(
        const PeriodDraft(startDate: LocalDate(2026, 10, 2)),
        today: today,
      ),
      throwsA(
        isA<PeriodWriteException>().having(
          (error) => error.failure,
          'failure',
          PeriodWriteFailure.futureDate,
        ),
      ),
    );
    await expectLater(
      repository.update(
        'd',
        const PeriodDraft(
          startDate: LocalDate(2026, 8, 31),
          endDate: LocalDate(2026, 10, 2),
        ),
        today: today,
      ),
      throwsA(
        isA<PeriodWriteException>().having(
          (error) => error.failure,
          'failure',
          PeriodWriteFailure.futureDate,
        ),
      ),
    );
    expect(await repository.getAll(), hasLength(4));
    expectBoth(
      await repository.getAll(),
      today,
      32,
      const LocalDate(2026, 9, 25),
      today,
    );
    await repository.update(
      'b',
      const PeriodDraft(
        startDate: LocalDate(2026, 7, 13),
        endDate: LocalDate(2026, 7, 17),
      ),
      today: today,
    );
    expectBoth(
      await repository.getAll(),
      today,
      32,
      const LocalDate(2026, 9, 21),
      const LocalDate(2026, 10, 5),
    );
  });

  testWidgets('a forecast crossing New Year names both years on each page', (
    tester,
  ) async {
    final date = const LocalDate(2026, 12, 20);
    final clock = DateTime(2026, 12, 20, 12);
    final records = [
      period(
        'oct',
        const LocalDate(2026, 10, 10),
        end: const LocalDate(2026, 10, 14),
      ),
      period(
        'nov',
        const LocalDate(2026, 11, 7),
        end: const LocalDate(2026, 11, 11),
      ),
      period(
        'dec',
        const LocalDate(2026, 12, 5),
        end: const LocalDate(2026, 12, 9),
      ),
    ];
    expectBoth(
      records,
      date,
      16,
      const LocalDate(2026, 12, 29),
      const LocalDate(2027, 1, 6),
    );
    final periods = InMemoryPeriodRepository(seed: records, clock: () => clock);
    final health = InMemoryHealthRecordRepository(clock: () => clock);
    final port = RepositoryTodayVisualPort(
      periodRepository: periods,
      checkInRepository: InMemoryMomentCheckInRepository(clock: () => clock),
      healthRecordRepository: health,
      captureNoteStore: InMemoryCaptureNoteStore(),
      today: () => date,
      now: () => clock,
      onCycleDataChanged: () {},
      onOpenCare: () {},
    );
    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: port)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Dec 29, 2026–Jan 6, 2027'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final ring = TodayCycleRingModel.fromRecords(records: records, today: date);
    await tester.pumpWidget(
      MaterialApp(
        home: CycleExperience(
          periodRepository: periods,
          healthRecordRepository: health,
          careMemoryRepository: InMemoryCareMemoryRepository(),
          onCycleDataChanged: () {},
          ringModel: ring,
          now: clock,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('12/29/2026 – 1/6/2027'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cycle renders edited history before the shell model refreshes', (
    tester,
  ) async {
    final records = [
      period(
        'a',
        const LocalDate(2026, 6, 8),
        end: const LocalDate(2026, 6, 12),
      ),
      period(
        'b',
        const LocalDate(2026, 7, 6),
        end: const LocalDate(2026, 7, 10),
      ),
      period(
        'c',
        const LocalDate(2026, 8, 3),
        end: const LocalDate(2026, 8, 7),
      ),
      period(
        'd',
        const LocalDate(2026, 8, 31),
        end: const LocalDate(2026, 9, 4),
      ),
    ];
    final periods = InMemoryPeriodRepository(seed: records, clock: () => now);
    final health = InMemoryHealthRecordRepository(clock: () => now);
    final care = InMemoryCareMemoryRepository();
    final oldRing = TodayCycleRingModel.fromRecords(
      records: records,
      today: today,
    );
    Widget screen(int revision) => MaterialApp(
      home: CycleExperience(
        periodRepository: periods,
        healthRecordRepository: health,
        careMemoryRepository: care,
        onCycleDataChanged: () {},
        ringModel: oldRing,
        revision: revision,
        now: DateTime(2026, 10, 1, 12),
      ),
    );

    await tester.pumpWidget(screen(0));
    await tester.pumpAndSettle();
    expect(find.text('9/25/2026 – 10/1/2026'), findsOneWidget);
    await periods.update(
      'b',
      const PeriodDraft(
        startDate: LocalDate(2026, 7, 13),
        endDate: LocalDate(2026, 7, 17),
      ),
      today: today,
    );
    await tester.pumpWidget(screen(1));
    await tester.pumpAndSettle();
    expect(find.text('9/21/2026 – 10/5/2026'), findsOneWidget);
    expect(find.text('9/25/2026 – 10/1/2026'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Today and Cycle expose matching estimate context at large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final records = regular();
      final periods = InMemoryPeriodRepository(seed: records, clock: () => now);
      final health = InMemoryHealthRecordRepository(clock: () => now);
      final ring = TodayCycleRingModel.fromRecords(
        records: records,
        today: today,
      );
      final port = RepositoryTodayVisualPort(
        periodRepository: periods,
        checkInRepository: InMemoryMomentCheckInRepository(clock: () => now),
        healthRecordRepository: health,
        captureNoteStore: InMemoryCaptureNoteStore(),
        today: () => today,
        now: () => now,
        onCycleDataChanged: () {},
        onOpenCare: () {},
      );
      const media = MediaQueryData(
        size: Size(320, 568),
        textScaler: TextScaler.linear(2),
        disableAnimations: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: media,
            child: TodayExperienceVisual(port: port),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cycle day 32'), findsOneWidget);
      expect(find.textContaining('Sep 24–Oct 2'), findsOneWidget);
      expect(
        find.text('limited history · estimate window is current'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('Cycle day 32')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Estimated next period Sep 24–Oct 2')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: media,
            child: CycleExperience(
              periodRepository: periods,
              healthRecordRepository: health,
              careMemoryRepository: InMemoryCareMemoryRepository(),
              onCycleDataChanged: () {},
              ringModel: ring,
              now: DateTime(2026, 10, 1, 12),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('9/24/2026 – 10/2/2026'), findsOneWidget);
      expect(
        find.textContaining('limited history · estimate window is current'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Day 32; usual cycle about 28 days')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp('Estimated next period 9/24/2026 – 10/2/2026'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
