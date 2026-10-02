// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' hide PurchaseResult;

import '../domain/entitlement.dart';
import '../domain/entitlement_repository.dart';

enum RevenueCatStore { apple, google }

class RevenueCatPlanOffer {
  const RevenueCatPlanOffer({
    required this.productId,
    required this.priceLabel,
    this.packageId,
  });

  final String productId;
  final String priceLabel;
  final String? packageId;
}

class RevenueCatCustomerState {
  const RevenueCatCustomerState({
    required this.hasActiveEntitlement,
    required this.hasPurchasedLetterProduct,
    this.productId,
    this.isIntro = false,
    this.isGracePeriod = false,
    this.managementUrl,
    this.expiresAt,
    this.willRenew,
    this.activeSubscriptions = const [],
  });

  final bool hasActiveEntitlement;
  final bool hasPurchasedLetterProduct;
  final String? productId;
  final bool isIntro;
  final bool isGracePeriod;
  final String? managementUrl;
  final DateTime? expiresAt;
  final bool? willRenew;
  final List<ActivePlanPeriod> activeSubscriptions;
}

/// Small SDK port so domain behavior is testable without a platform channel.
abstract interface class RevenueCatClient {
  Future<void> configure({required String apiKey, required String appUserId});

  Future<void> clearUser();

  Future<List<RevenueCatPlanOffer>> loadPlans();

  Future<RevenueCatCustomerState> currentCustomerState();

  Future<RevenueCatCustomerState> purchase(String productId);

  Future<RevenueCatCustomerState> restore();
}

/// Production RevenueCat 10.8.0 client. It sends only the authenticated
/// Supabase UUID as the RevenueCat app user id.
final class PurchasesFlutterRevenueCatClient implements RevenueCatClient {
  String? _configuredUserId;
  Offering? _currentOffering;

  @override
  Future<void> configure({
    required String apiKey,
    required String appUserId,
  }) async {
    if (apiKey.isEmpty || appUserId.isEmpty) {
      throw const EntitlementException('Purchases are unavailable.');
    }
    if (_configuredUserId == appUserId) return;
    if (_configuredUserId == null) {
      final configuration = PurchasesConfiguration(apiKey)
        ..appUserID = appUserId
        ..automaticDeviceIdentifierCollectionEnabled = false
        ..diagnosticsEnabled = false;
      await Purchases.configure(configuration);
    } else {
      await Purchases.logIn(appUserId);
    }
    _configuredUserId = appUserId;
  }

  @override
  Future<void> clearUser() async {
    _currentOffering = null;
    if (_configuredUserId == null || _configuredUserId!.isEmpty) return;
    await Purchases.logOut();
    // RevenueCat remains configured with a fresh anonymous user. A later
    // account can therefore be attached with logIn rather than configure.
    _configuredUserId = '';
  }

  @override
  Future<RevenueCatCustomerState> currentCustomerState() async =>
      _toCustomerState(await Purchases.getCustomerInfo());

  @override
  Future<List<RevenueCatPlanOffer>> loadPlans() async {
    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    if (current == null) return const [];
    _currentOffering = current;
    return [
      for (final package in current.availablePackages)
        if (const {
          'letter_monthly',
          'letter_yearly',
          'letter_lifetime',
        }.contains(package.storeProduct.identifier))
          RevenueCatPlanOffer(
            productId: package.storeProduct.identifier,
            packageId: package.identifier,
            priceLabel: package.storeProduct.priceString,
          ),
    ];
  }

  @override
  Future<RevenueCatCustomerState> purchase(String productId) async {
    final offering =
        _currentOffering ?? (await Purchases.getOfferings()).current;
    if (offering == null) {
      throw const EntitlementException('Plans are unavailable.');
    }
    _currentOffering = offering;
    Package? package;
    for (final candidate in offering.availablePackages) {
      if (candidate.storeProduct.identifier == productId) {
        package = candidate;
        break;
      }
    }
    if (package == null) {
      throw const EntitlementException('That plan is unavailable.');
    }
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return _toCustomerState(result.customerInfo);
  }

  @override
  Future<RevenueCatCustomerState> restore() async =>
      _toCustomerState(await Purchases.restorePurchases());

