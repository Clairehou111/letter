import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/care/domain/care_memory_repository.dart';
import '../features/capture/domain/capture_models.dart';
import '../features/check_in/domain/moment_check_in_repository.dart';
import '../features/comfort_kit/domain/comfort_kit_repository.dart';
import '../features/comfort_kit/application/comfort_experience_controller.dart';
import '../features/comfort_window/domain/comfort_reminder_preference.dart';
import '../features/cycle/domain/cycle_prediction.dart';
import '../features/cycle/domain/local_date.dart';
import '../features/cycle/domain/period_record.dart';
import '../features/cycle/domain/period_repository.dart';
import '../features/entitlement/domain/entitlement.dart';
import '../features/entitlement/domain/entitlement_repository.dart';
import '../features/health_records/domain/health_record_repository.dart';
import '../features/health_data/domain/local_health_read_transaction.dart';
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

enum LetterDestination { today, cycle, care, patterns }

/// Public integration boundary for the approved Letter Within Experience
/// System — Quiet Dusk: one ember in one plum sky.
///
/// The shell owns exactly four persistent destinations — **Today, Cycle,
/// Care, and Patterns** — plus the orchestration between them:
///
///  * **Routing.** Settings (the former You content: account, protection &
///    preferences including the screen-cover toggle, backup & restore, Plus
///    and Reports entry points) is a full-screen **pushed route above the
///    shell**, never a tab. It is one tap from each non-Care top-level
///    destination via the shell-rendered gear affordance in a stable
///    top-trailing slot; the bottom tab bar is not visible while Settings
///    is open, and a visible, semantic ≥44px Back affordance (or system
///    back) returns to the originating tab with all shell state intact.
///    Settings is absent from immersive Care. Plus is a route (from locked
///    depth or Settings), Reports is a route (from Patterns and Settings);
///    neither ever becomes a tab.
///  * **One sky, two depths.** The entire product renders inside the single
///    Quiet Dusk environment: Today, Cycle, and Patterns live at the
///    everyday dusk depth; Care is the same plum sky taken to its floor
///    value — not a second theme. Warm paper appears only as an inset
///    reading/writing material (letters, in-app report preview) owned by
///    those surfaces. There is no daylight world, no theme toggle, no
///    system switching, no time-based dimming.
///  * **World crossing.** Same-sky switches crossfade in 280 ms (150 ms
///    reduced); crossings to or from Care take the 450 ms signature
///    (250 ms reduced) via `_previousIndex` detection — a dimming of the
///    same room, not a trip to a foreign world. The Care tab is immersive:
///    the tab bar slides away while Care is active, and Care's own
///    persistent exit pill ("Return to daylight") is the way back.
///    Re-tapping the active tab is an explicit no-op; selection fires
///    [ExperienceHaptics.pick].
///  * **Chrome honesty.** The tab bar is a fully opaque deep-plum slab with
///    a 1px translucent hairline top edge, and every non-Care destination's
///    viewport is inset from the bottom by the bar's total height (bar +
///    system navigation inset), so no interactive or textual content ever
///    renders beneath the bar — the clipped-content defect is prohibited at
///    the shell level, not left to each destination's scroll padding.
///    Destinations keep their own scroll-bottom padding on top of this
///    reserve, so primary actions rest above the inset even at 200%
///    dynamic type. The soft-ember selected pill is composited at a
///    measured ≥3.0:1 against the bar (see [_selectedTabIndicatorColor]),
///    honoring the large-graphic contrast floor.
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
///    persistence, safety, and completion flow remain outside that
///    renderer. The optional RecoveryReceipt writes through the same
///    health-record repository used by Today, Cycle, Patterns, and reports.
///  * **Privacy.** When screen cover is enabled in privacy preferences,
///    the shell blanks all content behind an opaque deep-plum cover with
///    the resting 72px ember whenever the app leaves the foreground (app
///    switcher privacy). In Quiet Dusk the cover *is* the environment with
///    the light turned down to one ember — the product's privacy signature.
///    Reduced-motion resolution follows the platform accessibility setting
///    only.
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
    required this.comfortKitRepository,
    required this.comfortReminderPreferenceRepository,
    required this.comfortExperienceController,
    required this.entitlementRepository,
    required this.reportPort,
    required this.youPort,
    required this.onCycleDataChanged,
    this.onConnectAccount,
    super.key,
    this.backupPort,
    this.navigationRequest,
    this.hasPlusPreviewAccess = false,
    this.onCareUsed,
    this.now,
    this.readTransaction = const PassthroughLocalHealthReadTransaction(),
  });

  final PeriodRepository periodRepository;
  final CareMemoryRepository careMemoryRepository;
  final HealthRecordRepository healthRecordRepository;
  final CaptureNoteStore captureNoteStore;
  final MomentCheckInRepository momentCheckInRepository;
  final PreparationRepository preparationRepository;
  final ComfortKitRepository comfortKitRepository;
  final ComfortReminderPreferenceRepository comfortReminderPreferenceRepository;
  final ComfortExperienceController comfortExperienceController;
  final EntitlementRepository entitlementRepository;
  final ReportExperiencePort reportPort;
  final BackupExperiencePort? backupPort;
  final YouExperiencePort youPort;
  final Future<void> Function()? onConnectAccount;
  final ValueListenable<LetterDestination?>? navigationRequest;
  final bool hasPlusPreviewAccess;

  final Future<void> Function() onCycleDataChanged;
  final Future<void> Function()? onCareUsed;
  final DateTime Function()? now;
  final LocalHealthReadTransaction readTransaction;

  @override
  State<LetterExperienceShell> createState() => _LetterExperienceShellState();
}

