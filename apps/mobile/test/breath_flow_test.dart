import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/presentation/breath_flow.dart';

Future<void> pumpBreath(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = false,
  VoidCallback? onClose,
  BreathAudioStarter? audioStarter,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: LetterTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: BreathFlow(
          onClose: onClose ?? () {},
          audioStarter: audioStarter,
        ),
      ),
    ),
  );
  await tester.pump();
}

class _FakeBreathAudio implements BreathAudio {
  var stopCount = 0;

  @override
  Future<void> cue(String asset, {double gain = 0.8}) async {}

  @override
  void setLevel(double value) {}

  @override
  void setSwell(double value, {double seconds = 1.6}) {}

  @override
  Future<void> stop() async => stopCount++;
}

void expectAccessibleControl(WidgetTester tester, Key key) {
  final finder = find.byKey(key);
  expect(finder, findsOneWidget);
  expect(tester.getSize(finder).height, greaterThanOrEqualTo(44));
  expect(finder.hitTestable(), findsOneWidget);
}

Future<void> openBreathMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('breath-menu')));
  await tester.pump();
}

void main() {
  testWidgets('phase cue is a stable live region that changes by phase', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpBreath(tester);

      const phaseCueKey = Key('breath-phase-cue');
      final phaseCue = find.byKey(phaseCueKey);
      expect(phaseCue, findsOneWidget);
      final initialNode = tester.getSemantics(phaseCue);
      final semanticsNodeId = initialNode.id;
      expect(
        initialNode,
        matchesSemantics(label: 'Breathe in', isLiveRegion: true),
      );

      await tester.pump(const Duration(seconds: 1));
      final withinPhaseNode = tester.getSemantics(phaseCue);
      expect(withinPhaseNode.id, semanticsNodeId);
      expect(
        withinPhaseNode,
        matchesSemantics(label: 'Breathe in', isLiveRegion: true),
      );

      await tester.pump(const Duration(milliseconds: 4600));
      final nextPhaseNode = tester.getSemantics(phaseCue);
      expect(nextPhaseNode.id, semanticsNodeId);
      expect(
        nextPhaseNode,
        matchesSemantics(label: 'Breathe out', isLiveRegion: true),
      );

      await openBreathMenu(tester);
      expect(find.text('Sound: off'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('controls remain accessible at 320 wide with 2x text', (
    tester,
  ) async {
    var closed = false;
    await pumpBreath(
      tester,
      size: const Size(320, 700),
      textScale: 2,
      onClose: () => closed = true,
    );

    expectAccessibleControl(tester, const Key('breath-back'));
    expectAccessibleControl(tester, const Key('breath-menu'));
    expect(find.byKey(const Key('breath-pattern-coherent')), findsNothing);
    expect(find.byKey(const Key('breath-sound')), findsNothing);

    await openBreathMenu(tester);
    expectAccessibleControl(tester, const Key('breath-pattern-coherent'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('breath-sound')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    expectAccessibleControl(tester, const Key('breath-sound'));
    expect(find.text('Four corners'), findsOneWidget);
    expect(find.text('Adjust'), findsNothing);
    expect(find.text('Enough for now'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('breath-back')));
    expect(closed, isTrue);
  });

  testWidgets(
    'reduced motion does not overflow at the narrow large-text size',
    (tester) async {
      await pumpBreath(
        tester,
        size: const Size(320, 700),
        textScale: 2,
        disableAnimations: true,
      );
      await tester.pump(const Duration(milliseconds: 100));

      expectAccessibleControl(tester, const Key('breath-back'));
      expectAccessibleControl(tester, const Key('breath-menu'));
      expect(find.byKey(const Key('breath-pattern-coherent')), findsNothing);
      expect(find.byKey(const Key('breath-sound')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final stage in ['init', 'load', 'start']) {
    testWidgets('failed $stage leaves breath sound off and contained', (
      tester,
    ) async {
      await pumpBreath(
        tester,
        audioStarter: (asset, {gain = 0.3, rate = 0.97}) async {
          throw StateError('$stage failed');
        },
      );

      await openBreathMenu(tester);
      await tester.tap(find.text('Sound: off'));
      await tester.pump();

      await tester.pump();
      expect(find.text('Sound: off'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('stops a completed startup that loses the toggle race', (
    tester,
  ) async {
    final audio = _FakeBreathAudio();
    final started = Completer<BreathAudio>();
    await pumpBreath(
      tester,
      audioStarter: (asset, {gain = 0.3, rate = 0.97}) => started.future,
    );

    await openBreathMenu(tester);
    await tester.tap(find.text('Sound: off'));
    await tester.pump();
    await tester.tap(find.text('Sound: a voice'));
    await tester.pump();
    await tester.tap(find.text('Sound: wordless'));
    await tester.pump();
    started.complete(audio);
    await tester.pump();
    expect(audio.stopCount, greaterThanOrEqualTo(1));
    expect(find.text('Sound: off'), findsOneWidget);
  });
}
