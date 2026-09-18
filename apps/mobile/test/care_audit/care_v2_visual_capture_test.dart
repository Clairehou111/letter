import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/care/presentation/v2/care_v2_scene.dart';

Future<void> _pumpScene(WidgetTester tester, CareMode mode) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: LetterTheme.light,
      home: CareSceneV2(mode: mode, onBack: () {}),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> _leaveTrace(WidgetTester tester, Offset point) async {
  final gesture = await tester.startGesture(point);
  await tester.pump(const Duration(seconds: 2));
  await gesture.moveBy(const Offset(12, 6));
  await tester.pump(const Duration(milliseconds: 250));
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('capture Explode V2 checkpoints', (tester) async {
    await _pumpScene(tester, CareMode.explode);
    await tester.pump(const Duration(seconds: 8));
    await expectLater(
      find.byType(CareSceneV2),
      matchesGoldenFile('goldens_v2/explode_arrival_390x844.png'),
    );

    await _leaveTrace(tester, const Offset(128, 320));
    await tester.pump(const Duration(seconds: 31));
    await expectLater(
      find.byType(CareSceneV2),
      matchesGoldenFile('goldens_v2/explode_touched_390x844.png'),
    );

    await tester.pump(const Duration(seconds: 28));
    await expectLater(
      find.byType(CareSceneV2),
      matchesGoldenFile('goldens_v2/explode_sealed_390x844.png'),
    );
  });

  testWidgets('capture Heavy V2 checkpoints', (tester) async {
    await _pumpScene(tester, CareMode.heavy);
    await tester.pump(const Duration(seconds: 8));
    await expectLater(
      find.byType(CareSceneV2),
      matchesGoldenFile('goldens_v2/heavy_arrival_390x844.png'),
    );

    await _leaveTrace(tester, const Offset(270, 360));
    await tester.pump(const Duration(seconds: 31));
    await expectLater(
      find.byType(CareSceneV2),
      matchesGoldenFile('goldens_v2/heavy_touched_390x844.png'),
    );

    await tester.pump(const Duration(seconds: 48));
    await expectLater(
      find.byType(CareSceneV2),
      matchesGoldenFile('goldens_v2/heavy_landing_390x844.png'),
    );
  });
}
