import 'entitlement.dart';

enum PurchaseOutcome { activated, pending, cancelled, failed, unavailable }

class PurchaseResult {
  const PurchaseResult({
    required this.outcome,
    required this.state,
    this.message,
  });

  final PurchaseOutcome outcome;
  final EntitlementState state;
  final String? message;
}

class EntitlementException implements Exception {
  const EntitlementException(this.message);

  final String message;

  @override
  String toString() => 'EntitlementException($message)';
}

/// Source of entitlement state. Store-backed implementations (RevenueCat)
/// live behind this interface; health data never crosses it.
abstract class EntitlementRepository {
  EntitlementState get current;

  Stream<EntitlementState> watch();

  /// Loads only the approved catalog. Store-backed adapters return localized
  /// labels; the local adapter returns deterministic reference labels.
  Future<List<LetterPlan>> loadPlans();

  /// Purchases a selected approved plan. Cancellation never becomes failure
  /// and never grants access.
  Future<PurchaseResult> purchase(String planId);

  Future<EntitlementState> restorePurchases();

  /// Reconciles access with the store without starting a purchase flow.
  /// Implementations must keep failures isolated from local health features.
  Future<EntitlementState> refresh() async => current;

  /// Binds billing to the authenticated Supabase UUID. Local adapters ignore
  /// this; store adapters must never use email or health identifiers.
  Future<void> identifyAuthenticatedUser(String userId) async {}

  /// Removes app-level access to the previous account without touching local
  /// health records.
  Future<void> clearAuthenticatedUser() async {}

  /// Store-provided subscription management destination, when applicable.
  Future<Uri?> managementUrl() async => null;

  Future<void> dispose() async {}

  /// Compatibility helper for the deterministic local adapter and old tests.
  Future<EntitlementState> startIntroMonth(String planId) async =>
      (await purchase(planId)).state;
}
