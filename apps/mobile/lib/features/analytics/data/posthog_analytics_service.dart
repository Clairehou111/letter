// ignore_for_file: prefer_initializing_formals

import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:flutter/services.dart';

import '../domain/analytics_service.dart';

abstract interface class PosthogClient {
  Future<void> setup(PostHogConfig config);

  Future<void> capture({
    required String eventName,
    required Map<String, Object> properties,
  });

  Future<void> enable();

  Future<void> disable();

  /// Stops native workers before consent-revocation cleanup.
  Future<void> close();

  /// Removes native SDK queues that must not survive consent withdrawal.
  Future<void> clearPendingEvents(String projectToken);
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
  Future<void> enable() => _posthog.enable();

  @override
  Future<void> disable() => _posthog.disable();

  @override
  Future<void> close() => _posthog.close();

  @override
  Future<void> clearPendingEvents(String projectToken) async {
    const channel = MethodChannel('app.letterwithin/privacy');
    await channel.invokeMethod<void>('clearPosthogQueues', projectToken);
  }
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
      ..rageClickConfig.enabled = false
      ..surveys = false
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
    if (_configured) {
      // optOut prevents new capture, close stops native timers/reachability,
      // then the native bridge removes the file-backed queue. reset() is not
      // queue deletion in posthog-ios and must not be treated as such.
      await _client.disable();
      await _client.close();
      await _client.clearPendingEvents(_projectToken);
      _configured = false;
    }
  }

  @override
  Future<void> dispose() async {
    _enabled = false;
    if (_configured) {
      // Ordinary app teardown is not consent withdrawal. Preserve queued,
      // consented events for the next launch and only stop SDK workers.
      await _client.close();
      _configured = false;
    }
  }
}
