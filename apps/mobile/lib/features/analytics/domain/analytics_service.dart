/// Closed, privacy-safe operational analytics events.
library;

enum AnalyticsPlatform { android, ios, web }

enum StartupResult { completed, failed }

enum AnalyticsRoute { archive, cycle, home, settings }

enum RouteFailureCode { networkUnavailable, unexpectedResponse, timeout }

enum PurchaseOffer { annual, monthly, lifetime }

enum PurchaseOutcome { cancelled, completed, failed, pending }

sealed class AnalyticsEvent {
  const AnalyticsEvent();

  String get name;

  /// This is an internal serialization boundary. Callers cannot provide a
  /// property map; each event exposes only its typed, reviewed fields.
  Map<String, Object> toProperties();
}

final class AppStartupEvent extends AnalyticsEvent {
  const AppStartupEvent({
    required this.appVersion,
    required this.platform,
    required this.result,
  });

  final String appVersion;
  final AnalyticsPlatform platform;
  final StartupResult result;

  @override
  String get name => 'app_startup';

  @override
  Map<String, Object> toProperties() => {
    'app_version': appVersion,
    'platform': platform.name,
    'startup_result': result.name,
  };
}

final class RouteLoadFailureEvent extends AnalyticsEvent {
  const RouteLoadFailureEvent({
    required this.appVersion,
    required this.platform,
    required this.route,
    required this.failureCode,
  });

  final String appVersion;
  final AnalyticsPlatform platform;
  final AnalyticsRoute route;
  final RouteFailureCode failureCode;

  @override
  String get name => 'route_load_failed';

  @override
  Map<String, Object> toProperties() => {
    'app_version': appVersion,
    'platform': platform.name,
    'route_id': route.name,
    'failure_code': _routeFailureCodeName(failureCode),
  };
}

final class OnboardingCompletedEvent extends AnalyticsEvent {
  const OnboardingCompletedEvent();

  @override
  String get name => 'onboarding_completed';

  @override
  Map<String, Object> toProperties() => const {};
}

final class ExportCompletedEvent extends AnalyticsEvent {
  const ExportCompletedEvent();

  @override
  String get name => 'export_completed';

  @override
  Map<String, Object> toProperties() => const {};
}

final class ImportCompletedEvent extends AnalyticsEvent {
  const ImportCompletedEvent();

  @override
  String get name => 'import_completed';

  @override
  Map<String, Object> toProperties() => const {};
}

final class PurchaseFlowOutcomeEvent extends AnalyticsEvent {
  const PurchaseFlowOutcomeEvent({
    required this.appVersion,
    required this.platform,
    required this.offer,
    required this.outcome,
  });

  final String appVersion;
  final AnalyticsPlatform platform;
  final PurchaseOffer offer;
  final PurchaseOutcome outcome;

  @override
  String get name => 'purchase_flow_outcome';

  @override
  Map<String, Object> toProperties() => {
    'app_version': appVersion,
    'platform': platform.name,
    'purchase_offer': _purchaseOfferName(offer),
    'purchase_outcome': outcome.name,
  };
}

String _routeFailureCodeName(RouteFailureCode value) {
  return switch (value) {
    RouteFailureCode.networkUnavailable => 'network_unavailable',
    RouteFailureCode.unexpectedResponse => 'unexpected_response',
    RouteFailureCode.timeout => 'timeout',
  };
}

String _purchaseOfferName(PurchaseOffer value) {
  return switch (value) {
    PurchaseOffer.annual => 'annual',
    PurchaseOffer.monthly => 'monthly',
    PurchaseOffer.lifetime => 'lifetime',
  };
}

final class AnalyticsPayload {
  const AnalyticsPayload({required this.event, required this.timestamp});

  final AnalyticsEvent event;
  final DateTime timestamp;

  int get schemaVersion => 1;

  Map<String, Object> toRecord() => {
    'event_name': event.name,
    'schema_version': schemaVersion,
    ...event.toProperties(),
  };
}

abstract interface class AnalyticsService {
  Future<void> track(AnalyticsPayload payload);

  bool get isEnabled;

  Future<void> enable();

  Future<void> disable();

  /// Identifies only with an authenticated Supabase UUID. No person
  /// properties are accepted by this boundary.
  Future<void> identifyAuthenticatedUser(String supabaseUserId);

  /// Forgets the current analytics identity without changing the user's
  /// consent preference.
  Future<void> clearAuthenticatedUser();

  Future<void> dispose();
}
