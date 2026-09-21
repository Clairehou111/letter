import 'dart:async';

import 'package:flutter/material.dart';

import '../features/care/domain/care_memory_repository.dart';
import '../features/capture/domain/capture_models.dart';
import '../features/check_in/domain/moment_check_in_repository.dart';
import '../features/cycle/domain/local_date.dart';
import '../features/cycle/domain/period_record.dart';
import '../features/cycle/domain/period_repository.dart';
import '../features/entitlement/domain/entitlement.dart';
import '../features/entitlement/domain/entitlement_repository.dart';
import '../features/health_records/domain/health_record_repository.dart';
import '../features/insights/presentation/gravity_horizon_view_model.dart';
import '../features/insights/presentation/spectrum_log_view_model.dart';
import '../features/local_backup/domain/local_backup_models.dart';
import '../features/patterns/domain/pattern_source.dart';
import '../features/patterns/domain/personal_pattern.dart';
import '../features/patterns/domain/personal_pattern_engine.dart';
import '../features/patterns/data/repository_pattern_source.dart';
import '../features/patterns/presentation/personal_patterns_route.dart';
import '../features/preparation/domain/preparation_loop_state.dart';
import '../features/preparation/domain/preparation_plan.dart';
import '../features/recovery_receipt/application/recovery_receipt_controller.dart';
import '../features/today/today_cycle_ring_model.dart';
import 'care/care_experience.dart';
import 'care/original_care_animation_port.dart';
import 'cycle/cycle_experience.dart';
import 'experience_release_ports.dart';
import 'plus/plus_experience.dart';
import 'reports/reports_experience.dart';
import 'theme/experience_foundation.dart';
import 'today/today_experience.dart';
import 'you/you_experience.dart';

export 'experience_contract_context.dart';

/// Public integration boundary for the approved Letter Within Experience
/// System.
///
/// The shell owns five persistent destinations — Today, Cycle, Care,
/// Patterns, and You — plus the orchestration between them:
///
///  * **Routing.** Plus is a route (from locked depth or You), Reports is a
///    route (from Patterns and You); neither ever becomes a tab.
///  * **World crossing.** Moving between the daylight world and the dark
///    Care world is the signature emissive crossfade; under the platform
///    reduced-motion setting it degrades to a short plain fade. The Care
///    tab is an immersive full-screen world: the tab bar slides away while
///    Care is active, and Care's own persistent exit pill ("Return to
///    daylight") is the way back.
///  * **Chrome honesty.** The tab bar is fully opaque with a hairline top
///    edge, and every daylight destination's viewport is inset from the
///    bottom by the bar's total height (bar + system navigation inset), so
///    no interactive or textual content ever renders beneath the bar — the
///    clipped-content defect is prohibited at the shell level, not left to
///    each destination's scroll padding. Destinations keep their own
///    scroll-bottom padding on top of this reserve, so primary actions rest
///    above the inset even at 200% dynamic type.
///  * **Data coherence.** [onCycleDataChanged] is invoked after any
///    period/flow mutation reported by any destination — including
///    whole-cycle backfill and committed backup imports — and the shell
///    then refreshes the shared derived models (ring, gravity, spectrum,
///    twin, pattern analysis, preparation loop) so every destination
///    re-renders from the same facts. Today additionally reloads its own
///    working models from the repositories on each mutation, so the hero
///    estimate (read straight from the shared cycle-prediction contract)
///    and the ring can never diverge from Cycle.
///  * **Evidence.** The single memory-evidence gate is fed here: support
///    action patterns come from [PersonalPatternEngine.analyze] over one
///    factual [PatternSourceSnapshot] assembled from all four repositories,
///    and the preparation loop kind is derived from the persisted
///    [PreparationPlan] — never fabricated.
///  * **Port wiring.** The [CareAnimationPort] seam uses Letter Within's
///    original native five-scene motion system. The current Care journey,
///    persistence, safety, and completion flow remain outside that renderer.
///    The optional RecoveryReceipt writes through the same health-record
///    repository used by Today, Cycle, Patterns, and reports.
///  * **Privacy.** When screen cover is enabled in privacy preferences,
///    the shell blanks all content behind an opaque cover whenever the app
///    leaves the foreground (app switcher privacy). Reduced-motion
///    resolution follows the platform accessibility setting only.
///
/// Existing persistence, prediction, aggregation, entitlement, privacy, and
/// safety implementations remain outside this presentation shell. The shell
/// orchestrates these contracts but never reimplements their logic.
class LetterExperienceShell extends StatefulWidget {
  const LetterExperienceShell({
    required this.periodRepository,
    required this.careMemoryRepository,
    required this.healthRecordRepository,
    required this.captureNoteStore,
    required this.momentCheckInRepository,
    required this.preparationRepository,
    required this.entitlementRepository,
    required this.reportPort,
    required this.youPort,
    required this.onCycleDataChanged,
    super.key,
    this.backupPort,
    this.now,
  });