  RevenueCatCustomerState _toCustomerState(CustomerInfo info) {
    final active = info.entitlements.active['letter_plus'];
    final purchased = info.allPurchasedProductIdentifiers.firstWhere(
      (id) => const {
        'letter_monthly',
        'letter_yearly',
        'letter_lifetime',
      }.contains(id),
      orElse: () => '',
    );
    final activeSubscriptions = info.subscriptionsByProductIdentifier.values
        .where(
          (subscription) =>
              subscription.isActive &&
              const {
                'letter_monthly',
                'letter_yearly',
              }.contains(subscription.productIdentifier),
        )
        .map(
          (subscription) => ActivePlanPeriod(
            productId: subscription.productIdentifier,
            purchasedAt: DateTime.tryParse(subscription.purchaseDate)?.toUtc(),
            expiresAt: DateTime.tryParse(
              subscription.expiresDate ?? '',
            )?.toUtc(),
            willRenew: subscription.willRenew,
          ),
        )
        .toList();
    if (activeSubscriptions.isEmpty) {
      for (final id in info.activeSubscriptions) {
        if (!const {'letter_monthly', 'letter_yearly'}.contains(id)) {
          continue;
        }
        activeSubscriptions.add(
          ActivePlanPeriod(
            productId: id,
            purchasedAt: DateTime.tryParse(
              info.allPurchaseDates[id] ?? '',
            )?.toUtc(),
            expiresAt: DateTime.tryParse(
              info.allExpirationDates[id] ?? '',
            )?.toUtc(),
            willRenew: id == active?.productIdentifier
                ? active?.willRenew
                : null,
          ),
        );
      }
    }
    return RevenueCatCustomerState(
      hasActiveEntitlement: active != null && active.isActive,
      hasPurchasedLetterProduct: purchased.isNotEmpty,
      productId:
          active?.productIdentifier ?? (purchased.isEmpty ? null : purchased),
      isIntro: active?.periodType == PeriodType.intro,
      isGracePeriod:
          active != null &&
          active.isActive &&
          active.billingIssueDetectedAt != null,
      managementUrl: info.managementURL,
      expiresAt: DateTime.tryParse(active?.expirationDate ?? '')?.toUtc(),
      willRenew: active?.willRenew,
      activeSubscriptions: activeSubscriptions,
    );
  }
}

/// Store-backed entitlement repository. It never substitutes local access for
/// a missing/failing store configuration.
final class RevenueCatEntitlementRepository implements EntitlementRepository {
  RevenueCatEntitlementRepository({
    required String appUserId,
    required this.appleApiKey,
    required this.googleApiKey,
    this.store,
    RevenueCatClient? client,
  }) : _appUserId = appUserId,
       _client = client ?? PurchasesFlutterRevenueCatClient(),
       _state = const EntitlementState(status: EntitlementStatus.freeOrUnknown),
       _stateBeforeOperation = const EntitlementState(
         status: EntitlementStatus.freeOrUnknown,
       );

  String _appUserId;
  int _identityGeneration = 0;
  int _readGeneration = 0;
  int _purchaseRevision = 0;
  int _restoreGeneration = 0;
  final String appleApiKey;
  final String googleApiKey;
  final RevenueCatStore? store;
  final RevenueCatClient _client;
  EntitlementState _state;
  EntitlementState _stateBeforeOperation;
  Uri? _managementUrl;
  final _controller = StreamController<EntitlementState>.broadcast();

  @override
  EntitlementState get current => _state;

  @override
  Stream<EntitlementState> watch() => _controller.stream;

  bool get isConfigured => _isUuid(_appUserId) && _apiKeyForStore.isNotEmpty;

  String get _apiKeyForStore {
    final selected = store;
    if (selected == RevenueCatStore.apple) return appleApiKey;
    if (selected == RevenueCatStore.google) return googleApiKey;
    return '';
  }

