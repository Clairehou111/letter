import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/care/presentation/care_break_flow.dart';
import 'package:letter_mobile/features/care/presentation/care_sound_engine.dart';
import 'package:letter_mobile/features/care/presentation/prototype_scene_painter.dart';

class _FakeCareSoundEngine extends CareSoundEngine {
  _FakeCareSoundEngine({this.starts = true});

  final bool starts;
  int playCount = 0;
  final List<double> outsideValues = [];

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
  Future<void> stop() async {}

  @override
  Future<void> setOutside(double value) async {
    outsideValues.add(value);
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
  VoidCallback? onCompleted,
  VoidCallback? onLeave,
  VoidCallback? onPracticalHelp,
  CareSoundEngine? soundEngine,
  PrototypeSceneModel? motionModel,
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
          onCompleted: onCompleted,
          onLeaveCare: onLeave ?? () {},
          onPracticalHelp: onPracticalHelp ?? () {},
          soundEngine: soundEngine,
          motionModel: motionModel,
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
  await tester.tap(find.byKey(const Key('care-break-complete')));
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
  testWidgets('bundles all five original prototype sound loops', (
    tester,
  ) async {
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

      expect(
        find.byKey(Key('care-break-surface-${mode.name}')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('care-motion-line')), findsOneWidget);
      expect(find.byKey(const Key('care-break-complete')), findsOneWidget);
      expect(find.byKey(const Key('care-path-touch')), findsNothing);
      expect(find.byType(TextField), findsNothing);

      await finishScene(tester);
      if (mode == CareMode.explode) {
        expect(finished, isTrue);
      } else {
        expect(find.byKey(const Key('care-rest-leave')), findsOneWidget);
        expect(finished, isFalse);
        await tester.tap(find.byKey(const Key('care-rest-leave')));
        await tester.pumpAndSettle();
      }
      expect(finished, isTrue);
    });
  }

  testWidgets('rest overlay can resume the settled scene', (tester) async {
    var finished = false;
    await pumpBreak(tester, CareMode.heavy, onCompleted: () => finished = true);

    await finishScene(tester);
    expect(find.byKey(const Key('care-rest-leave')), findsOneWidget);
    await tester.tap(find.byKey(const Key('care-stay-longer')));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(const Key('care-break-surface-heavy')), findsOneWidget);
    expect(find.byKey(const Key('care-rest-leave')), findsNothing);
    expect(finished, isFalse);
  });

  testWidgets('single back control and safety remain reachable at large text', (
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
    expect(
      tester.getSize(find.byKey(const Key('care-break-safety'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(find.byKey(const Key('care-break-safety')).hitTestable(), findsOne);

    await tester.tap(find.byKey(const Key('care-break-back')));
    expect(backed, isTrue);
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
    expect(find.byKey(const Key('care-rest-leave')), findsOneWidget);
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

  testWidgets('motion words use the prototype 8.5 second breath', (
    tester,
  ) async {
    await pumpBreak(tester, CareMode.heavy);

    expect(find.text('crying is fine here.'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 8600));
    expect(find.byKey(const Key('care-motion-line')), findsNothing);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('this is not you failing.'), findsOneWidget);
  });

  testWidgets('stay a moment returns to the settled scene', (tester) async {
    var finished = false;
    await pumpBreak(tester, CareMode.heavy, onCompleted: () => finished = true);

    await finishScene(tester);
    expect(find.byKey(const Key('care-stay-moment')), findsOneWidget);
    await tester.tap(find.byKey(const Key('care-stay-moment')));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byKey(const Key('care-break-surface-heavy')), findsOneWidget);
    expect(find.byKey(const Key('care-rest-leave')), findsNothing);
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
  });

  testWidgets('sound is opt-in and confirms itself immediately', (
    tester,
  ) async {
    final sound = _FakeCareSoundEngine();
    await pumpBreak(tester, CareMode.explode, soundEngine: sound);

    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    expect(find.textContaining('Sound'), findsNothing);
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

  testWidgets('enabling sound after the door latches keeps crowd muted', (
    tester,
  ) async {
    final sound = _FakeCareSoundEngine();
    await pumpBreak(tester, CareMode.space, soundEngine: sound);
    await tester.pump(const Duration(seconds: 12));

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

  testWidgets('dismissing the rest overlay completes the activity', (
    tester,
  ) async {
    var finished = false;
    await pumpBreak(tester, CareMode.heavy, onCompleted: () => finished = true);

    await finishScene(tester);
    await tester.tap(find.byKey(const Key('care-rest-dismiss')));
    await tester.pumpAndSettle();

    expect(finished, isTrue);
  });
}
