import 'dart:async';

import 'package:flutter/material.dart';
import 'package:letter_mobile/app/letter_app.dart';
import 'package:letter_mobile/features/auth/domain/auth_service.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/entitlement/data/revenue_cat_entitlement_repository.dart';
import 'package:letter_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:letter_mobile/features/onboarding/domain/onboarding_profile.dart';

// Synthetic simulator-only scenario. No production account or store call.
void main() => runApp(
  LetterApp(
    authService: _QaAuthService(),
    entitlementRepository: RevenueCatEntitlementRepository(
      appUserId: '',
      appleApiKey: 'appl_synthetic_simulator_key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: _QaStoreClient(),
    ),
    onboardingRepository: _QaOnboardingRepository(),
    periodRepository: InMemoryPeriodRepository(),
    requireAuthentication: true,
  ),
);

final class _QaAuthService implements AuthService {
  static const _userId = '550e8400-e29b-41d4-a716-446655440000';
  final _controller = StreamController<AuthState>.broadcast();
  AuthState _state = const AuthState(
    status: AuthStatus.localOnlyAfterAccountDeletion,
  );

  @override
  AuthState get current => _state;

  @override
  Stream<AuthState> watch() => _controller.stream;

  @override
  Future<AuthState> initialize() async => _state;

  void _set(AuthState state) {
    _state = state;
    _controller.add(state);
  }

  @override
  Future<void> beginAccountConnectionAfterDeletion() async {}

  @override
  Future<void> cancelAccountConnectionAfterDeletion() async {}

  @override
  Future<void> signInWithApple() async => sendMagicLink('qa@letter.test');

  @override
  Future<void> sendMagicLink(String email) async => _set(
    AuthState(status: AuthStatus.authenticated, userId: _userId, email: email),
  );

  @override
  Future<void> signInWithPassword(String email, String password) =>
      sendMagicLink(email);

  @override
  Future<void> signOut() async =>
      _set(const AuthState(status: AuthStatus.signedOut));

  @override
  Future<void> deleteAccount() async =>
      _set(const AuthState(status: AuthStatus.localOnlyAfterAccountDeletion));

  @override
  Future<void> dispose() => _controller.close();
}

final class _QaOnboardingRepository implements OnboardingRepository {
  @override
  Future<OnboardingProfile?> load() async => OnboardingProfile();

  @override
  Future<void> save(OnboardingProfile value) async {}

  @override
  Future<void> clear() async {}
}

final class _QaStoreClient implements RevenueCatClient {
  @override
  Future<void> configure({
    required String apiKey,
    required String appUserId,
  }) async {}

  @override
  Future<void> clearUser() async {}

  @override
  Future<List<RevenueCatPlanOffer>> loadPlans() async => const [
    RevenueCatPlanOffer(
      productId: 'letter_yearly',
      priceLabel: 'TEST \$39.99 / year',
    ),
    RevenueCatPlanOffer(
      productId: 'letter_monthly',
      priceLabel: 'TEST \$7.99 / month',
    ),
    RevenueCatPlanOffer(
      productId: 'letter_lifetime',
      priceLabel: 'TEST \$99.99 once',
    ),
  ];

  @override
  Future<RevenueCatCustomerState> currentCustomerState() async =>
      const RevenueCatCustomerState(
        hasActiveEntitlement: false,
        hasPurchasedLetterProduct: false,
      );

  @override
  Future<RevenueCatCustomerState> purchase(String productId) async =>
      const RevenueCatCustomerState(
        hasActiveEntitlement: false,
        hasPurchasedLetterProduct: false,
      );

  @override
  Future<RevenueCatCustomerState> restore() => currentCustomerState();
}