  @override
  Future<List<LetterPlan>> loadPlans() async {
    if (!isConfigured) {
      final accountNotReady = !_isUuid(_appUserId);
      final message = accountNotReady
          ? 'Connect an account to view plans and restore purchases.'
          : 'Purchases are unavailable on this build.';
      _set(_state.copyWithMessage(message));
      throw EntitlementException(
        message,
        planLoadFailureCode: accountNotReady
            ? PlanLoadFailureCode.accountNotReady
            : store == null
            ? PlanLoadFailureCode.storeNotSelected
            : PlanLoadFailureCode.apiKeyMissing,
      );
    }
    var requestingOffering = false;
    try {
      await _configure();
      requestingOffering = true;
      final offers = await _client.loadPlans();
      final byId = {for (final offer in offers) offer.productId: offer};
      final plans = [
        for (final plan in letterPlans)
          if (byId[plan.id] case final offer?)
            LetterPlan(
              id: plan.id,
              title: plan.title,
              priceLabel: switch (plan.id) {
                'letter_monthly' => '${offer.priceLabel} / month',
                'letter_yearly' => '${offer.priceLabel} / year',
                _ => '${offer.priceLabel} once',
              },
              effectiveMonthlyLabel: switch (plan.id) {
                'letter_monthly' => 'Renews monthly until canceled',
                'letter_yearly' => 'Renews yearly until canceled',
                _ => 'Lifetime access',
              },
              referencePriceLabel: plan.referencePriceLabel,
            ),
      ];
      if (plans.isEmpty) {
        throw const EntitlementException(
          'Plans are temporarily unavailable.',
          planLoadFailureCode: PlanLoadFailureCode.emptyOffering,
        );
      }
      return plans;
    } on EntitlementException catch (error) {
      _set(
        _state.hasPremiumAccess
            ? _state.copyWithMessage(error.message)
            : EntitlementState(
                status: EntitlementStatus.freeOrUnknown,
                planId: _state.planId,
                message: error.message,
              ),
      );
      if (error.planLoadFailureCode != null) rethrow;
      throw EntitlementException(
        error.message,
        planLoadFailureCode: requestingOffering
            ? PlanLoadFailureCode.offeringRequestFailed
            : PlanLoadFailureCode.storeSetupFailed,
      );
    } on Object catch (error) {
      assert(() {
        debugPrint('RevenueCat plan loading failed: $error');
        return true;
      }());
      if (_isStoreConfigurationError(error)) {
        const message = 'Plans are not configured for this build.';
        _set(
          _state.hasPremiumAccess
              ? _state.copyWithMessage(message)
              : EntitlementState(
                  status: EntitlementStatus.freeOrUnknown,
                  planId: _state.planId,
                  message: message,
                ),
        );
        throw const EntitlementException(
          message,
          planLoadFailureCode: PlanLoadFailureCode.storeConfigurationError,
        );
      }
      if (_state.hasPremiumAccess) {
        _set(_state.copyWithMessage('Plans are temporarily unavailable.'));
      } else {
        _markUnavailable(error);
      }
      throw EntitlementException(
        'Plans are temporarily unavailable.',
        planLoadFailureCode: requestingOffering
            ? PlanLoadFailureCode.offeringRequestFailed
            : PlanLoadFailureCode.storeSetupFailed,
      );
    }
  }

  bool _isStoreConfigurationError(Object error) {
    if (error is! PlatformException) return false;
    final details = '${error.details} ${error.message}'.toUpperCase();
    return error.code == '23' || details.contains('CONFIGURATION_ERROR');
  }

  @override
  Future<PurchaseResult> purchase(String planId) async {
    if (!isConfigured) {
      return _unavailableResult(
        !_isUuid(_appUserId)
            ? 'Connect an account before purchasing Plus.'
            : 'Purchases are unavailable on this build.',
      );
    }
    if (!letterPlans.any((plan) => plan.id == planId)) {
      return _failedResult('That plan is unavailable.');
    }
    final identityGeneration = _identityGeneration;
    // An older read must not replace the result of this store transaction.
    _readGeneration += 1;
    _stateBeforeOperation = _state;
    if (!_state.hasPremiumAccess) {
      _set(const EntitlementState(status: EntitlementStatus.pending));
    }
    try {
      await _configure();
      final customer = await _client.purchase(planId);
      if (identityGeneration != _identityGeneration) {
        return PurchaseResult(outcome: PurchaseOutcome.failed, state: _state);
      }
      _purchaseRevision += 1;
      _readGeneration += 1;
      return _applyCustomer(customer, purchase: true);
    } on PlatformException catch (error) {
      if (identityGeneration != _identityGeneration) {
        return PurchaseResult(outcome: PurchaseOutcome.failed, state: _state);
      }
      if (PurchasesErrorHelper.getErrorCode(error) ==
          PurchasesErrorCode.purchaseCancelledError) {
        _restorePreviousState();
        return PurchaseResult(
          outcome: PurchaseOutcome.cancelled,
          state: _state,
        );
      }
      return _failedResult('The purchase could not be completed.');
    } on Object catch (error) {
      if (identityGeneration != _identityGeneration) {
        return PurchaseResult(outcome: PurchaseOutcome.failed, state: _state);
      }
      return _failedResult(_safeMessage(error));
    }
  }

