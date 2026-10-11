import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/components/record_option_scale.dart';
import 'package:letter_mobile/experience/components/record_temperature_picker.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';

void main() {
  testWidgets(
    'zero is an explicit selection; repeated taps return the same typed value',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final values = <int>[];
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.lightTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => RecordOptionScale<int>(
                options: [
                  for (var value = 0; value < 6; value++)
                    RecordScaleOption(
                      value: value,
                      label: value == 0 ? 'Not present' : 'Degree $value',
                      key: Key('degree-$value'),
                    ),
                ],
                selected: selected,
                onSelected: (value) => update(() {
                  values.add(value);
                  selected = value;
                }),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Not recorded'), findsOneWidget);
      final zero = find.byKey(const Key('degree-0'));
      expect(tester.getSize(zero).height, greaterThanOrEqualTo(48));
      expect(
        tester
            .getSemantics(zero)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      await tester.tap(zero);
      await tester.pumpAndSettle();
      await tester.tap(zero);
      await tester.pumpAndSettle();
      expect(values, [0, 0]);
      expect(selected, 0);
      expect(find.text('Not recorded'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'six degree targets fit the normal 330-point Record content width',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.lightTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 330,
                child: RecordOptionScale<int>(
                  options: [
                    for (var value = 0; value < 6; value++)
                      RecordScaleOption(
                        value: value,
                        label: 'Degree $value',
                        key: Key('normal-$value'),
                      ),
                  ],
                  selected: null,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      final first = find.byKey(const Key('normal-0'));
      final last = find.byKey(const Key('normal-5'));
      expect(tester.getTopLeft(first).dy, tester.getTopLeft(last).dy);
      for (var value = 0; value < 6; value++) {
        final size = tester.getSize(find.byKey(Key('normal-$value')));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disabled options expose no semantic tap action', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordOptionScale<String>(
            options: const [
              RecordScaleOption(
                value: 'gentle',
                label: 'Gentle',
                key: Key('disabled'),
              ),
            ],
            selected: null,
            onSelected: null,
          ),
        ),
      ),
    );
    final disabled = tester
        .getSemantics(find.byKey(const Key('disabled')))
        .getSemanticsData();
    expect(disabled.hasAction(SemanticsAction.tap), isFalse);
    await tester.tap(find.byKey(const Key('disabled')));
    await tester.pumpAndSettle();
    expect(find.text('Not recorded'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'six accessible options wrap at large text with Reduce Motion and keyboard activation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.lightTheme(),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: StatefulBuilder(
                builder: (context, update) => RecordOptionScale<int>(
                  options: [
                    for (var value = 0; value < 6; value++)
                      RecordScaleOption(
                        value: value,
                        label: 'Complete intensity label $value',
                        key: Key('accessible-$value'),
                      ),
                  ],
                  selected: selected,
                  onSelected: (value) => update(() => selected = value),
                ),
              ),
            ),
          ),
        ),
      );
      final first = find.byKey(const Key('accessible-0'));
      final fourth = find.byKey(const Key('accessible-3'));
      expect(
        tester.getTopLeft(fourth).dy,
        greaterThan(tester.getTopLeft(first).dy),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, 0);
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
      semantics.dispose();
    },
  );

  testWidgets('three-value vocabulary stays three distinct controls', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordOptionScale<String>(
            options: const [
              RecordScaleOption(value: 'low', label: 'Low', key: Key('low')),
              RecordScaleOption(
                value: 'moderate',
                label: 'Moderate',
                key: Key('moderate'),
              ),
              RecordScaleOption(value: 'high', label: 'High', key: Key('high')),
            ],
            selected: null,
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('low')), findsOneWidget);
    expect(find.byKey(const Key('moderate')), findsOneWidget);
    expect(find.byKey(const Key('high')), findsOneWidget);
    await tester.tap(find.byKey(const Key('moderate')));
    expect(selected, 'moderate');
  });

  testWidgets(
    'blank temperature wheels do not invent a draft reading; actual scroll selects hundredths',
    (tester) async {
      final values = <double?>[];
      double? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.lightTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => RecordTemperaturePicker(
                unitLabel: '°C',
                anchorWhole: 37,
                value: selected,
                onChanged: (value) => update(() {
                  selected = value;
                  values.add(value);
                }),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(values, isEmpty);
      expect(find.text('Choose a reading'), findsOneWidget);
      final whole = tester.widget<CupertinoPicker>(
        find.byKey(const Key('record-temperature-whole-wheel')),
      );
      whole.scrollController!.jumpToItem(38); // Explicit 37, adjacent to blank.
      await tester.pumpAndSettle();
      expect(values, [null]); // Decimal is still unchosen: no numeric reading.
      final fraction = tester.widget<CupertinoPicker>(
        find.byKey(const Key('record-temperature-fraction-wheel')),
      );
      fraction.scrollController!.jumpToItem(57); // Explicit .56.
      await tester.pumpAndSettle();
      expect(selected, 37.56);
      expect(values, [null, 37.56]);
      expect(find.text('37.56 °C'), findsOneWidget);
    },
  );

  testWidgets(
    'rendering wheels preserves typed precision until an actual choice',
    (tester) async {
      final values = <double?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.lightTheme(),
          home: Scaffold(
            body: RecordTemperaturePicker(
              unitLabel: '°F',
              anchorWhole: 97,
              value: 97.556,
              onChanged: values.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(values, isEmpty);
      expect(find.text('97.556 °F'), findsOneWidget);
      final fraction = tester.widget<CupertinoPicker>(
        find.byKey(const Key('record-temperature-fraction-wheel')),
      );
      fraction.scrollController!.jumpToItem(58);
      await tester.pumpAndSettle();
      expect(values, [97.57]);
    },
  );
  testWidgets(
    'typed precision survives wheel synchronization, rapid edits, and returning to an emitted value',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final values = <double?>[];
      final input = TextEditingController(text: '37.56');
      addTearDown(input.dispose);
      double? selected = 37.56;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.lightTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Column(
                  children: [
                    TextField(
                      key: const Key('exact-reading'),
                      controller: input,
                      onChanged: (text) =>
                          update(() => selected = double.tryParse(text)),
                    ),
                    RecordTemperaturePicker(
                      unitLabel: '°C',
                      anchorWhole: 37,
                      value: selected,
                      onChanged: (value) => update(() {
                        values.add(value);
                        selected = value;
                        input.text = value?.toStringAsFixed(2) ?? '';
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final exact = find.byKey(const Key('exact-reading'));
      final precisionHint = find.byKey(
        const Key('record-temperature-precision-hint'),
      );
      expect(precisionHint, findsNothing);
      await tester.enterText(exact, '36.555');
      await tester.pumpAndSettle();
      expect(input.text, '36.555');
      expect(selected, 36.555);
      expect(values, isEmpty);
      expect(precisionHint, findsOneWidget);
      final whole = tester.widget<CupertinoPicker>(
        find.byKey(const Key('record-temperature-whole-wheel')),
      );
      final fraction = tester.widget<CupertinoPicker>(
        find.byKey(const Key('record-temperature-fraction-wheel')),
      );
      expect(whole.scrollController!.selectedItem, 36);
      expect(fraction.scrollController!.selectedItem, 57);

      // A genuine wheel choice still uses hundredths and updates the draft.
      fraction.scrollController!.jumpToItem(58);
      await tester.pumpAndSettle();
      expect(values, [36.57]);
      expect(input.text, '36.57');
      expect(precisionHint, findsNothing);
      await tester.enterText(exact, '35.123');
      await tester.pumpAndSettle();
      expect(whole.scrollController!.selectedItem, 35);
      expect(fraction.scrollController!.selectedItem, 13);
      await tester.enterText(exact, '36.57');
      await tester.pumpAndSettle();
      expect(whole.scrollController!.selectedItem, 36);
      expect(fraction.scrollController!.selectedItem, 58);
      await tester.enterText(exact, '34.123');
      await tester.enterText(exact, '36.57');
      await tester.pumpAndSettle();
      expect(input.text, '36.57');
      expect(whole.scrollController!.selectedItem, 36);
      expect(fraction.scrollController!.selectedItem, 58);
      expect(values, [36.57]);

      await tester.enterText(exact, '');
      await tester.pumpAndSettle();
      expect(whole.scrollController!.selectedItem, 37); // Blank at anchor.
      expect(fraction.scrollController!.selectedItem, 0);
      expect(values, [36.57]);
      expect(precisionHint, findsNothing);
      await tester.enterText(exact, '36.555');
      await tester.pumpAndSettle();
      expect(input.text, '36.555');
      expect(values, [36.57]);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      SemanticsNode? adjustable;
      void findAdjustable(SemanticsNode node) {
        if (node.getSemanticsData().hasAction(SemanticsAction.increase)) {
          adjustable = node;
        }
        node.visitChildren((child) {
          findAdjustable(child);
          return true;
        });
      }

      findAdjustable(
        tester.getSemantics(
          find.byKey(const Key('record-temperature-fraction-wheel')),
        ),
      );
      expect(adjustable, isNotNull);
      adjustable!.owner!.performAction(
        adjustable!.id,
        SemanticsAction.increase,
      );
      await tester.pumpAndSettle();
      expect(selected, 36.57);
      adjustable!.owner!.performAction(
        adjustable!.id,
        SemanticsAction.decrease,
      );
      await tester.pumpAndSettle();
      expect(selected, 36.56);
      final beforeDrag = values.length;
      await tester.drag(
        find.byKey(const Key('record-temperature-fraction-wheel')),
        const Offset(0, -48),
      );
      await tester.pumpAndSettle();
      expect(values.length, greaterThan(beforeDrag));
      expect(selected, isNot(36.555));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'blanking a wheel explicitly clears a previously entered reading',
    (tester) async {
      double? selected = 97.556;
      await tester.pumpWidget(
        MaterialApp(
          theme: ExperienceFoundation.lightTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => RecordTemperaturePicker(
                unitLabel: '°F',
                anchorWhole: 97,
                value: selected,
                onChanged: (value) => update(() => selected = value),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final whole = tester.widget<CupertinoPicker>(
        find.byKey(const Key('record-temperature-whole-wheel')),
      );
      whole.scrollController!.jumpToItem(97);
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(find.text('Choose a reading'), findsOneWidget);
    },
  );
}
