enum AnalyticsConsent { notSet, granted, optedOut }

final class PrivacyPreferences {
  const PrivacyPreferences({
    this.appLockEnabled = false,
    this.screenCoverEnabled = true,
    this.cycleCheckInEnabled = true,
    this.notificationPermissionRequested = false,
    this.analyticsConsent = AnalyticsConsent.notSet,
  });

  static const schemaVersion = 3;

  final bool appLockEnabled;
  final bool screenCoverEnabled;
  final bool cycleCheckInEnabled;
  final bool notificationPermissionRequested;
  final AnalyticsConsent analyticsConsent;

  PrivacyPreferences copyWith({
    bool? appLockEnabled,
    bool? screenCoverEnabled,
    bool? cycleCheckInEnabled,
    bool? notificationPermissionRequested,
    AnalyticsConsent? analyticsConsent,
  }) {
    return PrivacyPreferences(
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      screenCoverEnabled: screenCoverEnabled ?? this.screenCoverEnabled,
      cycleCheckInEnabled: cycleCheckInEnabled ?? this.cycleCheckInEnabled,
      notificationPermissionRequested:
          notificationPermissionRequested ??
          this.notificationPermissionRequested,
      analyticsConsent: analyticsConsent ?? this.analyticsConsent,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PrivacyPreferences &&
        other.appLockEnabled == appLockEnabled &&
        other.screenCoverEnabled == screenCoverEnabled &&
        other.cycleCheckInEnabled == cycleCheckInEnabled &&
        other.notificationPermissionRequested ==
            notificationPermissionRequested &&
        other.analyticsConsent == analyticsConsent;
  }

  @override
  int get hashCode => Object.hash(
    appLockEnabled,
    screenCoverEnabled,
    cycleCheckInEnabled,
    notificationPermissionRequested,
    analyticsConsent,
  );
}
