enum AnalyticsConsent { notSet, granted, optedOut }

final class PrivacyPreferences {
  const PrivacyPreferences({
    this.screenCoverEnabled = true,
    this.cycleCheckInEnabled = true,
    this.notificationPermissionRequested = false,
    this.analyticsConsent = AnalyticsConsent.notSet,
    this.careCompanionName,
  });

  static const schemaVersion = 4;
  static const maxCareCompanionNameRunes = 24;
  static const Object _unchangedCareCompanionName = Object();

  final bool screenCoverEnabled;
  final bool cycleCheckInEnabled;
  final bool notificationPermissionRequested;
  final AnalyticsConsent analyticsConsent;
  final String? careCompanionName;

  static String? normalizeCareCompanionName(String? value) {
    if (value == null) return null;
    final normalized = value.trim();
    if (normalized.isEmpty ||
        normalized.runes.length > maxCareCompanionNameRunes) {
      return null;
    }
    return normalized;
  }

  PrivacyPreferences copyWith({
    bool? screenCoverEnabled,
    bool? cycleCheckInEnabled,
    bool? notificationPermissionRequested,
    AnalyticsConsent? analyticsConsent,
    Object? careCompanionName = _unchangedCareCompanionName,
  }) {
    return PrivacyPreferences(
      screenCoverEnabled: screenCoverEnabled ?? this.screenCoverEnabled,
      cycleCheckInEnabled: cycleCheckInEnabled ?? this.cycleCheckInEnabled,
      notificationPermissionRequested:
          notificationPermissionRequested ??
          this.notificationPermissionRequested,
      analyticsConsent: analyticsConsent ?? this.analyticsConsent,
      careCompanionName:
          identical(careCompanionName, _unchangedCareCompanionName)
          ? this.careCompanionName
          : careCompanionName as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PrivacyPreferences &&
        other.screenCoverEnabled == screenCoverEnabled &&
        other.cycleCheckInEnabled == cycleCheckInEnabled &&
        other.notificationPermissionRequested ==
            notificationPermissionRequested &&
        other.analyticsConsent == analyticsConsent &&
        other.careCompanionName == careCompanionName;
  }

  @override
  int get hashCode => Object.hash(
    screenCoverEnabled,
    cycleCheckInEnabled,
    notificationPermissionRequested,
    analyticsConsent,
    careCompanionName,
  );
}
