import 'dart:async';

import '../../entitlement/domain/entitlement.dart';
import '../../entitlement/domain/entitlement_repository.dart';

/// RevenueCat-backed entitlement repository.
///
/// In production this replaces LocalEntitlementRepository. When RevenueCat
/// is not configured (dev mode), falls back to the local adapter.
///
/// Store keys come from AppConfig; health data never crosses this boundary.
final class RevenueCatEntitlementRepository implements EntitlementRepository {
  RevenueCatEntitlementRepository({
    required this._appleApiKey,
    required this._googleApiKey,
    this.onFallback,
  }) : _state = const EntitlementState(status: EntitlementStatus.freeOrUnknown);

  final String _appleApiKey;
  final String _googleApiKey;
  EntitlementState _state;
  final _controller = StreamController<EntitlementState>.broadcast();
  final void Function(String reason)? onFallback;

  bool get _isConfigured =>
      _appleApiKey.isNotEmpty || _googleApiKey.isNotEmpty;

  @override
  EntitlementState get current => _state;

  @override
  Stream<EntitlementState> watch() => _controller.stream;

  @override
  Future<EntitlementState> startIntroMonth(String planId) async {
    if (!_isConfigured) {
      onFallback?.call('RevenueCat not configured; using local state');
      _set(
        EntitlementState(status: EntitlementStatus.activeIntro, planId: planId),
      );
      return _state;
    }
    // TODO: Integrate RevenueCat purchases_flutter SDK.
    // When configured:
    // 1. Call Purchases.configure() with apiKey
    // 2. Call Purchases.purchasePackage(package)
    // 3. Map customerInfo.entitlements.active to EntitlementState
    onFallback?.call('RevenueCat purchase flow pending SDK integration');
    _set(
      EntitlementState(status: EntitlementStatus.activeIntro, planId: planId),
    );
    return _state;
  }

  @override
  Future<EntitlementState> restorePurchases() async {
    if (!_isConfigured) {
      return _state;
    }
    // TODO: Call Purchases.restorePurchases()
    onFallback?.call('RevenueCat restore pending SDK integration');
    return _state;
  }

  void _set(EntitlementState next) {
    _state = next;
    _controller.add(next);
  }

  Future<void> dispose() async => _controller.close();
}
