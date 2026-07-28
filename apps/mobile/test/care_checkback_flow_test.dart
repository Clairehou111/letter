import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/presentation/care_checkback_flow.dart';

Future<void> pumpCheckBack(
  WidgetTester tester, {
  CareOutcome? recordedOutcome,
  bool isPinned = false,
  bool isBusy = false,
  bool hasError = false,
  ValueChanged<CareOutcome>? onOutcome,
  VoidCallback? onSkip,
  VoidCallback? onKeepInKit,
  VoidCallback? onDone,
  VoidCallback? onRetry,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = false,
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
        child: CareCheckBackFlow(
          recordedOutcome: recordedOutcome,
          isPinned: isPinned,
          isBusy: isBusy,
          hasError: hasError,
          onOutcome: onOutcome ?? (_) {},
          onSkip: onSkip ?? () {},
          onKeepInKit: onKeepInKit ?? () {},
          onDone: onDone ?? () {},
          onRetry: onRetry,
        ),
      ),
    ),
  );
  await tester.pump();
}

void expectMinimumTarget(WidgetTester tester, String key) {
  final size = tester.getSize(find.byKey(Key(key)));
  expect(size.width, greaterThanOrEqualTo(44), reason: '$key width');
  expect(size.height, greaterThanOrEqualTo(44), reason: '$key height');
}

void main() {
  testWidgets('asks the approved single question with exactly four choices', (
    tester,
  ) async {
    await pumpCheckBack(tester);

    expect(find.text('How is this moment now?'), findsOneWidget);
    expect(find.text('Better'), findsOneWidget);
    expect(find.text('Same'), findsOneWidget);
    expect(find.text('Worse'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.byKey(const Key('care-checkback-keep')), findsNothing);
    expect(find.byKey(const Key('care-checkback-done')), findsNothing);
  });

  testWidgets('emits Better Same and Worse only after their explicit taps', (
    tester,
  ) async {
    final outcomes = <CareOutcome>[];
    await pumpCheckBack(tester, onOutcome: outcomes.add);

    expect(outcomes, isEmpty);
    await tester.tap(find.byKey(const Key('care-checkback-better')));
    await tester.tap(find.byKey(const Key('care-checkback-same')));
    await tester.tap(find.byKey(const Key('care-checkback-worse')));
    await tester.pump();

    expect(outcomes, [CareOutcome.better, CareOutcome.same, CareOutcome.worse]);
  });

  testWidgets('Skip is separate and emits no outcome', (tester) async {
    final outcomes = <CareOutcome>[];
    var skips = 0;
    await pumpCheckBack(
      tester,
      onOutcome: outcomes.add,
      onSkip: () => skips += 1,
    );

    await tester.tap(find.byKey(const Key('care-checkback-skip')));
    await tester.pump();

    expect(skips, 1);
    expect(outcomes, isEmpty);
  });

  testWidgets('preserves Worse exactly and offers explicit pinning', (
    tester,
  ) async {
    var keeps = 0;
    var dones = 0;
    await pumpCheckBack(
      tester,
      recordedOutcome: CareOutcome.worse,
      onKeepInKit: () => keeps += 1,
      onDone: () => dones += 1,
    );

    expect(find.text('Recorded as Worse.'), findsOneWidget);
    expect(find.textContaining('progress'), findsNothing);
    expect(find.byKey(const Key('care-checkback-keep')), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);

    await tester.tap(find.byKey(const Key('care-checkback-keep')));
    await tester.tap(find.byKey(const Key('care-checkback-done')));
    await tester.pump();
    expect(keeps, 1);
    expect(dones, 1);
  });

  testWidgets('shows an already pinned state without another pin action', (
    tester,
  ) async {
    await pumpCheckBack(
      tester,
      recordedOutcome: CareOutcome.same,
      isPinned: true,
    );

    expect(find.text('Recorded as Same.'), findsOneWidget);
    expect(find.text('This action is in your Care Kit.'), findsOneWidget);
    expect(find.byKey(const Key('care-checkback-keep')), findsNothing);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('busy state disables every state-changing action', (
    tester,
  ) async {
    final outcomes = <CareOutcome>[];
    var skips = 0;
    await pumpCheckBack(
      tester,
      isBusy: true,
      onOutcome: outcomes.add,
      onSkip: () => skips += 1,
    );

    for (final key in [
      'care-checkback-better',
      'care-checkback-same',
      'care-checkback-worse',
    ]) {
      final button = tester.widget<OutlinedButton>(find.byKey(Key(key)));
      expect(button.onPressed, isNull);
    }
    final skip = tester.widget<TextButton>(
      find.byKey(const Key('care-checkback-skip')),
    );
    expect(skip.onPressed, isNull);
    expect(find.byKey(const Key('care-checkback-progress')), findsOneWidget);
    expect(outcomes, isEmpty);
    expect(skips, 0);
  });

  testWidgets('generic error preserves state and retry is explicit', (
    tester,
  ) async {
    var retries = 0;
    final semantics = tester.ensureSemantics();
    await pumpCheckBack(
      tester,
      recordedOutcome: CareOutcome.better,
      hasError: true,
      onRetry: () => retries += 1,
    );

    expect(find.text('Recorded as Better.'), findsOneWidget);
    expect(
      find.text('Letter could not update private Care memory. Try again.'),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.byKey(const Key('care-checkback-error'))),
      isSemantics(isLiveRegion: true),
    );

    await tester.tap(find.byKey(const Key('care-checkback-retry')));
    await tester.pump();
    expect(retries, 1);
    semantics.dispose();
  });

  testWidgets('stable controls meet the 44 logical-pixel target', (
    tester,
  ) async {
    await pumpCheckBack(tester);
    for (final key in [
      'care-checkback-better',
      'care-checkback-same',
      'care-checkback-worse',
      'care-checkback-skip',
    ]) {
      expectMinimumTarget(tester, key);
    }

    await pumpCheckBack(tester, recordedOutcome: CareOutcome.better);
    expectMinimumTarget(tester, 'care-checkback-keep');
    expectMinimumTarget(tester, 'care-checkback-done');
  });

  testWidgets('fits 320 pixels at 200 percent text with reduced motion', (
    tester,
  ) async {
    await pumpCheckBack(
      tester,
      size: const Size(320, 700),
      textScale: 2,
      disableAnimations: true,
    );

    for (final key in [
      'care-checkback-better',
      'care-checkback-same',
      'care-checkback-worse',
      'care-checkback-skip',
    ]) {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pump();
      expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('question state matches the visual baseline', (tester) async {
    await pumpCheckBack(tester);

    await expectLater(
      find.byType(CareCheckBackFlow),
      matchesGoldenFile('goldens/care_checkback_question_390x844.png'),
    );
  });

  testWidgets('recorded state matches the visual baseline', (tester) async {
    await pumpCheckBack(tester, recordedOutcome: CareOutcome.worse);

    await expectLater(
      find.byType(CareCheckBackFlow),
      matchesGoldenFile('goldens/care_checkback_recorded_390x844.png'),
    );
  });
}
