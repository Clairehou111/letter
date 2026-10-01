/// Closed, privacy-safe operational analytics events.
library;

enum PurchaseOffer { annual, monthly, lifetime }

enum PurchaseOutcome { cancelled, completed, failed, pending }

sealed class AnalyticsEvent {
  const AnalyticsEvent();

  String get name;

  /// This is an internal serialization boundary. Callers cannot provide a
  /// property map; each event exposes only its typed, reviewed fields.
  Map<String, Object> toProperties();
}

final class OnboardingCompletedEvent extends AnalyticsEvent {
  const OnboardingCompletedEvent();

  @override
  String get name => 'onboarding_completed';

  @override
  Map<String, Object> toProperties() => const {};
}

enum SettingsAction {
  opened,
  analyticsEnabled,
  analyticsDisabled,
  screenCoverChanged,
}

final class SettingsActionEvent extends AnalyticsEvent {
  const SettingsActionEvent(this.action);

  final SettingsAction action;

  @override
  String get name => 'settings_action';

  @override
  Map<String, Object> toProperties() => {'action': action.name};
}

enum PaywallContext { settings, patternReport, comfortInsights, previewEnded }

final class PaywallViewedEvent extends AnalyticsEvent {
  const PaywallViewedEvent(this.context);

  final PaywallContext context;

  @override
  String get name => 'paywall_viewed';

  @override
  Map<String, Object> toProperties() => {'context': context.name};
}

enum PlusPreviewState { eligible, started, active, ended }

final class PlusPreviewStateEvent extends AnalyticsEvent {
  const PlusPreviewStateEvent(this.state);

  final PlusPreviewState state;

  @override
  String get name => 'plus_preview_state';

  @override
  Map<String, Object> toProperties() => {'state': state.name};
}

enum CareUsageBucket { one, twoToFive, sixOrMore }

final class CareUsageBucketEvent extends AnalyticsEvent {
  const CareUsageBucketEvent(this.bucket);

  final CareUsageBucket bucket;

  @override
  String get name => 'care_usage_30d';

  @override
  Map<String, Object> toProperties() => {
    'usage_bucket': switch (bucket) {
      CareUsageBucket.one => '1',
      CareUsageBucket.twoToFive => '2-5',
      CareUsageBucket.sixOrMore => '6+',
    },
  };
}

final class PurchaseFlowOutcomeEvent extends AnalyticsEvent {
  const PurchaseFlowOutcomeEvent({required this.offer, required this.outcome});

  final PurchaseOffer offer;
  final PurchaseOutcome outcome;

  @override
  String get name => 'purchase_flow_outcome';

  @override
  Map<String, Object> toProperties() => {
    'purchase_offer': _purchaseOfferName(offer),
    'purchase_outcome': outcome.name,
  };
}

enum PlanCatalogLoadResult { loaded, failed }

enum PlanCatalogFailureReason {
  accountNotReady,
  storeNotSelected,
  apiKeyMissing,
  storeSetupFailed,
  storeConfigurationError,
  offeringRequestFailed,
  emptyOffering,
  unknown,
}

/// Fixed operational categories only. Never include SDK errors or store data.
final class PlanCatalogLoadEvent extends AnalyticsEvent {
  const PlanCatalogLoadEvent.loaded()
    : result = PlanCatalogLoadResult.loaded,
      reason = null;

  const PlanCatalogLoadEvent.failed(this.reason)
    : result = PlanCatalogLoadResult.failed;

  final PlanCatalogLoadResult result;
  final PlanCatalogFailureReason? reason;

  @override
  String get name => 'plan_catalog_load';

  @override
  Map<String, Object> toProperties() => {
    'result': result.name,
    if (reason case final reason?) 'reason': reason.name,
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

  Future<void> dispose();
}
