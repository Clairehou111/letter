import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../design_system/letter_theme.dart';
import '../experience/letter_experience_shell.dart';
import '../experience/reports/letter_report_experience_port.dart';
import '../experience/theme/experience_foundation.dart';
import '../features/care/data/in_memory_care_memory_repository.dart';
import '../features/auth/data/dev_auth_service.dart';
import '../features/auth/domain/auth_service.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/analytics/data/dev_analytics_service.dart';
import '../features/analytics/domain/analytics_service.dart';
import '../features/analytics/presentation/analytics_scope.dart';
import '../features/check_in/data/in_memory_moment_check_in_repository.dart';
import '../features/cycle/data/in_memory_period_repository.dart';
import '../features/entitlement/data/local_entitlement_repository.dart';
import '../features/entitlement/presentation/entitlement_scope.dart';
import '../features/health_data/data/local_health_store.dart';
import '../features/health_data/data/local_health_store_factory.dart';
import '../features/health_records/data/in_memory_health_record_repository.dart';
import '../features/notifications/application/cycle_check_in_scheduler.dart';
import '../features/notifications/application/notifying_period_repository.dart';
import '../features/notifications/data/flutter_local_notification_port.dart';
import '../features/notifications/domain/local_notification_port.dart';
import '../features/onboarding/data/onboarding_repository.dart';
import '../features/onboarding/data/onboarding_repository_factory.dart';
import '../features/onboarding/domain/onboarding_profile.dart';
import '../features/onboarding/presentation/onboarding_flow.dart';
import '../features/privacy/data/local_device_authenticator.dart';
import '../features/privacy/data/native_privacy_bridge.dart';
import '../features/privacy/data/privacy_preferences_repository_factory.dart';
import '../features/privacy/domain/device_authenticator.dart';
import '../features/privacy/domain/privacy_preferences.dart';
import '../features/privacy/domain/privacy_preferences_repository.dart';
import '../features/privacy/presentation/privacy_shell.dart';
import '../features/local_backup/data/secure_local_backup_credential_store.dart';
import '../features/local_backup/domain/local_backup_import.dart';
import '../experience/backup/letter_backup_experience_port.dart';
import '../features/preparation/data/in_memory_preparation_repository.dart';

class LetterApp extends StatefulWidget {
  const LetterApp({
    super.key,
    this.onboardingRepository,
    this.periodRepository,
    this.careMemoryRepository,
    this.healthRecordRepository,
    this.captureNoteStore,
    this.momentCheckInRepository,
    this.preparationRepository,
    this.entitlementRepository,
    this.authService,
    this.analyticsService,
    this.requireAuthentication = false,
    this.appleSignInEnabled = false,
    this.privacyPreferencesRepository,
    this.deviceAuthenticator,
    this.notificationPort,
    this.now,
  });

  final OnboardingRepository? onboardingRepository;
  final EntitlementRepository? entitlementRepository;
  final AuthService? authService;
  final AnalyticsService? analyticsService;
  final bool requireAuthentication;
  final bool appleSignInEnabled;
  final PeriodRepository? periodRepository;
  final CareMemoryRepository? careMemoryRepository;
  final HealthRecordRepository? healthRecordRepository;
  final CaptureNoteStore? captureNoteStore;
  final MomentCheckInRepository? momentCheckInRepository;
  final PreparationRepository? preparationRepository;
  final PrivacyPreferencesRepository? privacyPreferencesRepository;
  final DeviceAuthenticator? deviceAuthenticator;
  final LocalNotificationPort? notificationPort;
  final DateTime Function()? now;

  @override
  State<LetterApp> createState() => _LetterAppState();
}

