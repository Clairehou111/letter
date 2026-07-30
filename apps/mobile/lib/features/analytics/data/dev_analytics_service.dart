import 'dart:async';
import 'dart:developer' as developer;

import '../domain/analytics_service.dart';

/// Dev adapter that logs analytics events to the console. Rejects any event
/// with health-related properties. Never sends data off-device.
///
/// In production this is replaced by PostHogAnalyticsAdapter behind the same
/// interface.
final class DevAnalyticsService implements AnalyticsService {
  DevAnalyticsService() : _enabled = false;

  bool _enabled;
  final List<AnalyticsPayload> _buffer = [];

  @override
  bool get isEnabled => _enabled;

  @override
  Future<void> track(AnalyticsPayload payload) async {
    final violations = payload.validate();
    if (violations != null) {
      developer.log(
        'Analytics event REJECTED — health keys found: $violations',
        name: 'analytics',
        level: 900, // severe
      );
      return;
    }
    if (!_enabled) {
      _buffer.add(payload);
      return;
    }
    developer.log(
      '[analytics] ${payload.event.name} ${payload.properties}',
      name: 'analytics',
    );
  }

  @override
  Future<void> enable() async {
    _enabled = true;
    // Flush buffered events collected during opt-out.
    for (final payload in _buffer) {
      await track(payload);
    }
    _buffer.clear();
  }

  @override
  Future<void> disable() async {
    _enabled = false;
    _buffer.clear();
  }

  @override
  Future<void> dispose() async => _buffer.clear();
}
