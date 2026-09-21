import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/today/today_cycle_context.dart';
import 'package:letter_mobile/features/today/today_cycle_ring_model.dart';

PeriodRecord period({
  required String id,
  required LocalDate start,
  LocalDate? end,
}) {
  return PeriodRecord(
    id: id,
    startDate: start,
    endDate: end,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

void main() {
  const today = LocalDate(2026, 7, 28);

  test('no period history has no day number or prediction', () {
    final context = TodayCycleContext.fromRecords(
      records: const [],
      today: today,
    );

    expect(context.kind, TodayCycleKind.noHistory);
    expect(context.dayNumber, isNull);
    expect(context.latestStart, isNull);
    expect(context.prediction, isNull);
  });

  test('an open latest period produces an inclusive period day', () {
    final context = TodayCycleContext.fromRecords(
      records: [period(id: 'current', start: const LocalDate(2026, 7, 26))],
      today: today,
    );

    expect(context.kind, TodayCycleKind.periodInProgress);
    expect(context.dayNumber, 3);
    expect(context.latestStart, const LocalDate(2026, 7, 26));
  });

  test('a closed latest period produces an inclusive cycle day', () {
    final context = TodayCycleContext.fromRecords(
      records: [
        period(
          id: 'latest',
          start: const LocalDate(2026, 7, 1),
          end: const LocalDate(2026, 7, 5),
        ),
      ],
      today: today,
    );

    expect(context.kind, TodayCycleKind.betweenPeriods);
    expect(context.dayNumber, 28);
  });

  test('the final day of a closed period remains a period day', () {
    const finalDay = LocalDate(2026, 7, 5);
    final context = TodayCycleContext.fromRecords(
      records: [
        period(id: 'latest', start: const LocalDate(2026, 7, 1), end: finalDay),
      ],
      today: finalDay,
    );

    expect(context.kind, TodayCycleKind.periodInProgress);
    expect(context.dayNumber, 5);
  });

  test('prediction delegates to the shared cycle engine', () {
    final context = TodayCycleContext.fromRecords(
      records: [
        period(id: 'current', start: const LocalDate(2026, 7, 26)),
        period(
          id: 'past',
          start: const LocalDate(2026, 6, 27),
          end: const LocalDate(2026, 7, 1),
        ),
        period(
          id: 'older',
          start: const LocalDate(2026, 5, 29),
          end: const LocalDate(2026, 6, 2),
        ),
      ],
      today: today,
    );

    expect(context.prediction, isNotNull);
    expect(context.prediction!.intervalCount, 2);
    expect(context.prediction!.minimumCycleDays, 29);
    expect(context.prediction!.maximumCycleDays, 29);
  });

  test('Today and Cycle derive the same current day and estimate range', () {
    const demoToday = LocalDate(2026, 8, 15);
    final records = <PeriodRecord>[
      period(
        id: 'march',
        start: const LocalDate(2026, 3, 1),
        end: const LocalDate(2026, 3, 5),
      ),
      period(
        id: 'march-2',
        start: const LocalDate(2026, 3, 29),
        end: const LocalDate(2026, 4, 2),
      ),
      period(
        id: 'april',
        start: const LocalDate(2026, 4, 26),
        end: const LocalDate(2026, 4, 30),
      ),
      period(
        id: 'may',
        start: const LocalDate(2026, 5, 24),
        end: const LocalDate(2026, 5, 28),
      ),
      period(
        id: 'june',
        start: const LocalDate(2026, 6, 21),
        end: const LocalDate(2026, 6, 25),
      ),
      period(
        id: 'july',
        start: const LocalDate(2026, 7, 19),
        end: const LocalDate(2026, 7, 23),
      ),
    ];

    final context = TodayCycleContext.fromRecords(
      records: records,
      today: demoToday,
    );
    final ring = TodayCycleRingModel.fromRecords(
      records: records,
      today: demoToday,
    );

    expect(context.kind, TodayCycleKind.betweenPeriods);
    expect(context.dayNumber, 28);
    expect(context.prediction!.medianCycleDays, 28);
    expect(
      context.prediction!.predictedMensesStart,
      const LocalDate(2026, 8, 14),
    );
    expect(
      context.prediction!.predictedMensesEnd,
      const LocalDate(2026, 8, 18),
    );
    expect(ring.currentDay, context.dayNumber);
    expect(ring.predictedPeriodStart, context.prediction!.predictedMensesStart);
    expect(ring.predictedPeriodEnd, context.prediction!.predictedMensesEnd);
  });
}
