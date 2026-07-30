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
  Future<EntitlementState> startIntroMonth(String planId) async {
    _set(
      EntitlementState(status: EntitlementStatus.activeIntro, planId: planId),
    );
    return _state;
  }

  @override
  Future<EntitlementState> restorePurchases() async => _state;

  /// Test/development helper: move into any state directly.
  void debugSet(EntitlementState state) => _set(state);

  void _set(EntitlementState next) {
    _state = next;
    _controller.add(next);
  }

  Future<void> dispose() => _controller.close();
}
