import 'package:flutter/widgets.dart';

import '../domain/entitlement.dart';
import '../domain/entitlement_repository.dart';

/// Provides entitlement state to the subtree. Defaults to free/unknown when
/// no scope is present so ungated previews keep working.
class EntitlementScope extends InheritedWidget {
  const EntitlementScope({
    super.key,
    required this.repository,
    required this.state,
    required super.child,
  });

  final EntitlementRepository repository;
  final EntitlementState state;

  static EntitlementState stateOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<EntitlementScope>();
    return scope?.state ??
        const EntitlementState(status: EntitlementStatus.freeOrUnknown);
  }

  static EntitlementRepository? repositoryOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<EntitlementScope>()
        ?.repository;
  }

  static bool canUse(BuildContext context, LetterCapability capability) {
    return stateOf(context).canUse(capability);
  }

  @override
  bool updateShouldNotify(EntitlementScope oldWidget) {
    return state != oldWidget.state || repository != oldWidget.repository;
  }
}
