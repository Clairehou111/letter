import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/care/presentation/breath_flow.dart';
import 'package:letter_mobile/features/care/presentation/care_motion_flow.dart';
import 'package:letter_mobile/features/care/presentation/prototype_scene_painter.dart';

const _frameInterval = Duration(microseconds: 33333);

CareMode _careMode(String name) => CareMode.values.byName(name);

CareSceneVariant _sceneVariant(String? name) => name == null
    ? CareSceneVariant.aBaseline
    : CareSceneVariant.values.byName(name);

PhysicalCareContext? _physicalContext(String? name) =>
    name == null ? null : PhysicalCareContext.values.byName(name);

Future<void> _pumpScene(
  WidgetTester tester, {
  required CareMode mode,
  required int seed,
  required CareSceneVariant sceneVariant,
  required double intensity,
  bool disableAnimations = false,
}) async {
  const size = Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    MaterialApp(
      theme: LetterTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: disableAnimations),
        child: CareBreakFlow(
          mode: mode,
          motionModel: PrototypeSceneModel(random: math.Random(seed)),
          sceneVariant: sceneVariant,
          initialIntensity: intensity,
          onBack: () {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(_frameInterval);
}

Finder _captureBoundary(CareMode mode) {
  final surface = find.byKey(Key('care-break-surface-${mode.name}'));
  return find
      .descendant(of: surface, matching: find.byType(RepaintBoundary))
      .first;
}

Future<void> _writeFrame(
  WidgetTester tester,
  Finder boundaryFinder,
  Directory directory,
  int index,
) async {
  final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
    boundaryFinder,
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 0.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) {
      throw StateError('Could not encode Care audit frame.');
    }
    final name = 'frame_${index.toString().padLeft(4, '0')}.png';
    await File('${directory.path}/$name').writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
  });
}

