import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/care/domain/safety_dialer.dart';
import 'package:letter_mobile/features/care/presentation/care_safety_boundary_sheet.dart';
import 'package:letter_mobile/features/care/presentation/letter_safety_scope.dart';

class FakeSafetyDialer implements SafetyDialer {
  final List<String> calls = [];
  bool succeed = true;

  @override
  Future<bool> call(String number) async {
    calls.add(number);
    return succeed;
  }
}

Future<FakeSafetyDialer> pumpSheet(
  WidgetTester tester, {
  required CareSafetyKind kind,
  String regionCode = 'US',
  VoidCallback? onLeaveCare,
}) async {
  final dialer = FakeSafetyDialer();
  await tester.pumpWidget(
    MaterialApp(
      home: LetterSafetyScope(
        regionCode: regionCode,
        dialer: dialer,
        child: Scaffold(
          body: CareSafetyBoundarySheet(
            kind: kind,
            onLeaveCare: onLeaveCare ?? () {},
          ),
        ),
      ),
    ),
  );
  return dialer;
}

void main() {
  testWidgets('US crisis sheet shows tappable 988 and 911 with visible '
      'numbers', (tester) async {
    final dialer = await pumpSheet(tester, kind: CareSafetyKind.emotional);

    expect(find.text('Call or text 988'), findsOneWidget);
    expect(find.text('Call 911'), findsOneWidget);
    expect(
      find.textContaining('988 Suicide & Crisis Lifeline'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('safety-contact-988')));
    await tester.pump();
    expect(dialer.calls, ['988']);
  });

  testWidgets('CA crisis sheet shows 9-8-8 and 911', (tester) async {
    await pumpSheet(tester, kind: CareSafetyKind.emotional, regionCode: 'CA');

    expect(find.text('Call or text 9-8-8'), findsOneWidget);
    expect(find.text('Call 911'), findsOneWidget);
    expect(find.textContaining('Canada'), findsOneWidget);
  });

  testWidgets('fallback region shows honest guidance and no invented numbers', (
    tester,
  ) async {
    await pumpSheet(tester, kind: CareSafetyKind.emotional, regionCode: 'GB');

    expect(find.byKey(const Key('crisis-fallback-line')), findsOneWidget);
    expect(find.byKey(const Key('safety-contact-988')), findsNothing);
    expect(find.byKey(const Key('safety-contact-911')), findsNothing);
    expect(find.text('Call 911'), findsNothing);
  });

  testWidgets('crisis sheet states Letter cannot provide emergency help', (
    tester,
  ) async {
    await pumpSheet(tester, kind: CareSafetyKind.emotional);
    expect(
      find.textContaining('Letter cannot provide emergency help'),
      findsOneWidget,
    );
    expect(find.textContaining('someone you trust'), findsOneWidget);
  });

  testWidgets('physical sheet shows both red-flag tiers without diagnosis', (
    tester,
  ) async {
    await pumpSheet(tester, kind: CareSafetyKind.physical);

    expect(
      find.text('This needs medical attention, not more interaction.'),
      findsOneWidget,
    );
    expect(find.textContaining('Seek urgent medical care'), findsOneWidget);
    expect(find.textContaining('Book a medical assessment'), findsOneWidget);
    expect(find.textContaining('Fainting'), findsOneWidget);
    expect(find.textContaining('palpitations'), findsOneWidget);
    expect(
      find.textContaining('Letter cannot assess symptoms'),
      findsOneWidget,
    );
  });

  testWidgets('leave and return controls remain available', (tester) async {
    var left = 0;
    await pumpSheet(
      tester,
      kind: CareSafetyKind.emotional,
      onLeaveCare: () => left += 1,
    );

    await tester.tap(find.byKey(const Key('leave-care-from-safety')));
    await tester.pump();
    expect(left, 1);
    expect(find.byKey(const Key('return-to-care-scene')), findsOneWidget);
  });

  testWidgets('safety contact buttons meet the 44-pixel target', (
    tester,
  ) async {
    await pumpSheet(tester, kind: CareSafetyKind.emotional);
    final size = tester.getSize(find.byKey(const Key('safety-contact-988')));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  Future<void> pumpGolden(
    WidgetTester tester, {
    required CareSafetyKind kind,
    required String regionCode,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Arial'),
        home: LetterSafetyScope(
          regionCode: regionCode,
          dialer: FakeSafetyDialer(),
          child: Scaffold(
            body: CareSafetyBoundarySheet(kind: kind, onLeaveCare: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('US crisis sheet matches the visual baseline', (tester) async {
    await pumpGolden(tester, kind: CareSafetyKind.emotional, regionCode: 'US');
    await expectLater(
      find.byType(CareSafetyBoundarySheet),
      matchesGoldenFile('goldens/safety_crisis_us_390x844.png'),
    );
  });

  testWidgets('fallback crisis sheet matches the visual baseline', (
    tester,
  ) async {
    await pumpGolden(tester, kind: CareSafetyKind.emotional, regionCode: 'GB');
    await expectLater(
      find.byType(CareSafetyBoundarySheet),
      matchesGoldenFile('goldens/safety_crisis_fallback_390x844.png'),
    );
  });

  testWidgets('medical boundary sheet matches the visual baseline', (
    tester,
  ) async {
    await pumpGolden(tester, kind: CareSafetyKind.physical, regionCode: 'US');
    await expectLater(
      find.byType(CareSafetyBoundarySheet),
      matchesGoldenFile('goldens/safety_medical_390x844.png'),
    );
  });
}
