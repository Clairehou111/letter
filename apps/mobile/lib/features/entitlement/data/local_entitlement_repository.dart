import 'dart:async';

import '../domain/entitlement.dart';
import '../domain/entitlement_repository.dart';

/// Local development adapter. No store calls; state is held in memory so
/// previews and tests can exercise every entitlement state. The production
/// RevenueCat adapter replaces this without touching presentation code.
class LocalEntitlementRepository implements EntitlementRepository {
  LocalEntitlementRepository({
    EntitlementState initial = const EntitlementState(
      status: EntitlementStatus.freeOrUnknown,
    ),
  }) : _state = initial;

  EntitlementState _state;
  final _controller = StreamController<EntitlementState>.broadcast();

  @override
  EntitlementState get current => _state;

  @override
  Stream<EntitlementState> watch() => _controller.stream;

  @override
  Future<List<LetterPlan>> loadPlans() async => letterPlans;

  @override
  Future<PurchaseResult> purchase(String planId) async {
    LetterPlan? plan;
    for (final candidate in letterPlans) {
      if (candidate.id == planId) {
        plan = candidate;
        break;
      }
    }
    if (plan == null) {
      return PurchaseResult(
        outcome: PurchaseOutcome.failed,
        state: _state,
        message: 'That plan is not available.',
      );
    }
    _set(
      EntitlementState(status: EntitlementStatus.activeIntro, planId: plan.id),
    );
    return PurchaseResult(outcome: PurchaseOutcome.activated, state: _state);
  }

  @override
  Future<EntitlementState> startIntroMonth(String planId) async =>
      (await purchase(planId)).state;

  @override
  Future<EntitlementState> restorePurchases() async => _state;

  @override
  Future<EntitlementState> refresh() async => _state;

  @override
  Future<void> identifyAuthenticatedUser(String userId) async {}

  @override
  Future<void> clearAuthenticatedUser() async {}

  @override
  Future<Uri?> managementUrl() async => null;

  /// Test/development helper: move into any state directly.
  void debugSet(EntitlementState state) => _set(state);

  void _set(EntitlementState next) {
    _state = next;
    _controller.add(next);
  }

  @override
  Future<void> dispose() => _controller.close();
}
