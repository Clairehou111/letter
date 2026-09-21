import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/care/care_experience.dart';
import 'package:letter_mobile/experience/care/original_care_animation_port.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';

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

void main() {
  testWidgets('landing is usable at compact width and large text', (
    tester,
  ) async {
    await _pumpLanding(tester, size: const Size(320, 700), textScale: 2);

    expect(find.textContaining('What feels closest'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('I want to explode'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('care-breathe-entry')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('landing uses the wide layout without overflow', (tester) async {
    await _pumpLanding(tester, size: const Size(900, 844));

    expect(find.text('I want to explode'), findsOneWidget);
    expect(find.text('My body needs care'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landing phone viewport visual preview', (tester) async {
    await _pumpLanding(tester, size: const Size(390, 844));

    await expectLater(
      find.byKey(const ValueKey<String>('care-landing')),
      matchesGoldenFile('goldens/care_landing_polish_390x844.png'),
    );
  });
}
