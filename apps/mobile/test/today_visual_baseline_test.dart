import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/today/today_experience_visual_baseline.dart';
import 'package:letter_mobile/experience/today/today_visual_port.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/check_in/data/in_memory_moment_check_in_repository.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/bleeding_flow.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';

void main() {
  testWidgets('a difficult mood offers and opens the production Care route', (
    tester,
  ) async {
    const today = LocalDate(2026, 8, 15);
    final now = DateTime(2026, 8, 15, 12);
    var careOpened = false;
    final port = RepositoryTodayVisualPort(
      periodRepository: InMemoryPeriodRepository(clock: () => now),
      checkInRepository: InMemoryMomentCheckInRepository(clock: () => now),
      healthRecordRepository: InMemoryHealthRecordRepository(clock: () => now),
      captureNoteStore: InMemoryCaptureNoteStore(),
      today: () => today,
      now: () => now,
      onCycleDataChanged: () {},
      onOpenCare: () => careOpened = true,
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: port)),
    );
    await tester.pumpAndSettle();

    final irritable = find.text('Irritable');
    await tester.scrollUntilVisible(
      irritable,
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(irritable);
    await tester.pumpAndSettle();

    expect(find.text('This one sounds heavy.'), findsOneWidget);
    final openCare = find.text('Open Care');
    await tester.ensureVisible(openCare);
    await tester.tap(openCare);
    await tester.pumpAndSettle();
    expect(careOpened, isTrue);
  });

  testWidgets('Today shows factual remembered help when the gate supplies it', (
    tester,
  ) async {
    const today = LocalDate(2026, 8, 15);
    final now = DateTime(2026, 8, 15, 12);
    final port = RepositoryTodayVisualPort(
      periodRepository: InMemoryPeriodRepository(clock: () => now),
      checkInRepository: InMemoryMomentCheckInRepository(clock: () => now),
      healthRecordRepository: InMemoryHealthRecordRepository(clock: () => now),
      captureNoteStore: InMemoryCaptureNoteStore(),
      today: () => today,
      now: () => now,
      onCycleDataChanged: () {},
      onOpenCare: () {},
      loadRememberedHelpLine: () async =>
          'Apply warmth helped twice before — your check-backs say so.',
    );

    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: port)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Apply warmth helped twice before — your check-backs say so.'),
      findsOneWidget,
    );
  });

  testWidgets('Today writes the same facts Cycle reads', (tester) async {
    const today = LocalDate(2026, 8, 15);
    final now = DateTime(2026, 8, 15, 12);
    final periods = InMemoryPeriodRepository(
      seed: <PeriodRecord>[
        PeriodRecord(
          id: 'current',
          startDate: const LocalDate(2026, 8, 13),
          endDate: null,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      clock: () => now,
    );
    final moods = InMemoryMomentCheckInRepository(clock: () => now);
    final symptoms = InMemoryHealthRecordRepository(clock: () => now);
    final port = RepositoryTodayVisualPort(
      periodRepository: periods,
      checkInRepository: moods,
      healthRecordRepository: symptoms,
      captureNoteStore: InMemoryCaptureNoteStore(),
      today: () => today,
      now: () => now,
      onCycleDataChanged: () {},
      onOpenCare: () {},
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: port)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Good').first);
    await tester.pumpAndSettle();
    expect((await moods.getAll()).single.state, MomentCheckInState.good);

    final light = find.text('Light').first;
    await tester.scrollUntilVisible(
      light,
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(light);
    await tester.pumpAndSettle();
    final brightRed = find.text('Bright red').first;
    await tester.scrollUntilVisible(
      brightRed,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(brightRed);
    await tester.pumpAndSettle();
    final flow = (await periods.getAllFlowDays()).single;
    expect(flow.flow, BleedingFlow.light);
    expect(flow.color, BleedingColor.brightRed);

    final add = find.text('Add a symptom');
    await tester.scrollUntilVisible(
      add,
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cramps').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moderate').last);
    await tester.pumpAndSettle();

    final records = await symptoms.getAll();
    expect(records, hasLength(1));
    expect(records.single.symptom, SymptomType.cramps);
    expect(records.single.severity, SymptomSeverity.moderate);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ending a same-day period never offers an overlapping start', (
    tester,
  ) async {
    const today = LocalDate(2026, 8, 15);
    final now = DateTime(2026, 8, 15, 12);
    final periods = InMemoryPeriodRepository(
      seed: <PeriodRecord>[
        PeriodRecord(
          id: 'current',
          startDate: today,
          endDate: null,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      clock: () => now,
    );
    final port = RepositoryTodayVisualPort(
      periodRepository: periods,
      checkInRepository: InMemoryMomentCheckInRepository(clock: () => now),
      healthRecordRepository: InMemoryHealthRecordRepository(clock: () => now),
      captureNoteStore: InMemoryCaptureNoteStore(),
      today: () => today,
      now: () => now,
      onCycleDataChanged: () {},
      onOpenCare: () {},
    );

    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: port)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('End period'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End period').last);
    await tester.pumpAndSettle();

    expect(find.text('Period recorded today'), findsOneWidget);
    expect(find.text('Start period'), findsNothing);
    expect((await periods.getAll()).single.endDate, today);
  });
}
