import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/app/letter_app.dart';
import 'package:letter_mobile/features/auth/data/dev_auth_service.dart';
import 'package:letter_mobile/features/auth/domain/auth_service.dart';
import 'package:letter_mobile/features/auth/presentation/auth_screen.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:letter_mobile/features/onboarding/domain/onboarding_profile.dart';

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
    await tester.pumpAndSettle();

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
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(AuthScreen), findsNothing);
    await auth.signOut();
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
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
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

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
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(AuthScreen), findsNothing);
  });
}
