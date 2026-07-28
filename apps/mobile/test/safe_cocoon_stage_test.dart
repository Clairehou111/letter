import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/presentation/safe_cocoon_stage.dart';

Future<void> pumpSafeCocoon(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = false,
  bool initiallyClosed = false,
  VoidCallback? onClose,
  VoidCallback? onPrepareWords,
  VoidCallback? onNothingNow,
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
              key: const Key('safe-cocoon-test-scroll'),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              child: _SafeCocoonHarness(
                initiallyClosed: initiallyClosed,
                onClose: onClose,
                onPrepareWords: onPrepareWords,
                onNothingNow: onNothingNow,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _SafeCocoonHarness extends StatefulWidget {
  const _SafeCocoonHarness({
    required this.initiallyClosed,
    this.onClose,
    this.onPrepareWords,
    this.onNothingNow,
  });

  final bool initiallyClosed;
  final VoidCallback? onClose;
  final VoidCallback? onPrepareWords;
  final VoidCallback? onNothingNow;

  @override
  State<_SafeCocoonHarness> createState() => _SafeCocoonHarnessState();
}

class _SafeCocoonHarnessState extends State<_SafeCocoonHarness> {
  late bool _isClosed = widget.initiallyClosed;

  void _close() {
    widget.onClose?.call();
    setState(() => _isClosed = true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeCocoonStage(
      isClosed: _isClosed,
      onClose: _close,
      onPrepareWords: widget.onPrepareWords ?? () {},
      onNothingNow: widget.onNothingNow ?? () {},
    );
  }
}

void expectMinimumTouchTarget(WidgetTester tester, String key) {
  final size = tester.getSize(find.byKey(Key(key)));
  expect(size.width, greaterThanOrEqualTo(44), reason: '$key width');
  expect(size.height, greaterThanOrEqualTo(44), reason: '$key height');
}

void main() {
  testWidgets('open state shows one dominant action and honest boundary copy', (
    tester,
  ) async {
    await pumpSafeCocoon(tester);

    expect(find.text('Close the curtain'), findsOneWidget);
    expect(find.text('Tap or pull down'), findsOneWidget);
    expect(
      find.text(
        'Letter can quiet this screen. It cannot silence calls or other apps.',
      ),
      findsOneWidget,
    );
    expect(find.text('Prepare words'), findsNothing);
    expect(find.text('Nothing else right now'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('one tap requests close once and reveals the static cocoon', (
    tester,
  ) async {
    var closes = 0;
    await pumpSafeCocoon(tester, onClose: () => closes += 1);

    await tester.tap(find.byKey(const Key('safe-cocoon-close')));
    await tester.pumpAndSettle();

    expect(closes, 1);
    expect(
      find.text('The door is closed. You are allowed to be unavailable.'),
      findsOneWidget,
    );
    expect(find.text('Nothing is required here.'), findsOneWidget);
    expect(find.text('Prepare words'), findsOneWidget);
    expect(find.text('Nothing else right now'), findsOneWidget);

    await tester.tap(find.byKey(const Key('safe-cocoon-close')));
    await tester.pump();
    expect(closes, 1);
  });

  testWidgets('a short downward gesture reaches the same closed state', (
    tester,
  ) async {
    var closes = 0;
    await pumpSafeCocoon(tester, onClose: () => closes += 1);

    await tester.drag(
      find.byKey(const Key('safe-cocoon-close')),
      const Offset(0, 32),
    );
    await tester.pump(SafeCocoonStage.transitionDuration);

    expect(closes, 1);
    expect(find.text('Nothing is required here.'), findsOneWidget);
  });

  testWidgets('an upward gesture does not close the curtain', (tester) async {
    var closes = 0;
    await pumpSafeCocoon(tester, onClose: () => closes += 1);

    await tester.drag(
      find.byKey(const Key('safe-cocoon-close')),
      const Offset(0, -32),
    );
    await tester.pump();

    expect(closes, 0);
    expect(find.text('Close the curtain'), findsOneWidget);
  });

  testWidgets('parent-owned closed state starts directly in the cocoon', (
    tester,
  ) async {
    var closes = 0;
    await pumpSafeCocoon(
      tester,
      initiallyClosed: true,
      onClose: () => closes += 1,
    );

    expect(closes, 0);
    expect(find.text('Close the curtain'), findsNothing);
    expect(find.text('Nothing is required here.'), findsOneWidget);
  });

  testWidgets('closed-state exits invoke their parent callbacks once', (
    tester,
  ) async {
    var prepares = 0;
    var finishes = 0;
    await pumpSafeCocoon(
      tester,
      initiallyClosed: true,
      onPrepareWords: () => prepares += 1,
      onNothingNow: () => finishes += 1,
    );

    await tester.tap(find.byKey(const Key('safe-cocoon-prepare-words')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('safe-cocoon-nothing-now')));
    await tester.pump();

    expect(prepares, 1);
    expect(finishes, 1);
  });

  testWidgets('transition is restrained and Reduced Motion removes travel', (
    tester,
  ) async {
    await pumpSafeCocoon(tester);

    var animation = tester.widget<TweenAnimationBuilder<double>>(
      find.byKey(const Key('safe-cocoon-curtain-animation')),
    );
    expect(
      animation.duration,
      lessThanOrEqualTo(const Duration(milliseconds: 400)),
    );

    await pumpSafeCocoon(tester, disableAnimations: true);
    animation = tester.widget<TweenAnimationBuilder<double>>(
      find.byKey(const Key('safe-cocoon-curtain-animation')),
    );
    expect(animation.duration, Duration.zero);

    await tester.tap(find.byKey(const Key('safe-cocoon-close')));
    await tester.pump();
    expect(find.text('Nothing is required here.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('semantics distinguish the open and closed states', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpSafeCocoon(tester);

    expect(find.bySemanticsLabel('Close the curtain'), findsOneWidget);
    final openData = tester
        .getSemantics(find.byKey(const Key('safe-cocoon-curtain-semantics')))
        .getSemanticsData();
    expect(openData.hasAction(SemanticsAction.tap), isTrue);
    expect(openData.hint, 'Tap or pull down a short distance.');

    await tester.tap(find.byKey(const Key('safe-cocoon-close')));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Curtain closed. This Letter screen is quiet.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Prepare words'), findsOneWidget);
    expect(find.bySemanticsLabel('Nothing else right now'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('all component controls are at least 44 logical pixels', (
    tester,
  ) async {
    await pumpSafeCocoon(tester);
    expectMinimumTouchTarget(tester, 'safe-cocoon-close');

    await tester.tap(find.byKey(const Key('safe-cocoon-close')));
    await tester.pump(SafeCocoonStage.transitionDuration);
    expectMinimumTouchTarget(tester, 'safe-cocoon-prepare-words');
    expectMinimumTouchTarget(tester, 'safe-cocoon-nothing-now');
  });

  testWidgets('320 pixels at 200 percent text remains usable by scrolling', (
    tester,
  ) async {
    await pumpSafeCocoon(
      tester,
      size: const Size(320, 700),
      textScale: 2,
      disableAnimations: true,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('safe-cocoon-close')));
    await tester.pump();
    final nothingNow = find.byKey(const Key('safe-cocoon-nothing-now'));
    await tester.scrollUntilVisible(
      nothingNow,
      150,
      scrollable: find.byType(Scrollable).first,
    );

    expect(nothingNow.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    expectMinimumTouchTarget(tester, 'safe-cocoon-nothing-now');
  });

  testWidgets('contains no out-of-scope communication or urgency controls', (
    tester,
  ) async {
    await pumpSafeCocoon(tester, initiallyClosed: true);

    for (final text in [
      'Send',
      'Share',
      'Copy',
      'Contact',
      'Do Not Disturb',
      'Start timer',
      'Breathe',
      'Emergency',
      'symptom',
      'severity',
    ]) {
      expect(find.textContaining(text), findsNothing);
    }
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('open state matches its visual baseline', (tester) async {
    await pumpSafeCocoon(tester);

    await expectLater(
      find.byType(SafeCocoonStage),
      matchesGoldenFile('goldens/safe_cocoon_open_390x844.png'),
    );
  });

  testWidgets('closed state matches its visual baseline', (tester) async {
    await pumpSafeCocoon(tester, initiallyClosed: true);

    await expectLater(
      find.byType(SafeCocoonStage),
      matchesGoldenFile('goldens/safe_cocoon_closed_390x844.png'),
    );
  });
}
