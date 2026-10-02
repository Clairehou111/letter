import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/app/letter_app.dart';
import 'package:letter_mobile/features/auth/data/dev_auth_service.dart';
import 'package:letter_mobile/features/auth/domain/auth_service.dart';
import 'package:letter_mobile/features/auth/presentation/auth_screen.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/entitlement/data/revenue_cat_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:letter_mobile/features/onboarding/domain/onboarding_profile.dart';
import 'package:letter_mobile/features/onboarding/presentation/onboarding_flow.dart';
import 'package:letter_mobile/experience/letter_experience_shell.dart';
import 'package:letter_mobile/experience/you/you_experience.dart';

import 'support/widget_test_pump.dart';

final class _AuthGateOnboardingRepository implements OnboardingRepository {
  _AuthGateOnboardingRepository({this.profile});

  OnboardingProfile? profile;

  @override
  Future<OnboardingProfile?> load() async => profile;

  @override
  Future<void> save(OnboardingProfile value) async => profile = value;

  @override
  Future<void> clear() async => profile = null;
}

final class _DelayedAccountEntitlementRepository
    extends LocalEntitlementRepository {
  final clearStarted = Completer<void>();
  final finishClear = Completer<void>();
  final calls = <String>[];

  @override
  Future<void> clearAuthenticatedUser() async {
    calls.add('clear started');
    if (!clearStarted.isCompleted) clearStarted.complete();
    await finishClear.future;
    calls.add('clear finished');
  }

  @override
  Future<void> identifyAuthenticatedUser(String userId) async {
    calls.add('identified $userId');
  }
}

