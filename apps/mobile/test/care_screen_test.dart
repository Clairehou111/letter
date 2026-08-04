import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/care/data/in_memory_impulse_buffer_repository.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/care/domain/impulse_buffer_repository.dart';
import 'package:letter_mobile/features/care/presentation/care_safety_boundary_sheet.dart';
import 'package:letter_mobile/features/care/presentation/care_screen.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';

Future<void> pumpCare(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = false,
  ValueChanged<int>? onNavigationSelected,
  ImpulseBufferRepository? impulseBufferRepository,
  CareMemoryRepository? careMemoryRepository,
  InMemoryHealthRecordRepository? healthRecordRepository,
  DateTime Function()? now,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: LetterTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: CareScreen(
          onNavigationSelected: onNavigationSelected ?? (_) {},
          impulseBufferRepository:
              impulseBufferRepository ?? InMemoryImpulseBufferRepository(),
          careMemoryRepository:
              careMemoryRepository ?? InMemoryCareMemoryRepository(),
          healthRecordRepository:
              healthRecordRepository ?? InMemoryHealthRecordRepository(),
          now: now ?? () => DateTime.utc(2026, 7, 28, 8),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openMode(WidgetTester tester, CareMode mode) async {
  final finder = find.byKey(Key('care-mode-${mode.name}'));
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  await Scrollable.ensureVisible(
    tester.element(finder),
    alignment: 0.5,
    duration: Duration.zero,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> completeCareActivity(WidgetTester tester, CareMode mode) async {
  await openMode(tester, mode);

  switch (mode) {
    case CareMode.explode:
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(find.byKey(const Key('skip-shatter')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('leave-after-quiet')));
    case CareMode.heavy:
      await tester.tap(find.byKey(const Key('heavy-light')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('heavy-stop-here')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('heavy-handoff-return')));
    case CareMode.racing:
      await tester.tap(find.byKey(const Key('racing-convergence-surface')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('racing-nothing-now')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('racing-handoff-return')));
    case CareMode.space:
      await tester.tap(find.byKey(const Key('safe-cocoon-close')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('safe-cocoon-nothing-now')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('need-space-handoff-return')));
    case CareMode.physical:
      await tester.tap(find.byKey(const Key('physical-path-cramps')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('physical-auto-complete')));
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('physical-action-cramps_familiar_warmth')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('physical-handoff-return')));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the branch Care entries without a Care Kit', (
    tester,
  ) async {
    await pumpCare(tester);

    expect(find.text('What is closest to this moment?'), findsOneWidget);
    expect(find.byKey(const Key('care-nothing-left')), findsOneWidget);
    expect(find.byKey(const Key('care-breathe')), findsOneWidget);
    for (final mode in CareMode.values) {
      await tester.scrollUntilVisible(
        find.byKey(Key('care-mode-${mode.name}')),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(mode.label), findsOneWidget);
    }
    expect(find.textContaining('Care Kit'), findsNothing);
    expect(find.byKey(const Key('open-personal-care-kit')), findsNothing);
    expect(find.byKey(const Key('navigation-care')), findsOneWidget);
  });

  testWidgets('breathing entry opens, completes, and closes locally', (
    tester,
  ) async {
    await pumpCare(tester, disableAnimations: true);

    await tester.tap(find.byKey(const Key('care-breathe')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('breath-intro')), findsOneWidget);

    await tester.tap(find.byKey(const Key('breath-start')));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const ValueKey('breath-session')), findsOneWidget);
    await tester.tap(find.byKey(const Key('breath-finish')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('breath-done')), findsOneWidget);

    await tester.tap(find.byKey(const Key('breath-close')));
    await tester.pumpAndSettle();
    expect(find.text('What is closest to this moment?'), findsOneWidget);
  });

  testWidgets('low-energy entry is available without a required action', (
    tester,
  ) async {
    await pumpCare(tester, disableAnimations: true);

    await tester.tap(find.byKey(const Key('care-nothing-left')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('low-energy-close')), findsOneWidget);

    await tester.tap(find.byKey(const Key('low-energy-close')));
    await tester.pumpAndSettle();
    expect(find.text('What is closest to this moment?'), findsOneWidget);
  });

  testWidgets('all five Care activities reach check-back', (tester) async {
    await pumpCare(tester);

    for (final mode in CareMode.values) {
      await completeCareActivity(tester, mode);
      expect(
        find.text('How is this moment now?'),
        findsOneWidget,
        reason: 'completion did not reach check-back for ${mode.name}',
      );
      expect(
        find.byKey(const Key('care-checkback-better')),
        findsOneWidget,
        reason: mode.name,
      );
      expect(
        find.byKey(const Key('care-checkback-same')),
        findsOneWidget,
        reason: mode.name,
      );
      expect(
        find.byKey(const Key('care-checkback-worse')),
        findsOneWidget,
        reason: mode.name,
      );
      expect(
        find.byKey(const Key('care-checkback-record-symptoms')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('care-checkback-skip')));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('emotional safety route interrupts and can return', (
    tester,
  ) async {
    await pumpCare(tester);
    await openMode(tester, CareMode.explode);

    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.byKey(const Key('angry-safety')));
    await tester.pumpAndSettle();

    expect(find.text('Immediate safety comes first.'), findsOneWidget);
    expect(
      find.textContaining('Letter cannot provide emergency help'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('return-to-care-scene')));
    await tester.pump();
    expect(find.byKey(const Key('shatter-crystal')), findsOneWidget);
  });

  testWidgets('physical safety route leaves Care through navigation', (
    tester,
  ) async {
    int? selectedNavigation;
    await pumpCare(
      tester,
      onNavigationSelected: (index) => selectedNavigation = index,
    );
    await openMode(tester, CareMode.physical);

    await tester.tap(find.byKey(const Key('physical-safety')));
    await tester.pumpAndSettle();
    expect(
      find.text('This needs medical attention, not more interaction.'),
      findsOneWidget,
    );
    expect(find.textContaining('Book a medical assessment'), findsOneWidget);

    await tester.dragUntilVisible(
      find.byKey(const Key('leave-care-from-safety')),
      find.byType(CareSafetyBoundarySheet).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leave-care-from-safety')));
    await tester.pumpAndSettle();
    expect(selectedNavigation, 2);
  });

  testWidgets('primary Care controls remain at least 44 logical pixels', (
    tester,
  ) async {
    await pumpCare(tester);
    expect(
      tester.getSize(find.byKey(const Key('care-mode-explode'))).height,
      greaterThanOrEqualTo(44),
    );

    await openMode(tester, CareMode.racing);
    expect(
      tester
          .getSize(find.byKey(const Key('racing-convergence-surface')))
          .height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.byKey(const Key('racing-safety'))).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('outcome persists and symptom recording opens from check-back', (
    tester,
  ) async {
    final repository = InMemoryCareMemoryRepository(
      clock: () => DateTime.utc(2026, 7, 28, 9),
      idGenerator: () => 'care-record',
    );
    await pumpCare(tester, careMemoryRepository: repository);
    await completeCareActivity(tester, CareMode.heavy);

    expect(await repository.getRecords(), isEmpty);
    await tester.tap(find.byKey(const Key('care-checkback-better')));
    await tester.pump();
    expect((await repository.getRecords()).single.outcome.name, 'better');

    await tester.tap(find.byKey(const Key('care-checkback-record-symptoms')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recovery-receipt-flow')), findsOneWidget);
    await tester.tap(find.byKey(const Key('recovery-signal-not-remember')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('care-checkback-recorded')), findsOneWidget);
    expect(find.textContaining('Care Kit'), findsNothing);

    await tester.tap(find.byKey(const Key('care-checkback-done')));
    await tester.pump();
    expect(find.text('What is closest to this moment?'), findsOneWidget);
  });

  testWidgets('can record symptoms before choosing an outcome', (tester) async {
    await pumpCare(tester);
    await completeCareActivity(tester, CareMode.heavy);

    await tester.tap(find.byKey(const Key('care-checkback-record-symptoms')));
    await tester.pumpAndSettle();

    expect(find.text('Add symptom details'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('How is this moment now?'), findsOneWidget);
  });

  testWidgets('future-self note is not injected into immediate Care', (
    tester,
  ) async {
    final occurredAt = DateTime.utc(2026, 7, 27, 8);
    final record = CareRecord(
      id: 'racing-record',
      mode: CareMode.racing,
      actionId: 'racing.one-calm-point',
      actionLabel: 'Bring thoughts to one calm point',
      outcome: CareOutcome.better,
      occurredAt: occurredAt,
      createdAt: occurredAt,
      updatedAt: occurredAt,
      pinned: false,
    );
    final repository = InMemoryCareMemoryRepository(
      records: [record],
      reflections: [
        CareReflection(
          id: 'reflection',
          careRecordId: record.id,
          mode: CareMode.racing,
          observation: null,
          need: ReflectionNeed.restOrPhysicalCapacity,
          whatHelped: null,
          futureSelfNote: 'Close the laptop before choosing the next thing.',
          createdAt: occurredAt,
          updatedAt: occurredAt,
        ),
      ],
    );
    await pumpCare(tester, careMemoryRepository: repository);
    await openMode(tester, CareMode.racing);

    expect(
      find.text('Close the laptop before choosing the next thing.'),
      findsNothing,
    );
    expect(find.byKey(const Key('racing-convergence-surface')), findsOneWidget);
  });

  testWidgets('Care gate matches the 390 by 844 visual baseline', (
    tester,
  ) async {
    await pumpCare(tester);

    await expectLater(
      find.byType(CareScreen),
      matchesGoldenFile('goldens/care_gate_390x844.png'),
    );
  });
}
