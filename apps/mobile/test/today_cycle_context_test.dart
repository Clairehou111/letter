import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/today/today_cycle_context.dart';

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
}
