import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/recovery_receipt/application/recovery_receipt_controller.dart';
import 'package:letter_mobile/features/recovery_receipt/domain/recovery_receipt.dart';
import 'package:letter_mobile/features/recovery_receipt/presentation/recovery_receipt_flow.dart';

CareRecord sampleCare() {
  final occurred = DateTime.utc(2026, 7, 28, 10);
  return CareRecord(
    id: 'care-1',
    mode: CareMode.explode,
    actionId: 'shatter',
    actionLabel: 'Put the force somewhere safe.',
    outcome: CareOutcome.better,
    occurredAt: occurred,
    createdAt: occurred,
    updatedAt: occurred,
    pinned: false,
  );
}

Future<void> pumpReceipt(
  WidgetTester tester, {
  required InMemoryCareMemoryRepository careRepository,
  required InMemoryHealthRecordRepository healthRepository,
  ValueChanged<RecoveryReceiptResult>? onComplete,
  VoidCallback? onSkipped,
}) async {
  final controller = RecoveryReceiptController(
    careMemoryRepository: careRepository,
    healthRecordRepository: healthRepository,
    now: () => DateTime.utc(2026, 7, 28, 12),
  );
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: LetterTheme.light,
      home: RecoveryReceiptEntryScreen(
        careRecordId: 'care-1',
        controller: controller,
        onComplete: onComplete,
        onSkipped: onSkipped,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('keeps the Care suggestion editable and saves confirmed values', (
    tester,
  ) async {
    final careRepository = InMemoryCareMemoryRepository(
      records: [sampleCare()],
    );
    final healthRepository = InMemoryHealthRecordRepository();
    RecoveryReceiptResult? result;
    await pumpReceipt(
      tester,
      careRepository: careRepository,
      healthRepository: healthRepository,
      onComplete: (value) => result = value,
    );

    expect(find.text('What was strongest?'), findsOneWidget);
    expect(find.byKey(const Key('recovery-suggestion')), findsOneWidget);
    expect(
      find.byKey(const Key('recovery-signal-irritability')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('recovery-receipt-next')), findsOneWidget);

    await tester.tap(find.byKey(const Key('recovery-signal-lowMood')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('recovery-receipt-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('recovery-severity-severe')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('recovery-receipt-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('recovery-impact-workOrSchool')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('recovery-receipt-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('recovery-physical-headache')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('recovery-receipt-next')));
    await tester.pump();
    expect(find.byKey(const Key('recovery-review-provenance')), findsOneWidget);
    expect(find.text('This will be marked same_day.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('recovery-receipt-confirm')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect((await healthRepository.getAll()), hasLength(2));
    expect(
      (await healthRepository.getAll()).map((record) => record.symptom),
      containsAll([SymptomType.lowMood, SymptomType.headache]),
    );
  });

  testWidgets('I do not remember exits without saving a partial record', (
    tester,
  ) async {
    final careRepository = InMemoryCareMemoryRepository(
      records: [sampleCare()],
    );
    final healthRepository = InMemoryHealthRecordRepository();
    var skipped = 0;
    await pumpReceipt(
      tester,
      careRepository: careRepository,
      healthRepository: healthRepository,
      onSkipped: () => skipped += 1,
    );

    await tester.tap(find.byKey(const Key('recovery-signal-not-remember')));
    await tester.pump();
    expect(skipped, 1);
    expect(await healthRepository.getAll(), isEmpty);
  });

  testWidgets('something else opens the reviewed structured vocabulary', (
    tester,
  ) async {
    final careRepository = InMemoryCareMemoryRepository(
      records: [sampleCare()],
    );
    final healthRepository = InMemoryHealthRecordRepository();
    await pumpReceipt(
      tester,
      careRepository: careRepository,
      healthRepository: healthRepository,
    );

    final somethingElse = find.byKey(
      const Key('recovery-signal-something-else'),
    );
    await tester.drag(
      find.byKey(const Key('recovery-receipt-scroll')),
      const Offset(0, -180),
    );
    await tester.pump();
    await tester.ensureVisible(somethingElse);
    await tester.tap(somethingElse);
    await tester.pump();

    final next = tester.widget<FilledButton>(
      find.byKey(const Key('recovery-receipt-next')),
    );
    expect(next.onPressed, isNull);
    expect(find.byKey(const Key('recovery-signal-bodyAches')), findsOneWidget);

    final bodyAches = find.byKey(const Key('recovery-signal-bodyAches'));
    await tester.ensureVisible(bodyAches);
    await tester.tap(bodyAches);
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('recovery-receipt-next')))
          .onPressed,
      isNotNull,
    );
    expect(await healthRepository.getAll(), isEmpty);
  });

  testWidgets('skip at the severity step leaves no partial values', (
    tester,
  ) async {
    final careRepository = InMemoryCareMemoryRepository(
      records: [sampleCare()],
    );
    final healthRepository = InMemoryHealthRecordRepository();
    var skipped = 0;
    await pumpReceipt(
      tester,
      careRepository: careRepository,
      healthRepository: healthRepository,
      onSkipped: () => skipped += 1,
    );

    await tester.tap(find.byKey(const Key('recovery-signal-irritability')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('recovery-receipt-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('recovery-skip-severity')));
    await tester.pump();

    expect(skipped, 1);
    expect(await healthRepository.getAll(), isEmpty);
  });

  testWidgets('cannot start from a Care id that was not persisted', (
    tester,
  ) async {
    final healthRepository = InMemoryHealthRecordRepository();
    final controller = RecoveryReceiptController(
      careMemoryRepository: InMemoryCareMemoryRepository(),
      healthRecordRepository: healthRepository,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: RecoveryReceiptEntryScreen(
          careRecordId: 'missing',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('no longer available'), findsOneWidget);
    expect(find.text('What was strongest?'), findsNothing);
    expect(await healthRepository.getAll(), isEmpty);
  });
}
