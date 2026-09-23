import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/care/care_animation_port.dart';
import 'package:letter_mobile/experience/care/care_completion_flow.dart';
import 'package:letter_mobile/experience/care/care_experience.dart';
import 'package:letter_mobile/experience/care/original_care_animation_port.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';

Future<void> _pumpLanding(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: CareExperience(
          careMemoryRepository: InMemoryCareMemoryRepository(),
          animationPort: const OriginalCareAnimationPort(),
          performanceConstrained: true,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpCompletion(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: Scaffold(
          body: CareCompletionFlow(
            mode: CareMode.space,
            completion: CareActionCompletion(
              mode: CareMode.space,
              actionId: 'care.boundary.guided_scene',
              actionLabel: 'Space — a room of your own',
              occurredAt: DateTime(2026, 9, 22, 12),
            ),
            careMemoryRepository: InMemoryCareMemoryRepository(),
            onLeaveCare: () {},
            onSkip: () {},
            onOpenSafety: () {},
            motionPreference: CareSceneMotionPreference.reduced,
            now: () => DateTime(2026, 9, 22, 12),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

RenderParagraph _paragraph(WidgetTester tester, String text) {
  return tester.renderObject<RenderParagraph>(find.text(text));
}

void _expectWordsUnbroken(RenderParagraph paragraph, String text) {
  for (final match in RegExp(r'\S+').allMatches(text)) {
    expect(
      paragraph.getBoxesForSelection(
        TextSelection(baseOffset: match.start, extentOffset: match.end),
      ),
      hasLength(1),
      reason: 'The word "${match.group(0)}" must not split across lines',
    );
  }
}

void _expectInsideViewport(
  WidgetTester tester,
  Finder finder,
  double viewportWidth,
) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(viewportWidth));
}

void main() {
  testWidgets('phone-grid Care labels fit at 390x844', (tester) async {
    await _pumpLanding(tester, size: const Size(390, 844));

    final ellipsized = <String>[];
    for (final mode in CareMode.values) {
      final label = find.text(mode.label);
      expect(label, findsOneWidget);
      _expectInsideViewport(tester, label, 390);
      if (_paragraph(tester, mode.label).didExceedMaxLines) {
        ellipsized.add(mode.label);
      }
    }
    expect(
      ellipsized,
      isEmpty,
      reason: 'Care door labels must remain complete',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('large-text single-column landing stays within 320 pixels', (
    tester,
  ) async {
    await _pumpLanding(tester, size: const Size(320, 700), textScale: 2);

    final ellipsized = <String>[];
    for (final mode in CareMode.values) {
      final label = find.text(mode.label);
      await tester.scrollUntilVisible(
        label,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      _expectInsideViewport(tester, label, 320);
      if (_paragraph(tester, mode.label).didExceedMaxLines) {
        ellipsized.add(mode.label);
      }
    }
    expect(
      ellipsized,
      isEmpty,
      reason: 'Large-text labels must remain complete',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('maximum accessibility text keeps every Care choice reachable', (
    tester,
  ) async {
    await _pumpLanding(tester, size: const Size(390, 844), textScale: 3.2);

    final question = _paragraph(tester, 'What feels closest\nright now?');
    expect(
      question.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 29),
      ),
      hasLength(2),
      reason: 'The two authored display lines must not split inside words',
    );
    _expectWordsUnbroken(question, 'What feels closest\nright now?');

    final scrollable = find.byType(Scrollable).first;
    final breathe = find.byKey(const Key('care-breathe-entry'));
    await tester.scrollUntilVisible(breathe, 180, scrollable: scrollable);
    _expectInsideViewport(tester, breathe, 390);
    _expectWordsUnbroken(
      _paragraph(tester, 'Breathe with me'),
      'Breathe with me',
    );

    final ellipsized = <String>[];
    for (final mode in CareMode.values) {
      final label = find.text(mode.label);
      await tester.scrollUntilVisible(label, 180, scrollable: scrollable);
      _expectInsideViewport(tester, label, 390);
      final paragraph = _paragraph(tester, mode.label);
      _expectWordsUnbroken(paragraph, mode.label);
      if (paragraph.didExceedMaxLines) {
        ellipsized.add(mode.label);
      }
    }
    expect(
      ellipsized,
      isEmpty,
      reason: 'Maximum-text Care doors must remain complete',
    );

    final exit = find.text('Return to daylight');
    await tester.scrollUntilVisible(exit, 180, scrollable: scrollable);
    _expectInsideViewport(tester, exit, 390);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completion fits phone width and has one post-save exit', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await _pumpCompletion(tester, size: const Size(390, 844));

    expect(
      _paragraph(tester, 'How does this moment feel now?').didExceedMaxLines,
      isFalse,
    );
    final leaveForNow = find.text('Leave for now');
    expect(leaveForNow, findsNothing);
    expect(find.text("I'll check back later"), findsNothing);
    final skip = find.text('Skip — nothing needs saving');
    expect(skip, findsOneWidget);
    _expectInsideViewport(tester, skip, 390);

    await tester.tap(find.text('Better'));
    await tester.pump();
    await tester.tap(find.text('Save this check-back'));
    await tester.pumpAndSettle();

    final returnToDaylight = find.text('Return to daylight');
    expect(returnToDaylight, findsOneWidget);
    expect(leaveForNow, findsNothing);
    _expectInsideViewport(tester, returnToDaylight, 390);
    expect(tester.takeException(), isNull);
  });
}
