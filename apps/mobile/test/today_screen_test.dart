import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/today/today_screen.dart';

Future<void> pumpToday(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
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
        ),
        child: const TodayScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders balanced states and centered Today navigation', (
    tester,
  ) async {
    await pumpToday(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('state-physical')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    for (final label in [
      'Good',
      'Steady',
      'Energized',
      'Low',
      'Irritable',
      'Physical',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    expect(find.text('Cycle'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Care'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);

    final todayX = tester.getCenter(find.text('Today')).dx;
    expect(todayX, closeTo(195, 2));
  });

  testWidgets('records multiple pain locations with separate severity', (
    tester,
  ) async {
    await pumpToday(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('state-physical')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('state-physical')));
    await tester.pumpAndSettle();

    expect(find.text('Where does your body hurt?'), findsOneWidget);
    expect(find.text('Pelvic cramps'), findsOneWidget);
    expect(find.text('Lower back pain'), findsOneWidget);
    expect(find.text('Headache'), findsOneWidget);
    expect(find.text('Breast tenderness'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pain-pelvic-cramps')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('severity-strong')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pain-lower-back-pain')));
    await tester.pumpAndSettle();

    expect(find.text('2 pain locations added'), findsOneWidget);
    final pelvicChip = tester.widget<FilterChip>(
      find.byKey(const Key('pain-pelvic-cramps')),
    );
    final backChip = tester.widget<FilterChip>(
      find.byKey(const Key('pain-lower-back-pain')),
    );
    expect(pelvicChip.selected, isTrue);
    expect(backChip.selected, isTrue);
  });

  testWidgets('opens the low-effort Care sheet', (tester) async {
    await pumpToday(tester);

    await tester.tap(find.byKey(const Key('open-care-button')));
    await tester.pumpAndSettle();

    expect(find.text('What would feel easier right now?'), findsOneWidget);
    expect(find.text('Ease pain'), findsOneWidget);
    expect(find.text('Settle my body'), findsOneWidget);
    expect(find.text('Feel less alone'), findsOneWidget);
    expect(find.text('Use my plan'), findsOneWidget);

    await tester.tap(find.byKey(const Key('care-ease-pain')));
    await tester.pumpAndSettle();
    expect(find.text('Start gently'), findsOneWidget);
  });

  testWidgets('keeps primary touch targets at least 44 logical pixels', (
    tester,
  ) async {
    await pumpToday(tester);
    final logSize = tester.getSize(find.byKey(const Key('header-log-button')));
    final careSize = tester.getSize(find.byKey(const Key('open-care-button')));

    await tester.scrollUntilVisible(
      find.byKey(const Key('state-good')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final stateSize = tester.getSize(find.byKey(const Key('state-good')));

    expect(stateSize.height, greaterThanOrEqualTo(44));
    expect(careSize.height, greaterThanOrEqualTo(44));
    expect(logSize.height, greaterThanOrEqualTo(44));
  });

  testWidgets('does not overflow at 320 width and 200 percent text scale', (
    tester,
  ) async {
    await pumpToday(tester, size: const Size(320, 700), textScale: 2);

    expect(find.text('Your body may be asking for a softer day.'), findsOne);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const Key('state-good')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Good'), findsOneWidget);
    expect(find.text('Physical'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('matches the approved 390 by 844 visual baseline', (
    tester,
  ) async {
    await pumpToday(tester);

    await expectLater(
      find.byType(TodayScreen),
      matchesGoldenFile('goldens/today_390x844.png'),
    );
  });
}
