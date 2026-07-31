import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/entitlement.dart';
import '../domain/entitlement_repository.dart';

/// Provides entitlement state to the subtree. Defaults to free/unknown when
/// no scope is present so ungated previews keep working.
class EntitlementScope extends StatefulWidget {
  const EntitlementScope({
    super.key,
    required this.repository,
    this.initialState,
    required this.child,
  });

  final EntitlementRepository repository;
  final EntitlementState? initialState;
  final Widget child;

  static EntitlementState stateOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_EntitlementInherited>();
    return scope?.state ??
        const EntitlementState(status: EntitlementStatus.freeOrUnknown);
  }

  static EntitlementRepository? repositoryOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_EntitlementInherited>()
        ?.repository;
  }

  static bool canUse(BuildContext context, LetterCapability capability) {
    return stateOf(context).canUse(capability);
  }

  @override
  State<EntitlementScope> createState() => _EntitlementScopeState();
}

class _EntitlementScopeState extends State<EntitlementScope> {
  late EntitlementState _state;
  StreamSubscription<EntitlementState>? _subscription;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState ?? widget.repository.current;
    _subscription = widget.repository.watch().listen((next) {
      if (mounted) setState(() => _state = next);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EntitlementInherited(
      repository: widget.repository,
      state: _state,
      child: widget.child,
    );
  }
}

class _EntitlementInherited extends InheritedWidget {
  const _EntitlementInherited({
    required this.repository,
    required this.state,
    required super.child,
  });

  final EntitlementRepository repository;
  final EntitlementState state;

  @override
  bool updateShouldNotify(_EntitlementInherited oldWidget) {
    return state != oldWidget.state || repository != oldWidget.repository;
  }
}
