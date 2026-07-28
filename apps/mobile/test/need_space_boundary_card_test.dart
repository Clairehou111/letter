import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/presentation/need_space_boundary_card.dart';

const _templateOne30m =
    'I need some quiet time for the next 30 minutes. '
    'I will not be available to reply.';
const _templateOne2h =
    'I need some quiet time for the next 2 hours. '
    'I will not be available to reply.';
const _templateTwo4h =
    'I am stepping away for 4 hours. '
    'Please do not call or message me during that time.';
const _clipboardDisclosure =
    'Copying puts this text on your device clipboard. It may remain there '
    'after you leave Letter.';

Future<void> pumpBoundaryCard(
  WidgetTester tester, {
  required TextEditingController controller,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = false,
  VoidCallback? onBack,
  VoidCallback? onFinish,
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
        child: Scaffold(
          backgroundColor: const Color(0xFFF1F5F3),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              child: NeedSpaceBoundaryCard(
                controller: controller,
                onBack: onBack ?? () {},
                onFinish: onFinish ?? () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> selectTemplate(WidgetTester tester, {int index = 0}) async {
  await tester.tap(find.byKey(Key('need-space-template-$index')));
  await tester.pump();
}

Future<void> scrollTo(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void expectMinimumTouchTarget(WidgetTester tester, String key) {
  final size = tester.getSize(find.byKey(Key(key)));
  expect(size.width, greaterThanOrEqualTo(44), reason: '$key width');
  expect(size.height, greaterThanOrEqualTo(44), reason: '$key height');
}

List<MethodCall> clipboardWrites(List<MethodCall> calls) {
  return calls.where((call) => call.method == 'Clipboard.setData').toList();
}

List<MethodCall> clipboardContentReads(List<MethodCall> calls) {
  return calls.where((call) => call.method == 'Clipboard.getData').toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TextEditingController controller;
  late List<MethodCall> platformCalls;

  setUp(() {
    controller = TextEditingController();
    platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('offers only the two approved templates and three durations', (
    tester,
  ) async {
    await pumpBoundaryCard(tester, controller: controller);

    expect(find.byKey(const Key('need-space-template-0')), findsOneWidget);
    expect(find.byKey(const Key('need-space-template-1')), findsOneWidget);
    expect(find.byKey(const Key('need-space-template-2')), findsNothing);
    expect(find.text(_templateOne30m), findsOneWidget);
    expect(
      find.text(
        'I am stepping away for 30 minutes. '
        'Please do not call or message me during that time.',
      ),
      findsOneWidget,
    );

    for (final key in [
      'need-space-duration-30m',
      'need-space-duration-2h',
      'need-space-duration-4h',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(find.text('30 minutes'), findsOneWidget);
    expect(find.text('2 hours'), findsOneWidget);
    expect(find.text('4 hours'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(controller.text, isEmpty);
  });

  testWidgets('template and duration selections produce editable local text', (
    tester,
  ) async {
    await pumpBoundaryCard(tester, controller: controller);
    await selectTemplate(tester);

    expect(controller.text, _templateOne30m);
    expect(find.byKey(const Key('need-space-boundary-field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('need-space-duration-2h')));
    await tester.pump();
    expect(controller.text, _templateOne2h);

    await tester.enterText(
      find.byKey(const Key('need-space-boundary-field')),
      'I am taking a quiet pause.',
    );
    expect(controller.text, 'I am taking a quiet pause.');
    expect(clipboardWrites(platformCalls), isEmpty);
    expect(clipboardContentReads(platformCalls), isEmpty);
  });

  testWidgets('second template uses the selected bounded duration', (
    tester,
  ) async {
    await pumpBoundaryCard(tester, controller: controller);
    await tester.tap(find.byKey(const Key('need-space-duration-4h')));
    await tester.pump();
    await selectTemplate(tester, index: 1);

    expect(controller.text, _templateTwo4h);
  });

  testWidgets('field disables autocorrect and suggestions and caps at 280', (
    tester,
  ) async {
    await pumpBoundaryCard(tester, controller: controller);
    await selectTemplate(tester);

    final field = tester.widget<TextField>(
      find.byKey(const Key('need-space-boundary-field')),
    );
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.maxLength, 280);
    expect(field.smartDashesType, SmartDashesType.disabled);
    expect(field.smartQuotesType, SmartQuotesType.disabled);

    await tester.enterText(
      find.byKey(const Key('need-space-boundary-field')),
      'x' * 281,
    );
    expect(controller.text.length, 280);
  });

  testWidgets('copy writes visible text exactly once only after explicit tap', (
    tester,
  ) async {
    await pumpBoundaryCard(tester, controller: controller);
    await selectTemplate(tester);
    await scrollTo(tester, 'need-space-copy');

    expect(clipboardWrites(platformCalls), isEmpty);
    expect(clipboardContentReads(platformCalls), isEmpty);
    await tester.tap(find.byKey(const Key('need-space-copy')));
    await tester.pump();

    final writes = clipboardWrites(platformCalls);
    expect(writes, hasLength(1));
    expect(writes.single.arguments, <String, dynamic>{'text': _templateOne30m});
    expect(clipboardContentReads(platformCalls), isEmpty);
    expect(find.text('Copied to your device clipboard.'), findsOneWidget);
    expect(find.text(_clipboardDisclosure), findsOneWidget);
  });

  testWidgets('copy failure preserves text and shows an honest error', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'clipboard-unavailable');
          }
          return null;
        });
    await pumpBoundaryCard(tester, controller: controller);
    await selectTemplate(tester);
    await scrollTo(tester, 'need-space-copy');

    await tester.tap(find.byKey(const Key('need-space-copy')));
    await tester.pump();

    expect(clipboardWrites(platformCalls), hasLength(1));
    expect(controller.text, _templateOne30m);
    expect(
      find.text('Could not copy. Your text is still here.'),
      findsOneWidget,
    );
    expect(find.text('Copied to your device clipboard.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection editing navigation and completion never auto-copy', (
    tester,
  ) async {
    var backs = 0;
    var finishes = 0;
    await pumpBoundaryCard(
      tester,
      controller: controller,
      onBack: () => backs += 1,
      onFinish: () => finishes += 1,
    );

    await selectTemplate(tester);
    await tester.enterText(
      find.byKey(const Key('need-space-boundary-field')),
      'Please give me two quiet hours.',
    );
    await tester.tap(find.byKey(const Key('need-space-duration-2h')));
    await tester.pump();
    await scrollTo(tester, 'need-space-boundary-back');
    await tester.tap(find.byKey(const Key('need-space-boundary-back')));
    await tester.pump();
    expect(backs, 1);
    expect(clipboardWrites(platformCalls), isEmpty);
    expect(clipboardContentReads(platformCalls), isEmpty);

    await scrollTo(tester, 'need-space-continue');
    await tester.tap(find.byKey(const Key('need-space-continue')));
    await tester.pump();
    expect(finishes, 1);
    expect(clipboardWrites(platformCalls), isEmpty);
    expect(clipboardContentReads(platformCalls), isEmpty);
  });

  testWidgets('whitespace cannot be copied or continued', (tester) async {
    var finishes = 0;
    await pumpBoundaryCard(
      tester,
      controller: controller,
      onFinish: () => finishes += 1,
    );
    await selectTemplate(tester);
    await tester.enterText(
      find.byKey(const Key('need-space-boundary-field')),
      '   ',
    );
    await scrollTo(tester, 'need-space-copy');

    await tester.tap(find.byKey(const Key('need-space-copy')));
    await tester.pump();
    expect(
      find.text('Write at least one character, or choose Discard.'),
      findsOneWidget,
    );
    expect(clipboardWrites(platformCalls), isEmpty);
    expect(clipboardContentReads(platformCalls), isEmpty);

    await scrollTo(tester, 'need-space-continue');
    await tester.tap(find.byKey(const Key('need-space-continue')));
    await tester.pump();
    expect(finishes, 0);
    expect(clipboardWrites(platformCalls), isEmpty);
    expect(clipboardContentReads(platformCalls), isEmpty);
  });

  testWidgets('continue finishes without clearing or copying', (tester) async {
    var finishes = 0;
    await pumpBoundaryCard(
      tester,
      controller: controller,
      onFinish: () => finishes += 1,
    );
    await selectTemplate(tester);
    await scrollTo(tester, 'need-space-continue');

    await tester.tap(find.byKey(const Key('need-space-continue')));
    await tester.pump();

    expect(finishes, 1);
    expect(controller.text, _templateOne30m);
    expect(clipboardWrites(platformCalls), isEmpty);
    expect(clipboardContentReads(platformCalls), isEmpty);
  });

  testWidgets('discard clears before finish and requires no valid text', (
    tester,
  ) async {
    String? textSeenByFinish;
    await pumpBoundaryCard(
      tester,
      controller: controller,
      onFinish: () => textSeenByFinish = controller.text,
    );
    controller.text = '   ';

    await scrollTo(tester, 'need-space-discard');
    await tester.tap(find.byKey(const Key('need-space-discard')));
    await tester.pump();

    expect(textSeenByFinish, isEmpty);
    expect(controller.text, isEmpty);
    expect(clipboardWrites(platformCalls), isEmpty);
    expect(clipboardContentReads(platformCalls), isEmpty);
  });

  testWidgets('does not dispose the caller-owned controller', (tester) async {
    await pumpBoundaryCard(tester, controller: controller);
    await selectTemplate(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.text = 'Caller still owns this controller.';

    expect(controller.text, 'Caller still owns this controller.');
  });

  testWidgets(
    'semantics expose selected state disclosure and live copy status',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpBoundaryCard(tester, controller: controller);

      await selectTemplate(tester);
      expect(
        find.bySemanticsLabel('Quiet time boundary. $_templateOne30m'),
        findsOneWidget,
      );

      final templateSemantics = tester.getSemantics(
        find.bySemanticsLabel('Quiet time boundary. $_templateOne30m'),
      );
      expect(templateSemantics, isSemantics(isSelected: true));
      final disclosure = tester.getSemantics(
        find.byKey(const Key('need-space-clipboard-disclosure')),
      );
      expect(
        disclosure,
        isSemantics(label: 'Clipboard disclosure. $_clipboardDisclosure'),
      );

      await scrollTo(tester, 'need-space-copy');
      await tester.tap(find.byKey(const Key('need-space-copy')));
      await tester.pump();
      final acknowledgement = tester.getSemantics(
        find.byKey(const Key('need-space-copy-acknowledgement')),
      );
      expect(acknowledgement, isSemantics(isLiveRegion: true));
      semantics.dispose();
    },
  );

  testWidgets('all stable controls meet the 44 logical-pixel target', (
    tester,
  ) async {
    await pumpBoundaryCard(tester, controller: controller);

    for (final key in [
      'need-space-template-0',
      'need-space-template-1',
      'need-space-duration-30m',
      'need-space-duration-2h',
      'need-space-duration-4h',
      'need-space-discard',
      'need-space-boundary-back',
    ]) {
      expectMinimumTouchTarget(tester, key);
    }

    await selectTemplate(tester);
    for (final key in ['need-space-copy', 'need-space-continue']) {
      await scrollTo(tester, key);
      expectMinimumTouchTarget(tester, key);
    }
  });

  testWidgets('fits at 320 pixels and 200 percent text with reduced motion', (
    tester,
  ) async {
    await pumpBoundaryCard(
      tester,
      controller: controller,
      size: const Size(320, 700),
      textScale: 2,
      disableAnimations: true,
    );
    expect(tester.takeException(), isNull);

    await scrollTo(tester, 'need-space-template-1');
    await selectTemplate(tester, index: 1);
    expect(tester.takeException(), isNull);

    for (final key in [
      'need-space-boundary-field',
      'need-space-copy',
      'need-space-continue',
      'need-space-discard',
    ]) {
      await scrollTo(tester, key);
      expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('selected template matches the visual baseline', (tester) async {
    await pumpBoundaryCard(tester, controller: controller);
    await selectTemplate(tester);
    await scrollTo(tester, 'need-space-boundary-field');

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        'goldens/need_space_boundary_card_selected_390x844.png',
      ),
    );
  });
}
