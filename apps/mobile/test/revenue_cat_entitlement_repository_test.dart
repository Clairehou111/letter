import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:letter_mobile/features/entitlement/data/revenue_cat_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/domain/entitlement.dart';
import 'package:letter_mobile/features/entitlement/domain/entitlement_repository.dart';

class FakeRevenueCatClient implements RevenueCatClient {
  FakeRevenueCatClient({this.purchaseState, this.restoreState});

  RevenueCatCustomerState? purchaseState;
  RevenueCatCustomerState? restoreState;
  List<RevenueCatPlanOffer> offers = const [
    RevenueCatPlanOffer(
      productId: 'letter_monthly',
      priceLabel: 'CA\$9.99 / month',
    ),
    RevenueCatPlanOffer(
      productId: 'letter_yearly',
      priceLabel: 'CA\$39.99 / year',
    ),
    RevenueCatPlanOffer(
      productId: 'letter_lifetime',
      priceLabel: 'CA\$99.99 once',
    ),
  ];
  Object? loadError;
  Object? purchaseError;
  Object? clearError;
  String? configuredUserId;
  String? purchasedProductId;
  var clearUserCalls = 0;

  @override
  Future<void> configure({
    required String apiKey,
    required String appUserId,
  }) async {
    configuredUserId = appUserId;
  }

  @override
  Future<void> clearUser() async {
    clearUserCalls += 1;
    if (clearError != null) throw clearError!;
    configuredUserId = null;
  }

  @override
  Future<List<RevenueCatPlanOffer>> loadPlans() async {
    if (loadError != null) throw loadError!;
    return offers;
  }

  @override
  Future<RevenueCatCustomerState> currentCustomerState() async =>
      restoreState ??
      const RevenueCatCustomerState(
        hasActiveEntitlement: false,
        hasPurchasedLetterProduct: false,
      );

  @override
  Future<RevenueCatCustomerState> purchase(String productId) async {
    purchasedProductId = productId;
    if (purchaseError != null) throw purchaseError!;
    if (purchaseState == null) {
      throw const EntitlementException('Purchase failed.');
    }
    return purchaseState!;
  }

  @override
  Future<RevenueCatCustomerState> restore() async {
    if (restoreState == null) {
      throw const EntitlementException('Restore failed.');
    }
    return restoreState!;
  }
}

RevenueCatCustomerState active({bool intro = false, String? productId}) =>
    RevenueCatCustomerState(
      hasActiveEntitlement: true,
      hasPurchasedLetterProduct: true,
      productId: productId ?? 'letter_yearly',
      isIntro: intro,
    );

