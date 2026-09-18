import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../design_system/letter_bottom_navigation.dart';
import '../../../design_system/lovable/health_record_kit.dart';
import '../../../design_system/lovable/letter_kit.dart';
import '../../../design_system/letter_theme.dart';
import '../../auth/domain/auth_service.dart';
import '../../auth/presentation/account_screen.dart';
import '../../care/domain/care_memory_repository.dart';
import '../../care/domain/care_mode.dart';
import '../../care/presentation/care_screen.dart';
import '../../capture/domain/capture_models.dart';
import '../../check_in/domain/moment_check_in_repository.dart';
import '../../cycle/domain/period_repository.dart';
import '../../entitlement/presentation/entitlement_scope.dart';
import '../../entitlement/presentation/plans_sheet.dart';
import '../../health_records/domain/health_record_repository.dart';
import '../../letters/presentation/letters_home_screen.dart';
import '../../local_backup/domain/local_backup_file_port.dart';
import '../../local_backup/domain/local_backup_import.dart';
import '../../local_backup/presentation/local_backup_screen.dart';
import '../../notifications/domain/local_notification_port.dart';
import '../../privacy/domain/device_authenticator.dart';
import '../../privacy/domain/privacy_preferences.dart';
import '../../preparation/domain/preparation_plan.dart';
import '../../today/today_screen.dart';
import '../domain/onboarding_profile.dart';
import 'privacy_protection_screen.dart';

typedef UpdateOnboardingProfile =
    Future<void> Function(OnboardingProfile profile);

class LetterHome extends StatefulWidget {
  const LetterHome({
    required this.profile,
    required this.periodRepository,
    required this.careMemoryRepository,
    required this.healthRecordRepository,
    required this.captureNoteStore,
    required this.momentCheckInRepository,
    required this.preparationRepository,
    required this.onProfileChanged,
    required this.onReset,
    required this.privacyPreferences,
    required this.notificationAuthorization,
    required this.deviceAuthenticator,
    required this.onPrivacyPreferencesChanged,
    required this.navigationRequest,
    required this.onCycleDataChanged,
    this.localBackupStore,
    this.localBackupFilePort,
    this.now,
    this.authService,
    super.key,
  });

  final OnboardingProfile profile;
  final PeriodRepository periodRepository;
  final CareMemoryRepository careMemoryRepository;
  final HealthRecordRepository healthRecordRepository;
  final CaptureNoteStore captureNoteStore;
  final MomentCheckInRepository momentCheckInRepository;
  final PreparationRepository preparationRepository;
  final UpdateOnboardingProfile onProfileChanged;
  final Future<void> Function() onReset;
  final PrivacyPreferences privacyPreferences;
  final NotificationAuthorization notificationAuthorization;
  final DeviceAuthenticator deviceAuthenticator;
  final Future<void> Function(PrivacyPreferences preferences)
  onPrivacyPreferencesChanged;
  final ValueListenable<int> navigationRequest;
  final Future<void> Function() onCycleDataChanged;
  final LocalBackupStore? localBackupStore;
  final LocalBackupFilePort? localBackupFilePort;
  final DateTime Function()? now;
  final AuthService? authService;

  @override
  State<LetterHome> createState() => _LetterHomeState();
}

