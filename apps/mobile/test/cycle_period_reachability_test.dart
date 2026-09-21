import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/cycle/cycle_experience.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';

final _now = DateTime(2026, 8, 14, 12);

PeriodRecord _period(String id, LocalDate start, LocalDate end) => PeriodRecord(
  id: id,
  startDate: start,
  endDate: end,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  testWidgets(
    'two-record history keeps the latest start as the current cycle',
    (tester) async {
      tester.view.physicalSize = const Size(622, 865);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final periods = InMemoryPeriodRepository(
        seed: [
          _period(
            'older',
            const LocalDate(2026, 8, 1),
            const LocalDate(2026, 8, 5),
          ),
          _period(
            'latest',
            const LocalDate(2026, 8, 14),
            const LocalDate(2026, 8, 14),
          ),
        ],
        clock: () => _now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CycleExperience(
            periodRepository: periods,
            healthRecordRepository: InMemoryHealthRecordRepository(),
            careMemoryRepository: InMemoryCareMemoryRepository(),
            ringModel: null,
            now: _now,
            onCycleDataChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The compact list deliberately has no "View all" affordance until
      // there are more than six archive records. The latest start remains
      // directly reachable as the current cycle; the preceding start is a
      // completed cycle in Recent cycles.
      expect(find.text('View all 2 periods'), findsNothing);
      expect(find.text('Current cycle'), findsWidgets);
      expect(find.textContaining('8/1/2026'), findsOneWidget);

      await tester.tap(find.text('Current cycle'));
      await tester.pumpAndSettle();

      expect(find.text('Current cycle'), findsWidgets);
      expect(find.text('Edit dates'), findsWidgets);
      expect(find.text('Delete period'), findsOneWidget);
    },
  );

  testWidgets(
    'latest same-day period is reachable, removable, then a new start succeeds',
    (tester) async {
      tester.view.physicalSize = const Size(622, 865);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final periods = InMemoryPeriodRepository(
        seed: [
          _period(
            'older',
            const LocalDate(2026, 8, 1),
            const LocalDate(2026, 8, 5),
          ),
          _period(
            'same-day',
            const LocalDate(2026, 8, 14),
            const LocalDate(2026, 8, 14),
          ),
        ],
        clock: () => _now,
        idGenerator: () => 'new-start',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CycleExperience(
            periodRepository: periods,
            healthRecordRepository: InMemoryHealthRecordRepository(),
            careMemoryRepository: InMemoryCareMemoryRepository(),
            ringModel: null,
            now: _now,
            onCycleDataChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('View all 2 periods'), findsNothing);
      await tester.tap(find.text('Current cycle'));
      await tester.pumpAndSettle();

      expect(find.text('Edit dates'), findsWidgets);
      expect(find.text('Delete period'), findsOneWidget);
      await tester.tap(find.text('Delete period'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this period?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect((await periods.getAll()).map((period) => period.id), ['older']);
      expect(find.text('Record a new period start'), findsOneWidget);

      await tester.tap(find.text('Record a new period start'));
      await tester.pumpAndSettle();

      final remaining = await periods.getAll();
      expect(remaining, hasLength(2));
      expect(
        remaining.where((period) => period.id == 'new-start'),
        hasLength(1),
      );
      expect(
        remaining.singleWhere((period) => period.id == 'new-start').startDate,
        const LocalDate(2026, 8, 14),
      );
      expect(
        remaining.singleWhere((period) => period.id == 'new-start').isOpen,
        isTrue,
      );
    },
  );
}
