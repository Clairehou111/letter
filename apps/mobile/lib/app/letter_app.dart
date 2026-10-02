import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/letter_theme.dart';
import '../experience/letter_experience_shell.dart';
import '../experience/reports/letter_report_experience_port.dart';
import '../experience/theme/experience_foundation.dart';
import '../features/care/data/in_memory_care_memory_repository.dart';
import '../features/auth/data/dev_auth_service.dart';
import '../features/auth/domain/auth_service.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/analytics/data/dev_analytics_service.dart';
import '../features/analytics/data/secure_care_usage_aggregate_store.dart';
import '../features/analytics/domain/analytics_service.dart';
import '../features/analytics/domain/care_usage_aggregate.dart';
import '../features/analytics/presentation/analytics_scope.dart';
import '../features/check_in/data/in_memory_moment_check_in_repository.dart';
import '../features/comfort_kit/data/in_memory_comfort_kit_repository.dart';
import '../features/comfort_kit/application/comfort_experience_controller.dart';
import '../features/comfort_kit/domain/comfort_kit_repository.dart';
import '../features/comfort_window/data/comfort_reminder_preference_repositories.dart';
import '../features/comfort_window/domain/comfort_reminder_preference.dart';
import '../features/cycle/data/in_memory_period_repository.dart';
import '../features/entitlement/data/local_entitlement_repository.dart';
import '../features/entitlement/data/plus_preview_repositories.dart';
import '../features/entitlement/domain/plus_preview.dart';
import '../features/entitlement/domain/plus_preview_evidence.dart';
import '../features/entitlement/presentation/entitlement_scope.dart';
import '../features/health_data/data/local_health_store.dart';
import '../features/health_data/data/local_health_store_factory.dart';
import '../features/health_data/domain/local_health_read_transaction.dart';
import '../features/health_records/data/in_memory_health_record_repository.dart';
import '../features/notifications/application/cycle_check_in_scheduler.dart';
import '../features/notifications/application/comfort_window_scheduler.dart';
import '../features/notifications/application/notifying_period_repository.dart';
import '../features/notifications/data/flutter_local_notification_port.dart';
import '../features/notifications/domain/local_notification_port.dart';
import '../features/onboarding/data/onboarding_repository.dart';
import '../features/onboarding/data/onboarding_repository_factory.dart';
import '../features/onboarding/domain/onboarding_profile.dart';
import '../features/onboarding/presentation/onboarding_flow.dart';
import '../features/privacy/data/native_privacy_bridge.dart';
import '../features/privacy/data/privacy_preferences_repository_factory.dart';
import '../features/privacy/domain/privacy_preferences.dart';
import '../features/privacy/domain/privacy_preferences_repository.dart';
import '../features/privacy/presentation/privacy_shell.dart';
import '../features/local_backup/data/secure_local_backup_credential_store.dart';
import '../features/local_backup/domain/local_backup_import.dart';
import '../experience/backup/letter_backup_experience_port.dart';
import '../features/preparation/data/in_memory_preparation_repository.dart';
import '../features/patterns/data/repository_pattern_source.dart';

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
    this.comfortKitRepository,
    this.comfortReminderPreferenceRepository,
    this.entitlementRepository,
    this.plusPreviewGrantRepository,
    this.authService,
    this.analyticsService,
    this.careUsageAggregateStore,
    this.requireAuthentication = false,
    this.appleSignInEnabled = false,
    this.privacyPreferencesRepository,
    this.notificationPort,
    this.comfortNotificationPort,
    this.now,
  });

  final OnboardingRepository? onboardingRepository;
  final EntitlementRepository? entitlementRepository;
  final PlusPreviewGrantRepository? plusPreviewGrantRepository;
  final AuthService? authService;
  final AnalyticsService? analyticsService;
  final CareUsageAggregateStore? careUsageAggregateStore;
  final bool requireAuthentication;
  final bool appleSignInEnabled;
  final PeriodRepository? periodRepository;
  final CareMemoryRepository? careMemoryRepository;
  final HealthRecordRepository? healthRecordRepository;
  final CaptureNoteStore? captureNoteStore;
  final MomentCheckInRepository? momentCheckInRepository;
  final PreparationRepository? preparationRepository;
  final ComfortKitRepository? comfortKitRepository;
  final ComfortReminderPreferenceRepository?
  comfortReminderPreferenceRepository;
  final PrivacyPreferencesRepository? privacyPreferencesRepository;
  final LocalNotificationPort? notificationPort;
  final ComfortNotificationPort? comfortNotificationPort;
  final DateTime Function()? now;

  @override
  State<LetterApp> createState() => _LetterAppState();
}

