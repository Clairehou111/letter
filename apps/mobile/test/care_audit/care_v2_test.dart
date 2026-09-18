import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/care/presentation/care_motion_flow.dart';
import 'package:letter_mobile/features/care/presentation/v2/care_v2_copy.dart';
import 'package:letter_mobile/features/care/presentation/v2/care_v2_kernel.dart';
import 'package:letter_mobile/features/care/presentation/v2/care_v2_scene.dart';
import 'package:letter_mobile/screens/care/care_v2_lab.dart';

Future<CareSceneV2State> pumpV2(
  WidgetTester tester,
  CareMode mode, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = false,
  CareV2TraceField? traceField,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final key = GlobalKey<CareSceneV2State>();
  await tester.pumpWidget(
    MaterialApp(
      theme: LetterTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: CareSceneV2(
          key: key,
          mode: mode,
          onBack: () {},
          traceField: traceField,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  return key.currentState!;
}

void main() {
  group('kernel', () {
    test('timeline lands then settles without any contact', () {
      expect(
        CareV2Timeline.phaseFor(
          elapsed: 10,
          sceneDuration: 90,
          extending: false,
        ),
        CareV2Phase.active,
      );
      expect(
        CareV2Timeline.phaseFor(
          elapsed: 80,
          sceneDuration: 90,
          extending: false,
        ),
        CareV2Phase.landing,
      );
      expect(
        CareV2Timeline.phaseFor(
          elapsed: 90,
          sceneDuration: 90,
          extending: false,
        ),
        CareV2Phase.settled,
      );
      expect(
        CareV2Timeline.phaseFor(
          elapsed: 140,
          sceneDuration: 150,
          extending: true,
        ),
        CareV2Phase.extending,
      );
    });

    test('traces never exceed four and repeated contact merges', () {
      final field = CareV2TraceField();
      for (var index = 0; index < 24; index++) {
        field.commit(
          Offset(0.05 + (index % 12) * 0.08, 0.1 + (index % 7) * 0.11),
          at: index.toDouble(),
        );
        expect(field.length, lessThanOrEqualTo(CareV2TraceField.maxTraces));
      }
      expect(field.length, CareV2TraceField.maxTraces);

      final near = CareV2TraceField();
      near.commit(const Offset(0.5, 0.5), at: 1);
      near.commit(const Offset(0.52, 0.51), at: 2);
      expect(near.length, 1, reason: 'nearby contacts deepen one trace');
      expect(near.traces.single.weight, greaterThan(0.34));
    });

    test('settling boost is subtle and capped', () {
      final settling = CareV2Settling();
      settling.absorbHold(400);
      expect(settling.boostSeconds, CareV2Settling.maxBoostSeconds);
      expect(settling.progress(60), lessThan(0.79));
      expect(settling.progress(90), 1);
    });

    test('rain thins to nothing and keeps a fixed drop budget', () {
      final rain = CareV2RainModel();
      expect(rain.drops.length, 30);
      expect(rain.activeDropCount(0), 30);
      expect(rain.activeDropCount(0.5), lessThan(30));
      expect(rain.activeDropCount(1), 0);
    });
  });

  group('scene', () {
    testWidgets('untouched Explode reaches the settled ending', (tester) async {
      final state = await pumpV2(tester, CareMode.explode);
      await tester.pump(const Duration(seconds: 80));
      expect(state.phase, CareV2Phase.landing);
      await tester.pump(const Duration(seconds: 11));
      expect(state.phase, CareV2Phase.settled);
      expect(find.byKey(const Key('care-v2-stay-longer')), findsOneWidget);
      expect(
        find.byKey(const Key('care-v2-check-in-when-ready')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('care-v2-done')), findsOneWidget);
    });

    testWidgets('untouched Heavy reaches the settled ending', (tester) async {
      final state = await pumpV2(tester, CareMode.heavy);
      await tester.pump(const Duration(seconds: 91));
      expect(state.phase, CareV2Phase.settled);
      expect(find.byKey(const Key('care-v2-stay-longer')), findsOneWidget);
    });

    testWidgets('stay another minute extends the settled state', (
      tester,
    ) async {
      final state = await pumpV2(tester, CareMode.heavy);
      await tester.pump(const Duration(seconds: 91));
      expect(state.phase, CareV2Phase.settled);
      await tester.tap(find.byKey(const Key('care-v2-stay-longer')));
      await tester.pump();
      expect(state.phase, CareV2Phase.extending);
      await tester.pump(const Duration(seconds: 61));
      expect(state.phase, CareV2Phase.settled);
    });

    testWidgets('frantic tapping leaves at most four traces', (tester) async {
      final state = await pumpV2(tester, CareMode.heavy);
      for (var index = 0; index < 18; index++) {
        await tester.tapAt(
          Offset(40 + (index % 9) * 34, 220 + (index % 6) * 48),
        );
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(
        state.traceField.length,
        lessThanOrEqualTo(CareV2TraceField.maxTraces),
      );
      expect(state.traceField.isEmpty, isFalse);
    });

    testWidgets('one contact leaves a persistent trace that survives to 80s', (
      tester,
    ) async {
      final state = await pumpV2(tester, CareMode.explode);
      final gesture = await tester.startGesture(const Offset(140, 300));
      await tester.pump(const Duration(seconds: 2));
      await gesture.moveBy(const Offset(18, 8));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pump();
      expect(state.traceField.length, 1);
      await tester.pump(const Duration(seconds: 78));
      expect(state.traceField.length, 1, reason: 'the trace persists');
    });

    testWidgets('sealed inscription appears once and does not return', (
      tester,
    ) async {
      await pumpV2(tester, CareMode.explode);
      final inscription = find.byKey(const Key('care-v2-seal-inscription'));
      expect(inscription, findsNothing);
      await tester.pump(const Duration(seconds: 69));
      expect(inscription, findsOneWidget);
      expect(find.text(CareV2SealInscription.text), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      expect(inscription, findsNothing);
      await tester.pump(const Duration(seconds: 20));
      expect(inscription, findsNothing);
    });

    testWidgets('copy shows one line at a time inside a fixed reserved area', (
      tester,
    ) async {
      await pumpV2(tester, CareMode.heavy);
      await tester.pump(const Duration(seconds: 8));
      expect(find.byKey(const Key('care-v2-copy-line')), findsOneWidget);
      final band = tester.getSize(find.byType(CareV2CopyLayer));
      await tester.pump(const Duration(seconds: 8));
      expect(find.byKey(const Key('care-v2-copy-line')), findsNothing);
      expect(
        tester.getSize(find.byType(CareV2CopyLayer)),
        band,
        reason: 'the reserved copy area never changes the painter bounds',
      );
    });

    testWidgets('reduced motion renders a still scene without sound control', (
      tester,
    ) async {
      final state = await pumpV2(
        tester,
        CareMode.heavy,
        disableAnimations: true,
      );
      expect(find.byKey(const Key('care-v2-heavy')), findsOneWidget);
      expect(find.byKey(const Key('care-v2-sound')), findsNothing);
      await tester.pump(const Duration(seconds: 91));
      expect(state.phase, CareV2Phase.settled);
      expect(find.byKey(const Key('care-v2-stay-longer')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('narrow width at 200% text scale does not overflow', (
      tester,
    ) async {
      await pumpV2(
        tester,
        CareMode.explode,
        size: const Size(320, 640),
        textScale: 2,
      );
      await tester.pump(const Duration(seconds: 91));
      expect(tester.takeException(), isNull);
    });
  });

  group('lab', () {
    testWidgets('lab switches between the V1 baseline and V2', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: CareV2Lab()));
      await tester.tap(find.byKey(const Key('care-lab-mode-heavy')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('care-lab-open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CareSceneV2), findsOneWidget);
      await tester.tap(find.byKey(const Key('care-v2-back')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('care-lab-version-v1')));
      await tester.tap(find.byKey(const Key('care-lab-version-v1')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('care-lab-open')));
      await tester.tap(find.byKey(const Key('care-lab-open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CareBreakFlow), findsOneWidget);
      expect(find.byType(CareSceneV2), findsNothing);
    });
  });

  group('baseline preservation', () {
    test('V1 sources are still present beside V2', () {
      for (final path in const [
        'lib/features/care/presentation/care_motion_flow.dart',
        'lib/features/care/presentation/prototype_scene_painter.dart',
        'lib/features/care/presentation/care_haptics.dart',
        'lib/features/care/presentation/care_sound_engine.dart',
        'lib/features/care/domain/care_mode.dart',
        'lib/features/care/domain/care_memory.dart',
      ]) {
        expect(File(path).existsSync(), isTrue, reason: '$path was removed');
      }
    });
  });
}
