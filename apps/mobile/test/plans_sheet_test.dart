import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/domain/entitlement.dart';
import 'package:letter_mobile/features/entitlement/presentation/plans_sheet.dart';

Future<LocalEntitlementRepository> pumpPlans(WidgetTester tester) async {
  final repo = LocalEntitlementRepository();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'Arial'),
      home: Scaffold(body: PlansSheet(repository: repo)),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('plans sheet shows intro, renewal, alternatives, and notes', (
    tester,
  ) async {
    await pumpPlans(tester);

    expect(find.textContaining('\$0.99 first month'), findsWidgets);
    expect(find.textContaining('not a free trial'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('6 months'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Best for learning your pattern'), findsOneWidget);
    expect(find.textContaining('only \$1 more'), findsOneWidget);
    expect(find.text('\$8.99 / month'), findsOneWidget);
    expect(find.text('\$50.99 / year'), findsOneWidget);
  });

  testWidgets('no scarcity, countdown, or preselection', (tester) async {
    await pumpPlans(tester);

    for (final banned in [
      'Only today',
      'Limited time',
      'Hurry',
      'expires',
      'Free trial',
    ]) {
      expect(find.textContaining(banned), findsNothing, reason: banned);
    }
    expect(find.text('Select a plan'), findsOneWidget);
    final startButton = tester.widget<FilledButton>(
      find.byKey(const Key('plans-start-intro')),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets('explicit selection enables start and completes intro', (
    tester,
  ) async {
    final repo = await pumpPlans(tester);

    await tester.tap(find.byKey(const Key('plan-letter_yearly')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plans-start-intro')));
    await tester.pumpAndSettle();

    expect(repo.current.status, EntitlementStatus.activeIntro);
    expect(repo.current.planId, 'letter_yearly');
  });

  testWidgets('plans sheet matches the visual baseline', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = LocalEntitlementRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Arial'),
        home: Scaffold(body: PlansSheet(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PlansSheet),
      matchesGoldenFile('goldens/plans_sheet_390x844.png'),
    );
  });
}
