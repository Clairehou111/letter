import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/care/presentation/care_motion_flow.dart';
import 'package:letter_mobile/features/care/presentation/prototype_scene_painter.dart';

Future<void> pumpAuditScene(
  WidgetTester tester, {
  required CareMode mode,
  bool disableAnimations = false,
}) async {
  const size = Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: LetterTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: disableAnimations),
        child: CareBreakFlow(mode: mode, onBack: () {}),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

PrototypeScenePainter auditPainter(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .whereType<PrototypeScenePainter>()
      .single;
}

void main() {
  testWidgets('reduced motion renders a still scene and hides sound', (
    tester,
  ) async {
    await pumpAuditScene(tester, mode: CareMode.heavy, disableAnimations: true);

    expect(auditPainter(tester).still, isTrue);
    expect(find.byKey(const Key('care-break-sound')), findsNothing);
  });

  testWidgets('headache physical scene is still and silent', (tester) async {
    await pumpAuditScene(tester, mode: CareMode.physical);

    await tester.tap(find.byKey(const Key('care-context-headache')));
    await tester.pump(const Duration(milliseconds: 20));

    final painter = auditPainter(tester);
    expect(painter.physicalContext, PhysicalCareContext.headache);
    expect(painter.still, isTrue);
    expect(find.byKey(const Key('care-break-sound')), findsNothing);
  });
}
