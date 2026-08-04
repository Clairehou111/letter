import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_memory_repository.dart';
import 'package:letter_mobile/features/care/presentation/cycle_reflection_flow.dart';

void main() {
  testWidgets('saves one optional cycle reflection at large text size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.reset);
    CycleReflectionDraft? saved;
    var closed = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(2),
          ),
          child: CycleReflectionFlow(
            cycleLabel: 'Jul 1 - Jul 28, 2026',
            onSave: (draft) async => saved = draft,
            onClose: () => closed += 1,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('cycle-reflection-observation')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const Key('cycle-reflection-observation')),
      'A quieter pace helped.',
    );
    tester.testTextInput.hide();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('cycle-reflection-need-restOrPhysicalCapacity')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.byKey(const Key('cycle-reflection-need-restOrPhysicalCapacity')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('cycle-reflection-need-restOrPhysicalCapacity')),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('cycle-reflection-save')),
      140,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -80));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cycle-reflection-save')));
    await tester.pump();

    expect(saved?.observation, 'A quieter pace helped.');
    expect(saved?.need, ReflectionNeed.restOrPhysicalCapacity);
    expect(closed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty cycle reflection stays open with a specific message', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: CycleReflectionFlow(
          cycleLabel: 'Jul 1 - Jul 28, 2026',
          onSave: (draft) async {
            throw const CareMemoryException(CareMemoryFailure.emptyReflection);
          },
          onClose: () {},
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('cycle-reflection-save')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -80));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cycle-reflection-save')));
    await tester.pump();

    expect(
      find.text('Add one thought before saving this reflection.'),
      findsOneWidget,
    );
  });
}
