import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/data/in_memory_impulse_buffer_repository.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/care/domain/impulse_buffer_repository.dart';
import 'package:letter_mobile/features/care/presentation/care_screen.dart';
import 'package:letter_mobile/features/care/presentation/heavy_presence_flow.dart';
import 'package:letter_mobile/features/care/presentation/racing_thoughts_flow.dart';

Future<void> pumpCare(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = false,
  ValueChanged<int>? onNavigationSelected,
  ImpulseBufferRepository? impulseBufferRepository,
  DateTime Function()? now,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: LetterTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: CareScreen(
          onNavigationSelected: onNavigationSelected ?? (_) {},
          impulseBufferRepository:
              impulseBufferRepository ?? InMemoryImpulseBufferRepository(),
          now: now ?? () => DateTime.utc(2026, 7, 28, 8),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openMode(WidgetTester tester, CareMode mode) async {
  final finder = find.byKey(Key('care-mode-${mode.name}'));
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  if (mode == CareMode.explode ||
      mode == CareMode.heavy ||
      mode == CareMode.racing) {
    await tester.pump();
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('shows all five entrances without selecting one', (tester) async {
    await pumpCare(tester);

    expect(find.text('What is closest to this moment?'), findsOneWidget);
    for (final mode in CareMode.values) {
      await tester.scrollUntilVisible(
        find.byKey(Key('care-mode-${mode.name}')),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(mode.label), findsOneWidget);
    }
    expect(find.byKey(const Key('care-protective-line')), findsNothing);
    expect(find.byKey(const Key('navigation-care')), findsOneWidget);
  });

  for (final mode in CareMode.values.where(
    (mode) =>
        mode != CareMode.explode &&
        mode != CareMode.heavy &&
        mode != CareMode.racing,
  )) {
    testWidgets('${mode.name} follows one finite response and hand-off', (
      tester,
    ) async {
      await pumpCare(tester);
      await openMode(tester, mode);

      expect(find.text(mode.sceneTitle), findsOneWidget);
      expect(find.text(mode.protectiveLine), findsNothing);
      expect(find.byKey(Key('care-respond-${mode.name}')), findsOneWidget);

      await tester.tap(find.byKey(Key('care-respond-${mode.name}')));
      await tester.pumpAndSettle();

      expect(find.text(mode.transformedLabel), findsOneWidget);
      expect(find.text(mode.protectiveLine), findsOneWidget);
      expect(find.text(mode.handOff), findsOneWidget);
      expect(find.byKey(Key('care-respond-${mode.name}')), findsNothing);

      await tester.tap(find.byKey(Key('care-handoff-${mode.name}')));
      await tester.pumpAndSettle();

      expect(find.text('What is closest to this moment?'), findsOneWidget);
      expect(find.text(mode.protectiveLine), findsNothing);
    });
  }

  testWidgets('Not now returns to the gate and close exits to Today', (
    tester,
  ) async {
    int? selectedNavigation;
    await pumpCare(
      tester,
      onNavigationSelected: (index) => selectedNavigation = index,
    );
    await openMode(tester, CareMode.space);
    await tester.tap(find.byKey(const Key('care-respond-space')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('care-not-now')));
    await tester.pumpAndSettle();

    expect(find.text('What is closest to this moment?'), findsOneWidget);

    await openMode(tester, CareMode.space);
    await tester.tap(find.byKey(const Key('care-exit')));

    expect(selectedNavigation, 2);
  });

  testWidgets('heavy entrance opens the dedicated presence flow', (
    tester,
  ) async {
    await pumpCare(tester);
    await openMode(tester, CareMode.heavy);

    expect(find.byType(HeavyPresenceFlow), findsOneWidget);
    expect(find.byKey(const Key('heavy-light')), findsOneWidget);
    expect(find.byKey(const Key('care-respond-heavy')), findsNothing);
  });

  testWidgets('racing entrance opens the dedicated convergence flow', (
    tester,
  ) async {
    await pumpCare(tester);
    await openMode(tester, CareMode.racing);

    expect(find.byType(RacingThoughtsFlow), findsOneWidget);
    expect(find.byKey(const Key('racing-convergence-surface')), findsOneWidget);
    expect(find.byKey(const Key('care-respond-racing')), findsNothing);
  });

  testWidgets('emotional safety route interrupts and can return', (
    tester,
  ) async {
    await pumpCare(tester);
    await openMode(tester, CareMode.explode);

    await tester.tap(find.byKey(const Key('angry-safety')));
    await tester.pumpAndSettle();

    expect(find.text('Immediate safety comes first.'), findsOneWidget);
    expect(
      find.textContaining('Letter cannot provide emergency help'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('return-to-care-scene')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shatter-crystal')), findsOneWidget);
  });

  testWidgets('physical safety route stops normal Care and can leave', (
    tester,
  ) async {
    int? selectedNavigation;
    await pumpCare(
      tester,
      onNavigationSelected: (index) => selectedNavigation = index,
    );
    await openMode(tester, CareMode.physical);

    await tester.tap(find.byKey(const Key('care-safety-physical')));
    await tester.pumpAndSettle();

    expect(
      find.text('This needs medical attention, not more interaction.'),
      findsOneWidget,
    );
    expect(find.textContaining('needs medical assessment'), findsOneWidget);

    await tester.tap(find.byKey(const Key('leave-care-from-safety')));
    await tester.pumpAndSettle();
    expect(selectedNavigation, 2);
  });

  testWidgets('primary controls remain at least 44 logical pixels', (
    tester,
  ) async {
    await pumpCare(tester);
    final entranceSize = tester.getSize(
      find.byKey(const Key('care-mode-explode')),
    );
    expect(entranceSize.height, greaterThanOrEqualTo(44));

    await openMode(tester, CareMode.explode);
    expect(
      tester.getSize(find.byKey(const Key('shatter-crystal'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.byKey(const Key('angry-safety'))).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('supports reduced motion at 320 width and 200 percent text', (
    tester,
  ) async {
    await pumpCare(
      tester,
      size: const Size(320, 700),
      textScale: 2,
      disableAnimations: true,
    );
    await openMode(tester, CareMode.space);
    expect(tester.takeException(), isNull);

    final scene = find.byKey(const Key('care-scene-space'));
    final respond = find.byKey(const Key('care-respond-space'));
    await tester.drag(scene, const Offset(0, -180));
    await tester.pump();
    await tester.tap(respond);
    await tester.pumpAndSettle();
    await tester.drag(scene, const Offset(0, -260));
    await tester.pump();

    expect(find.text(CareMode.space.protectiveLine), findsOneWidget);
    expect(find.text(CareMode.space.handOff), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not show fabricated personal support', (tester) async {
    await pumpCare(tester);

    for (final text in [
      'Care Kit',
      'My person',
      'Last time',
      'saved action',
      'future-self',
      'Message Maya',
    ]) {
      expect(find.textContaining(text), findsNothing);
    }
  });

  testWidgets('Care gate matches the 390 by 844 visual baseline', (
    tester,
  ) async {
    await pumpCare(tester);

    await expectLater(
      find.byType(CareScreen),
      matchesGoldenFile('goldens/care_gate_390x844.png'),
    );
  });

  testWidgets('generic transformed scene matches the visual baseline', (
    tester,
  ) async {
    await pumpCare(tester);
    await openMode(tester, CareMode.space);
    await tester.tap(find.byKey(const Key('care-respond-space')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(CareScreen),
      matchesGoldenFile('goldens/care_space_transformed_390x844.png'),
    );
  });
}
