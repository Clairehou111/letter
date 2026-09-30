import 'dart:developer' as developer;

import '../domain/analytics_service.dart';

/// Local development adapter. Events created before consent are discarded and
/// are never buffered or flushed later.
final class DevAnalyticsService implements AnalyticsService {
  bool _enabled = false;

  @override
  bool get isEnabled => _enabled;

  @override
  Future<void> track(AnalyticsPayload payload) async {
    if (!_enabled) return;
    developer.log(
      '[analytics] ${payload.event.name} ${payload.toRecord()}',
      name: 'analytics',
    );
  }

  @override
  Future<void> enable() async => _enabled = true;

  @override
  Future<void> disable() async => _enabled = false;

  @override
  Future<void> dispose() async => _enabled = false;
}
