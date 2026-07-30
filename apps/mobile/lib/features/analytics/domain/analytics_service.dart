/// Allowlisted operational analytics events (spec: 2026-07-28-privacy-safe-operational-analytics).
///
/// Every event is explicitly defined here. Free-form properties are forbidden.
/// No health values, cycle dates, symptoms, Care labels, or inferred states may
/// ever appear in an analytics event payload.
library;

/// The set of operational events Letter is allowed to send.
///
/// Adding a new event requires updating this enum and the allowlist schema
/// validator. Events must be versioned and reviewed for health-data leakage.
enum AnalyticsEvent {
  appOpened,
  appCrashed,
  routeLoadFailed,
  purchaseFlowStarted,
  purchaseFlowCompleted,
  purchaseFlowFailed,
  purchaseRestored,
  onboardingCompleted,
  exportStarted,
  exportCompleted,
  importStarted,
  importCompleted,
  diaryEnrollmentStarted,
  diaryEntrySaved,
}

/// Analytics payload: only pre-approved properties, no free-form data.
final class AnalyticsPayload {
  const AnalyticsPayload({
    required this.event,
    this.properties = const {},
    required this.timestamp,
  });

  final AnalyticsEvent event;
  final Map<String, Object?> properties;
  final DateTime timestamp;

  /// Validates that no health-related keys appear in properties.
  /// Returns null if valid, or a list of violating keys.
  List<String>? validate() {
    const forbiddenKeys = {
      'cycleDate',
      'cycleDay',
      'periodStart',
      'periodEnd',
      'symptom',
      'severity',
      'painRating',
      'painLocation',
      'mood',
      'energy',
      'careMode',
      'careAction',
      'careOutcome',
      'note',
      'transcript',
      'draft',
      'report',
      'prediction',
      'healthRecord',
      'reflection',
      'futureSelfNote',
    };
    final violations = properties.keys
        .where((key) => forbiddenKeys.contains(key))
        .toList();
    return violations.isEmpty ? null : violations;
  }
}

/// Analytics service contract. Implementations must enforce the allowlist
/// and never send health data.
abstract interface class AnalyticsService {
  /// Sends an allowlisted event. The implementation validates the payload
  /// and rejects any event with forbidden keys.
  Future<void> track(AnalyticsPayload payload);

  /// Whether analytics is enabled. Disabled until user opts in.
  bool get isEnabled;

  /// Enable analytics after user consent. No events are sent retroactively.
  Future<void> enable();

  /// Disable analytics and purge any buffered events.
  Future<void> disable();

  Future<void> dispose();
}
