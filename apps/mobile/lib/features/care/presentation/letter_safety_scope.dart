import 'package:flutter/widgets.dart';

import '../domain/safety_dialer.dart';

/// Optional override point for safety content resolution.
///
/// Production uses the device region and the url_launcher dialer by default;
/// tests wrap subtrees with explicit values instead of touching platform
/// channels.
class LetterSafetyScope extends InheritedWidget {
  const LetterSafetyScope({
    super.key,
    this.regionCode,
    this.dialer,
    required super.child,
  });

  /// ISO region code override (e.g. `US`, `CA`). Null means device region.
  final String? regionCode;

  /// Dialer override. Null means the default url_launcher dialer.
  final SafetyDialer? dialer;

  static LetterSafetyScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LetterSafetyScope>();
  }

  @override
  bool updateShouldNotify(LetterSafetyScope oldWidget) {
    return regionCode != oldWidget.regionCode || dialer != oldWidget.dialer;
  }
}
