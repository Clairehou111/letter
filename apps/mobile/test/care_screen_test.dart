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
import 'package:letter_mobile/features/care/presentation/heavy_presence_flow.dart';
import 'package:letter_mobile/features/care/presentation/need_space_flow.dart';
import 'package:letter_mobile/features/care/presentation/physical_pain_flow.dart';
import 'package:letter_mobile/features/care/presentation/racing_thoughts_flow.dart';
import 'package:letter_mobile/features/care/presentation/safe_cocoon_stage.dart';
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
  if (mode == CareMode.explode ||
      mode == CareMode.heavy ||
      mode == CareMode.racing ||
      mode == CareMode.space) {
    await tester.pump();
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('shows all five entrances without selecting one', (tester) async {
    await pumpCare(tester);

    expect(find.text('What is closest to this moment?'), findsOneWidget);
    for (final mode in CareMode.values) {
      await tester.scrollUntilVisible(
        find.byKey(Key('care-mode-${mode.name}')),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(mode.label), findsOneWidget);
    }
    expect(find.byKey(const Key('care-protective-line')), findsNothing);
    expect(find.byKey(const Key('navigation-care')), findsOneWidget);
  });

  testWidgets('heavy entrance opens the dedicated presence flow', (
    tester,
  ) async {
    await pumpCare(tester);
    await openMode(tester, CareMode.heavy);

    expect(find.byType(HeavyPresenceFlow), findsOneWidget);
    expect(find.byKey(const Key('heavy-light')), findsOneWidget);
    expect(find.byKey(const Key('care-respond-heavy')), findsNothing);
  });

  testWidgets('racing entrance opens the dedicated convergence flow', (
    tester,
  ) async {
    await pumpCare(tester);
    await openMode(tester, CareMode.racing);

    expect(find.byType(RacingThoughtsFlow), findsOneWidget);
    expect(find.byKey(const Key('racing-convergence-surface')), findsOneWidget);
    expect(find.byKey(const Key('care-respond-racing')), findsNothing);
  });

  testWidgets('space entrance opens the dedicated safe cocoon flow', (
    tester,
  ) async {
    await pumpCare(tester);
    await openMode(tester, CareMode.space);

    expect(find.byType(NeedSpaceFlow), findsOneWidget);
    expect(find.byType(SafeCocoonStage), findsOneWidget);
    expect(find.byKey(const Key('care-respond-space')), findsNothing);
  });

  testWidgets('physical entrance opens the dedicated comfort flow', (
    tester,
  ) async {
    await pumpCare(tester);
    await openMode(tester, CareMode.physical);

    expect(find.byType(PhysicalPainFlow), findsOneWidget);
    expect(find.byKey(const Key('physical-path-cramps')), findsOneWidget);
    expect(find.byKey(const Key('care-respond-physical')), findsNothing);
  });

  testWidgets('emotional safety route interrupts and can return', (
    tester,
  ) async {
    await pumpCare(tester);
    await openMode(tester, CareMode.explode);

    await tester.tap(find.byKey(const Key('angry-safety')));
    await tester.pumpAndSettle();

    expect(find.text('Immediate safety comes first.'), findsOneWidget);
    expect(
      find.textContaining('Letter cannot provide emergency help'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('return-to-care-scene')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shatter-crystal')), findsOneWidget);
  });

  testWidgets('physical safety route stops normal Care and can leave', (
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

  testWidgets('primary controls remain at least 44 logical pixels', (
    tester,
  ) async {
    await pumpCare(tester);
    final entranceSize = tester.getSize(
      find.byKey(const Key('care-mode-explode')),
    );
    expect(entranceSize.height, greaterThanOrEqualTo(44));

    await openMode(tester, CareMode.explode);
    expect(
      tester.getSize(find.byKey(const Key('shatter-crystal'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.byKey(const Key('angry-safety'))).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('does not show fabricated contacts or prior outcomes', (
    tester,
  ) async {
    await pumpCare(tester);

    for (final text in [
      'My person',
      'Last time',
      'saved action',
      'future-self',
      'Message Maya',
    ]) {
      expect(find.textContaining(text), findsNothing);
    }
  });

  testWidgets(
    'physical completion checks back and persists only after outcome',
    (tester) async {
      final repository = InMemoryCareMemoryRepository(
        clock: () => DateTime.utc(2026, 7, 28, 9),
        idGenerator: () => 'care-record',
      );
      await pumpCare(tester, careMemoryRepository: repository);
      await openMode(tester, CareMode.physical);

      await tester.tap(find.byKey(const Key('physical-path-cramps')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('physical-auto-complete')));
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('physical-action-cramps_familiar_warmth')),
      );
      await tester.pump();
      expect(await repository.getRecords(), isEmpty);

      await tester.tap(find.byKey(const Key('physical-handoff-return')));
      await tester.pump();
      expect(find.text('How is this moment now?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('care-checkback-better')));
      await tester.pump();
      expect((await repository.getRecords()).single.outcome.name, 'better');

      expect(
        find.byKey(const Key('care-checkback-recovery-receipt')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('care-checkback-recovery-receipt')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recovery-receipt-flow')), findsOneWidget);
      await tester.tap(find.byKey(const Key('recovery-signal-not-remember')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('care-checkback-recorded')), findsOneWidget);

      await tester.tap(find.byKey(const Key('care-checkback-keep')));
      await tester.pump();
      expect((await repository.getRecords()).single.pinned, isTrue);

      await tester.tap(find.byKey(const Key('care-checkback-done')));
      await tester.pump();
      expect(find.text('What is closest to this moment?'), findsOneWidget);
    },
  );

  testWidgets('future-self note appears only after acute feedback', (
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
    await tester.tap(find.byKey(const Key('racing-convergence-surface')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('racing-nothing-now')));
    await tester.pump();

    expect(
      find.text('Close the laptop before choosing the next thing.'),
      findsOneWidget,
    );
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