class _LetterAppState extends State<LetterApp> with WidgetsBindingObserver {
  late final AuthService _authService;
  late final AnalyticsService _analyticsService;
  late final CareUsageAnalytics _careUsageAnalytics;
  late final StreamSubscription<AuthState> _authSubscription;
  late final StreamSubscription<EntitlementState> _entitlementSubscription;
  Future<void> _entitlementAccountSync = Future<void>.value();
  int _entitlementAccountRevision = 0;
  AuthState _authState = const AuthState(status: AuthStatus.signedOut);
  bool _authLoaded = false;
  late final OnboardingRepository _repository;
  late final EntitlementRepository _entitlementRepository;
  late final PlusPreviewController _plusPreviewController;
  PlusPreviewDecision _plusPreview = const PlusPreviewDecision(
    PlusPreviewAccess.notEligible,
  );
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
  late final ComfortKitRepository _comfortKitRepository;
  late final ComfortReminderPreferenceRepository
  _comfortReminderPreferenceRepository;
  late final PrivacyPreferencesRepository _privacyPreferencesRepository;
  late final LocalNotificationPort _notificationPort;
  late final ComfortNotificationPort _comfortNotificationPort;
  late final CycleCheckInScheduler _cycleCheckInScheduler;
  late final ComfortWindowScheduler _comfortWindowScheduler;
  late final ComfortExperienceController _comfortExperienceController;
  final ValueNotifier<LetterDestination?> _navigationRequest =
      ValueNotifier<LetterDestination?>(null);
  final ValueNotifier<int> _rootContentRevision = ValueNotifier<int>(0);
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final _NotificationNavigationObserver _navigationObserver =
      _NotificationNavigationObserver();
  LocalHealthStore? _ownedHealthStore;
  LocalBackupStore? _localBackupStore;
  late final LocalHealthReadTransaction _healthReadTransaction;
  late final RepositoryPatternSource _patternSource;
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
    _careUsageAnalytics = CareUsageAnalytics(
      analytics: _analyticsService,
      store: widget.careUsageAggregateStore ?? SecureCareUsageAggregateStore(),
      now: widget.now,
    );
    _authState = _authService.current;
    _repository =
        widget.onboardingRepository ?? createDefaultOnboardingRepository();
    _entitlementRepository =
        widget.entitlementRepository ?? LocalEntitlementRepository();
    _entitlementState = _entitlementRepository.current;
    _authSubscription = _authService.watch().listen((state) {
      if (mounted) {
        setState(() => _authState = state);
        _rootContentRevision.value += 1;
      }
      unawaited(_syncAccountBoundServices(state));
    });
    _entitlementSubscription = _entitlementRepository.watch().listen((state) {
      if (mounted) setState(() => _entitlementState = state);
      if (_loaded) unawaited(_refreshPlusPreview());
    });
    if (widget.periodRepository == null &&
        widget.careMemoryRepository == null &&
        widget.healthRecordRepository == null &&
        widget.captureNoteStore == null &&
        widget.momentCheckInRepository == null &&
        widget.preparationRepository == null &&
        widget.comfortKitRepository == null &&
        widget.comfortReminderPreferenceRepository == null) {
      final healthStore = createDefaultLocalHealthStore();
      _ownedHealthStore = healthStore;
      _localBackupStore = healthStore.localBackupStore;
      _basePeriodRepository = healthStore.periodRepository;
      _careMemoryRepository = healthStore.careMemoryRepository;
      _healthRecordRepository = healthStore.healthRecordRepository;
      _captureNoteStore = healthStore.captureNoteStore;
      _momentCheckInRepository = healthStore.momentCheckInRepository;
      _preparationRepository = healthStore.preparationRepository;
      _comfortKitRepository = healthStore.comfortKitRepository;
      _comfortReminderPreferenceRepository =
          healthStore.comfortReminderPreferenceRepository;
      _healthReadTransaction = healthStore.readTransaction;
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
      _comfortKitRepository =
          widget.comfortKitRepository ?? InMemoryComfortKitRepository();
      _comfortReminderPreferenceRepository =
          widget.comfortReminderPreferenceRepository ??
          InMemoryComfortReminderPreferenceRepository();
      _healthReadTransaction = const PassthroughLocalHealthReadTransaction();
    }
    final useProductionAdapters =
        widget.onboardingRepository == null && widget.periodRepository == null;
    _plusPreviewController = PlusPreviewController(
      widget.plusPreviewGrantRepository ??
          (useProductionAdapters
              ? SecurePlusPreviewGrantRepository()
              : InMemoryPlusPreviewGrantRepository()),
    );
    _privacyPreferencesRepository =
        widget.privacyPreferencesRepository ??
        (useProductionAdapters
            ? createDefaultPrivacyPreferencesRepository()
            : InMemoryPrivacyPreferencesRepository());
    _notificationPort =
        widget.notificationPort ??
        (useProductionAdapters
            ? FlutterLocalNotificationPort()
            : const DisabledLocalNotificationPort());
    _comfortNotificationPort =
        widget.comfortNotificationPort ??
        (_notificationPort is ComfortNotificationPort
            ? _notificationPort as ComfortNotificationPort
            : const DisabledLocalNotificationPort());
    _cycleCheckInScheduler = CycleCheckInScheduler(
      _basePeriodRepository,
      _privacyPreferencesRepository,
      _notificationPort,
      now: widget.now,
    );
    _patternSource = RepositoryPatternSource(
      healthRecords: _healthRecordRepository,
      careMemory: _careMemoryRepository,
      periods: _basePeriodRepository,
      momentCheckIns: _momentCheckInRepository,
      now: widget.now,
      readTransaction: _healthReadTransaction,
    );
    _comfortWindowScheduler = ComfortWindowScheduler(
      _basePeriodRepository,
      _patternSource,
      _comfortReminderPreferenceRepository,
      _comfortNotificationPort,
      now: widget.now,
    );
    _comfortExperienceController = ComfortExperienceController(
      patternSource: _patternSource,
      careMemory: _careMemoryRepository,
      quickNotes: _captureNoteStore,
      kitRepository: _comfortKitRepository,
      reminderRepository: _comfortReminderPreferenceRepository,
      onReminderChanged: () => _reconcileComfortWindow(requestPermission: true),
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
    _rootContentRevision.dispose();
    _ownedHealthStore?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshEntitlement());
      // A background interval may cross midnight or include a device time-zone
      // change. Rebuild the local forecast before trusting the pending
      // reminder's calendar time; this never asks for notification permission.
      if (_loaded) {
        unawaited(_reconcileComfortWindow(requestPermission: false));
      }
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
    _rootContentRevision.value += 1;
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
      final privacyPreferences = loadedPrivacyPreferences;
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
      _rootContentRevision.value += 1;
      await _applyAnalyticsPreference(privacyPreferences);
      await _syncEntitlementForAccount(authState);
      await _refreshPlusPreview();
      await _reconcileCycleCheckIn(requestPermission: profile != null);
      await _reconcileComfortWindow(requestPermission: false);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _authLoaded = true;
        _loaded = true;
        _loadFailed = true;
      });
      _rootContentRevision.value += 1;
    }
  }

  Future<void> _completeOnboarding(OnboardingProfile profile) async {
    await _repository.save(profile);
    if (!mounted) {
      return;
    }
    setState(() => _profile = profile);
    _rootContentRevision.value += 1;
    await _trackOperationally(const OnboardingCompletedEvent());
    await _reconcileCycleCheckIn(requestPermission: true);
  }

  void _handleNotificationTap(String payload) {
    final destination = switch (payload) {
      CycleCheckInScheduler.notificationPayload => LetterDestination.cycle,
      ComfortWindowScheduler.notificationPayload => LetterDestination.care,
      _ => null,
    };
    if (destination != null) {
      unawaited(_showNotificationDestination(destination));
    }
  }

  Future<void> _showNotificationDestination(
    LetterDestination destination,
  ) async {
    final navigator = _navigatorKey.currentState;

    // A notification is an external navigation request. Dismiss every
    // presented route (including sheets) through maybePop so PopScope and
    // unsaved-draft guards retain authority. If a route declines the pop,
    // leave both it and the tab beneath it unchanged.
    while (navigator?.canPop() ?? false) {
      final popRevision = _navigationObserver.popRevision;
      await navigator!.maybePop();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (_navigationObserver.popRevision == popRevision) return;
    }

    _navigationRequest.value = null;
    _navigationRequest.value = destination;
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

  Future<void> _reconcileComfortWindow({
    required bool requestPermission,
  }) async {
    try {
      await _comfortWindowScheduler.reconcile(
        requestPermission: requestPermission,
      );
    } on Object {
      // Forecasts and local records remain available if reminders fail.
    }
  }

  Future<void> _reconcileLocalPredictions() async {
    await Future.wait<void>([
      _reconcileCycleCheckIn(requestPermission: true),
      _reconcileComfortWindow(requestPermission: false),
      _refreshPlusPreview(),
    ]);
  }

  Future<void> _refreshPlusPreview() async {
    try {
      final now = (widget.now ?? DateTime.now)();
      final today = LocalDate.fromDateTime(now.toLocal());
      final source = (await _patternSource.read()).through(today);
      final analysis = const PersonalPatternEngine().analyze(source);
      final decision = await _plusPreviewController.resolve(
        hasPaidAccess: _entitlementState.hasPremiumAccess,
        hasPlusGradeEvidence: PlusPreviewEvidencePolicy.isEligible(
          periods: source.periods,
          analysis: analysis,
        ),
        periods: source.periods,
        now: now,
      );
      if (!mounted) return;
      setState(() => _plusPreview = decision);
    } on Object {
      // Preview availability never blocks local records or paid access.
    }
  }

  Future<void> _updatePrivacyPreferences(PrivacyPreferences preferences) async {
    final previous = _privacyPreferences;
    await _privacyPreferencesRepository.save(preferences);
    await NativePrivacyBridge.setScreenCoverEnabled(
      preferences.screenCoverEnabled,
    );
    if (!mounted) return;
    setState(() => _privacyPreferences = preferences);
    await _applyAnalyticsPreference(preferences);
    if (previous.analyticsConsent != preferences.analyticsConsent &&
        preferences.analyticsConsent == AnalyticsConsent.granted) {
      await _trackOperationally(
        const SettingsActionEvent(SettingsAction.analyticsEnabled),
      );
    } else if (previous.screenCoverEnabled != preferences.screenCoverEnabled) {
      await _trackOperationally(
        const SettingsActionEvent(SettingsAction.screenCoverChanged),
      );
    }
    await _reconcileCycleCheckIn(
      requestPermission: preferences.cycleCheckInEnabled,
    );
  }

  Future<void> _applyAnalyticsPreference(PrivacyPreferences preferences) async {
    try {
      if (preferences.analyticsConsent == AnalyticsConsent.granted) {
        await _analyticsService.enable();
        await _careUsageAnalytics.flushIfReady();
      } else {
        await _analyticsService.disable();
        await _careUsageAnalytics.clearPending();
      }
    } on Object {
      // Optional operational analytics never blocks local health features.
    }
  }

  Future<void> _syncAccountBoundServices(AuthState state) async {
    await _syncEntitlementForAccount(state);
  }

  Future<void> _connectAccountAfterDeletion() async {
    await _authService.beginAccountConnectionAfterDeletion();
    try {
      final navigator = _navigatorKey.currentState;
      if (navigator == null) return;
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (routeContext) => AuthScreen(
            service: _authService,
            appleSignInEnabled: widget.appleSignInEnabled,
            onClose: () => Navigator.of(routeContext).maybePop(),
            onAuthenticated: () => Navigator.of(routeContext).maybePop(),
          ),
        ),
      );
    } finally {
      await _authService.cancelAccountConnectionAfterDeletion();
    }
  }

  Future<void> _syncEntitlementForAccount(AuthState state) {
    final revision = ++_entitlementAccountRevision;
    final task = _entitlementAccountSync.then((_) async {
      if (revision != _entitlementAccountRevision) return;
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
    });
    _entitlementAccountSync = task;
    return task;
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

  Widget _buildRootContent() {
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
        comfortKitRepository: _comfortKitRepository,
        comfortReminderPreferenceRepository:
            _comfortReminderPreferenceRepository,
        comfortExperienceController: _comfortExperienceController,
        navigationRequest: _navigationRequest,
        hasPlusPreviewAccess: _plusPreview.canUsePlusDepth,
        entitlementRepository: _entitlementRepository,
        reportPort: LetterReportExperiencePort(
          periodRepository: _periodRepository,
          careMemoryRepository: _careMemoryRepository,
          healthRecordRepository: _healthRecordRepository,
          momentCheckInRepository: _momentCheckInRepository,
          captureNoteStore: _captureNoteStore,
          entitlementRepository: _entitlementRepository,
          readTransaction: _healthReadTransaction,
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
        onConnectAccount: _connectAccountAfterDeletion,
        onCycleDataChanged: _reconcileLocalPredictions,
        onCareUsed: _careUsageAnalytics.recordCareUse,
        readTransaction: _healthReadTransaction,
        now: widget.now,
      );
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final rootContent = ListenableBuilder(
      listenable: _rootContentRevision,
      builder: (context, _) => _buildRootContent(),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Letter Within',
      theme: ExperienceFoundation.lightTheme(),
      navigatorKey: _navigatorKey,
      navigatorObservers: <NavigatorObserver>[_navigationObserver],
      builder: (context, navigator) {
        return AnalyticsScope(
          service: _analyticsService,
          child: PrivacyShell(
            preferences: _privacyPreferences,
            child: EntitlementScope(
              repository: _entitlementRepository,
              initialState: _entitlementState,
              hasPlusPreviewAccess: _plusPreview.canUsePlusDepth,
              child: navigator ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      // The builder-level scopes wrap the Navigator itself, so they cover
      // home, pushed routes, and modal routes without duplicate subscriptions
      // or conflicting inherited state inside home.
      home: rootContent,
    );
  }
}

final class _NotificationNavigationObserver extends NavigatorObserver {
  int popRevision = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popRevision += 1;
    super.didPop(route, previousRoute);
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
                    Icons.error_outline,
                    color: ExperienceColors.ember,
                    size: 38,
                  ),
                  const SizedBox(height: LetterSpacing.md),
                  const Text(
                    'Letter Within could not finish opening.',
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