class _LetterHomeState extends State<LetterHome> {
  late int _selectedIndex;
  CareMode? _requestedCareMode;
  bool _requestedQuickReset = false;
  bool _requestedToolkit = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.navigationRequest.value;
    widget.navigationRequest.addListener(_followNavigationRequest);
  }

  @override
  void didUpdateWidget(LetterHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationRequest != widget.navigationRequest) {
      oldWidget.navigationRequest.removeListener(_followNavigationRequest);
      widget.navigationRequest.addListener(_followNavigationRequest);
      _followNavigationRequest();
    }
  }

  @override
  void dispose() {
    widget.navigationRequest.removeListener(_followNavigationRequest);
    super.dispose();
  }

  void _followNavigationRequest() {
    _selectTab(widget.navigationRequest.value);
  }

  void _selectTab(int index) {
    if (index < 0 || index > 3) return;
    setState(() {
      _selectedIndex = index;
      _requestedCareMode = null;
      _requestedQuickReset = false;
      _requestedToolkit = false;
    });
  }

  void _openPreparedCare(CareMode mode) {
    setState(() {
      _requestedCareMode = mode;
      _selectedIndex = 1;
      _requestedQuickReset = false;
      _requestedToolkit = false;
    });
  }

  void _openQuickCare(CareMode mode) {
    setState(() {
      _requestedCareMode = mode;
      _requestedQuickReset = true;
      _requestedToolkit = false;
      _selectedIndex = 1;
    });
  }

  void _openCareToolkit() {
    setState(() {
      _requestedCareMode = null;
      _requestedQuickReset = false;
      _requestedToolkit = true;
      _selectedIndex = 1;
    });
  }

  void _openCareHome() {
    setState(() {
      _requestedCareMode = null;
      _requestedQuickReset = false;
      _requestedToolkit = false;
      _selectedIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedIndex == 3) {
      return PrivacyCenterScreen(
        profile: widget.profile,
        onProfileChanged: widget.onProfileChanged,
        onReset: widget.onReset,
        privacyPreferences: widget.privacyPreferences,
        notificationAuthorization: widget.notificationAuthorization,
        deviceAuthenticator: widget.deviceAuthenticator,
        onPrivacyPreferencesChanged: widget.onPrivacyPreferencesChanged,
        localBackupStore: widget.localBackupStore,
        localBackupFilePort: widget.localBackupFilePort,
        onNavigationSelected: _selectTab,
        onCycleDataChanged: widget.onCycleDataChanged,
        authService: widget.authService,
      );
    }
    if (_selectedIndex == 2) {
      return LettersHomeScreen(
        periodRepository: widget.periodRepository,
        careMemoryRepository: widget.careMemoryRepository,
        healthRecordRepository: widget.healthRecordRepository,
        momentCheckInRepository: widget.momentCheckInRepository,
        onOptionalCare: _openCareHome,
        preparationRepository: widget.preparationRepository,
        now: widget.now,
        onNavigationSelected: _selectTab,
      );
    }
    if (_selectedIndex == 1) {
      return CareScreen(
        onNavigationSelected: _selectTab,
        careMemoryRepository: widget.careMemoryRepository,
        healthRecordRepository: widget.healthRecordRepository,
        now: widget.now,
        initialMode: _requestedCareMode,
        initialQuickReset: _requestedQuickReset,
        initialToolkit: _requestedToolkit,
      );
    }
    return TodayScreen(
      repository: widget.periodRepository,
      healthRecordRepository: widget.healthRecordRepository,
      captureNoteStore: widget.captureNoteStore,
      momentCheckInRepository: widget.momentCheckInRepository,
      careMemoryRepository: widget.careMemoryRepository,
      preparationRepository: widget.preparationRepository,
      onOpenCareMode: _openPreparedCare,
      onOpenQuickCareMode: _openQuickCare,
      onOpenCareToolkit: _openCareToolkit,
      onNavigationSelected: _selectTab,
      now: widget.now,
    );
  }
}

class PrivacyCenterScreen extends StatefulWidget {
  const PrivacyCenterScreen({
    required this.profile,
    required this.onProfileChanged,
    required this.onReset,
    required this.onNavigationSelected,
    required this.privacyPreferences,
    required this.notificationAuthorization,
    required this.deviceAuthenticator,
    required this.onPrivacyPreferencesChanged,
    required this.onCycleDataChanged,
    this.localBackupStore,
    this.localBackupFilePort,
    this.authService,
    super.key,
  });

  final OnboardingProfile profile;
  final UpdateOnboardingProfile onProfileChanged;
  final Future<void> Function() onReset;
  final ValueChanged<int> onNavigationSelected;
  final PrivacyPreferences privacyPreferences;
  final NotificationAuthorization notificationAuthorization;
  final DeviceAuthenticator deviceAuthenticator;
  final Future<void> Function(PrivacyPreferences preferences)
  onPrivacyPreferencesChanged;
  final Future<void> Function() onCycleDataChanged;
  final LocalBackupStore? localBackupStore;
  final LocalBackupFilePort? localBackupFilePort;
  final AuthService? authService;