  final PeriodRepository periodRepository;
  final CareMemoryRepository careMemoryRepository;
  final HealthRecordRepository healthRecordRepository;
  final CaptureNoteStore captureNoteStore;
  final MomentCheckInRepository momentCheckInRepository;
  final PreparationRepository preparationRepository;
  final EntitlementRepository entitlementRepository;
  final ReportExperiencePort reportPort;
  final BackupExperiencePort? backupPort;
  final YouExperiencePort youPort;

  final Future<void> Function() onCycleDataChanged;
  final DateTime Function()? now;

  @override
  State<LetterExperienceShell> createState() => _LetterExperienceShellState();
}

class _LetterExperienceShellState extends State<LetterExperienceShell>
    with WidgetsBindingObserver {
  // Destination indices — five persistent destinations, in tab order.
  static const int _todayIndex = 0;
  static const int _cycleIndex = 1;
  static const int _careIndex = 2;
  static const int _patternsIndex = 3;
  static const int _youIndex = 4;

  /// The tab bar's fixed content height. Declared once here and applied to
  /// the [NavigationBar] itself, so the reserve subtracted from every
  /// daylight viewport always matches the bar's real footprint — content
  /// can never slide beneath an under-measured chrome area.
  static const double _tabBarContentHeight = 80;

  int _index = _todayIndex;
  int _previousIndex = _todayIndex;
  int _recordRevision = 0;
  int _todayReadRevision = 0;
  int _cycleReadRevision = 0;
  int _patternsReadRevision = 0;

  CareEntrySource _careEntrySource = CareEntrySource.tab;

  // Derived, shared models. Today and Cycle self-load their own working
  // data; the shell derives the cross-destination layer — the ring model
  // shared with Cycle, the chart view models for Patterns, the factual
  // pattern analysis feeding every memory surface, and the preparation
  // loop kind feeding the single memory gate.
  String? _derivedError;
  TodayCycleRingModel? _ringModel;
  GravityHorizonViewModel? _gravity;
  SpectrumLogViewModel? _spectrum;
  PersonalPatternAnalysis _analysis = PersonalPatternAnalysis.empty;
  PreparationLoopKind? _loopKind;

  late EntitlementState _entitlement;
  StreamSubscription<EntitlementState>? _entitlementSubscription;
  late final RecoveryReceiptController _recoveryReceiptController;

  bool _screenCoverActive = false;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recoveryReceiptController = RecoveryReceiptController(
      careMemoryRepository: widget.careMemoryRepository,
      healthRecordRepository: widget.healthRecordRepository,
      now: widget.now,
    );
    _entitlement = widget.entitlementRepository.current;
    _entitlementSubscription = widget.entitlementRepository.watch().listen(
      (state) {
        if (!mounted) return;
        setState(() => _entitlement = state);
      },
      onError: (_) {
        // Entitlement stream failures must never touch the local-first
        // core; the last known state simply stays on screen.
      },
    );
    _loadDerived();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entitlementSubscription?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Screen cover — when enabled, blanks content in the app switcher. The
  // current persisted preference is read at the moment the app leaves the
  // foreground, so a change in You takes effect immediately.
  // -------------------------------------------------------------------------

  bool _screenCoverEnabled() {
    try {
      return widget.youPort.privacy.screenCoverEnabled;
    } catch (_) {
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_screenCoverEnabled() && !_screenCoverActive && mounted) {
        setState(() => _screenCoverActive = true);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_screenCoverActive && mounted) {
        setState(() => _screenCoverActive = false);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Derived model orchestration. The shell reads repositories and composes
  // the existing presentation/domain view models through their exact typed
  // APIs; it never reimplements their math. Every construction degrades
  // honestly: the ring model refuses with insufficientHistory, chart models
  // rebuild from empty inputs into their structural-preview states, and the
  // pattern analysis falls back to empty — which renders silence through
  // the memory gate, never fabricated copy.
  // -------------------------------------------------------------------------

  Future<void> _loadDerived({bool quiet = false}) async {
    if (!quiet || (_derivedError != null && _gravity == null)) {
      if (mounted) {
        setState(() {
          _derivedError = null;
        });
      }
    }
    try {
      final today = LocalDate.fromDateTime(_now());
      final records = await widget.periodRepository.getAll();
      final ordered = List<PeriodRecord>.of(records)
        ..sort((a, b) => b.startDate.compareTo(a.startDate));

      TodayCycleRingModel? ring;
      try {
        ring = TodayCycleRingModel.fromRecords(records: ordered, today: today);
      } on TodayCycleRingException {
        // insufficientHistory is an honest state, handled by the
        // destinations themselves (empty orbit / ring forming).
        ring = null;
      }

      final healthRecords = await widget.healthRecordRepository.getAll();
      final careRecords = await widget.careMemoryRepository.getRecords();
      final careReflections = await widget.careMemoryRepository
          .getReflections();

      // One factual snapshot from all four repositories — the single
      // source Spectrum and the pattern engine analyze. Nothing here is
      // synthesized; missing inputs stay missing.
      final snapshot = PatternSourceSnapshot(
        healthRecords: healthRecords,
        careRecords: careRecords,
        careReflections: careReflections,
        periods: ordered,
      );

      PreparationLoopKind? loopKind;
      try {
        final plan = await widget.preparationRepository.getActivePlan();
        loopKind = plan == null
            ? null
            : switch (plan.status) {
                PreparationPlanStatus.current => PreparationLoopKind.saved,
                PreparationPlanStatus.privateReference =>
                  PreparationLoopKind.privateReference,
              };
      } catch (_) {
        // An unreadable plan never blocks the record; the gate falls back
        // to raw evidence counts.
        loopKind = null;
      }

      final gravity = _buildGravity(ordered, today);
      final spectrum = _buildSpectrum(snapshot);
      final analysis = _buildAnalysis(snapshot);

      if (!mounted) return;
      setState(() {
        _ringModel = ring;
        if (gravity != null) _gravity = gravity;
        if (spectrum != null) _spectrum = spectrum;
        _analysis = analysis;
        _loopKind = loopKind;
        _derivedError = _gravity == null || _spectrum == null
            ? _derivedError
            : null;
      });

      if (_gravity == null || _spectrum == null) {
        setState(() {
          _derivedError =
              'Patterns could not read your records right now. '
              'Nothing is lost — your entries are safe on this device.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _derivedError =
            'Patterns could not read your records right now. '
            'Nothing is lost — your entries are safe on this device.';
      });
    }
  }

  GravityHorizonViewModel? _buildGravity(
    List<PeriodRecord> ordered,
    LocalDate today,
  ) {
    try {
      return GravityHorizonViewModel.fromRecords(
        records: ordered,
        today: today,
      );
    } catch (_) {
      try {
        // Structural-preview state (noHistory) rather than a dead surface.
        return GravityHorizonViewModel.fromRecords(
          records: const <PeriodRecord>[],
          today: today,
        );
      } catch (_) {
        return _gravity;
      }
    }
  }

  /// Spectrum's aggregation seam lives in the feature module behind one
  /// typed factory. The shell hands it the factual snapshot and keeps the
  /// last good model — or an honest error panel — when the computation
  /// itself fails. Nothing is ever synthesized here.
  SpectrumLogViewModel? _buildSpectrum(PatternSourceSnapshot snapshot) {
    try {
      return SpectrumLogViewModel.fromSource(snapshot);
    } catch (_) {
      return _spectrum;
    }
  }

  /// The factual pattern analysis behind every memory surface. One typed
  /// engine call over the snapshot; a genuine failure returns the empty
  /// analysis, which renders silence through the single memory gate —
  /// never a fabricated claim.
  PersonalPatternAnalysis _buildAnalysis(PatternSourceSnapshot snapshot) {
    try {
      return const PersonalPatternEngine().analyze(snapshot);
    } catch (_) {
      return PersonalPatternAnalysis.empty;
    }
  }

  // -------------------------------------------------------------------------
  // Cross-destination change propagation: any period/flow mutation — a
  // Today quick action, a Cycle day-editor or backfill write, or a
  // committed backup import — fires the host callback and refreshes the
  // shared derived models so ring, gravity, and charts stay coherent.
  // -------------------------------------------------------------------------

  void _handleCycleDataChanged() {
    try {
      widget.onCycleDataChanged().catchError((Object _) {});
    } catch (_) {
      // The host callback must never break the record flow.
    }
    if (mounted) setState(() => _recordRevision += 1);
    _loadDerived(quiet: true);
  }

  // -------------------------------------------------------------------------
  // Navigation orchestration.
  // -------------------------------------------------------------------------

  void _selectDestination(int index) {
    if (index == _index) return;
    ExperienceHaptics.pick();
    setState(() {
      _previousIndex = _index;
      _index = index;
      // Destinations remain mounted to preserve navigation context, but their
      // facts always come from local storage. Re-entering Today or Cycle
      // therefore advances a read revision and makes that destination reload.
      if (index == _todayIndex) {
        _todayReadRevision += 1;
      } else if (index == _cycleIndex) {
        _cycleReadRevision += 1;
      } else if (index == _patternsIndex) {
        _patternsReadRevision += 1;
      }
      if (index == _careIndex) {
        _careEntrySource = CareEntrySource.tab;
      }
    });
  }

  /// The inline distress doorway on Today crosses into the dark world as a
  /// doorway entry — the landing acknowledges it with one quiet line.
  void _openCareFromDoorway() {
    setState(() {
      _previousIndex = _index;
      _index = _careIndex;
      _careEntrySource = CareEntrySource.todayDoorway;
    });
  }

  /// Care's persistent exit — "Return to daylight" — and its "check in on
  /// Today instead" recovery path both land on Today. Derived evidence is
  /// quietly refreshed so a just-saved outcome can inform the next memory
  /// surface render (still only through the shared gate).
  void _leaveCareToToday() {
    setState(() {
      _previousIndex = _index;
      _index = _todayIndex;
      _careEntrySource = CareEntrySource.tab;
    });
    _loadDerived(quiet: true);
  }

  bool _canUse(LetterCapability capability) {
    try {
      return _entitlement.canUse(capability);
    } catch (_) {
      return false;
    }
  }

  void _openPlus() {
    PlusExperience.open(
      context,
      entitlementRepository: widget.entitlementRepository,
    );
  }

  Future<PlusCommitResult?> _openPlusWithContext(
    PlusOutcomeContext outcomeContext,
  ) {
    return PlusExperience.open(
      context,
      entitlementRepository: widget.entitlementRepository,
      outcomeContext: outcomeContext,
    );
  }

  void _openReports() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => ReportsExperience(
          port: widget.reportPort,
          canUseClinicianReports: _canUse(LetterCapability.clinicianReports),
          onOpenPlusWithContext: _openPlusWithContext,
          onOpenSourceRecords: () => Navigator.of(routeContext).maybePop(),
          now: widget.now,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final reduced = ExperienceMotion.reducedMotion(context);
    final careInvolved = _index == _careIndex || _previousIndex == _careIndex;
    final crossing = careInvolved
        ? (reduced
              ? ExperienceMotion.worldCrossingReduced
              : ExperienceMotion.worldCrossing)
        : (reduced
              ? const Duration(milliseconds: 150)
              : const Duration(milliseconds: 280));

    // The total footprint of the bottom chrome: the bar's declared content
    // height plus the system navigation inset it sits above. Every daylight
    // destination viewport is inset from the bottom by exactly this amount,
    // so no control, chip, or caption can ever rest beneath the bar —
    // shell-wide, at any text scale.
    final systemBottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final chromeReserve = _tabBarContentHeight + systemBottomInset;

    return Theme(
      data: ExperienceFoundation.lightTheme(),
      child: Scaffold(
        backgroundColor: ExperienceColors.canvas,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _worldLayer(
              _todayIndex,
              _wrapLight(_buildToday(), chromeReserve),
              crossing,
            ),
            _worldLayer(
              _cycleIndex,
              _wrapLight(_buildCycle(), chromeReserve),
              crossing,
            ),
            // Care is the immersive world: the tab bar slides away while it
            // is active, and Care's own SafeArea + pinned exit pill own its
            // bottom rhythm. No chrome reserve is applied here.
            _worldLayer(_careIndex, _buildCare(), crossing),
            _worldLayer(
              _patternsIndex,
              _wrapLight(_buildPatterns(), chromeReserve),
              crossing,
            ),
            _worldLayer(
              _youIndex,
              _wrapLight(_buildYou(), chromeReserve),
              crossing,
            ),
            // Persistent navigation — slides away while the immersive Care
            // world is active; Care's own exit pill is always visible.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildTabBar(context),
            ),
            // Screen cover: a real blank over everything, including chrome.
            if (_screenCoverActive)
              const Positioned.fill(child: _ScreenCover()),
          ],
        ),
      ),
    );
  }

  /// One world layer. State is preserved for every destination (layers are
  /// never unmounted on switching); hidden layers stop their tickers, are
  /// excluded from the accessibility tree, and ignore pointer input.
  Widget _worldLayer(int index, Widget child, Duration duration) {
    final visible = _index == index;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: duration,
      curve: ExperienceMotion.crossingCurve,
      child: TickerMode(
        enabled: visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: IgnorePointer(ignoring: !visible, child: child),
        ),
      ),
    );
  }

  /// Daylight destination frame: the opaque canvas, top safe area, and —
  /// critically — a bottom viewport reserve equal to the tab bar's total
  /// footprint. The bar itself is opaque, but this reserve guarantees that
  /// destination content never even travels beneath the chrome area, so no
  /// interactive element or label can be clipped by or rest under the bar.
  /// Destinations keep their own scroll-bottom padding inside this frame.
  Widget _wrapLight(Widget child, double chromeReserve) {
    return Padding(
      padding: EdgeInsets.only(bottom: chromeReserve),
      child: ColoredBox(
        color: ExperienceColors.canvas,
        child: SafeArea(bottom: false, child: child),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final hidden = _index == _careIndex;
    final reduced = ExperienceMotion.reducedMotion(context);
    final duration = reduced
        ? const Duration(milliseconds: 150)
        : ExperienceMotion.sheetUp;
    return AnimatedSlide(
      offset: hidden ? const Offset(0, 1.2) : Offset.zero,
      duration: duration,
      curve: ExperienceMotion.sheetCurve,
      child: AnimatedOpacity(
        opacity: hidden ? 0 : 1,
        duration: duration,
        child: IgnorePointer(
          ignoring: hidden,
          child: ExcludeSemantics(
            excluding: hidden,
            // A fully opaque, hairline-topped chrome slab: nothing behind
            // the bar can show through its hit area, during scroll or at
            // rest.
            child: Container(
              decoration: const BoxDecoration(
                color: ExperienceColors.surface,
                border: Border(
                  top: BorderSide(color: ExperienceColors.hairline, width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: _tabBarContentHeight,
                  child: NavigationBar(
                    height: _tabBarContentHeight,
                    backgroundColor: ExperienceColors.surface,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    indicatorColor: ExperienceColors.emberSoft.withValues(
                      alpha: 0.45,
                    ),
                    selectedIndex: _index,
                    onDestinationSelected: _selectDestination,
                    destinations: const <Widget>[
                      NavigationDestination(
                        icon: Icon(Icons.water_drop_outlined),
                        selectedIcon: Icon(Icons.water_drop),
                        label: 'Today',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.radio_button_unchecked),
                        selectedIcon: Icon(Icons.radio_button_checked),
                        label: 'Cycle',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.favorite_border),
                        selectedIcon: Icon(Icons.favorite),
                        label: 'Care',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.bar_chart),
                        selectedIcon: Icon(Icons.bar_chart),
                        label: 'Patterns',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: 'You',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Destinations
  // -------------------------------------------------------------------------

  Widget _buildToday() {
    return TodayExperience(
      key: const ValueKey<String>('destination-today'),
      periodRepository: widget.periodRepository,
      checkInRepository: widget.momentCheckInRepository,
      healthRecordRepository: widget.healthRecordRepository,
      captureNoteStore: widget.captureNoteStore,
      today: () => LocalDate.fromDateTime(_now()),
      now: widget.now,
      loadSupportActionPatterns: () async => _analysis.supportActions,
      loadPreparationLoopKind: () async => _loopKind,
      onOpenCare: _openCareFromDoorway,
      // Deeper detail lives in Cycle's day editor; the shell routes there
      // rather than duplicating the editor. Returning to Today is one tab
      // away, and any save made there propagates through
      // _handleCycleDataChanged.
      onOpenCycleDayEditor: () async {
        _selectDestination(_cycleIndex);
      },
      onOpenCycleBackfill: () => _selectDestination(_cycleIndex),
      onCycleDataChanged: _handleCycleDataChanged,
      revision: _recordRevision + _todayReadRevision,
    );
  }

  Widget _buildCycle() {
    return CycleExperience(
      key: const ValueKey<String>('destination-cycle'),
      periodRepository: widget.periodRepository,
      healthRecordRepository: widget.healthRecordRepository,
      careMemoryRepository: widget.careMemoryRepository,
      onCycleDataChanged: _handleCycleDataChanged,
      ringModel: _ringModel,
      revision: _recordRevision + _cycleReadRevision,
      now: widget.now?.call(),
    );
  }

  Widget _buildCare() {
    return CareExperience(
      key: const ValueKey<String>('destination-care'),
      careMemoryRepository: widget.careMemoryRepository,
      // The optional post-Care symptom receipt writes through the same health
      // record repository used by Today, Cycle, Patterns, and reports.
      saveReceipt: _recoveryReceiptController.save,
      // Keep the current landing, safety, interruption, and completion
      // journey while restoring the original five native motion scenes.
      animationPort: const OriginalCareAnimationPort(),
      loopKind: _loopKind,
      memoryEvidence: _analysis.supportActions,
      // No region is known at this boundary; the safety route renders its
      // honest no-invented-number fallback.
      regionCode: null,
      entrySource: _careEntrySource,
      onLeaveCare: _leaveCareToToday,
      onRequestCheckIn: _leaveCareToToday,
      // Motion preference resolves from the platform accessibility
      // setting only; no jank override is asserted at this layer.
      performanceConstrained: false,
      now: widget.now,
    );
  }

  Widget _buildPatterns() {
    // Patterns has its own factual aggregation contract.  Recreate the
    // route when this destination is selected so the local database is read
    // afresh rather than displaying a cached cross-tab snapshot.
    return PersonalPatternsRoute(
      key: ValueKey<String>('destination-patterns-$_patternsReadRevision'),
      showBack: false,
      source: RepositoryPatternSource(
        healthRecords: widget.healthRecordRepository,
        careMemory: widget.careMemoryRepository,
        periods: widget.periodRepository,
        momentCheckIns: widget.momentCheckInRepository,
      ),
      preparationRepository: widget.preparationRepository,
      now: _now,
    );
  }

  Widget _buildYou() {
    return YouExperience(
      key: const ValueKey<String>('destination-you'),
      port: widget.youPort,
      backupPort: widget.backupPort ?? const _UnavailableBackupPort(),
      onOpenPlus: _openPlus,
      onOpenReports: _openReports,
      onCycleDataChanged: _handleCycleDataChanged,
      now: widget.now,
    );
  }
}

// ---------------------------------------------------------------------------
// Screen cover — an opaque plum blank with the ember at rest, shown over all
// content and chrome while the app is out of the foreground. Excluded from
// the accessibility tree: there is nothing to read behind a privacy blank.
// ---------------------------------------------------------------------------

class _ScreenCover extends StatelessWidget {
  const _ScreenCover();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: ColoredBox(
        color: ExperienceColors.careSkyBottom,
        child: Center(child: EmberOrb(size: 72)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Backup fallback. The shell's backup port is optional; when the host does
// not provide one, You still opens and every other capability works — the
// backup flow itself reports an honest unavailable state and never pretends
// a backup ran. Local records are untouched either way.
// ---------------------------------------------------------------------------

final class _UnavailableBackupPort implements BackupExperiencePort {
  const _UnavailableBackupPort();

  @override
  String get localDestinationDescription => 'your Letter folder on this device';

  @override
  Future<bool> hasStoredPassphrase() async => false;

  @override
  Future<ExperienceFileReceipt> exportEncrypted({
    required String passphrase,
    required bool rememberPassphrase,
  }) async {
    return const ExperienceFileReceipt(
      outcome: ExperienceFileOutcome.failed,
      message:
          'Backup is not available in this build. '
          'Your records remain safe on this device.',
    );
  }

  @override
  Future<LocalBackupImportPreview?> prepareImport({
    required String passphrase,
    required LocalBackupImportPolicy policy,
  }) {
    return Future<LocalBackupImportPreview?>.error(
      StateError(
        'Backup restore is not available in this build. '
        'Your records remain safe on this device.',
      ),
    );
  }

  @override
  Future<void> commitPreparedImport() async {}

  @override
  Future<void> discardPreparedImport() async {}
}