  @override
  Future<EntitlementState> startIntroMonth(String planId) async =>
      (await purchase(planId)).state;

  @override
  Future<EntitlementState> restorePurchases() async {
    if (!isConfigured) {
      _set(
        _state.copyWithMessage(
          !_isUuid(_appUserId)
              ? 'Connect an account before restoring purchases.'
              : 'Purchases are unavailable on this build.',
        ),
      );
      return _state;
    }
    final identityGeneration = _identityGeneration;
    final purchaseRevision = _purchaseRevision;
    final restoreGeneration = ++_restoreGeneration;
    _readGeneration += 1;
    _stateBeforeOperation = _state;
    if (!_state.hasPremiumAccess) {
      _set(const EntitlementState(status: EntitlementStatus.pending));
    }
    try {
      await _configure();
      final customer = await _client.restore();
      if (identityGeneration != _identityGeneration) return _state;
      if (purchaseRevision != _purchaseRevision ||
          restoreGeneration != _restoreGeneration) {
        return _state;
      }
      _readGeneration += 1;
      return _applyCustomer(customer).state;
    } on Object catch (error) {
      if (identityGeneration == _identityGeneration &&
          purchaseRevision == _purchaseRevision &&
          restoreGeneration == _restoreGeneration) {
        _markUnavailable(error);
      }
      return _state;
    }
  }

  @override
  Future<EntitlementState> refresh() async {
    if (!isConfigured) {
      return _state;
    }
    final identityGeneration = _identityGeneration;
    final readGeneration = ++_readGeneration;
    try {
      await _configure();
      final customer = await _client.currentCustomerState();
      if (identityGeneration != _identityGeneration ||
          readGeneration != _readGeneration) {
        return _state;
      }
      return _applyCustomer(customer).state;
    } on Object catch (error) {
      if (identityGeneration == _identityGeneration &&
          readGeneration == _readGeneration) {
        _markUnavailable(error);
      }
      return _state;
    }
  }

  Future<void> _configure() =>
      _client.configure(apiKey: _apiKeyForStore, appUserId: _appUserId);

  @override
  Future<void> identifyAuthenticatedUser(String userId) async {
    if (!_isUuid(userId)) {
      _identityGeneration += 1;
      _appUserId = '';
      _managementUrl = null;
      _set(
        const EntitlementState(
          status: EntitlementStatus.freeOrUnknown,
          message: 'Purchases require an authenticated account.',
        ),
      );
      return;
    }
    if (userId == _appUserId && _state.hasPremiumAccess) {
      return;
    }
    if (userId != _appUserId) {
      // A confirmed purchase belongs to the previous account. Never carry it
      // into a new identity if store reconciliation fails while offline.
      _appUserId = userId;
      _identityGeneration += 1;
      _managementUrl = null;
      _set(const EntitlementState(status: EntitlementStatus.freeOrUnknown));
    }
    final identityGeneration = _identityGeneration;
    final readGeneration = ++_readGeneration;
    if (!isConfigured) {
      _set(
        const EntitlementState(
          status: EntitlementStatus.freeOrUnknown,
          message: 'Purchases are unavailable on this build.',
        ),
      );
      return;
    }
    try {
      await _configure();
      final customer = await _client.currentCustomerState();
      if (identityGeneration == _identityGeneration &&
          readGeneration == _readGeneration) {
        _applyCustomer(customer);
      }
    } on Object catch (error) {
      if (identityGeneration == _identityGeneration &&
          readGeneration == _readGeneration) {
        _markUnavailable(error);
      }
    }
  }