void main() {
  testWidgets('first install remains behind the auth gate', (tester) async {
    final auth = DevAuthService();

    await tester.pumpWidget(
      LetterApp(
        authService: auth,
        requireAuthentication: true,
        periodRepository: InMemoryPeriodRepository(),
        onboardingRepository: _AuthGateOnboardingRepository(),
      ),
    );
    await pumpUntilFound(tester, find.byType(AuthScreen));

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text("Read your body's letter."), findsNothing);
  });

  testWidgets('explicit sign-out closes the local-data gate', (tester) async {
    final auth = DevAuthService(
      initialState: const AuthState(
        status: AuthStatus.authenticated,
        userId: 'dev-user-001',
      ),
    );

    await tester.pumpWidget(
      LetterApp(
        authService: auth,
        requireAuthentication: true,
        periodRepository: InMemoryPeriodRepository(),
        onboardingRepository: _AuthGateOnboardingRepository(),
      ),
    );
    await pumpUntilFound(tester, find.byType(OnboardingFlow));

    expect(find.byType(AuthScreen), findsNothing);
    await auth.signOut();
    await pumpUntilFound(tester, find.byType(AuthScreen));

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(LetterExperienceShell), findsNothing);
    expect(find.text('Restore a previous purchase'), findsNothing);
  });

  testWidgets('a stale Plus action after sign-out cannot reopen the shell', (
    tester,
  ) async {
    final auth = DevAuthService(
      initialState: const AuthState(
        status: AuthStatus.authenticated,
        userId: 'dev-user-001',
      ),
    );
    await tester.pumpWidget(
      LetterApp(
        authService: auth,
        requireAuthentication: true,
        periodRepository: InMemoryPeriodRepository(),
        onboardingRepository: _AuthGateOnboardingRepository(
          profile: OnboardingProfile(),
        ),
      ),
    );
    await pumpUntilFound(tester, find.byType(LetterExperienceShell));
    await tester.tap(find.byTooltip('Settings').first);
    await tester.pumpAndSettle();
    final openPlus = tester
        .widget<YouExperience>(find.byType(YouExperience))
        .onOpenPlus!;

    await auth.signOut();
    await pumpUntilFound(tester, find.byType(AuthScreen));
    openPlus();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Letter Within Plus'), findsNothing);
  });

  testWidgets('prior-auth offline state does not reopen the sign-in gate', (
    tester,
  ) async {
    final auth = DevAuthService(
      initialState: const AuthState(
        status: AuthStatus.offlineOrExpired,
        userId: 'dev-user-001',
      ),
    );

    await tester.pumpWidget(
      LetterApp(
        authService: auth,
        requireAuthentication: true,
        periodRepository: InMemoryPeriodRepository(),
        onboardingRepository: _AuthGateOnboardingRepository(
          profile: OnboardingProfile(),
        ),
      ),
    );
    await pumpUntilFound(tester, find.byType(LetterExperienceShell));

    expect(find.byType(AuthScreen), findsNothing);
  });

  testWidgets('deleted server account keeps local-only records open', (
    tester,
  ) async {
    final auth = DevAuthService(
      initialState: const AuthState(
        status: AuthStatus.localOnlyAfterAccountDeletion,
      ),
    );

    await tester.pumpWidget(
      LetterApp(
        authService: auth,
        requireAuthentication: true,
        periodRepository: InMemoryPeriodRepository(),
        onboardingRepository: _AuthGateOnboardingRepository(
          profile: OnboardingProfile(),
        ),
      ),
    );
    await pumpUntilFound(tester, find.byType(LetterExperienceShell));

    expect(find.byType(AuthScreen), findsNothing);
  });

  testWidgets('deleted account can open and cancel new account connection', (
    tester,
  ) async {
    final auth = DevAuthService(
      initialState: const AuthState(
        status: AuthStatus.localOnlyAfterAccountDeletion,
      ),
    );
    final entitlement = RevenueCatEntitlementRepository(
      appUserId: '',
      appleApiKey: 'appl_test_key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
    );
    await tester.pumpWidget(
      LetterApp(
        authService: auth,
        entitlementRepository: entitlement,
        requireAuthentication: true,
        periodRepository: InMemoryPeriodRepository(),
        onboardingRepository: _AuthGateOnboardingRepository(
          profile: OnboardingProfile(),
        ),
      ),
    );
    await pumpUntilFound(tester, find.byType(LetterExperienceShell));

    await tester.tap(find.byTooltip('Settings').first);
    await tester.pumpAndSettle();
    final plus = find.text('Letter Within Plus');
    await tester.drag(find.byType(YouExperience), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(YouExperience), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(YouExperience), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(plus);
    await tester.pumpAndSettle();
    expect(find.text('Connect an account for Plus'), findsOneWidget);
    await tester.tap(find.text('Open account settings'));
    await tester.pumpAndSettle();
    expect(find.text('Connect an account for Plus'), findsNothing);

    final connect = find.text('Create or connect an account');
    await tester.ensureVisible(connect);
    await tester.tap(connect);
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Back to your records'));
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsNothing);
    expect(auth.current.status, AuthStatus.localOnlyAfterAccountDeletion);
    expect(find.text('Create or connect an account'), findsOneWidget);

    await tester.ensureVisible(connect);
    await tester.tap(connect);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'new@letter.test',
    );
    await tester.ensureVisible(find.text('Email me a sign-in link'));
    await tester.tap(find.text('Email me a sign-in link'));
    await tester.pumpAndSettle();
    expect(auth.current.status, AuthStatus.authenticated);
    expect(find.byType(AuthScreen), findsNothing);
  });

  testWidgets('new account waits for previous store logout to finish', (
    tester,
  ) async {
    final auth = DevAuthService(
      initialState: const AuthState(
        status: AuthStatus.authenticated,
        userId: 'old-account',
      ),
    );
    final entitlement = _DelayedAccountEntitlementRepository();
    await tester.pumpWidget(
      LetterApp(
        authService: auth,
        entitlementRepository: entitlement,
        requireAuthentication: true,
        periodRepository: InMemoryPeriodRepository(),
        onboardingRepository: _AuthGateOnboardingRepository(
          profile: OnboardingProfile(),
        ),
      ),
    );
    await pumpUntilFound(tester, find.byType(LetterExperienceShell));

    await auth.deleteAccount();
    await entitlement.clearStarted.future;
    await auth.sendMagicLink('new@letter.test');
    await tester.pump();
    expect(entitlement.calls, contains('clear started'));
    expect(
      entitlement.calls.where((call) => call == 'identified dev-user-001'),
      isEmpty,
    );

    entitlement.finishClear.complete();
    await tester.pump();
    await tester.pump();
    expect(
      entitlement.calls,
      containsAllInOrder([
        'clear started',
        'clear finished',
        'identified dev-user-001',
      ]),
    );
  });
}
