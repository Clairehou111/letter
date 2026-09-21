import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/cycle/cycle_experience.dart';
import 'package:letter_mobile/experience/today/today_cycle_ring.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';

PeriodRecord _period({
  required String id,
  required LocalDate start,
  required LocalDate end,
}) {
  return PeriodRecord(
    id: id,
    startDate: start,
    endDate: end,
    createdAt: DateTime.utc(2026, 8, 15),
    updatedAt: DateTime.utc(2026, 8, 15),
  );
}

void main() {
  testWidgets('learning ring does not invent another required period start', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TodayCycleRing.learning(observedDays: 1)),
      ),
    );

    expect(
      find.text('Cycle pattern still forming from your recorded dates.'),
      findsOneWidget,
    );
    expect(find.textContaining('one more recorded period start'), findsNothing);
  });

  testWidgets(
    'Cycle uses a steady fallback when three starts cannot produce a model',
    (tester) async {
      // The experience fonts are not loaded in this focused widget test, so
      // use the desktop preview width to avoid unrelated fallback-font header
      // overflow while exercising the ring state itself.
      tester.view.physicalSize = const Size(622, 865);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final periods = <PeriodRecord>[
        _period(
          id: 'july',
          start: const LocalDate(2026, 7, 8),
          end: const LocalDate(2026, 7, 13),
        ),
        _period(
          id: 'august-14',
          start: const LocalDate(2026, 8, 14),
          end: const LocalDate(2026, 8, 14),
        ),
        _period(
          id: 'august-15',
          start: const LocalDate(2026, 8, 15),
          end: const LocalDate(2026, 8, 15),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: CycleExperience(
            periodRepository: InMemoryPeriodRepository(seed: periods),
            healthRecordRepository: InMemoryHealthRecordRepository(),
            careMemoryRepository: InMemoryCareMemoryRepository(),
            ringModel: null,
            now: DateTime(2026, 8, 15),
            onCycleDataChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Cycle pattern still forming from your recorded dates.'),
        findsOneWidget,
      );
      expect(find.textContaining('Preparing your cycle ring'), findsNothing);
      expect(
        find.textContaining('one more recorded period start'),
        findsNothing,
      );
    },
  );
}
