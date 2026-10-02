import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:letter_mobile/features/entitlement/data/revenue_cat_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/domain/entitlement.dart';
import 'package:letter_mobile/features/entitlement/domain/entitlement_repository.dart';

class FakeRevenueCatClient implements RevenueCatClient {
  FakeRevenueCatClient({this.purchaseState, this.restoreState});

  RevenueCatCustomerState? purchaseState;
  Completer<RevenueCatCustomerState>? purchaseCompleter;
  RevenueCatCustomerState? restoreState;
  List<RevenueCatPlanOffer> offers = const [
    RevenueCatPlanOffer(productId: 'letter_monthly', priceLabel: 'CA\$9.99'),
    RevenueCatPlanOffer(productId: 'letter_yearly', priceLabel: 'CA\$39.99'),
    RevenueCatPlanOffer(productId: 'letter_lifetime', priceLabel: 'CA\$99.99'),
  ];
  Object? loadError;
  Object? configureError;
  Object? customerError;
  Completer<RevenueCatCustomerState>? customerCompleter;
  Object? purchaseError;
  Object? restoreError;
  Completer<RevenueCatCustomerState>? restoreCompleter;
  Object? clearError;
  String? configuredUserId;
  String? purchasedProductId;
  var clearUserCalls = 0;
  var customerStateCalls = 0;
  var restoreCalls = 0;

