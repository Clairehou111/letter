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

Future<void> completeMotionActivity(WidgetTester tester, CareMode mode) async {
  await openMode(tester, mode);
  if (mode == CareMode.physical) {
    await tester.tap(find.byKey(const Key('care-context-cramps')));
    await tester.pump();
  }
  await tester.tap(find.byKey(const Key('care-break-complete')));
  await tester.pumpAndSettle();
  if (find.byKey(const Key('care-rest-leave')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('care-rest-leave')));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('shows all five entrances without selecting one', (tester) async {
    await pumpCare(tester);

    expect(find.text('Change the next minute.'), findsOneWidget);
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
    expect(find.byKey(const Key('care-protective-line')), findsNothing);
    expect(find.byKey(const Key('navigation-care')), findsOneWidget);
  });

  testWidgets('all five activities end in outcome and symptom actions', (
    tester,
  ) async {
    await pumpCare(tester);

    for (final mode in CareMode.values) {
      await completeMotionActivity(tester, mode);

      expect(find.byKey(const Key('care-checkback-better')), findsOneWidget);
      expect(find.byKey(const Key('care-checkback-same')), findsOneWidget);
      expect(find.byKey(const Key('care-checkback-worse')), findsOneWidget);
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

    await tester.tap(find.byKey(const Key('care-break-safety')));
    await tester.pumpAndSettle();

    expect(find.text('Immediate safety comes first.'), findsOneWidget);
    expect(
      find.textContaining('Letter cannot provide emergency help'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('return-to-care-scene')));
    await tester.pump();
    expect(find.byKey(const Key('care-break-surface-explode')), findsOneWidget);
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

    await tester.tap(find.byKey(const Key('care-break-safety')));
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
      tester
          .getSize(find.byKey(const Key('care-break-surface-explode')))
          .height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.byKey(const Key('care-break-safety'))).height,
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

  testWidgets('motion completion persists outcome and can record symptoms', (
    tester,
  ) async {
    final repository = InMemoryCareMemoryRepository(
      clock: () => DateTime.utc(2026, 7, 28, 9),
      idGenerator: () => 'care-record',
    );
    await pumpCare(tester, careMemoryRepository: repository);
    await completeMotionActivity(tester, CareMode.physical);
    expect(await repository.getRecords(), isEmpty);
    expect(find.text('How is this moment now?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('care-checkback-better')));
    await tester.pump();
    expect((await repository.getRecords()).single.outcome.name, 'better');

    expect(
      find.byKey(const Key('care-checkback-record-symptoms')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('care-checkback-record-symptoms')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recovery-receipt-flow')), findsOneWidget);
    await tester.tap(find.byKey(const Key('recovery-signal-not-remember')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('care-checkback-recorded')), findsOneWidget);
    expect(find.textContaining('Care Kit'), findsNothing);

    await tester.tap(find.byKey(const Key('care-checkback-done')));
    await tester.pump();
    expect(find.text('Change the next minute.'), findsOneWidget);
  });

  testWidgets('can record symptoms before choosing an outcome', (tester) async {
    await pumpCare(tester);
    await completeMotionActivity(tester, CareMode.heavy);

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
    expect(find.byKey(const Key('care-break-surface-racing')), findsOneWidget);

    expect(
      find.text('Close the laptop before choosing the next thing.'),
      findsNothing,
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
