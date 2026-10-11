import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:letter_mobile/experience/components/interaction_controls.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';

void main() {
  Widget host({required VoidCallback? onTap, bool reduce = false}) {
    return MaterialApp(
      theme: ExperienceFoundation.lightTheme(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Scaffold(
          body: Center(
            child: InteractionSurface(
              onTap: onTap,
              padding: const EdgeInsets.all(16),
              child: const Text('Open record'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('press responds before release, cancellation never activates', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(host(onTap: () => activations++));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Open record')),
    );
    await tester.pump(const Duration(milliseconds: 110));
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      0.97,
    );
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0.88,
    );
    expect(activations, 0);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(activations, 0);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets('reduce motion retains activation without spatial travel', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(host(onTap: () => activations++, reduce: true));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Open record')),
    );
    await tester.pump(const Duration(milliseconds: 110));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(activations, 1);
  });

  testWidgets('disabled surface cannot activate', (tester) async {
    await tester.pumpWidget(host(onTap: null));
    await tester.tap(find.text('Open record'));
    await tester.pumpAndSettle();
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    expect(
      tester.getSize(find.byType(InteractionSurface)).height,
      greaterThanOrEqualTo(44),
    );
    expect(tester.takeException(), isNull);
  });
}