class _LetterExperienceShellState extends State<LetterExperienceShell>
    with WidgetsBindingObserver {
  // Destination identities — four persistent destinations, in tab order.
  // Read revisions and crossing detection key off these identities, never
  // off array position alone, so the four-tab structure stays honest.
  static const int _todayIndex = 0;
  static const int _cycleIndex = 1;
  static const int _careIndex = 2;
  static const int _patternsIndex = 3;

  /// The tab bar's fixed content height. Declared once here and applied to
  /// the [NavigationBar] itself, so the reserve subtracted from every dusk
  /// viewport always matches the bar's real footprint — content can never
  /// slide beneath an under-measured chrome area.
  static const double _tabBarContentHeight = 80;

  /// The soft-ember selected-tab pill, composited over the bar's surface
  /// color. emberSoft at 55% alpha over [ExperienceColors.surface]
  /// measures ≈3.5:1 — clearing the declared 3.0:1 large-graphic floor for
  /// the "you are here" indicator with headroom — while still reading as a
  /// soft wash rather than a solid action fill (ember coral stays scarce:
  /// the pill marks location; labels carry selection semantically). The
  /// earlier 45% composite measured 2.76:1 and was rejected at audit.
  static final Color _selectedTabIndicatorColor = ExperienceColors.emberSoft
      .withValues(alpha: 0.55);

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
  //
  // `_derivedError` stays write-only at the shell level (owner constraint
  // 12): its careful copy is composed here, but Patterns' own rendering
  // remains the sole visible surface. No new shell-level error surface is
  // added in this visual session.
  String? _derivedError;
  int _derivedLoadGeneration = 0;
  TodayCycleRingModel? _ringModel;
  GravityHorizonViewModel? _gravity;
  SpectrumLogViewModel? _spectrum;
  PersonalPatternAnalysis _analysis = PersonalPatternAnalysis.empty;
  PreparationLoopKind? _loopKind;

  late EntitlementState _entitlement;
  StreamSubscription<EntitlementState>? _entitlementSubscription;
  late final RecoveryReceiptController _recoveryReceiptController;

  bool _screenCoverActive = false;
  Route<void>? _settingsRoute;

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
    widget.navigationRequest?.addListener(_handleNavigationRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNavigationRequest();
    });
    _loadDerived();
  }

  @override
  void didUpdateWidget(covariant LetterExperienceShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationRequest != widget.navigationRequest) {
      oldWidget.navigationRequest?.removeListener(_handleNavigationRequest);
      widget.navigationRequest?.addListener(_handleNavigationRequest);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNavigationRequest();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.navigationRequest?.removeListener(_handleNavigationRequest);
    _entitlementSubscription?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Screen cover — when enabled, blanks content in the app switcher. The
  // current persisted preference is read at the moment the app leaves the
  // foreground, so a change in Settings takes effect immediately.
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
    final generation = ++_derivedLoadGeneration;
    if (!quiet || (_derivedError != null && _gravity == null)) {
      if (mounted) {
        setState(() {
          _derivedError = null;
        });
      }
    }
    try {
      final today = LocalDate.fromDateTime(_now().toLocal());
      final records = CyclePredictionEngine.recordsThrough(
        await widget.periodRepository.getAll(),
        today,
      );
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
      ).through(today);

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

      if (!mounted || generation != _derivedLoadGeneration) return;
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
      if (!mounted || generation != _derivedLoadGeneration) return;
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

  void _handleNavigationRequest() {
    if (!mounted) return;
    final destination = widget.navigationRequest?.value;
    if (destination == null) return;
    final index = switch (destination) {
      LetterDestination.today => _todayIndex,
      LetterDestination.cycle => _cycleIndex,
      LetterDestination.care => _careIndex,
      LetterDestination.patterns => _patternsIndex,
    };
    if (index == _index) return;
    setState(() {
      _previousIndex = _index;
      _index = index;
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

  void _selectDestination(int index) {
    // Active-tab re-tap is an explicit no-op (owner constraint 3): no
    // re-tap-to-scroll is implemented.
    if (index == _index) return;
    ExperienceHaptics.pick();
    setState(() {
      _previousIndex = _index;
      _index = index;
      // Destinations remain mounted to preserve navigation context, but their
      // facts always come from local storage. Re-entering Today, Cycle, or
      // Patterns therefore advances that destination's own read revision —
      // keyed to destination identity, not array position — and makes it
      // reload.
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

  /// The inline distress doorway on Today crosses into the deep world as a
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
      return _entitlement.canUse(capability) ||
          (widget.hasPlusPreviewAccess && isPlusPreviewCapability(capability));
    } catch (_) {
      return false;
    }
  }

  void _openPlus() {
    if (!mounted) return;
    PlusExperience.open(
      context,
      entitlementRepository: widget.entitlementRepository,
    );
  }

  Future<PlusCommitResult?> _openPlusWithContext(
    PlusOutcomeContext outcomeContext,
  ) {
    if (!mounted) {
      return Future<PlusCommitResult?>.value(
        const PlusCommitResult.dismissed(),
      );
    }
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
          onOpenCycle: () {
            _selectDestination(_cycleIndex);
            Navigator.of(routeContext).popUntil((route) => route.isFirst);
          },
          now: widget.now,
        ),
      ),
    );
  }

  /// Settings is a full-screen pushed route **above the shell** — a room
  /// off the house, not a world. The route sits on the same navigator stack
  /// that contains the shell, so the bottom tab bar is not visible while
  /// Settings is open, and the route's own back affordance (or system back)
  /// returns to the originating tab with every shell layer — scroll
  /// positions, in-progress edits, read revisions, and the derived models —
  /// intact. The transition is the standard neutral platform slide, not
  /// the world crossing.
  ///
  /// The route is built on a dusk [Scaffold], so every control You hosts —
  /// toggles included — resolves a valid Material ancestor inside the Quiet
  /// Dusk theme. A shell-rendered Back affordance occupies a stable
  /// top-leading slot at ≥44px, visible and announced, ahead of You's own
  /// content.
  ///
  /// Settings inherits everything You currently hosts, behaviorally
  /// unchanged: account, protection & preferences (including the
  /// screen-cover toggle), backup & restore, and the Plus and Reports
  /// entry points.
  void _openSettings() {
    if (_settingsRoute?.isActive ?? false) return;
    ExperienceHaptics.pick();
    final route = MaterialPageRoute<void>(
      builder: (routeContext) => Theme(
        data: ExperienceFoundation.lightTheme(),
        child: Scaffold(
          backgroundColor: ExperienceColors.canvas,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _SettingsBackSlot(
                  onBack: () => Navigator.of(routeContext).maybePop(),
                ),
                Expanded(child: _buildYou()),
              ],
            ),
          ),
        ),
      ),
    );
    _settingsRoute = route;
    Navigator.of(context).push(route).whenComplete(() {
      if (identical(_settingsRoute, route)) _settingsRoute = null;
    });
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
    // height plus the system navigation inset it sits above. Every
    // non-Care destination viewport is inset from the bottom by exactly
    // this amount, so no control, chip, or caption can ever rest beneath
    // the bar — shell-wide, at any text scale.
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
              _wrapDusk(_buildToday(), chromeReserve),
              crossing,
            ),
            _worldLayer(
              _cycleIndex,
              _wrapDusk(_buildCycle(), chromeReserve),
              crossing,
            ),
            // Care is the immersive deep-dusk world: the tab bar slides
            // away while it is active, and Care's own SafeArea + pinned
            // exit pill own its bottom rhythm. No chrome reserve — and no
            // Settings affordance — is applied here (owner constraints
            // 2 and 16).
            _worldLayer(_careIndex, _buildCare(), crossing),
            _worldLayer(
              _patternsIndex,
              _wrapDusk(_buildPatterns(), chromeReserve),
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
            // Screen cover: a real blank over everything, including chrome —
            // the same plum sky with the light turned down to one ember.
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
    // All four destination trees stay mounted to preserve their local state.
    // Hidden vertical ScrollViews must not inherit the route's primary
    // controller, otherwise a hardware Page Up/Down action sees several
    // attached positions and throws before it can reach the visible page.
    final scrollIsolatedChild = visible
        ? child
        : PrimaryScrollController.none(child: child);
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: duration,
      curve: ExperienceMotion.crossingCurve,
      child: TickerMode(
        enabled: visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: IgnorePointer(ignoring: !visible, child: scrollIsolatedChild),
        ),
      ),
    );
  }

  /// Dusk destination frame: the opaque plum canvas, top safe area, the
  /// shell-owned Settings affordance in its reserved top-trailing slot, and
  /// — critically — a bottom viewport reserve equal to the tab bar's total
  /// footprint. The bar itself is opaque, but this reserve guarantees that
  /// destination content never even travels beneath the chrome area, so no
  /// interactive element or label can be clipped by or rest under the bar.
  /// Destinations keep their own scroll-bottom padding inside this frame.
  ///
  /// The gear lives in a shell-rendered header strip above the destination
  /// body (owner constraint 16): the strip reserves the full top-trailing
  /// slot at the shell level, so the affordance can never overlap
  /// destination titles, dates, or controls, and it crossfades with its
  /// destination layer like the rest of the chrome.
  Widget _wrapDusk(Widget child, double chromeReserve) {
    return Padding(
      padding: EdgeInsets.only(bottom: chromeReserve),
      child: ColoredBox(
        color: ExperienceColors.canvas,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              _SettingsGearSlot(onOpenSettings: _openSettings),
              Expanded(child: child),
            ],
          ),
        ),
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
                    // The soft-ember pill marks "you are here" at a measured
                    // ≈3.5:1 against the bar (≥3.0:1 large-graphic floor);
                    // labels carry selection semantically.
                    indicatorColor: _selectedTabIndicatorColor,
                    selectedIndex: _index,
                    onDestinationSelected: _selectDestination,
                    destinations: const <Widget>[
                      NavigationDestination(
                        icon: Icon(Icons.water_drop_outlined),
                        selectedIcon: Icon(Icons.water_drop, size: 20),
                        label: 'Today',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.radio_button_unchecked),
                        selectedIcon: Icon(
                          Icons.radio_button_checked,
                          size: 20,
                        ),
                        label: 'Cycle',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.favorite_border),
                        selectedIcon: Icon(Icons.favorite, size: 20),
                        label: 'Care',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.bar_chart),
                        selectedIcon: Icon(Icons.bar_chart, size: 20),
                        label: 'Patterns',
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
      comfortExperienceController: widget.comfortExperienceController,
      today: () => LocalDate.fromDateTime(_now().toLocal()),
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
      comfortExperienceController: widget.comfortExperienceController,
      loopKind: _loopKind,
      memoryEvidence: _analysis.supportActions,
      // Let the safety route resolve US/Canada from the device locale and use
      // its honest no-invented-number fallback for every other region.
      regionCode: null,
      entrySource: _careEntrySource,
      onLeaveCare: _leaveCareToToday,
      onRequestCheckIn: _leaveCareToToday,
      // Motion preference resolves from the platform accessibility
      // setting only; no jank override is asserted at this layer.
      performanceConstrained: false,
      now: widget.now,
      onCareUsed: widget.onCareUsed,
      onRecordsChanged: () async => _handleCycleDataChanged(),
      careCompanionName: widget.youPort.privacy.careCompanionName,
      onCareCompanionNameSaved: (name) {
        return widget.youPort.savePrivacy(
          widget.youPort.privacy.copyWith(careCompanionName: name),
        );
      },
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
        now: _now,
        readTransaction: widget.readTransaction,
      ),
      preparationRepository: widget.preparationRepository,
      now: _now,
      onOpenCycle: () => _selectDestination(_cycleIndex),
    );
  }

  /// The former You destination, now hosted exclusively inside the pushed
  /// Settings route. All content — account, protection & preferences
  /// (including the screen-cover toggle), backup & restore, Plus and
  /// Reports entry points — is behaviorally unchanged.
  Widget _buildYou() {
    return YouExperience(
      key: const ValueKey<String>('destination-you'),
      port: widget.youPort,
      onConnectAccount: widget.onConnectAccount,
      backupPort: widget.backupPort ?? const _UnavailableBackupPort(),
      onOpenPlus: _openPlus,
      onOpenReports: _openReports,
      onCycleDataChanged: _handleCycleDataChanged,
      loadComfortExperience: widget.comfortExperienceController.load,
      saveComfortReminder: ({required bool enabled, required int leadDays}) =>
          widget.comfortExperienceController.saveReminder(
            enabled: enabled,
            leadDays: leadDays,
          ),
      now: widget.now,
    );
  }
}