  @override
  State<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends State<PrivacyCenterScreen> {
  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear onboarding choices?'),
        content: const Text(
          'This clears your privacy mode and selected goals from this device. '
          'It does not delete health or cycle records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-reset-onboarding'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: LetterColors.safetyRed,
            ),
            child: const Text('Clear choices'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.onReset();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Letter Within could not clear these choices. Try again.',
            ),
          ),
        );
      }
    }
  }

  void _openBackup() {
    final store = widget.localBackupStore;
    final filePort = widget.localBackupFilePort;
    if (store == null || filePort == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LocalBackupScreen(
          store: store,
          filePort: filePort,
          onImportCommitted: widget.onCycleDataChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backupAvailable =
        widget.localBackupStore != null && widget.localBackupFilePort != null;
    final entitlement = EntitlementScope.stateOf(context);
    final entitlementRepository = EntitlementScope.repositoryOf(context);
    return ScreenScaffold(
      bottomNavigationBar: LetterBottomNavigation(
        selectedIndex: 3,
        onSelected: widget.onNavigationSelected,
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: LetterDimensions.maxContentWidth,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    eyebrow: 'You',
                    title: 'Your copy, your privacy',
                    support:
                        'A small home for your records, privacy choices, and '
                        'the way you began with Letter Within.',
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.authService != null) ...[
                          const _UtilityGroupLabel('Account'),
                          const SizedBox(height: LetterSpacing.sm),
                          _UtilityTile(
                            key: const Key('open-account'),
                            icon: Icons.account_circle_outlined,
                            title: 'Account',
                            body:
                                widget
                                    .authService!
                                    .current
                                    .hasDeletedServerAccount
                                ? 'Account deleted. Local records remain available on this device.'
                                : widget
                                      .authService!
                                      .current
                                      .requiresServerReauthentication
                                ? 'Offline or session expired. Local records remain available.'
                                : 'Sign-in, purchases, and account deletion.',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) =>
                                    AccountScreen(service: widget.authService!),
                              ),
                            ),
                          ),
                          const SizedBox(height: LetterSpacing.xl),
                        ],
                        const _UtilityGroupLabel('Letter Within Plus'),
                        const SizedBox(height: LetterSpacing.sm),
                        _UtilityTile(
                          key: const Key('open-letter-plus'),
                          icon: Icons.auto_awesome_outlined,
                          title: 'Letter Within Plus',
                          body: entitlement.hasPremiumAccess
                              ? 'Active. Manage or restore your purchase.'
                              : 'Continuing patterns, preparation, and deeper comparisons.',
                          onTap: entitlementRepository == null
                              ? null
                              : () => PlansSheet.show(
                                  context,
                                  entitlementRepository,
                                ),
                        ),
                        const SizedBox(height: LetterSpacing.xl),
                        const _UtilityGroupLabel('Your records'),
                        const SizedBox(height: LetterSpacing.sm),
                        _UtilityTile(
                          key: const Key('open-local-backup'),
                          icon: Icons.lock_outline,
                          title: 'Encrypted backup',
                          body: backupAvailable
                              ? 'Keep an encrypted copy of your records with you.'
                              : 'Backup is unavailable on this device.',
                          onTap: backupAvailable ? _openBackup : null,
                        ),
                        const SizedBox(height: LetterSpacing.xl),
                        const _UtilityGroupLabel('Privacy and protection'),
                        const SizedBox(height: LetterSpacing.sm),
                        _UtilityTile(
                          key: const Key('open-privacy-protection'),
                          icon: Icons.shield_outlined,
                          title: 'Privacy and protection',
                          body:
                              'Screen cover, reminders, and optional product analytics.',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => PrivacyProtectionScreen(
                                profile: widget.profile,
                                onProfileChanged: widget.onProfileChanged,
                                privacyPreferences: widget.privacyPreferences,
                                notificationAuthorization:
                                    widget.notificationAuthorization,
                                deviceAuthenticator: widget.deviceAuthenticator,
                                onPrivacyPreferencesChanged:
                                    widget.onPrivacyPreferencesChanged,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: LetterSpacing.xl),
                        const _UtilityGroupLabel(
                          'How you set Letter Within up',
                        ),
                        const SizedBox(height: LetterSpacing.sm),
                        _UtilityTile(
                          key: const Key('open-welcome-privacy'),
                          icon: Icons.waving_hand_outlined,
                          title: 'Welcome / privacy',
                          body: 'Review the choices and intentions from setup.',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  const _WelcomePrivacyScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: LetterSpacing.lg),
                        _GoalsCard(profile: widget.profile),
                        const SizedBox(height: LetterSpacing.xl),
                        const Text(
                          'Your account, purchases, and privacy-safe product '
                          'analytics stay separate from your health and cycle '
                          'records. Letter Within keeps those records on this device '
                          'unless you choose an explicit backup or export.',
                          style: TextStyle(
                            color: LetterColors.muted,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: LetterSpacing.xl),
                        const Divider(),
                        const SizedBox(height: LetterSpacing.sm),
                        TextButton.icon(
                          key: const Key('reset-onboarding'),
                          onPressed: _confirmReset,
                          style: TextButton.styleFrom(
                            foregroundColor: LetterColors.safetyRed,
                            minimumSize: const Size.fromHeight(48),
                            alignment: Alignment.centerLeft,
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Clear onboarding choices'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UtilityGroupLabel extends StatelessWidget {
  const _UtilityGroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => LetterEyebrow(text);
}

class _UtilityTile extends StatelessWidget {
  const _UtilityTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: LetterColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.panel),
          side: const BorderSide(color: LetterColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.all(LetterSpacing.md),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: enabled ? LetterColors.teal : LetterColors.muted,
                  ),
                  const SizedBox(width: LetterSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: LetterSpacing.xxs),
                        Text(
                          body,
                          style: const TextStyle(
                            color: LetterColors.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: LetterSpacing.sm),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: enabled ? LetterColors.teal : LetterColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalsCard extends StatelessWidget {
  const _GoalsCard({required this.profile});

  final OnboardingProfile profile;

  @override
  Widget build(BuildContext context) {
    return LetterCard(
      padding: const EdgeInsets.all(LetterSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your starting goals',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: LetterSpacing.xs),
          if (profile.selectedGoals.isEmpty)
            const Text(
              'No goals selected yet.',
              style: TextStyle(color: LetterColors.muted),
            )
          else
            Wrap(
              spacing: LetterSpacing.xs,
              runSpacing: LetterSpacing.xs,
              children: [
                for (final goal in profile.selectedGoals)
                  Chip(
                    label: Text(goal.shortLabel),
                    side: const BorderSide(color: LetterColors.line),
                    backgroundColor: LetterColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LetterRadius.control),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WelcomePrivacyScreen extends StatelessWidget {
  const _WelcomePrivacyScreen();

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      showHeader: false,
      child: Column(
        children: [
          PageTopBar(title: 'Welcome / privacy'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                const SectionHeader(
                  eyebrow: 'Private by default',
                  title: 'Your story stays with you.',
                  support:
                      'These are the privacy intentions Letter Within follows.',
                ),
                const SizedBox(height: LetterSpacing.xl),
                const LetterCard(
                  child: Column(
                    children: [
                      _WelcomeFact(
                        icon: Icons.account_circle_outlined,
                        text:
                            'Your Letter Within account does not contain your health '
                            'or cycle records.',
                      ),
                      Divider(height: 24),
                      _WelcomeFact(
                        icon: Icons.phone_android_outlined,
                        text:
                            'Your health and cycle records stay on this device.',
                      ),
                      Divider(height: 24),
                      _WelcomeFact(
                        icon: Icons.move_to_inbox_outlined,
                        text:
                            'Records move only when you create a backup, restore, or export.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeFact extends StatelessWidget {
  const _WelcomeFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: LetterColors.teal),
      const SizedBox(width: LetterSpacing.sm),
      Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
    ],
  );
}

extension on OnboardingGoal {
  String get shortLabel => switch (this) {
    OnboardingGoal.understandCycle => 'Cycle',
    OnboardingGoal.emotionalChanges => 'Emotions',
    OnboardingGoal.physicalDiscomfort => 'Physical comfort',
    OnboardingGoal.energyAndSleep => 'Energy and sleep',
    OnboardingGoal.selfCarePreparation => 'Self-care',
    OnboardingGoal.appointmentPreparation => 'Appointments',
  };
}