Future<void> _captureScenario(
  WidgetTester tester, {
  required Directory root,
  required String id,
  required CareMode mode,
  required int seed,
  CareSceneVariant sceneVariant = CareSceneVariant.aBaseline,
  PhysicalCareContext? physicalContext,
  bool disableAnimations = false,
  int frameCount = 120,
  Duration simulatedFrameInterval = _frameInterval,
  double intensity = 0.6,
  String interaction = 'none',
}) async {
  await _pumpScene(
    tester,
    mode: mode,
    seed: seed,
    sceneVariant: sceneVariant,
    intensity: intensity,
    disableAnimations: disableAnimations,
  );
  if (physicalContext != null) {
    await tester.tap(find.byKey(Key('care-context-${physicalContext.name}')));
    await tester.pump(_frameInterval);
  }
  final directory = Directory('${root.path}/$id');
  await tester.runAsync(() => directory.create(recursive: true));
  final surface = find.byKey(Key('care-break-surface-${mode.name}'));
  final rect = tester.getRect(surface);
  TestGesture? gesture;
  final frameSeconds = simulatedFrameInterval.inMicroseconds / 1000000;
  int at(double seconds) => (seconds / frameSeconds).round();

  for (var frame = 0; frame < frameCount; frame++) {
    if (!disableAnimations && physicalContext != PhysicalCareContext.headache) {
      final startsGesture = switch (interaction) {
        'explode_hold_reopen' ||
        'tap_close' ||
        'racing_sweep' ||
        'heavy_swipe' ||
        'space_hold' => frame == at(0.5),
        _ => false,
      };
      if (startsGesture) {
        gesture = await tester.startGesture(
          Offset(rect.center.dx, rect.top + rect.height * 0.48),
        );
      }
      if (interaction == 'racing_sweep' &&
          gesture != null &&
          frame > at(0.5) &&
          frame < at(2.5)) {
        final progress = (frame - at(0.5)) / math.max(1, at(2.0));
        await gesture.moveTo(
          Offset(
            rect.center.dx +
                math.sin(progress * math.pi * 2) * rect.width * 0.12,
            rect.top + rect.height * (0.25 + progress * 0.5),
          ),
        );
      }
      if (interaction == 'heavy_swipe' &&
          gesture != null &&
          frame > at(0.5) &&
          frame < at(3.5)) {
        final progress = (frame - at(0.5)) / math.max(1, at(3.0));
        await gesture.moveTo(
          Offset(
            rect.center.dx +
                math.sin(progress * math.pi * 1.5) * rect.width * 0.18,
            rect.top + rect.height * (0.42 + progress * 0.16),
          ),
        );
      }
      final releasesGesture = switch (interaction) {
        'tap_close' => frame == at(0.5) + 1,
        'explode_hold_reopen' => frame == at(1.5),
        'racing_sweep' => frame == at(2.5),
        'heavy_swipe' => frame == at(3.5),
        'space_hold' => frame == at(2.0),
        _ => false,
      };
      if (gesture != null && releasesGesture) {
        await gesture.up();
        gesture = null;
      }
      if (interaction == 'explode_hold_reopen' && frame == at(4.5)) {
        gesture = await tester.startGesture(rect.center);
      }
      if (interaction == 'explode_hold_reopen' &&
          gesture != null &&
          frame == at(4.5) + 1) {
        await gesture.up();
        gesture = null;
      }
    }
    await tester.pump(simulatedFrameInterval);
    await _writeFrame(tester, _captureBoundary(mode), directory, frame);
  }
  if (gesture != null) {
    await gesture.up();
  }
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _captureBreathScenario(
  WidgetTester tester, {
  required Directory root,
  required String id,
  required String pattern,
  required int frameCount,
  required Duration simulatedFrameInterval,
  required bool disableAnimations,
}) async {
  const size = Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    MaterialApp(
      theme: LetterTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: disableAnimations),
        child: BreathFlow(onClose: () {}),
      ),
    ),
  );
  await tester.pump();
  if (pattern != 'coherent') {
    await tester.tap(find.byKey(const Key('breath-options')));
    await tester.pump();
    final label = switch (pattern) {
      'longExhale' => 'Longer out-breath',
      'box' => 'Four corners',
      _ => throw ArgumentError.value(pattern, 'pattern'),
    };
    await tester.tap(find.text(label));
    await tester.pump();
  }
  final directory = Directory('${root.path}/$id');
  await tester.runAsync(() => directory.create(recursive: true));
  final boundary = find.byKey(const Key('breath-animation-surface'));
  for (var frame = 0; frame < frameCount; frame++) {
    await tester.pump(simulatedFrameInterval);
    await _writeFrame(tester, boundary, directory, frame);
  }
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  final outputPath = Platform.environment['CARE_AUDIT_OUTPUT_DIR'];
  final scenarioFilterText =
      Platform.environment['CARE_AUDIT_SCENARIO_IDS'] ??
      Platform.environment['CARE_AUDIT_SCENARIO_ID'];
  final scenarioFilter = scenarioFilterText
      ?.split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();

  testWidgets(
    'captures deterministic Care animation frame sequences',
    (tester) async {
      final root = Directory(outputPath!);
      await tester.runAsync(() => root.create(recursive: true));
      addTearDown(tester.view.reset);

      final configText = await tester.runAsync(
        () => File('tool/care_audit/scenarios.json').readAsString(),
      );
      final config = jsonDecode(configText!) as Map<String, dynamic>;
      final scenarios = config['scenarios'] as List<dynamic>;
      for (final raw in scenarios) {
        final scenario = raw as Map<String, dynamic>;
        if (scenarioFilter != null &&
            !scenarioFilter.contains(scenario['id'])) {
          continue;
        }
        if (scenario['mode'] == 'breath') {
          await _captureBreathScenario(
            tester,
            root: root,
            id: scenario['id'] as String,
            pattern: scenario['pattern'] as String,
            frameCount: scenario['frame_count'] as int,
            simulatedFrameInterval: Duration(
              microseconds: scenario['frame_interval_us'] as int,
            ),
            disableAnimations: scenario['reduced_motion'] as bool? ?? false,
          );
          continue;
        }
        await _captureScenario(
          tester,
          root: root,
          id: scenario['id'] as String,
          mode: _careMode(scenario['mode'] as String),
          seed: scenario['seed'] as int,
          sceneVariant: _sceneVariant(scenario['variant'] as String?),
          physicalContext: _physicalContext(scenario['context'] as String?),
          disableAnimations: scenario['reduced_motion'] as bool? ?? false,
          frameCount: scenario['frame_count'] as int,
          simulatedFrameInterval: Duration(
            microseconds: scenario['frame_interval_us'] as int,
          ),
          intensity: (scenario['intensity'] as num?)?.toDouble() ?? 0.6,
          interaction: scenario['interaction'] as String? ?? 'none',
        );
      }
    },
    skip: outputPath == null,
  );
}
