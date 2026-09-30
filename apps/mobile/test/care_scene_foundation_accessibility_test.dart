import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/care/care_animation_port.dart';
import 'package:letter_mobile/experience/care/care_scene_foundation.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';

Future<void> _pumpScene(
  WidgetTester tester, {
  required TargetPlatform platform,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Material(
        child: CareSceneFoundation.scene(
          mode: CareMode.heavy,
          eyebrow: 'Care',
          title: 'Heavy',
          steps: const <CareSceneStep>[
            CareSceneStep(
              id: 'arrive',
              text: 'Let the moment be smaller.',
              primaryActionLabel: 'Stay here',
            ),
          ],
          motionPreference: CareSceneMotionPreference.staticFallback,
          onSignal: (_) {},
          onSafety: () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

double _focusOrderFor(WidgetTester tester, Finder control) {
  final ordered = find.ancestor(
    of: control,
    matching: find.byType(FocusTraversalOrder),
  );
  final widget = tester.widget<FocusTraversalOrder>(ordered.first);
  return (widget.order as NumericFocusOrder).order;
}

void main() {
  testWidgets('control focus order follows primary, safety, then exit', (
    tester,
  ) async {
    await _pumpScene(tester, platform: TargetPlatform.iOS);

    final primary = find.text('Stay here');
    final safety = find.text(CareSceneFoundation.defaultSafetyLine);
    final exit = find.text(CareSceneFoundation.defaultExitLabel);

    expect(_focusOrderFor(tester, primary), 3);
    expect(_focusOrderFor(tester, safety), 4);
    expect(_focusOrderFor(tester, exit), 5);
    expect(
      tester.getTopLeft(primary).dy,
      lessThan(tester.getTopLeft(safety).dy),
    );
    expect(tester.getTopLeft(safety).dy, lessThan(tester.getTopLeft(exit).dy));
  });

  for (final target in <(TargetPlatform, double)>[
    (TargetPlatform.iOS, 44),
    (TargetPlatform.android, 48),
  ]) {
    testWidgets('safety target is at least ${target.$2} on ${target.$1.name}', (
      tester,
    ) async {
      await _pumpScene(tester, platform: target.$1);

      final safetyInkWell = find.ancestor(
        of: find.text(CareSceneFoundation.defaultSafetyLine),
        matching: find.byType(InkWell),
      );
      expect(safetyInkWell, findsOneWidget);
      expect(
        tester.getSize(safetyInkWell).height,
        greaterThanOrEqualTo(target.$2),
      );
      expect(safetyInkWell.hitTestable(), findsOneWidget);
    });
  }
}
