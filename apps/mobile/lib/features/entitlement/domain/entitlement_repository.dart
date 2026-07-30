import 'entitlement.dart';

/// Source of entitlement state. Store-backed implementations (RevenueCat)
/// live behind this interface; health data never crosses it.
abstract class EntitlementRepository {
  EntitlementState get current;

  Stream<EntitlementState> watch();

  /// Starts the intro month on the chosen plan. Local adapters complete
  /// immediately; the store adapter defers to the platform purchase sheet.
  Future<EntitlementState> startIntroMonth(String planId);

  Future<EntitlementState> restorePurchases();
}