class _LetterAppState extends State<LetterApp> with WidgetsBindingObserver {
  late final AuthService _authService;
  late final AnalyticsService _analyticsService;
  late final StreamSubscription<AuthState> _authSubscription;
  late final StreamSubscription<EntitlementState> _entitlementSubscription;
  AuthState _authState = const AuthState(status: AuthStatus.signedOut);
  bool _authLoaded = false;
  late final OnboardingRepository _repository;
  late final EntitlementRepository _entitlementRepository;
  EntitlementState _entitlementState = const EntitlementState(
    status: EntitlementStatus.freeOrUnknown,
  );
  late final PeriodRepository _periodRepository;
  late final PeriodRepository _basePeriodRepository;
  late final CareMemoryRepository _careMemoryRepository;
  late final HealthRecordRepository _healthRecordRepository;
  late final CaptureNoteStore _captureNoteStore;
  late final MomentCheckInRepository _momentCheckInRepository;
  late final PreparationRepository _preparationRepository;
  late final PrivacyPreferencesRepository _privacyPreferencesRepository;
  late final DeviceAuthenticator _deviceAuthenticator;
  late final LocalNotificationPort _notificationPort;
  late final CycleCheckInScheduler _cycleCheckInScheduler;
  final ValueNotifier<int> _navigationRequest = ValueNotifier<int>(0);
  LocalHealthStore? _ownedHealthStore;
  LocalBackupStore? _localBackupStore;
  OnboardingProfile? _profile;
  PrivacyPreferences _privacyPreferences = const PrivacyPreferences();
  bool _loaded = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authService =
        widget.authService ??
        DevAuthService(
          initialState: const AuthState(
            status: AuthStatus.authenticated,
            userId: 'local-development',
          ),
        );
    _analyticsService = widget.analyticsService ?? DevAnalyticsService();
    _authState = _authService.current;
    _repository =
        widget.onboardingRepository ?? createDefaultOnboardingRepository();
    _entitlementRepository =
        widget.entitlementRepository ?? LocalEntitlementRepository();
    _entitlementState = _entitlementRepository.current;
    _authSubscription = _authService.watch().listen((state) {
      if (mounted) setState(() => _authState = state);
      unawaited(_syncAccountBoundServices(state));
    });
    _entitlementSubscription = _entitlementRepository.watch().listen((state) {
      if (mounted) setState(() => _entitlementState = state);
    });
    if (widget.periodRepository == null &&
        widget.careMemoryRepository == null &&
        widget.healthRecordRepository == null &&
        widget.captureNoteStore == null &&
        widget.momentCheckInRepository == null &&
        widget.preparationRepository == null) {
      final healthStore = createDefaultLocalHealthStore();
      _ownedHealthStore = healthStore;
      _localBackupStore = healthStore.localBackupStore;
      _basePeriodRepository = healthStore.periodRepository;
      _careMemoryRepository = healthStore.careMemoryRepository;
      _healthRecordRepository = healthStore.healthRecordRepository;
      _captureNoteStore = healthStore.captureNoteStore;
      _momentCheckInRepository = healthStore.momentCheckInRepository;
      _preparationRepository = healthStore.preparationRepository;
    } else {
      _basePeriodRepository =
          widget.periodRepository ?? InMemoryPeriodRepository();
      _careMemoryRepository =
          widget.careMemoryRepository ??
          InMemoryCareMemoryRepository(clock: widget.now);
      _healthRecordRepository =
          widget.healthRecordRepository ??
          InMemoryHealthRecordRepository(clock: widget.now);
      _captureNoteStore = widget.captureNoteStore ?? InMemoryCaptureNoteStore();
      _momentCheckInRepository =
          widget.momentCheckInRepository ??
          InMemoryMomentCheckInRepository(clock: widget.now);
      _preparationRepository =
          widget.preparationRepository ?? InMemoryPreparationRepository();
    }
    final useProductionAdapters =
        widget.onboardingRepository == null && widget.periodRepository == null;
    _privacyPreferencesRepository =
        widget.privacyPreferencesRepository ??
        (useProductionAdapters
            ? createDefaultPrivacyPreferencesRepository()
            : InMemoryPrivacyPreferencesRepository());
    _deviceAuthenticator =
        widget.deviceAuthenticator ??
        (useProductionAdapters
            ? LocalDeviceAuthenticator()
            : const AllowingDeviceAuthenticator());
    _notificationPort =
        widget.notificationPort ??
        (useProductionAdapters
            ? FlutterLocalNotificationPort()
            : const DisabledLocalNotificationPort());
    _cycleCheckInScheduler = CycleCheckInScheduler(
      _basePeriodRepository,
      _privacyPreferencesRepository,
      _notificationPort,
      now: widget.now,
    );
    _periodRepository = NotifyingPeriodRepository(
      _basePeriodRepository,
      () => _reconcileCycleCheckIn(requestPermission: true),
    );
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription.cancel());
    unawaited(_entitlementSubscription.cancel());
    unawaited(_authService.dispose());
    unawaited(_analyticsService.dispose());
    unawaited(_entitlementRepository.dispose());
    _navigationRequest.dispose();
    _ownedHealthStore?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshEntitlement());
    }
  }

  Future<void> _refreshEntitlement() async {
    try {
      await _entitlementRepository.refresh();
    } on Object {
      // Store reconciliation never blocks local records or acute Care.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loaded = false;
      _loadFailed = false;
    });
    try {
      await _notificationPort.initialize(_handleNotificationTap);
      final results = await Future.wait<Object?>([
        _authService.initialize(),
        _repository.load(),
        _privacyPreferencesRepository.load(),
      ]);
      final authState = results[0] as AuthState;
      final profile = results[1] as OnboardingProfile?;
      final loadedPrivacyPreferences = results[2] as PrivacyPreferences;
      // App Lock and product analytics are not part of this release. Clear
      // any pre-release toggles so a hidden control cannot remain active.
      final privacyPreferences = loadedPrivacyPreferences.copyWith(
        appLockEnabled: false,
        analyticsConsent: AnalyticsConsent.optedOut,
      );
      if (privacyPreferences != loadedPrivacyPreferences) {
        await _privacyPreferencesRepository.save(privacyPreferences);
      }
      await NativePrivacyBridge.setScreenCoverEnabled(
        privacyPreferences.screenCoverEnabled,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _authState = authState;
        _authLoaded = true;
        _profile = profile;
        _privacyPreferences = privacyPreferences;
        _loaded = true;
      });
      await _applyAnalyticsPreference(privacyPreferences);
      await _syncEntitlementForAccount(authState);
      await _trackOperationally(
        AppStartupEvent(
          appVersion: const String.fromEnvironment(
            'FLUTTER_BUILD_NAME',
            defaultValue: 'development',
          ),
          platform: _analyticsPlatform,
          result: StartupResult.completed,
        ),
      );
      await _reconcileCycleCheckIn(requestPermission: profile != null);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _authLoaded = true;
        _loaded = true;
        _loadFailed = true;
      });
    }
  }

  Future<void> _completeOnboarding(OnboardingProfile profile) async {
    await _repository.save(profile);
    if (!mounted) {
      return;
    }
    setState(() => _profile = profile);
    await _trackOperationally(const OnboardingCompletedEvent());
    await _reconcileCycleCheckIn(requestPermission: true);
  }

  void _handleNotificationTap(String payload) {
    if (payload != CycleCheckInScheduler.notificationPayload) return;
    _navigationRequest.value = 2;
  }

  Future<void> _reconcileCycleCheckIn({required bool requestPermission}) async {
    try {
      await _cycleCheckInScheduler.reconcile(
        requestPermission: requestPermission,
      );
      final preferences = await _privacyPreferencesRepository.load();
      if (!mounted) return;
      setState(() {
        _privacyPreferences = preferences;
      });
    } on Object {
      // Cycle records remain available even when optional reminders fail.
    }
  }

  Future<void> _updatePrivacyPreferences(PrivacyPreferences preferences) async {
    final supportedPreferences = preferences.copyWith(
      appLockEnabled: false,
      analyticsConsent: AnalyticsConsent.optedOut,
    );
    await _privacyPreferencesRepository.save(supportedPreferences);
    await NativePrivacyBridge.setScreenCoverEnabled(
      supportedPreferences.screenCoverEnabled,
    );
    if (!mounted) return;
    setState(() => _privacyPreferences = supportedPreferences);
    await _applyAnalyticsPreference(supportedPreferences);
    await _reconcileCycleCheckIn(
      requestPermission: supportedPreferences.cycleCheckInEnabled,
    );
  }

  Future<void> _applyAnalyticsPreference(PrivacyPreferences preferences) async {
    try {
      if (preferences.analyticsConsent == AnalyticsConsent.granted) {
        await _analyticsService.enable();
        await _identifyForAnalytics(_authState);
      } else {
        await _analyticsService.disable();
      }
    } on Object {
      // Optional operational analytics never blocks local health features.
    }
  }

  Future<void> _identifyForAnalytics(AuthState state) async {
    if (_privacyPreferences.analyticsConsent != AnalyticsConsent.granted) {
      return;
    }
    final userId = state.userId;
    if (state.isAuthenticated && userId != null) {
      try {
        await _analyticsService.identifyAuthenticatedUser(userId);
      } on Object {
        // Identity for optional analytics is non-critical.
      }
    }
  }

  Future<void> _syncAccountBoundServices(AuthState state) async {
    if (state.isAuthenticated) {
      await _identifyForAnalytics(state);
    } else {
      try {
        await _analyticsService.clearAuthenticatedUser();
      } on Object {
        // Identity cleanup is retried on the next account-state transition.
      }
    }
    await _syncEntitlementForAccount(state);
  }

  Future<void> _syncEntitlementForAccount(AuthState state) async {
    try {
      final userId = state.userId;
      if (state.canOpenLocalData && userId != null) {
        await _entitlementRepository.identifyAuthenticatedUser(userId);
      } else {
        await _entitlementRepository.clearAuthenticatedUser();
      }
    } on Object {
      // Store reconciliation never blocks local records or acute Care.
    }
  }

  Future<void> _trackOperationally(AnalyticsEvent event) async {
    try {
      await _analyticsService.track(
        AnalyticsPayload(event: event, timestamp: DateTime.now().toUtc()),
      );
    } on Object {
      // Optional operational analytics never blocks the requested action.
    }
  }

  AnalyticsPlatform get _analyticsPlatform {
    if (kIsWeb) return AnalyticsPlatform.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => AnalyticsPlatform.ios,
      _ => AnalyticsPlatform.android,
    };
  }

  @override
  Widget build(BuildContext context) {
    final Widget? accountGate =
        widget.requireAuthentication && (!_authLoaded || !_loaded)
        ? const _OnboardingLoadingScreen()
        : widget.requireAuthentication && !_authState.canOpenLocalData
        ? AuthScreen(
            service: _authService,
            appleSignInEnabled: widget.appleSignInEnabled,
          )
        : null;
    final Widget content;
    if (accountGate != null) {
      content = accountGate;
    } else if (!_loaded) {
      content = const _OnboardingLoadingScreen();
    } else if (_loadFailed) {
      content = _OnboardingLoadErrorScreen(onRetry: _load);
    } else if (_profile == null) {
      content = OnboardingFlow(onComplete: _completeOnboarding);
    } else {
      content = LetterExperienceShell(
        periodRepository: _periodRepository,
        careMemoryRepository: _careMemoryRepository,
        healthRecordRepository: _healthRecordRepository,
        momentCheckInRepository: _momentCheckInRepository,
        captureNoteStore: _captureNoteStore,
        preparationRepository: _preparationRepository,
        entitlementRepository: _entitlementRepository,
        reportPort: LetterReportExperiencePort(
          periodRepository: _periodRepository,
          careMemoryRepository: _careMemoryRepository,
          healthRecordRepository: _healthRecordRepository,
          momentCheckInRepository: _momentCheckInRepository,
          captureNoteStore: _captureNoteStore,
          now: widget.now,
        ),
        backupPort: _localBackupStore == null
            ? null
            : LetterBackupExperiencePort(
                store: _localBackupStore!,
                credentialStore: SecureLocalBackupCredentialStore(),
              ),
        youPort: _LetterYouExperiencePort(
          authService: _authService,
          readPrivacy: () => _privacyPreferences,
          persistPrivacy: _updatePrivacyPreferences,
        ),
        onCycleDataChanged: () =>
            _reconcileCycleCheckIn(requestPermission: true),
        now: widget.now,
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Letter Within',
      theme: ExperienceFoundation.lightTheme(),
      home: AnalyticsScope(
        service: _analyticsService,
        child: PrivacyShell(
          preferences: _privacyPreferences,
          ready: _loaded && !_loadFailed,
          authenticator: _deviceAuthenticator,
          child: EntitlementScope(
            repository: _entitlementRepository,
            initialState: _entitlementState,
            child: content,
          ),
        ),
      ),
    );
  }
}