  @override
  Future<void> configure({
    required String apiKey,
    required String appUserId,
  }) async {
    if (configureError != null) throw configureError!;
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
  Future<RevenueCatCustomerState> currentCustomerState() async {
    customerStateCalls += 1;
    if (customerError != null) throw customerError!;
    if (customerCompleter != null) return customerCompleter!.future;
    return restoreState ??
        const RevenueCatCustomerState(
          hasActiveEntitlement: false,
          hasPurchasedLetterProduct: false,
        );
  }

  @override
  Future<RevenueCatCustomerState> purchase(String productId) async {
    purchasedProductId = productId;
    if (purchaseError != null) throw purchaseError!;
    if (purchaseCompleter != null) return purchaseCompleter!.future;
    if (purchaseState == null) {
      throw const EntitlementException('Purchase failed.');
    }
    return purchaseState!;
  }

  @override
  Future<RevenueCatCustomerState> restore() async {
    restoreCalls += 1;
    if (restoreError != null) throw restoreError!;
    if (restoreCompleter != null) return restoreCompleter!.future;
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

  test('refresh carries the subscription period and renewal status', () async {
    final endsAt = DateTime.utc(2030, 11, 2);
    final client = FakeRevenueCatClient(
      restoreState: RevenueCatCustomerState(
        hasActiveEntitlement: true,
        hasPurchasedLetterProduct: true,
        productId: 'letter_monthly',
        expiresAt: endsAt,
        willRenew: false,
        activeSubscriptions: [
          ActivePlanPeriod(
            productId: 'letter_monthly',
            purchasedAt: DateTime.utc(2030, 10, 1),
            expiresAt: endsAt,
          ),
          ActivePlanPeriod(
            productId: 'letter_yearly',
            expiresAt: DateTime.utc(2030, 12, 2),
          ),
        ],
      ),
    );
    final repo = RevenueCatEntitlementRepository(
      appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
      appleApiKey: 'apple-key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: client,
    );
    addTearDown(repo.dispose);

    final state = await repo.refresh();

    expect(state.expiresAt, endsAt);
    expect(state.willRenew, isFalse);
    expect(state.activeSubscriptions.map((plan) => plan.productId), [
      'letter_monthly',
      'letter_yearly',
    ]);
    expect(
      state.activeSubscriptions.first.purchasedAt,
      DateTime.utc(2030, 10, 1),
    );
    expect(state.hasPremiumAccess, isTrue);
  });

  test(
    'offline refresh retains confirmed Plus until the store reports a lapse',
    () async {
      final client = FakeRevenueCatClient(
        restoreState: RevenueCatCustomerState(
          hasActiveEntitlement: true,
          hasPurchasedLetterProduct: true,
          productId: 'letter_monthly',
          expiresAt: DateTime.utc(2030, 11, 2),
          willRenew: true,
        ),
      );
      final repo = RevenueCatEntitlementRepository(
        appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
        appleApiKey: 'apple-key',
        googleApiKey: '',
        store: RevenueCatStore.apple,
        client: client,
      );
      addTearDown(repo.dispose);
      await repo.refresh();
      client.customerError = StateError('offline');

      final offline = await repo.refresh();
      expect(offline.status, EntitlementStatus.activePaid);
      expect(offline.planId, 'letter_monthly');
      expect(offline.expiresAt, DateTime.utc(2030, 11, 2));
      expect(offline.canUse(LetterCapability.personalPatterns), isTrue);
      expect(offline.canUse(LetterCapability.clinicianReports), isTrue);

      client.customerError = null;
      client.restoreState = const RevenueCatCustomerState(
        hasActiveEntitlement: false,
        hasPurchasedLetterProduct: true,
        productId: 'letter_monthly',
      );
      final reconnected = await repo.refresh();
      expect(reconnected.status, EntitlementStatus.lapsed);
      expect(reconnected.hasPremiumAccess, isFalse);
    },
  );

  test('offline restore retains confirmed Lifetime access', () async {
    final client = FakeRevenueCatClient(
      restoreState: active(productId: 'letter_lifetime'),
    );
    final repo = RevenueCatEntitlementRepository(
      appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
      appleApiKey: 'apple-key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: client,
    );
    addTearDown(repo.dispose);
    await repo.refresh();
    client.restoreError = StateError('offline');

    final offline = await repo.restorePurchases();
    expect(offline.status, EntitlementStatus.activePaid);
    expect(offline.planId, 'letter_lifetime');
    expect(offline.canUse(LetterCapability.clinicianReports), isTrue);
  });

  test(
    'offline account switch cannot inherit the previous account Plus',
    () async {
      final client = FakeRevenueCatClient(
        restoreState: active(productId: 'letter_lifetime'),
      );
      final repo = RevenueCatEntitlementRepository(
        appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
        appleApiKey: 'apple-key',
        googleApiKey: '',
        store: RevenueCatStore.apple,
        client: client,
      );
      addTearDown(repo.dispose);
      await repo.refresh();
      client.configureError = StateError('offline');

      await repo.identifyAuthenticatedUser(
        '550e8400-e29b-41d4-a716-446655440000',
      );
      expect(repo.current.hasPremiumAccess, isFalse);
      expect(repo.current.canUse(LetterCapability.personalPatterns), isFalse);

      client.configureError = null;
      client.restoreState = const RevenueCatCustomerState(
        hasActiveEntitlement: false,
        hasPurchasedLetterProduct: false,
      );
      await repo.identifyAuthenticatedUser(
        '550e8400-e29b-41d4-a716-446655440000',
      );
      expect(repo.current.status, EntitlementStatus.freeOrUnknown);
    },
  );

  test(
    'a delayed old-account refresh cannot restore Plus after sign-out',
    () async {
      final client = FakeRevenueCatClient(
        restoreState: active(productId: 'letter_lifetime'),
      );
      final repo = RevenueCatEntitlementRepository(
        appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
        appleApiKey: 'apple-key',
        googleApiKey: '',
        store: RevenueCatStore.apple,
        client: client,
      );
      addTearDown(repo.dispose);
      await repo.refresh();
      final delayedCustomer = Completer<RevenueCatCustomerState>();
      client.customerCompleter = delayedCustomer;

      final pendingRefresh = repo.refresh();
      await Future<void>.delayed(Duration.zero);
      await repo.clearAuthenticatedUser();
      delayedCustomer.complete(active(productId: 'letter_lifetime'));
      await pendingRefresh;

      expect(repo.current.status, EntitlementStatus.freeOrUnknown);
      expect(repo.current.canUse(LetterCapability.clinicianReports), isFalse);
    },
  );

  test(
    'an older same-account refresh cannot revoke a completed purchase',
    () async {
      final client = FakeRevenueCatClient(purchaseState: active());
      final repo = RevenueCatEntitlementRepository(
        appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
        appleApiKey: 'apple-key',
        googleApiKey: '',
        store: RevenueCatStore.apple,
        client: client,
      );
      addTearDown(repo.dispose);
      final oldRead = Completer<RevenueCatCustomerState>();
      client.customerCompleter = oldRead;

      final refresh = repo.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(
        (await repo.purchase('letter_yearly')).outcome,
        PurchaseOutcome.activated,
      );
      oldRead.complete(
        const RevenueCatCustomerState(
          hasActiveEntitlement: false,
          hasPurchasedLetterProduct: false,
        ),
      );
      await refresh;

      expect(repo.current.status, EntitlementStatus.activePaid);
      expect(repo.current.planId, 'letter_yearly');
    },
  );

  test(
    'an older same-account refresh cannot revoke a completed restore',
    () async {
      final client = FakeRevenueCatClient(restoreState: active());
      final repo = RevenueCatEntitlementRepository(
        appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
        appleApiKey: 'apple-key',
        googleApiKey: '',
        store: RevenueCatStore.apple,
        client: client,
      );
      addTearDown(repo.dispose);
      final oldRead = Completer<RevenueCatCustomerState>();
      client.customerCompleter = oldRead;

      final refresh = repo.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(
        (await repo.restorePurchases()).status,
        EntitlementStatus.activePaid,
      );
      oldRead.complete(
        const RevenueCatCustomerState(
          hasActiveEntitlement: false,
          hasPurchasedLetterProduct: false,
        ),
      );
      await refresh;

      expect(repo.current.status, EntitlementStatus.activePaid);
    },
  );

  test(
    'a current same-account refresh still applies a store revocation',
    () async {
      final client = FakeRevenueCatClient(restoreState: active());
      final repo = RevenueCatEntitlementRepository(
        appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
        appleApiKey: 'apple-key',
        googleApiKey: '',
        store: RevenueCatStore.apple,
        client: client,
      );
      addTearDown(repo.dispose);
      await repo.refresh();
      client.restoreState = const RevenueCatCustomerState(
        hasActiveEntitlement: false,
        hasPurchasedLetterProduct: true,
        productId: 'letter_yearly',
      );

      expect((await repo.refresh()).status, EntitlementStatus.lapsed);
      expect(repo.current.hasPremiumAccess, isFalse);
    },
  );

  test(
    'delayed old-account purchase and restore cannot grant Plus after sign-out',
    () async {
      final client = FakeRevenueCatClient();
      final repo = RevenueCatEntitlementRepository(
        appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
        appleApiKey: 'apple-key',
        googleApiKey: '',
        store: RevenueCatStore.apple,
        client: client,
      );
      addTearDown(repo.dispose);
      final delayedPurchase = Completer<RevenueCatCustomerState>();
      final delayedRestore = Completer<RevenueCatCustomerState>();
      client.purchaseCompleter = delayedPurchase;
      client.restoreCompleter = delayedRestore;

      final purchase = repo.purchase('letter_monthly');
      final restore = repo.restorePurchases();
      await Future<void>.delayed(Duration.zero);
      await repo.clearAuthenticatedUser();
      delayedPurchase.complete(active(productId: 'letter_monthly'));
      delayedRestore.complete(active(productId: 'letter_yearly'));
      expect((await purchase).state.hasPremiumAccess, isFalse);
      expect((await restore).hasPremiumAccess, isFalse);
      expect(repo.current.status, EntitlementStatus.freeOrUnknown);
    },
  );

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

  test(
    'signing back into the same account reloads Plus without Restore',
    () async {
      const userId = '2c1a7f42-2d87-4ad6-8d89-b6b68b429127';
      final client = FakeRevenueCatClient(restoreState: active());
      final repo = RevenueCatEntitlementRepository(
        appUserId: '',
        appleApiKey: 'apple-key',
        googleApiKey: '',
        store: RevenueCatStore.apple,
        client: client,
      );
      addTearDown(repo.dispose);

      await repo.identifyAuthenticatedUser(userId);
      expect(repo.current.status, EntitlementStatus.activePaid);
      await repo.clearAuthenticatedUser();
      expect(repo.current.status, EntitlementStatus.freeOrUnknown);

      await repo.identifyAuthenticatedUser(userId);
      expect(repo.current.status, EntitlementStatus.activePaid);
      expect(client.customerStateCalls, 2);
      expect(client.restoreCalls, 0);
    },
  );

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

  test(
    'plan load identifies account setup separately from connectivity',
    () async {
      final repo = RevenueCatEntitlementRepository(
        appUserId: '',
        appleApiKey: 'rc_apple_key',
        googleApiKey: '',
        store: RevenueCatStore.apple,
        client: FakeRevenueCatClient(),
      );
      await expectLater(
        repo.loadPlans(),
        throwsA(
          isA<EntitlementException>()
              .having(
                (error) => error.planLoadFailureCode,
                'planLoadFailureCode',
                PlanLoadFailureCode.accountNotReady,
              )
              .having(
                (error) => error.message,
                'message',
                contains('Connect an account'),
              ),
        ),
      );
      final restored = await repo.restorePurchases();
      expect(
        restored.message,
        'Connect an account before restoring purchases.',
      );
      await repo.dispose();
    },
  );

  test(
    'plan load reports missing store key before making an SDK call',
    () async {
      final repo = RevenueCatEntitlementRepository(
        appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
        appleApiKey: '',
        googleApiKey: '',
        store: RevenueCatStore.apple,
        client: FakeRevenueCatClient(),
      );
      await expectLater(
        repo.loadPlans(),
        throwsA(
          isA<EntitlementException>().having(
            (error) => error.planLoadFailureCode,
            'planLoadFailureCode',
            PlanLoadFailureCode.apiKeyMissing,
          ),
        ),
      );
      await repo.dispose();
    },
  );

  test('plan load separates store setup errors from offering errors', () async {
    final client = FakeRevenueCatClient()
      ..configureError = StateError('setup failed');
    final repo = RevenueCatEntitlementRepository(
      appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
      appleApiKey: 'rc_apple_key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: client,
    );
    await expectLater(
      repo.loadPlans(),
      throwsA(
        isA<EntitlementException>().having(
          (error) => error.planLoadFailureCode,
          'planLoadFailureCode',
          PlanLoadFailureCode.storeSetupFailed,
        ),
      ),
    );
    client.configureError = null;
    client.loadError = StateError('request failed');
    await expectLater(
      repo.loadPlans(),
      throwsA(
        isA<EntitlementException>().having(
          (error) => error.planLoadFailureCode,
          'planLoadFailureCode',
          PlanLoadFailureCode.offeringRequestFailed,
        ),
      ),
    );
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
    expect(plans[1].priceLabel, 'CA\$9.99 / month');
    expect(plans[2].priceLabel, 'CA\$99.99 once');
    await repo.dispose();
  });

  test(
    'catalog failure does not revoke an already confirmed Plus plan',
    () async {
      final client = FakeRevenueCatClient(
        restoreState: RevenueCatCustomerState(
          hasActiveEntitlement: true,
          hasPurchasedLetterProduct: true,
          productId: 'letter_monthly',
          expiresAt: DateTime.utc(2030, 11, 2),
          willRenew: true,
        ),
      );
      final repo = RevenueCatEntitlementRepository(
        appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
        appleApiKey: 'key',
        googleApiKey: '',
        store: RevenueCatStore.apple,
        client: client,
      );
      addTearDown(repo.dispose);
      await repo.refresh();
      client.loadError = StateError('catalog offline');

      await expectLater(repo.loadPlans(), throwsA(isA<EntitlementException>()));

      expect(repo.current.hasPremiumAccess, isTrue);
      expect(repo.current.planId, 'letter_monthly');
      expect(repo.current.expiresAt, DateTime.utc(2030, 11, 2));
      expect(repo.current.willRenew, isTrue);

      client.loadError = const EntitlementException('Empty catalog.');
      await expectLater(repo.loadPlans(), throwsA(isA<EntitlementException>()));
      expect(repo.current.hasPremiumAccess, isTrue);
      expect(repo.current.planId, 'letter_monthly');
    },
  );

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

  test(
    'changing an active plan keeps access during and after store wait',
    () async {
      final purchaseCompleter = Completer<RevenueCatCustomerState>();
      final client = FakeRevenueCatClient(
        restoreState: active(productId: 'letter_monthly'),
      )..purchaseCompleter = purchaseCompleter;
      final repo = RevenueCatEntitlementRepository(
        appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
        appleApiKey: 'key',
        googleApiKey: '',
        store: RevenueCatStore.apple,
        client: client,
      );
      addTearDown(repo.dispose);
      await repo.refresh();
      final observed = <EntitlementState>[];
      final subscription = repo.watch().listen(observed.add);
      addTearDown(subscription.cancel);

      final purchase = repo.purchase('letter_yearly');
      await Future<void>.delayed(Duration.zero);
      expect(repo.current.planId, 'letter_monthly');
      expect(repo.current.hasPremiumAccess, isTrue);
      purchaseCompleter.complete(
        const RevenueCatCustomerState(
          hasActiveEntitlement: false,
          hasPurchasedLetterProduct: true,
          productId: 'letter_yearly',
        ),
      );
      final result = await purchase;
      expect(result.outcome, PurchaseOutcome.pending);
      expect(repo.current.planId, 'letter_monthly');
      expect(observed.every((state) => state.hasPremiumAccess), isTrue);
    },
  );

  test('a deferred crossgrade keeps the current subscription active', () async {
    final client = FakeRevenueCatClient(
      restoreState: active(productId: 'letter_monthly'),
      purchaseState: active(productId: 'letter_monthly'),
    );
    final repo = RevenueCatEntitlementRepository(
      appUserId: '2c1a7f42-2d87-4ad6-8d89-b6b68b429127',
      appleApiKey: 'key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: client,
    );
    addTearDown(repo.dispose);
    await repo.refresh();

    final result = await repo.purchase('letter_yearly');

    expect(client.purchasedProductId, 'letter_yearly');
    expect(result.outcome, PurchaseOutcome.activated);
    expect(repo.current.planId, 'letter_monthly');
    expect(repo.current.hasPremiumAccess, isTrue);
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
          contains('not configured for this build'),
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