void main() {
  test('authenticated UUID binds and refreshes current entitlement', () async {
    final client = FakeRevenueCatClient(restoreState: active());
    final repo = RevenueCatEntitlementRepository(
      appUserId: '',
      appleApiKey: 'apple-key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: client,
    );

    await repo.identifyAuthenticatedUser(
      '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
    );

    expect(client.configuredUserId, '2c1a7f42-2d87-4ad6-8d89-b6b68b429127');
    expect(repo.current.status, EntitlementStatus.activePaid);
  });

  test('refresh reconciles an external entitlement change', () async {
    final client = FakeRevenueCatClient(
      restoreState: const RevenueCatCustomerState(
        hasActiveEntitlement: false,
        hasPurchasedLetterProduct: false,
      ),
    );
    final repo = RevenueCatEntitlementRepository(
      appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
      appleApiKey: 'apple-key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: client,
    );

    expect((await repo.refresh()).status, EntitlementStatus.freeOrUnknown);
    client.restoreState = active(productId: 'letter_yearly');
    expect((await repo.refresh()).status, EntitlementStatus.activePaid);
    await repo.dispose();
  });

  test('clearing the account logs out RevenueCat and removes access', () async {
    final client = FakeRevenueCatClient(restoreState: active());
    final repo = RevenueCatEntitlementRepository(
      appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
      appleApiKey: 'apple-key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: client,
    );
    await repo.identifyAuthenticatedUser(
      '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
    );
    await repo.clearAuthenticatedUser();

    expect(client.clearUserCalls, 1);
    expect(repo.current.status, EntitlementStatus.freeOrUnknown);
  });

  test('store logout failure still removes app-level premium access', () async {
    final client = FakeRevenueCatClient(restoreState: active())
      ..clearError = StateError('offline');
    final repo = RevenueCatEntitlementRepository(
      appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
      appleApiKey: 'apple-key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: client,
    );
    await repo.identifyAuthenticatedUser(
      '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
    );

    await repo.clearAuthenticatedUser();

    expect(client.clearUserCalls, 1);
    expect(repo.current.status, EntitlementStatus.freeOrUnknown);
  });

  test('unconfigured repository never grants local access', () async {
    final repo = RevenueCatEntitlementRepository(
      appUserId: '',
      appleApiKey: '',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: FakeRevenueCatClient(),
    );

    final plans = await repo.loadPlans().catchError(
      (_) => const <LetterPlan>[],
    );
    final result = await repo.purchase('letter_yearly');

    expect(plans, isEmpty);
    expect(result.outcome, PurchaseOutcome.unavailable);
    expect(repo.current.status, EntitlementStatus.freeOrUnknown);
    await repo.dispose();
  });

  test('configured catalog uses localized store prices and UUID', () async {
    final client = FakeRevenueCatClient();
    final repo = RevenueCatEntitlementRepository(
      appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
      appleApiKey: 'rc_apple_key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: client,
    );

    final plans = await repo.loadPlans();

    expect(client.configuredUserId, '2c1a7f42-2d87-4ad6-8d89-b6b68b429127');
    expect(plans.map((plan) => plan.id), [
      'letter_yearly',
      'letter_monthly',
      'letter_lifetime',
    ]);
    expect(plans[0].priceLabel, 'CA\$39.99 / year');
    await repo.dispose();
  });

  test('purchase maps active intro without using reference pricing', () async {
    final client = FakeRevenueCatClient(purchaseState: active(intro: true));
    final repo = RevenueCatEntitlementRepository(
      appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
      appleApiKey: 'key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: client,
    );

    final result = await repo.purchase('letter_yearly');

    expect(client.purchasedProductId, 'letter_yearly');
    expect(result.outcome, PurchaseOutcome.activated);
    expect(repo.current.status, EntitlementStatus.activeIntro);
    await repo.dispose();
  });

  test('purchase stays pending when customer info is not active', () async {
    final client = FakeRevenueCatClient(
      purchaseState: const RevenueCatCustomerState(
        hasActiveEntitlement: false,
        hasPurchasedLetterProduct: true,
        productId: 'letter_yearly',
      ),
    );
    final repo = RevenueCatEntitlementRepository(
      appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
      appleApiKey: 'key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: client,
    );

    final result = await repo.purchase('letter_yearly');

    expect(result.outcome, PurchaseOutcome.pending);
    expect(result.state.status, EntitlementStatus.pending);
    expect(result.state.hasPremiumAccess, isFalse);
    await repo.dispose();
  });

  test('restore maps an active paid entitlement', () async {
    final client = FakeRevenueCatClient(restoreState: active());
    final repo = RevenueCatEntitlementRepository(
      appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
      appleApiKey: 'key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: client,
    );

    expect(
      (await repo.restorePurchases()).status,
      EntitlementStatus.activePaid,
    );
    await repo.dispose();
  });

  test('store-confirmed grace period keeps Plus available', () async {
    final client = FakeRevenueCatClient(
      restoreState: const RevenueCatCustomerState(
        hasActiveEntitlement: true,
        hasPurchasedLetterProduct: true,
        productId: 'letter_yearly',
        isGracePeriod: true,
      ),
    );
    final repo = RevenueCatEntitlementRepository(
      appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
      appleApiKey: 'key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: client,
    );

    expect(
      (await repo.restorePurchases()).status,
      EntitlementStatus.gracePeriod,
    );
    expect(repo.current.hasPremiumAccess, isTrue);
    await repo.dispose();
  });

  test('restore preserves truthful lapsed state', () async {
    final client = FakeRevenueCatClient(
      restoreState: const RevenueCatCustomerState(
        hasActiveEntitlement: false,
        hasPurchasedLetterProduct: true,
        productId: 'letter_yearly',
      ),
    );
    final repo = RevenueCatEntitlementRepository(
      appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
      appleApiKey: 'key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: client,
    );

    expect((await repo.restorePurchases()).status, EntitlementStatus.lapsed);
    expect(repo.current.hasPremiumAccess, isFalse);
    await repo.dispose();
  });

  test(
    'store failure exposes offline unknown and does not grant access',
    () async {
      final client = FakeRevenueCatClient()..loadError = StateError('offline');
      final repo = RevenueCatEntitlementRepository(
        appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
        appleApiKey: 'key',
        googleApiKey: '',
        store: RevenueCatStore.apple,
        client: client,
      );

      await expectLater(repo.loadPlans(), throwsA(isA<EntitlementException>()));
      expect(repo.current.status, EntitlementStatus.offlineUnknown);
      expect(repo.current.hasPremiumAccess, isFalse);
      await repo.dispose();
    },
  );

  test('store configuration failure is not mislabeled as offline', () async {
    final client = FakeRevenueCatClient()
      ..loadError = PlatformException(
        code: '23',
        message: 'CONFIGURATION_ERROR: no App Store products in offering',
      );
    final repo = RevenueCatEntitlementRepository(
      appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
      appleApiKey: 'key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: client,
    );

    await expectLater(
      repo.loadPlans(),
      throwsA(
        isA<EntitlementException>().having(
          (error) => error.message,
          'message',
          contains('not configured for this TestFlight build'),
        ),
      ),
    );
    expect(repo.current.status, EntitlementStatus.freeOrUnknown);
    expect(repo.current.message, contains('not configured'));
    expect(repo.current.hasPremiumAccess, isFalse);
    await repo.dispose();
  });

  test('purchase failure keeps the previous state', () async {
    final client = FakeRevenueCatClient();
    final repo = RevenueCatEntitlementRepository(
      appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
      appleApiKey: 'key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: client,
    );

    final result = await repo.purchase('letter_yearly');

    expect(result.outcome, PurchaseOutcome.failed);
    expect(repo.current.status, EntitlementStatus.freeOrUnknown);
    expect(repo.current.hasPremiumAccess, isFalse);
    await repo.dispose();
  });

  test(
    'user cancellation keeps access unchanged and is not a failure',
    () async {
      final client = FakeRevenueCatClient()
        ..purchaseError = PlatformException(
          code: PurchasesErrorCode.purchaseCancelledError.index.toString(),
          message: 'cancelled',
        );
      final repo = RevenueCatEntitlementRepository(
        appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
        appleApiKey: 'key',
        googleApiKey: '',
        store: RevenueCatStore.apple,
        client: client,
      );

      final result = await repo.purchase('letter_yearly');

      expect(result.outcome, PurchaseOutcome.cancelled);
      expect(repo.current.status, EntitlementStatus.freeOrUnknown);
      expect(repo.current.hasPremiumAccess, isFalse);
      await repo.dispose();
    },
  );
}