  @override
  Future<void> clearAuthenticatedUser() async {
    final hadAuthenticatedUser = _isUuid(_appUserId);
    _identityGeneration += 1;
    _appUserId = '';
    _managementUrl = null;
    _set(const EntitlementState(status: EntitlementStatus.freeOrUnknown));
    try {
      if (hadAuthenticatedUser) await _client.clearUser();
    } on Object {
      // Store logout may fail offline. Letter Within must still revoke local access;
      // the next authenticated UUID is reconciled through RevenueCat.logIn.
    }
  }

  @override
  Future<Uri?> managementUrl() async => _managementUrl;

  PurchaseResult _applyCustomer(
    RevenueCatCustomerState customer, {
    bool purchase = false,
  }) {
    _managementUrl = customer.managementUrl == null
        ? null
        : Uri.tryParse(customer.managementUrl!);
    if (purchase &&
        _stateBeforeOperation.hasPremiumAccess &&
        !customer.hasActiveEntitlement) {
      _set(_stateBeforeOperation);
      return PurchaseResult(outcome: PurchaseOutcome.pending, state: _state);
    }
    final status = customer.hasActiveEntitlement
        ? (customer.isGracePeriod
              ? EntitlementStatus.gracePeriod
              : customer.isIntro
              ? EntitlementStatus.activeIntro
              : EntitlementStatus.activePaid)
        : purchase
        ? EntitlementStatus.pending
        : customer.hasPurchasedLetterProduct
        ? EntitlementStatus.lapsed
        : EntitlementStatus.freeOrUnknown;
    _set(
      EntitlementState(
        status: status,
        planId: customer.productId,
        expiresAt: customer.expiresAt,
        willRenew: customer.willRenew,
        activeSubscriptions: customer.activeSubscriptions,
      ),
    );
    return PurchaseResult(
      outcome: _state.hasPremiumAccess
          ? PurchaseOutcome.activated
          : status == EntitlementStatus.pending
          ? PurchaseOutcome.pending
          : PurchaseOutcome.failed,
      state: _state,
    );
  }

  PurchaseResult _unavailableResult(String message) {
    _set(_state.copyWithMessage(message));
    return PurchaseResult(
      outcome: PurchaseOutcome.unavailable,
      state: _state,
      message: message,
    );
  }

  PurchaseResult _failedResult(String message) {
    _restorePreviousState(message: message);
    return PurchaseResult(
      outcome: PurchaseOutcome.failed,
      state: _state,
      message: message,
    );
  }

  void _markUnavailable(Object error) {
    if (_state.hasPremiumAccess) {
      // A failed network read is not a store-confirmed revocation. The SDK
      // supplies a fresh or cached CustomerInfo when it can; retain the last
      // confirmed access until a successful read says otherwise.
      _set(_state.copyWithMessage(_safeMessage(error)));
      return;
    }
    _set(
      EntitlementState(
        status: EntitlementStatus.offlineUnknown,
        planId: _state.planId,
        message: _safeMessage(error),
        expiresAt: _state.expiresAt,
        willRenew: _state.willRenew,
        activeSubscriptions: _state.activeSubscriptions,
      ),
    );
  }

  void _restorePreviousState({String? message}) {
    final previous = _state.status == EntitlementStatus.pending
        ? _stateBeforeOperation
        : _state;
    _set(
      EntitlementState(
        status: previous.status,
        planId: previous.planId,
        message: message,
        expiresAt: previous.expiresAt,
        willRenew: previous.willRenew,
        activeSubscriptions: previous.activeSubscriptions,
      ),
    );
  }

  String _safeMessage(Object error) => error is EntitlementException
      ? error.message
      : 'The store could not verify your purchase.';

  void _set(EntitlementState next) {
    _state = next;
    _controller.add(next);
  }

  @override
  Future<void> dispose() => _controller.close();
}

bool _isUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
).hasMatch(value);

extension on EntitlementState {
  EntitlementState copyWithMessage(String message) => EntitlementState(
    status: status,
    planId: planId,
    message: message,
    expiresAt: expiresAt,
    willRenew: willRenew,
    activeSubscriptions: activeSubscriptions,
  );
}
