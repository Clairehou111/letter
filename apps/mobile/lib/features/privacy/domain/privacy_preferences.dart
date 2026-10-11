enum AnalyticsConsent { notSet, granted, optedOut }

final class PrivacyPreferences {
  const PrivacyPreferences({
    this.appLockEnabled = false,
    this.screenCoverEnabled = true,
    this.cycleCheckInEnabled = true,
    this.notificationPermissionRequested = false,
    this.comfortWindowReminderEnabled = false,
    this.comfortWindowReminderLeadDays = 2,
    this.comfortWindowInvitationDismissed = false,
    this.analyticsConsent = AnalyticsConsent.notSet,
    this.careCompanionName,
  });

  static const schemaVersion = 5;
  static const maxCareCompanionNameRunes = 24;
  static const Object _unchangedCareCompanionName = Object();

  final bool appLockEnabled;
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

  final bool comfortWindowReminderEnabled;
  final int comfortWindowReminderLeadDays;
  final bool comfortWindowInvitationDismissed;

  PrivacyPreferences copyWith({
    bool? appLockEnabled,
    bool? screenCoverEnabled,
    bool? cycleCheckInEnabled,
    bool? notificationPermissionRequested,
    AnalyticsConsent? analyticsConsent,
    Object? careCompanionName = _unchangedCareCompanionName,
    bool? comfortWindowReminderEnabled,
    int? comfortWindowReminderLeadDays,
    bool? comfortWindowInvitationDismissed,
  }) {
    return PrivacyPreferences(
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
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
      comfortWindowReminderEnabled:
          comfortWindowReminderEnabled ?? this.comfortWindowReminderEnabled,
      comfortWindowReminderLeadDays:
          comfortWindowReminderLeadDays ?? this.comfortWindowReminderLeadDays,
      comfortWindowInvitationDismissed:
          comfortWindowInvitationDismissed ??
          this.comfortWindowInvitationDismissed,
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
        other.analyticsConsent == analyticsConsent &&
        other.careCompanionName == careCompanionName &&
        other.comfortWindowReminderEnabled == comfortWindowReminderEnabled &&
        other.comfortWindowReminderLeadDays == comfortWindowReminderLeadDays &&
        other.comfortWindowInvitationDismissed ==
            comfortWindowInvitationDismissed;
  }

  @override
  int get hashCode => Object.hash(
    appLockEnabled,
    screenCoverEnabled,
    cycleCheckInEnabled,
    notificationPermissionRequested,
    analyticsConsent,
    careCompanionName,
    comfortWindowReminderEnabled,
    comfortWindowReminderLeadDays,
    comfortWindowInvitationDismissed,
  );
}
