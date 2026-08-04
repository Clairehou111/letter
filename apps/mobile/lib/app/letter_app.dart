import 'package:flutter/material.dart';

import '../design_system/letter_theme.dart';
import '../features/care/data/in_memory_impulse_buffer_repository.dart';
import '../features/care/data/in_memory_care_memory_repository.dart';
import '../features/care/domain/care_memory_repository.dart';
import '../features/care/domain/impulse_buffer_repository.dart';
import '../features/capture/domain/capture_models.dart';
import '../features/check_in/data/in_memory_moment_check_in_repository.dart';
import '../features/check_in/domain/moment_check_in_repository.dart';
import '../features/cycle/data/in_memory_period_repository.dart';
import '../features/cycle/domain/period_repository.dart';
import '../features/entitlement/data/local_entitlement_repository.dart';
import '../features/entitlement/domain/entitlement.dart';
import '../features/entitlement/domain/entitlement_repository.dart';
import '../features/entitlement/presentation/entitlement_scope.dart';
import '../features/health_data/data/local_health_store.dart';
import '../features/health_data/data/local_health_store_factory.dart';
import '../features/health_records/data/in_memory_health_record_repository.dart';
import '../features/health_records/domain/health_record_repository.dart';
import '../features/local_backup/domain/local_backup_file_port.dart';
import '../features/local_backup/domain/local_backup_import.dart';
import '../features/onboarding/data/onboarding_repository.dart';
import '../features/onboarding/data/onboarding_repository_factory.dart';
import '../features/onboarding/domain/onboarding_profile.dart';
import '../features/onboarding/presentation/onboarding_flow.dart';
import '../features/onboarding/presentation/privacy_center_screen.dart';

class LetterApp extends StatefulWidget {
  const LetterApp({
    super.key,
    this.onboardingRepository,
    this.periodRepository,
    this.impulseBufferRepository,
    this.careMemoryRepository,
    this.healthRecordRepository,
    this.captureNoteStore,
    this.momentCheckInRepository,
    this.entitlementRepository,
    this.now,
  });

  final OnboardingRepository? onboardingRepository;
  final EntitlementRepository? entitlementRepository;
  final PeriodRepository? periodRepository;
  final ImpulseBufferRepository? impulseBufferRepository;
  final CareMemoryRepository? careMemoryRepository;
  final HealthRecordRepository? healthRecordRepository;
  final CaptureNoteStore? captureNoteStore;
  final MomentCheckInRepository? momentCheckInRepository;
  final DateTime Function()? now;

  @override
  State<LetterApp> createState() => _LetterAppState();
}

class _LetterAppState extends State<LetterApp> {
  late final OnboardingRepository _repository;
  late final EntitlementRepository _entitlementRepository;
  EntitlementState _entitlementState = const EntitlementState(
    status: EntitlementStatus.freeOrUnknown,
  );
  late final PeriodRepository _periodRepository;
  late final ImpulseBufferRepository _impulseBufferRepository;
  late final CareMemoryRepository _careMemoryRepository;
  late final HealthRecordRepository _healthRecordRepository;
  late final CaptureNoteStore _captureNoteStore;
  late final MomentCheckInRepository _momentCheckInRepository;
  LocalBackupStore? _localBackupStore;
  LocalHealthStore? _ownedHealthStore;
  OnboardingProfile? _profile;
  bool _loaded = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.onboardingRepository ?? createDefaultOnboardingRepository();
    _entitlementRepository =
        widget.entitlementRepository ?? LocalEntitlementRepository();
    _entitlementState = _entitlementRepository.current;
    _entitlementRepository.watch().listen((state) {
      if (mounted) setState(() => _entitlementState = state);
    });
    if (widget.periodRepository == null &&
        widget.impulseBufferRepository == null &&
        widget.careMemoryRepository == null &&
        widget.healthRecordRepository == null &&
        widget.captureNoteStore == null &&
        widget.momentCheckInRepository == null) {
      final healthStore = createDefaultLocalHealthStore();
      _ownedHealthStore = healthStore;
      _periodRepository = healthStore.periodRepository;
      _impulseBufferRepository = healthStore.impulseBufferRepository;
      _careMemoryRepository = healthStore.careMemoryRepository;
      _healthRecordRepository = healthStore.healthRecordRepository;
      _captureNoteStore = healthStore.captureNoteStore;
      _momentCheckInRepository = healthStore.momentCheckInRepository;
      _localBackupStore = healthStore.localBackupStore;
    } else {
      _periodRepository = widget.periodRepository ?? InMemoryPeriodRepository();
      _impulseBufferRepository =
          widget.impulseBufferRepository ??
          InMemoryImpulseBufferRepository(clock: widget.now);
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
    }
    _load();
  }

  @override
  void dispose() {
    _ownedHealthStore?.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loaded = false;
      _loadFailed = false;
    });
    try {
      final profile = await _repository.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _loaded = true;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
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
  }

  Future<void> _updateProfile(OnboardingProfile profile) async {
    await _repository.save(profile);
    if (!mounted) {
      return;
    }
    setState(() => _profile = profile);
  }

  Future<void> _resetOnboarding() async {
    await _repository.clear();
    if (!mounted) {
      return;
    }
    setState(() => _profile = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Letter',
      theme: LetterTheme.light,
      home: EntitlementScope(
        repository: _entitlementRepository,
        initialState: _entitlementState,
        child: !_loaded
            ? const _OnboardingLoadingScreen()
            : _loadFailed
            ? _OnboardingLoadErrorScreen(onRetry: _load)
            : _profile == null
            ? OnboardingFlow(onComplete: _completeOnboarding)
            : LetterHome(
                profile: _profile!,
                periodRepository: _periodRepository,
                impulseBufferRepository: _impulseBufferRepository,
                careMemoryRepository: _careMemoryRepository,
                healthRecordRepository: _healthRecordRepository,
                captureNoteStore: _captureNoteStore,
                momentCheckInRepository: _momentCheckInRepository,
                onProfileChanged: _updateProfile,
                onReset: _resetOnboarding,
                localBackupStore: _localBackupStore,
                localBackupFilePort: _localBackupStore == null
                    ? null
                    : SystemLocalBackupFilePort(),
                now: widget.now,
              ),
      ),
    );
  }
}

class _OnboardingLoadingScreen extends StatelessWidget {
  const _OnboardingLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Loading Letter',
          child: CircularProgressIndicator(color: LetterColors.teal),
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
                    color: LetterColors.teal,
                    size: 38,
                  ),
                  const SizedBox(height: LetterSpacing.md),
                  const Text(
                    'Letter could not open secure storage.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Newsreader',
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: LetterSpacing.sm),
                  const Text(
                    'Your choices have not been changed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: LetterColors.muted),
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
