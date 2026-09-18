import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/care/presentation/care_motion_flow.dart';
import 'package:letter_mobile/features/care/presentation/care_sound_engine.dart';
import 'package:letter_mobile/features/care/presentation/prototype_scene_painter.dart';

class _FakeCareSoundEngine extends CareSoundEngine {
  _FakeCareSoundEngine({this.starts = true});

  final bool starts;
  int playCount = 0;
  int stopCount = 0;
  final List<double> outsideValues = [];
  final List<double> sceneProgressValues = [];

  @override
  Future<bool> play(
    CareMode mode, {
    bool settled = false,
    bool words = false,
    double intensity = 0.6,
  }) async {
    playCount += 1;
    return starts;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }

  @override
  Future<void> setOutside(double value) async {
    outsideValues.add(value);
  }

  @override
  Future<void> setSceneProgress(double value) async {
    sceneProgressValues.add(value);
  }

  @override
  Future<void> dispose() async {}
}

Future<void> pumpBreak(
  WidgetTester tester,
  CareMode mode, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = false,
  VoidCallback? onBack,
  VoidCallback? onSafety,
  VoidCallback? onCompleted,
  CareSoundEngine? soundEngine,
  PrototypeSceneModel? motionModel,
  double sceneSeconds = 90,
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
        child: CareBreakFlow(
          key: ValueKey(mode),
          mode: mode,
          onBack: onBack ?? () {},
          onSafety: onSafety,
          onCompleted: onCompleted,
          soundEngine: soundEngine,
          motionModel: motionModel,
          sceneSeconds: sceneSeconds,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> enterScene(WidgetTester tester, CareMode mode) async {
  if (mode == CareMode.physical) {
    await tester.tap(find.byKey(const Key('care-context-cramps')));
    await tester.pump();
  }
}

Future<void> finishScene(WidgetTester tester) async {
  final directFinish = find.byKey(const Key('care-break-complete'));
  if (directFinish.evaluate().isNotEmpty) {
    await tester.tap(directFinish);
    await tester.pumpAndSettle();
    return;
  }
  await tester.tap(find.byKey(const Key('care-scene-adjust')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('care-adjust-settle-now')));
  await tester.pumpAndSettle();
}

PrototypeScenePainter prototypePainter(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .whereType<PrototypeScenePainter>()
      .single;
}

void main() {
  testWidgets('30-second reset uses a full visual arc and settles on time', (
    tester,
  ) async {
    var completed = false;
    await pumpBreak(
      tester,
      CareMode.heavy,
      sceneSeconds: 30,
      onCompleted: () => completed = true,
    );

    await tester.pump(const Duration(seconds: 15));
    expect(prototypePainter(tester).progress, closeTo(.5, .03));
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('care-check-in-when-ready')), findsOneWidget);
    expect(completed, isFalse);
  });

  testWidgets('bundles all five selected runtime sound loops', (tester) async {
    await pumpBreak(tester, CareMode.explode);

    for (final name in ['explode', 'heavy', 'racing', 'space', 'physical']) {
      final bytes = await rootBundle.load(
        'assets/audio/care/prototype/$name.mp3',
      );
      expect(bytes.lengthInBytes, greaterThan(100000), reason: name);
    }
  });

  for (final mode in CareMode.values) {
    testWidgets('${mode.name} enters its motion and reaches a finite end', (
      tester,
    ) async {
      var finished = false;
      await pumpBreak(tester, mode, onCompleted: () => finished = true);
      await enterScene(tester, mode);
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byKey(Key('care-break-surface-${mode.name}')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('care-motion-line')), findsOneWidget);
      expect(find.byKey(const Key('care-scene-adjust')), findsOneWidget);
      expect(find.byKey(const Key('care-path-touch')), findsNothing);
      expect(find.byType(TextField), findsNothing);

      await finishScene(tester);
      if (mode == CareMode.explode) {
        expect(finished, isTrue);
      } else {
        expect(
          find.byKey(const Key('care-check-in-when-ready')),
          findsOneWidget,
        );
        expect(finished, isFalse);
        await tester.tap(find.byKey(const Key('care-check-in-when-ready')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-moment-easier')));
        await tester.pumpAndSettle();
      }
      expect(finished, isTrue);
    });
  }

  testWidgets('settled scene can hold another quiet minute', (tester) async {
    var finished = false;
    await pumpBreak(tester, CareMode.heavy, onCompleted: () => finished = true);

    await finishScene(tester);
    expect(find.byKey(const Key('care-check-in-when-ready')), findsOneWidget);
    await tester.tap(find.byKey(const Key('care-stay-longer')));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(const Key('care-break-surface-heavy')), findsOneWidget);
    expect(find.byKey(const Key('care-check-in-when-ready')), findsNothing);
    expect(finished, isFalse);

    await tester.pump(const Duration(seconds: 61));
    expect(find.byKey(const Key('care-check-in-when-ready')), findsOneWidget);
  });

  testWidgets('natural ending lands softly and keeps ambience continuous', (
    tester,
  ) async {
    final sound = _FakeCareSoundEngine();
    await pumpBreak(tester, CareMode.heavy, soundEngine: sound);
    await tester.tap(find.byKey(const Key('care-break-sound')));
    await tester.pump();

    await tester.pump(const Duration(seconds: 76));
    expect(find.byKey(const Key('care-scene-adjust')), findsNothing);
    expect(find.byKey(const Key('care-check-in-when-ready')), findsNothing);

    await tester.pump(const Duration(seconds: 14));
    expect(find.text('You did not have to manage the rain'), findsOneWidget);
    expect(find.byKey(const Key('care-check-in-when-ready')), findsOneWidget);
    expect(sound.stopCount, 0);
    expect(sound.sceneProgressValues.last, 1);
  });

  testWidgets('heavy touch creates an optional local scene response', (
    tester,
  ) async {
    await pumpBreak(tester, CareMode.heavy);
    final surface = find.byKey(const Key('care-break-surface-heavy'));
    final gesture = await tester.startGesture(tester.getCenter(surface));
    await tester.pump(const Duration(milliseconds: 32));

    expect(prototypePainter(tester).touchPoint, isNotNull);
    await gesture.moveBy(const Offset(36, 18));
    await tester.pump(const Duration(milliseconds: 32));
    expect(prototypePainter(tester).pointerSpeed, greaterThan(0));

    await gesture.up();
    await tester.pump();
    expect(prototypePainter(tester).touchPoint, isNull);
  });

  testWidgets('active heavy scene keeps adjustments compact and on demand', (
    tester,
  ) async {
    await pumpBreak(tester, CareMode.heavy);

    expect(find.byKey(const Key('care-scene-adjust')), findsOneWidget);
    expect(find.byKey(const Key('care-motion-intensity')), findsNothing);
    expect(find.text('Breath guide'), findsNothing);

    await tester.tap(find.byKey(const Key('care-scene-adjust')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('care-motion-intensity')), findsOneWidget);
    expect(find.text('Adjust the scene'), findsOneWidget);
  });

  testWidgets('settled scene preserves immersion and offers quiet choices', (
    tester,
  ) async {
    await pumpBreak(tester, CareMode.heavy);
    await finishScene(tester);

    expect(find.byKey(const Key('care-check-in-when-ready')), findsOneWidget);
    expect(find.text('Check how it felt'), findsOneWidget);
    expect(find.text('Stay a little longer'), findsOneWidget);
    expect(find.text('Done for now'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('single back control remains reachable without a safety footer', (
    tester,
  ) async {
    var backed = false;
    await pumpBreak(
      tester,
      CareMode.racing,
      size: const Size(320, 700),
      textScale: 2,
      disableAnimations: true,
      onBack: () => backed = true,
    );

    expect(
      tester.getSize(find.byKey(const Key('care-break-back'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(find.byKey(const Key('care-break-exit')), findsNothing);
    expect(find.byKey(const Key('care-break-safety')), findsNothing);

    await tester.tap(find.byKey(const Key('care-break-back')));
    expect(backed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scene support stays reachable without compact-width overflow', (
    tester,
  ) async {
    var opened = false;
    await pumpBreak(
      tester,
      CareMode.heavy,
      size: const Size(320, 700),
      textScale: 2,
      onSafety: () => opened = true,
    );

    expect(find.byKey(const Key('care-break-safety')), findsOneWidget);
    expect(find.byKey(const Key('care-scene-adjust')), findsOneWidget);
    expect(find.byKey(const Key('care-break-complete')), findsOneWidget);

    await tester.tap(find.byKey(const Key('care-break-safety')));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion enters a quiet complete scene automatically', (
    tester,
  ) async {
    await pumpBreak(tester, CareMode.heavy, disableAnimations: true);

    expect(find.byKey(const Key('care-break-surface-heavy')), findsOneWidget);
    expect(find.byKey(const Key('care-motion-line')), findsOneWidget);
    expect(find.byKey(const Key('care-break-sound')), findsNothing);
    expect(find.byKey(const Key('care-break-extend')), findsNothing);
    await finishScene(tester);
    expect(find.byKey(const Key('care-check-in-when-ready')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('anger motion matches the visual baseline', (tester) async {
    await pumpBreak(
      tester,
      CareMode.explode,
      motionModel: PrototypeSceneModel(random: math.Random(8)),
    );
    await tester.pump(const Duration(seconds: 8));

    await expectLater(
      find.byType(CareBreakFlow),
      matchesGoldenFile('goldens/care_break_explode_390x844.png'),
    );
  });

  testWidgets('anger hold and implosion match prototype checkpoints', (
    tester,
  ) async {
    await pumpBreak(
      tester,
      CareMode.explode,
      motionModel: PrototypeSceneModel(random: math.Random(8)),
    );
    await tester.pump(const Duration(milliseconds: 800));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('care-break-surface-explode'))),
    );
    await tester.pump(const Duration(seconds: 1));
    await expectLater(
      find.byType(CareBreakFlow),
      matchesGoldenFile('goldens/care_break_explode_held_390x844.png'),
    );

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 1200));
    await expectLater(
      find.byType(CareBreakFlow),
      matchesGoldenFile('goldens/care_break_explode_closing_390x844.png'),
    );
  });

  testWidgets('anger interaction replaces scheduled copy with one seal cue', (
    tester,
  ) async {
    await pumpBreak(tester, CareMode.explode);
    final surface = find.byKey(const Key('care-break-surface-explode'));

    expect(find.text('you are not too much.'), findsOneWidget);
    await tester.tap(surface);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('you are not too much.'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('care-motion-line')), findsOneWidget);
    final initialLargeOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const Key('seal-inscription-large')),
        matching: find.byType(Opacity),
      ),
    );
    final initialMediumOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const Key('seal-inscription-medium')),
        matching: find.byType(Opacity),
      ),
    );
    expect(
      initialLargeOpacity.opacity,
      greaterThan(initialMediumOpacity.opacity),
    );
    await expectLater(
      find.byType(CareBreakFlow),
      matchesGoldenFile('goldens/care_break_explode_sealed_390x844.png'),
    );

    await tester.pump(const Duration(seconds: 2));
    final middleLargeOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const Key('seal-inscription-large')),
        matching: find.byType(Opacity),
      ),
    );
    final middleMediumOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const Key('seal-inscription-medium')),
        matching: find.byType(Opacity),
      ),
    );
    expect(
      middleMediumOpacity.opacity,
      greaterThan(middleLargeOpacity.opacity),
    );

    await tester.pump(const Duration(seconds: 2));
    final lateMediumOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const Key('seal-inscription-medium')),
        matching: find.byType(Opacity),
      ),
    );
    final lateSmallOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const Key('seal-inscription-small')),
        matching: find.byType(Opacity),
      ),
    );
    expect(lateSmallOpacity.opacity, greaterThan(lateMediumOpacity.opacity));

    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('care-motion-line')), findsNothing);
  });

  testWidgets('racing motion spans the full scene', (tester) async {
    await pumpBreak(
      tester,
      CareMode.racing,
      motionModel: PrototypeSceneModel(random: math.Random(10)),
    );
    await tester.pump(const Duration(seconds: 2));

    await expectLater(
      find.byType(CareBreakFlow),
      matchesGoldenFile('goldens/care_break_racing_390x844.png'),
    );
  });

  testWidgets('ported scenes keep the prototype local clocks and interaction', (
    tester,
  ) async {
    final explode = PrototypeSceneModel(random: math.Random(1));
    await pumpBreak(tester, CareMode.explode, motionModel: explode);
    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('care-break-surface-explode'))),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(prototypePainter(tester).progress, closeTo(0.72, 0.03));
    await hold.up();

    final space = PrototypeSceneModel(random: math.Random(2));
    await pumpBreak(tester, CareMode.space, motionModel: space);
    await tester.pump(const Duration(seconds: 6));
    expect(prototypePainter(tester).progress, closeTo(0.5, 0.02));

    final heavy = PrototypeSceneModel(random: math.Random(3));
    await pumpBreak(tester, CareMode.heavy, motionModel: heavy);
    await tester.pump(const Duration(seconds: 45));
    expect(prototypePainter(tester).progress, closeTo(0.5, 0.02));

    final racing = PrototypeSceneModel(random: math.Random(4));
    await pumpBreak(tester, CareMode.racing, motionModel: racing);
    final surface = find.byKey(const Key('care-break-surface-racing'));
    final rect = tester.getRect(surface);
    final comb = await tester.startGesture(
      Offset(rect.center.dx, rect.top + 40),
    );
    for (var step = 1; step <= 8; step++) {
      await comb.moveTo(
        Offset(rect.center.dx, rect.top + rect.height * step / 9),
      );
      await tester.pump(const Duration(milliseconds: 180));
    }
    expect(racing.calm, greaterThan(0));
    await comb.up();
  });

  testWidgets('heavy check-in matches the visual baseline', (tester) async {
    await pumpBreak(
      tester,
      CareMode.heavy,
      motionModel: PrototypeSceneModel(random: math.Random(9)),
    );
    await finishScene(tester);

    await expectLater(
      find.byType(CareBreakFlow),
      matchesGoldenFile('goldens/care_break_heavy_settled_390x844.png'),
    );
  });

  testWidgets('only one fading line is layered over motion', (tester) async {
    await pumpBreak(tester, CareMode.explode);

    expect(find.byKey(const Key('care-motion-line')), findsOneWidget);
    expect(find.byKey(const Key('care-motion-guide')), findsNothing);
    expect(find.byKey(const Key('care-motion-cue')), findsNothing);
    expect(find.byKey(const Key('care-path-words')), findsNothing);
    expect(find.byKey(const Key('care-words-field')), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('motion words leave long quiet intervals', (tester) async {
    await pumpBreak(tester, CareMode.heavy);

    expect(find.text('crying is fine here'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 7100));
    expect(find.byKey(const Key('care-motion-line')), findsNothing);
    await tester.pump(const Duration(milliseconds: 9400));
    expect(find.text('you do not have to hold this up'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 7100));
    expect(find.byKey(const Key('care-motion-line')), findsNothing);
    await tester.pump(const Duration(milliseconds: 9400));
    expect(find.text('let the rain get lighter on its own'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 7100));
    expect(find.byKey(const Key('care-motion-line')), findsNothing);
    await tester.pump(const Duration(seconds: 20));
    expect(find.byKey(const Key('care-motion-line')), findsNothing);
  });

  testWidgets('not sure closes check-in and keeps the settled scene', (
    tester,
  ) async {
    var finished = false;
    await pumpBreak(tester, CareMode.heavy, onCompleted: () => finished = true);

    await finishScene(tester);
    await tester.tap(find.byKey(const Key('care-check-in-when-ready')));
    await tester.pumpAndSettle();
    expect(find.text('How is this moment now?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('care-moment-not-sure')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('care-break-surface-heavy')), findsOneWidget);
    expect(find.byKey(const Key('care-check-in-when-ready')), findsOneWidget);
    expect(finished, isFalse);
  });

  testWidgets('headache context is quiet, dim, and has no sound', (
    tester,
  ) async {
    await pumpBreak(tester, CareMode.physical);

    await tester.tap(find.byKey(const Key('care-context-headache')));
    await tester.pump();

    expect(
      find.byKey(const Key('care-break-surface-physical')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('care-break-sound')), findsNothing);
    expect(find.byKey(const Key('care-break-extend')), findsNothing);
    expect(find.text('nothing to follow here'), findsOneWidget);

    await expectLater(
      find.byType(CareBreakFlow),
      matchesGoldenFile('goldens/care_break_headache_390x844.png'),
    );

    await tester.pump(const Duration(seconds: 17));
    expect(find.text('dim, still, and quiet'), findsOneWidget);

    await tester.pump(const Duration(seconds: 73));
    expect(find.byKey(const Key('care-check-in-when-ready')), findsOneWidget);
    expect(
      find.text('Stay with the quiet, or leave when you need'),
      findsOneWidget,
    );
  });

  testWidgets('sound is opt-in and confirms itself immediately', (
    tester,
  ) async {
    final sound = _FakeCareSoundEngine();
    await pumpBreak(tester, CareMode.explode, soundEngine: sound);

    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    expect(find.text('Sound off'), findsOneWidget);
    await tester.tap(find.byKey(const Key('care-break-sound')));
    await tester.pump();
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(sound.playCount, 1);

    await tester.tap(find.byKey(const Key('care-break-sound')));
    await tester.pump();
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('away crowd is hard-muted exactly when the door latches', (
    tester,
  ) async {
    final sound = _FakeCareSoundEngine();
    await pumpBreak(tester, CareMode.space, soundEngine: sound);

    await tester.tap(find.byKey(const Key('care-break-sound')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));

    expect(sound.outsideValues, isNotEmpty);
    expect(sound.outsideValues.last, 0);
  });

  testWidgets('heavy ambience follows the slow visual settling envelope', (
    tester,
  ) async {
    final sound = _FakeCareSoundEngine();
    await pumpBreak(tester, CareMode.heavy, soundEngine: sound);

    await tester.tap(find.byKey(const Key('care-break-sound')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));

    expect(sound.sceneProgressValues, isNotEmpty);
    expect(sound.sceneProgressValues.first, closeTo(0, 0.02));
    expect(sound.sceneProgressValues.last, closeTo(1 / 3, 0.02));
  });

  testWidgets('enabling sound after the door latches keeps crowd muted', (
    tester,
  ) async {
    final sound = _FakeCareSoundEngine();
    await pumpBreak(tester, CareMode.space, soundEngine: sound);
    await tester.pump(const Duration(seconds: 12));

    await tester.tap(find.byKey(const Key('care-scene-menu')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-break-sound')));
    await tester.pump();

    expect(sound.playCount, 1);
    expect(sound.outsideValues.last, 0);
  });

  testWidgets('failed playback never falsely claims sound is on', (
    tester,
  ) async {
    await pumpBreak(
      tester,
      CareMode.explode,
      soundEngine: _FakeCareSoundEngine(starts: false),
    );

    await tester.tap(find.byKey(const Key('care-break-sound')));
    await tester.pump();

    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    expect(find.textContaining('Sound could not start'), findsOneWidget);
  });

  testWidgets('explicit in-scene check-in completes the activity', (
    tester,
  ) async {
    var finished = false;
    await pumpBreak(tester, CareMode.heavy, onCompleted: () => finished = true);

    await finishScene(tester);
    await tester.tap(find.byKey(const Key('care-check-in-when-ready')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('care-moment-easier')));
    await tester.pumpAndSettle();

    expect(finished, isTrue);
  });
}
