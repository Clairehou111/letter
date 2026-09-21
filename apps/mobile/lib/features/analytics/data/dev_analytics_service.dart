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
  Future<void> identifyAuthenticatedUser(String supabaseUserId) async {
    if (!_isUuid(supabaseUserId)) return;
    // Deliberately do not log or retain the identifier in the dev adapter.
  }

  @override
  Future<void> clearAuthenticatedUser() async {}

  @override
  Future<void> dispose() async => _enabled = false;
}

bool _isUuid(String value) {
  final uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  return uuid.hasMatch(value);
}
