// ignore_for_file: prefer_initializing_formals

import 'package:posthog_flutter/posthog_flutter.dart';

import '../domain/analytics_service.dart';

abstract interface class PosthogClient {
  Future<void> setup(PostHogConfig config);

  Future<void> capture({
    required String eventName,
    required Map<String, Object> properties,
  });

  Future<void> identify({required String userId});

  Future<void> enable();

  Future<void> disable();

  Future<void> reset();
}

final class FlutterPosthogClient implements PosthogClient {
  FlutterPosthogClient({Posthog? posthog}) : _posthog = posthog ?? Posthog();

  final Posthog _posthog;

  @override
  Future<void> setup(PostHogConfig config) => _posthog.setup(config);

  @override
  Future<void> capture({
    required String eventName,
    required Map<String, Object> properties,
  }) => _posthog.capture(eventName: eventName, properties: properties);

  @override
  Future<void> identify({required String userId}) =>
      _posthog.identify(userId: userId);

  @override
  Future<void> enable() => _posthog.enable();

  @override
  Future<void> disable() => _posthog.disable();

  @override
  Future<void> reset() => _posthog.reset();
}

final class PosthogAnalyticsService implements AnalyticsService {
  PosthogAnalyticsService({
    required String projectToken,
    required String host,
    PosthogClient? client,
  }) : _projectToken = projectToken,
       _host = host,
       _client = client ?? FlutterPosthogClient();

  final String _projectToken;
  final String _host;
  final PosthogClient _client;
  bool _enabled = false;
  bool _configured = false;

  @override
  bool get isEnabled => _enabled;

  Future<void> _setupIfNeeded() async {
    if (_configured || _projectToken.isEmpty || _host.isEmpty) return;
    final config = PostHogConfig(_projectToken)
      ..host = _host
      ..optOut = true
      ..captureApplicationLifecycleEvents = false
      ..sessionReplay = false
      ..preloadFeatureFlags = false
      ..sendFeatureFlagEvents = false
      ..capturePushNotificationSubscriptions = false
      ..capturePushNotificationOpened = false
      ..personProfiles = PostHogPersonProfiles.never;
    await _client.setup(config);
    _configured = true;
  }

  @override
  Future<void> track(AnalyticsPayload payload) async {
    if (!_enabled) return;
    await _setupIfNeeded();
    if (!_configured) return;
    await _client.capture(
      eventName: payload.event.name,
      properties: payload.toRecord(),
    );
  }

  @override
  Future<void> enable() async {
    await _setupIfNeeded();
    if (!_configured) return;
    await _client.enable();
    _enabled = true;
  }

  @override
  Future<void> disable() async {
    _enabled = false;
    if (_configured) await _client.disable();
  }

  @override
  Future<void> identifyAuthenticatedUser(String supabaseUserId) async {
    if (!_enabled || !_isUuid(supabaseUserId)) return;
    await _client.identify(userId: supabaseUserId);
  }

  @override
  Future<void> clearAuthenticatedUser() async {
    if (_configured) await _client.reset();
  }

  @override
  Future<void> dispose() async {
    _enabled = false;
    if (_configured) {
      await _client.disable();
      await _client.reset();
    }
  }
}

bool _isUuid(String value) {
  final uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  return uuid.hasMatch(value);
}
