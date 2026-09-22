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
  });

  final bool hasActiveEntitlement;
  final bool hasPurchasedLetterProduct;
  final String? productId;
  final bool isIntro;
  final bool isGracePeriod;
  final String? managementUrl;
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
      _set(_state.copyWithMessage('Purchases are unavailable on this build.'));
      throw const EntitlementException(
        'Purchases are unavailable on this build.',
      );
    }
    try {
      await _configure();
      final offers = await _client.loadPlans();
      final byId = {for (final offer in offers) offer.productId: offer};
      final plans = [
        for (final plan in letterPlans)
          if (byId[plan.id] case final offer?)
            LetterPlan(
              id: plan.id,
              title: plan.title,
              priceLabel: offer.priceLabel,
              effectiveMonthlyLabel: switch (plan.id) {
                'letter_monthly' => 'Monthly billing',
                'letter_yearly' => 'Annual billing',
                _ => 'One payment',
              },
              referencePriceLabel: plan.referencePriceLabel,
              highlight: plan.highlight,
            ),
      ];
      if (plans.isEmpty) {
        throw const EntitlementException('Plans are temporarily unavailable.');
      }
      return plans;
    } on EntitlementException catch (error) {
      _set(
        EntitlementState(
          status: EntitlementStatus.freeOrUnknown,
          planId: _state.planId,
          message: error.message,
        ),
      );
      rethrow;
    } on Object catch (error) {
      assert(() {
        debugPrint('RevenueCat plan loading failed: $error');
        return true;
      }());
      if (_isStoreConfigurationError(error)) {
        const message = 'Plans are not configured for this build.';
        _set(
          EntitlementState(
            status: EntitlementStatus.freeOrUnknown,
            planId: _state.planId,
            message: message,
          ),
        );
        throw const EntitlementException(message);
      }
      _markUnavailable(error);
      throw const EntitlementException('Plans are temporarily unavailable.');
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
      return _unavailableResult('Purchases are unavailable on this build.');
    }
    if (!letterPlans.any((plan) => plan.id == planId)) {
      return _failedResult('That plan is unavailable.');
    }
    _stateBeforeOperation = _state;
    _set(const EntitlementState(status: EntitlementStatus.pending));
    try {
      await _configure();
      final customer = await _client.purchase(planId);
      return _applyCustomer(customer, purchase: true);
    } on PlatformException catch (error) {
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
      return _failedResult(_safeMessage(error));
    }
  }

  @override
  Future<EntitlementState> startIntroMonth(String planId) async =>
      (await purchase(planId)).state;

  @override
  Future<EntitlementState> restorePurchases() async {
    if (!isConfigured) {
      _set(_state.copyWithMessage('Purchases are unavailable on this build.'));
      return _state;
    }
    _stateBeforeOperation = _state;
    _set(const EntitlementState(status: EntitlementStatus.pending));
    try {
      await _configure();
      return _applyCustomer(await _client.restore()).state;
    } on Object catch (error) {
      _markUnavailable(error);
      return _state;
    }
  }

  @override
  Future<EntitlementState> refresh() async {
    if (!isConfigured) {
      return _state;
    }
    try {
      await _configure();
      return _applyCustomer(await _client.currentCustomerState()).state;
    } on Object catch (error) {
      _markUnavailable(error);
      return _state;
    }
  }

  Future<void> _configure() =>
      _client.configure(apiKey: _apiKeyForStore, appUserId: _appUserId);

  @override
  Future<void> identifyAuthenticatedUser(String userId) async {
    if (!_isUuid(userId)) {
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
    _appUserId = userId;
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
      _applyCustomer(await _client.currentCustomerState());
    } on Object catch (error) {
      _markUnavailable(error);
    }
  }

  @override
  Future<void> clearAuthenticatedUser() async {
    final hadAuthenticatedUser = _isUuid(_appUserId);
    try {
      if (hadAuthenticatedUser) await _client.clearUser();
    } on Object {
      // Store logout may fail offline. Letter Within must still revoke local access;
      // the next authenticated UUID is reconciled through RevenueCat.logIn.
    } finally {
      _appUserId = '';
      _managementUrl = null;
      _set(const EntitlementState(status: EntitlementStatus.freeOrUnknown));
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
    _set(EntitlementState(status: status, planId: customer.productId));
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
    _set(
      EntitlementState(
        status: EntitlementStatus.offlineUnknown,
        planId: _state.planId,
        message: _safeMessage(error),
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
  EntitlementState copyWithMessage(String message) =>
      EntitlementState(status: status, planId: planId, message: message);
}
