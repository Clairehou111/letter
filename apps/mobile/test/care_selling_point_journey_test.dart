import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/care/care_animation_port.dart';
import 'package:letter_mobile/experience/care/care_experience.dart';
import 'package:letter_mobile/experience/care/original_care_animation_port.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/recovery_receipt/domain/recovery_receipt.dart';

final class _SignalPort implements CareAnimationPort {
  @override
  Widget buildScene(
    BuildContext context, {
    required CareMode mode,
    required CareSceneMotionPreference motionPreference,
    required ValueChanged<CareSceneSignal> onSignal,
  }) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(mode.label),
            TextButton(
              key: const Key('signal-complete'),
              onPressed: () => onSignal(CareSceneSignal.sceneCompleted),
              child: const Text('Complete scene'),
            ),
            TextButton(
              key: const Key('signal-dismiss'),
              onPressed: () => onSignal(CareSceneSignal.sceneDismissed),
              child: const Text('Dismiss scene'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _FailFirstOutcomeRepository implements CareMemoryRepository {
  _FailFirstOutcomeRepository(this.delegate);

  final InMemoryCareMemoryRepository delegate;
  bool shouldFail = true;

  @override
  Future<List<CareRecord>> getRecords() => delegate.getRecords();

  @override
  Future<CareRecord> saveOutcome(
    CareActionCompletion completion,
    CareOutcome outcome,
  ) async {
    if (shouldFail) {
      shouldFail = false;
      throw const CareMemoryException(CareMemoryFailure.storageUnavailable);
    }
    return delegate.saveOutcome(completion, outcome);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpCare(
  WidgetTester tester, {
  required CareMemoryRepository repository,
  CareAnimationPort animationPort = const OriginalCareAnimationPort(),
  Future<RecoveryReceiptResult> Function(RecoveryReceiptDraft draft)?
  saveReceipt,
  VoidCallback? onLeaveCare,
}) async {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: CareExperience(
        careMemoryRepository: repository,
        animationPort: animationPort,
        saveReceipt: saveReceipt,
        onLeaveCare: onLeaveCare,
        performanceConstrained: true,
        now: () => DateTime(2026, 9, 23, 10),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openMode(WidgetTester tester, CareMode mode) async {
  final door = find.text(mode.label);
  await tester.scrollUntilVisible(
    door,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(
    tester.element(door),
    alignment: 0.45,
    duration: Duration.zero,
  );
  await tester.pump();
  await tester.tap(door);
  await tester.pump(const Duration(milliseconds: 400));
  if (mode == CareMode.physical) {
    await tester.tap(find.byKey(const Key('care-context-cramps')));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _completeSignalScene(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('signal-complete')));
  await tester.pumpAndSettle();
  expect(find.text('You stayed with the moment.'), findsOneWidget);
}

Future<void> _finishProductionScene(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('care-break-complete')));
  await tester.pump(const Duration(milliseconds: 500));
  if (find.text('You stayed with the moment.').evaluate().isEmpty) {
    expect(find.text('Done for now'), findsOneWidget);
    await tester.tap(find.text('Done for now'));
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final mode in CareMode.values) {
    testWidgets('${mode.name} production completion reaches check-back', (
      tester,
    ) async {
      await _pumpCare(tester, repository: InMemoryCareMemoryRepository());
      await _openMode(tester, mode);
      await _finishProductionScene(tester);

      expect(find.text('You stayed with the moment.'), findsOneWidget);
      expect(find.text('Better'), findsOneWidget);
      expect(find.text('Same'), findsOneWidget);
      expect(find.text('Worse'), findsOneWidget);
      expect(find.text('Leave for now'), findsNothing);
      expect(find.text("I'll check back later"), findsNothing);
    });
  }

  testWidgets('Skip returns to Care landing and writes nothing', (
    tester,
  ) async {
    final repository = InMemoryCareMemoryRepository();
    var leaveCount = 0;
    await _pumpCare(
      tester,
      repository: repository,
      animationPort: _SignalPort(),
      onLeaveCare: () => leaveCount++,
    );
    await _openMode(tester, CareMode.heavy);
    await _completeSignalScene(tester);

    await tester.tap(find.text('Skip — nothing needs saving'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('care-landing')), findsOneWidget);
    expect(await repository.getRecords(), isEmpty);
    expect(leaveCount, 0);
  });

  testWidgets('system back mirrors Skip and writes nothing', (tester) async {
    final repository = InMemoryCareMemoryRepository();
    var leaveCount = 0;
    await _pumpCare(
      tester,
      repository: repository,
      animationPort: _SignalPort(),
      onLeaveCare: () => leaveCount++,
    );
    await _openMode(tester, CareMode.heavy);
    await _completeSignalScene(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('care-landing')), findsOneWidget);
    expect(await repository.getRecords(), isEmpty);
    expect(leaveCount, 0);
  });

  testWidgets('scene dismissal returns to landing without a check-back', (
    tester,
  ) async {
    final repository = InMemoryCareMemoryRepository();
    await _pumpCare(
      tester,
      repository: repository,
      animationPort: _SignalPort(),
    );
    await _openMode(tester, CareMode.heavy);
    await tester.tap(find.byKey(const Key('signal-dismiss')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('care-landing')), findsOneWidget);
    expect(find.text('You stayed with the moment.'), findsNothing);
    expect(await repository.getRecords(), isEmpty);
  });

  testWidgets('failed outcome save retries once without a duplicate', (
    tester,
  ) async {
    final delegate = InMemoryCareMemoryRepository();
    final repository = _FailFirstOutcomeRepository(delegate);
    await _pumpCare(
      tester,
      repository: repository,
      animationPort: _SignalPort(),
    );
    await _openMode(tester, CareMode.heavy);
    await _completeSignalScene(tester);
    await tester.tap(find.text('Better'));
    await tester.pump();
    await tester.tap(find.text('Save this check-back'));
    await tester.pumpAndSettle();

    const message =
        'Letter Within could not update private Care memory. Try again.';
    expect(find.text(message), findsOneWidget);
    expect(await delegate.getRecords(), isEmpty);

    await tester.tap(find.text('Save this check-back'));
    await tester.pumpAndSettle();

    expect(await delegate.getRecords(), hasLength(1));
    expect(
      find.text('Return to daylight'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .join(' | '),
    );
    expect(find.text('Leave for now'), findsNothing);
  });

  testWidgets('saved check-back keeps health-note and reflection paths', (
    tester,
  ) async {
    final repository = InMemoryCareMemoryRepository();
    var leaveCount = 0;
    await _pumpCare(
      tester,
      repository: repository,
      animationPort: _SignalPort(),
      saveReceipt: (_) => throw UnimplementedError(),
      onLeaveCare: () => leaveCount++,
    );
    await _openMode(tester, CareMode.heavy);
    await _completeSignalScene(tester);
    await tester.tap(find.text('Same'));
    await tester.pump();
    await tester.tap(find.text('Save this check-back'));
    await tester.pumpAndSettle();

    expect(
      find.text('Return to daylight'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .join(' | '),
    );
    expect(find.text('Leave for now'), findsNothing);
    expect(find.text('Add this moment to your health record?'), findsOneWidget);

    await tester.ensureVisible(find.text('Yes, add the note'));
    await tester.pump();
    await tester.tap(find.text('Yes, add the note'));
    await tester.pumpAndSettle();
    expect(find.text('What was this moment?'), findsOneWidget);
    Navigator.of(tester.element(find.text('What was this moment?'))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Write a reflection'));
    await tester.pump();
    await tester.tap(find.text('Write a reflection'));
    await tester.pumpAndSettle();
    expect(find.text('A few words for future you'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'I needed a quieter minute.',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Keep this reflection'));
    await tester.pump();
    await tester.tap(find.text('Keep this reflection'));
    await tester.pumpAndSettle();

    expect(await repository.getRecords(), hasLength(1));
    expect(await repository.getReflections(), hasLength(1));
    expect(find.text('Reflection kept for future you.'), findsOneWidget);

    await tester.ensureVisible(find.text('Return to daylight'));
    await tester.tap(find.text('Return to daylight'));
    await tester.pumpAndSettle();
    expect(leaveCount, 1);
  });
}
