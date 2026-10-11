import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_workspace_stage.dart';

void main() {
  testWidgets(
    'rapid reverse keeps draft and only the latest face interactive',
    (tester) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await tester.pumpWidget(_host(selected));
      await tester.enterText(find.byKey(const Key('draft-0')), 'Unsent words');
      FocusManager.instance.primaryFocus?.unfocus();
      selected.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      selected.value = 2;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      selected.value = 0;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('draft-0')).hitTestable(), findsOneWidget);
      for (final index in [1, 2]) {
        expect(
          find.byKey(Key('draft-$index'), skipOffstage: false).hitTestable(),
          findsNothing,
        );
      }
      expect(find.byType(_DraftPane, skipOffstage: false), findsNWidgets(3));
      final labels = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.label)
          .toList();
      expect(labels.any((label) => label.contains('Private words 0')), isTrue);
      for (final index in [1, 2]) {
        expect(
          labels.any((label) => label.contains('Private words $index')),
          isFalse,
        );
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('draft-0')))
            .controller!
            .text,
        'Unsent words',
      );
      expect(find.byKey(const Key('draft-1')), findsNothing);
      expect(find.byKey(const Key('draft-2')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Reduce Motion switches face immediately without spatial travel',
    (tester) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await tester.pumpWidget(_host(selected, reduced: true));
      final originalPosition = tester.getTopLeft(
        find.byKey(const Key('draft-0')),
      );
      selected.value = 1;
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const Key('draft-1'))),
        originalPosition,
      );
      expect(find.byKey(const Key('draft-0')), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _host(ValueNotifier<int> selected, {bool reduced = false}) =>
    MaterialApp(
      theme: ExperienceFoundation.lightTheme(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: SizedBox(
            width: 402,
            height: 500,
            child: ValueListenableBuilder<int>(
              valueListenable: selected,
              builder: (context, index, _) => RecordWorkspaceStage(
                selectedIndex: index,
                children: const [
                  _DraftPane(index: 0),
                  _DraftPane(index: 1),
                  _DraftPane(index: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );

class _DraftPane extends StatefulWidget {
  const _DraftPane({required this.index});
  final int index;
  @override
  State<_DraftPane> createState() => _DraftPaneState();
}

class _DraftPaneState extends State<_DraftPane> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextField(
        key: Key('draft-${widget.index}'),
        controller: controller,
        decoration: InputDecoration(labelText: 'Private words ${widget.index}'),
      ),
    ],
  );
}