// ---------------------------------------------------------------------------
// Settings gear slot — the shell-owned header affordance (owner constraint
// 16). Rendered by the shell itself on Today, Cycle, and Patterns in a
// stable top-trailing position, inside a reserved strip so it can never
// overlap destination titles, dates, or controls. Absent from immersive
// Care entirely: Care never passes through `_wrapDusk`.
//
// The slot is pinned above the destination body, so it stays put while the
// destination scrolls, and it inherits the destination layer's world
// crossfade, TickerMode freeze, semantics exclusion, and pointer gating —
// hidden layers never expose a tappable gear.
// ---------------------------------------------------------------------------

class _SettingsGearSlot extends StatelessWidget {
  const _SettingsGearSlot({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ExperienceSpacing.minTouchTarget,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(
            right: ExperienceSpacing.screenMargin - 12,
          ),
          child: IconButton(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
            color: ExperienceColors.inkSoft,
            tooltip: 'Settings',
            constraints: const BoxConstraints(
              minWidth: ExperienceSpacing.minTouchTarget,
              minHeight: ExperienceSpacing.minTouchTarget,
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings back slot — the shell-owned return affordance on the pushed
// Settings route. A visible, semantic back chevron in a stable top-leading
// slot at the 44px touch floor; tapping it pops the route and lands back on
// the originating tab with every shell layer — scroll positions,
// in-progress edits, read revisions, and the derived models — intact. The
// strip reserves its own height above You's content, so the affordance can
// never overlap destination titles or controls.
// ---------------------------------------------------------------------------

class _SettingsBackSlot extends StatelessWidget {
  const _SettingsBackSlot({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ExperienceSpacing.minTouchTarget,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(
            left: ExperienceSpacing.screenMargin - 12,
          ),
          child: IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new),
            color: ExperienceColors.inkSoft,
            tooltip: 'Back',
            constraints: const BoxConstraints(
              minWidth: ExperienceSpacing.minTouchTarget,
              minHeight: ExperienceSpacing.minTouchTarget,
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen cover — an opaque deep-plum blank with the ember at rest, shown
// over all content and chrome while the app is out of the foreground. In
// Quiet Dusk this is no longer a palette leak: the cover IS the environment
// with the light turned down to one ember — the product's privacy
// signature. Excluded from the accessibility tree: there is nothing to
// read behind a privacy blank.
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
// not provide one, Settings still opens and every other capability works —
// the backup flow itself reports an honest unavailable state and never
// pretends a backup ran. Local records are untouched either way.
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
