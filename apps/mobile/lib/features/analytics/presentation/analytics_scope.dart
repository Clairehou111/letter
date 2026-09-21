import 'package:flutter/widgets.dart';

import '../domain/analytics_service.dart';

class AnalyticsScope extends InheritedWidget {
  const AnalyticsScope({
    required this.service,
    required super.child,
    super.key,
  });

  final AnalyticsService service;

  static AnalyticsService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AnalyticsScope>()?.service;

  @override
  bool updateShouldNotify(AnalyticsScope oldWidget) =>
      service != oldWidget.service;
}
