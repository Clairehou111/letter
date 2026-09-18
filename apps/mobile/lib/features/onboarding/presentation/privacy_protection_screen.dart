import 'package:flutter/material.dart';

import '../../../design_system/lovable/letter_kit.dart';
import '../../../design_system/letter_theme.dart';
import '../../notifications/domain/local_notification_port.dart';
import '../../privacy/domain/device_authenticator.dart';
import '../../privacy/domain/privacy_preferences.dart';
import '../domain/onboarding_profile.dart';

typedef SaveOnboardingProfile =
    Future<void> Function(OnboardingProfile profile);

class PageTopBar extends StatelessWidget implements PreferredSizeWidget {
  const PageTopBar({required this.title, this.onBack, super.key});

  final String title;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LetterColors.canvas,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              IconButton(
                key: const Key('privacy-protection-back'),
                tooltip: 'Back',
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
                constraints: const BoxConstraints(
                  minWidth: LetterDimensions.tapTarget,
                  minHeight: LetterDimensions.tapTarget,
                ),
              ),
              const SizedBox(width: LetterSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Newsreader',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: LetterColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: LetterSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class PrivacyProtectionScreen extends StatefulWidget {
  const PrivacyProtectionScreen({
    required this.profile,
    required this.onProfileChanged,
    required this.privacyPreferences,
    required this.notificationAuthorization,
    required this.deviceAuthenticator,
    required this.onPrivacyPreferencesChanged,
    super.key,
  });

  final OnboardingProfile profile;
  final SaveOnboardingProfile onProfileChanged;
  final PrivacyPreferences privacyPreferences;
  final NotificationAuthorization notificationAuthorization;
  final DeviceAuthenticator deviceAuthenticator;
  final Future<void> Function(PrivacyPreferences preferences)
  onPrivacyPreferencesChanged;

  @override
  State<PrivacyProtectionScreen> createState() =>
      _PrivacyProtectionScreenState();
}

class _PrivacyProtectionScreenState extends State<PrivacyProtectionScreen> {
  late PrivacyPreferences _preferences = widget.privacyPreferences;
  bool _updatingPrivacy = false;

  @override
  void didUpdateWidget(PrivacyProtectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.privacyPreferences != widget.privacyPreferences) {
      _preferences = widget.privacyPreferences;
    }
  }

  Future<void> _setCycleCheckIn(bool enabled) {
    return _savePrivacyPreferences(
      _preferences.copyWith(cycleCheckInEnabled: enabled),
    );
  }

  Future<void> _setScreenCover(bool enabled) {
    return _savePrivacyPreferences(
      _preferences.copyWith(screenCoverEnabled: enabled),
    );
  }

  Future<void> _setAnalyticsConsent(bool enabled) {
    return _savePrivacyPreferences(
      _preferences.copyWith(
        analyticsConsent: enabled
            ? AnalyticsConsent.granted
            : AnalyticsConsent.optedOut,
      ),
    );
  }

  Future<void> _savePrivacyPreferences(PrivacyPreferences preferences) async {
    if (_updatingPrivacy) return;
    if (!mounted) return;
    setState(() => _updatingPrivacy = true);
    try {
      await widget.onPrivacyPreferencesChanged(preferences);
      if (mounted) setState(() => _preferences = preferences);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Letter Within could not update this setting. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingPrivacy = false);
    }
  }

  String get _cycleCheckInStatus {
    if (!_preferences.cycleCheckInEnabled) return 'Off.';
    if (widget.notificationAuthorization == NotificationAuthorization.granted) {
      return 'On. Letter Within schedules it locally when an estimate is available.';
    }
    if (_preferences.notificationPermissionRequested) {
      return 'On, but notifications are blocked in system settings.';
    }
    return 'On. Letter Within will ask when a cycle estimate is available.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageTopBar(title: 'Privacy and protection'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: LetterDimensions.maxContentWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                const Text(
                  'The controls that protect your private record.',
                  style: TextStyle(color: LetterColors.muted, height: 1.5),
                ),
                const SizedBox(height: LetterSpacing.lg),
                LetterCard(
                  child: Material(
                    color: Colors.transparent,
                    child: SwitchListTile.adaptive(
                      key: const Key('screen-cover-toggle'),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(
                        Icons.visibility_off_outlined,
                        color: LetterColors.teal,
                      ),
                      title: const Text('Screen cover'),
                      subtitle: const Text(
                        'Hide your records when Letter Within is in the background.',
                      ),
                      value: _preferences.screenCoverEnabled,
                      onChanged: _updatingPrivacy ? null : _setScreenCover,
                    ),
                  ),
                ),
                const SizedBox(height: LetterSpacing.md),
                LetterCard(
                  child: Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile.adaptive(
                          key: const Key('cycle-check-in-toggle'),
                          contentPadding: EdgeInsets.zero,
                          secondary: const Icon(
                            Icons.notifications_none,
                            color: LetterColors.teal,
                          ),
                          title: const Text('Cycle Check-in'),
                          subtitle: const Text(
                            'One neutral reminder after the estimated period range.',
                          ),
                          value: _preferences.cycleCheckInEnabled,
                          onChanged: _updatingPrivacy ? null : _setCycleCheckIn,
                        ),
                      ),
                      const Divider(height: 1),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: LetterSpacing.sm),
                          child: Text(
                            _cycleCheckInStatus,
                            style: const TextStyle(
                              color: LetterColors.muted,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LetterSpacing.md),
                LetterCard(
                  child: Material(
                    color: Colors.transparent,
                    child: SwitchListTile.adaptive(
                      key: const Key('analytics-consent-toggle'),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(
                        Icons.insights_outlined,
                        color: LetterColors.teal,
                      ),
                      title: const Text('Optional product analytics'),
                      subtitle: const Text(
                        'If enabled, Letter Within sends limited operational events '
                        'such as startup and export completion. It never '
                        'includes dates, symptoms, Care, notes, text, or email.',
                      ),
                      value:
                          _preferences.analyticsConsent ==
                          AnalyticsConsent.granted,
                      onChanged: _updatingPrivacy ? null : _setAnalyticsConsent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
