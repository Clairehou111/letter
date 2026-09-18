import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/plus/plus_experience.dart';
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
  testWidgets('legacy upgrade entry opens the approved commitment sheet', (
    tester,
  ) async {
    final repository = LocalEntitlementRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => PlansSheet.show(context, repository),
            child: const Text('Open plans'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open plans'));
    await tester.pumpAndSettle();

    expect(find.byType(PlusExperience), findsOneWidget);
    expect(find.byType(PlansSheet), findsNothing);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Choose a plan'), findsNothing);
  });

  test('legal links use the live privacy page and Apple standard EULA', () {
    expect(privacyPolicyUrl.toString(), 'https://letterwithin.app/privacy');
    expect(
      termsOfUseUrlFor(TargetPlatform.iOS).toString(),
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
    );
  });

  test('refund requests use the platform store', () {
    expect(
      refundRequestUrlFor(TargetPlatform.iOS),
      Uri.parse('https://reportaproblem.apple.com/'),
    );
    expect(
      refundRequestUrlFor(TargetPlatform.android),
      Uri.parse('https://support.google.com/googleplay/workflow/9813244'),
    );
    expect(refundRequestUrlFor(TargetPlatform.macOS), isNull);
  });

  test('subscription management uses a platform fallback', () {
    expect(
      subscriptionManagementUrlFor(TargetPlatform.iOS),
      Uri.parse('https://apps.apple.com/account/subscriptions'),
    );
    expect(
      subscriptionManagementUrlFor(TargetPlatform.android),
      Uri.parse('https://play.google.com/store/account/subscriptions'),
    );
    expect(subscriptionManagementUrlFor(TargetPlatform.macOS), isNull);
  });

  testWidgets('plans sheet shows approved catalog and store terms', (
    tester,
  ) async {
    await pumpPlans(tester);

    expect(find.text('Choose Letter Within Plus'), findsOneWidget);
    expect(find.textContaining('Store pricing'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Lifetime'), findsOneWidget);
    expect(find.text('Best for learning your pattern'), findsOneWidget);
    expect(find.text('One payment, keeps working offline'), findsOneWidget);
    expect(find.text('\$6.99 / month'), findsOneWidget);
    expect(find.text('\$29.99 / year'), findsOneWidget);
    expect(find.text('\$79.99 once'), findsOneWidget);
    expect(find.byKey(const Key('plans-restore')), findsOneWidget);
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
      find.byKey(const Key('plans-purchase')),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets('explicit selection enables start and completes intro', (
    tester,
  ) async {
    final repo = await pumpPlans(tester);

    await tester.tap(find.byKey(const Key('plan-letter_yearly')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plans-purchase')));
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