final class _LetterYouExperiencePort implements YouExperiencePort {
  const _LetterYouExperiencePort({
    required this.authService,
    required this.readPrivacy,
    required this.persistPrivacy,
  });

  final AuthService authService;
  final PrivacyPreferences Function() readPrivacy;
  final Future<void> Function(PrivacyPreferences preferences) persistPrivacy;

  @override
  AuthState get account => authService.current;

  @override
  PrivacyPreferences get privacy => readPrivacy();

  @override
  Stream<AuthState> watchAccount() => authService.watch();

  @override
  Future<void> savePrivacy(PrivacyPreferences preferences) =>
      persistPrivacy(preferences);

  @override
  Future<void> signOut() => authService.signOut();

  @override
  Future<void> deleteServerAccount() => authService.deleteAccount();
}

class _OnboardingLoadingScreen extends StatelessWidget {
  const _OnboardingLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Loading Letter Within',
          child: CircularProgressIndicator(color: ExperienceColors.ember),
        ),
      ),
    );
  }
}

class _OnboardingLoadErrorScreen extends StatelessWidget {
  const _OnboardingLoadErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(LetterSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    color: ExperienceColors.ember,
                    size: 38,
                  ),
                  const SizedBox(height: LetterSpacing.md),
                  const Text(
                    'Letter Within could not open secure storage.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: ExperienceColors.ink,
                    ),
                  ),
                  const SizedBox(height: LetterSpacing.sm),
                  const Text(
                    'Your choices have not been changed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ExperienceColors.inkSoft),
                  ),
                  const SizedBox(height: LetterSpacing.lg),
                  FilledButton.icon(
                    key: const Key('retry-onboarding-load'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
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
