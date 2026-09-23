import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/care/domain/care_memory.dart';
import '../../features/care/domain/care_memory_repository.dart';
import '../../features/care/domain/care_mode.dart';
import '../../features/care/presentation/breath_flow.dart';
import '../../features/patterns/domain/personal_pattern.dart';
import '../../features/preparation/domain/preparation_loop_state.dart';
import '../../features/recovery_receipt/domain/recovery_receipt.dart';
import '../theme/experience_foundation.dart';
import 'care_animation_port.dart';
import 'care_body_scene.dart';
import 'care_boundary_scene.dart';
import 'care_completion_flow.dart';
import 'care_focus_scene.dart';
import 'care_heavy_scene.dart';
import 'care_release_scene.dart';
import 'care_safety_route.dart';
import 'care_scene_foundation.dart';
import 'care_toolkit_experience.dart';

/// How the person arrived at the Care world.
///
/// Three entries converge on one landing: the Care tab, Today's inline
/// distress doorway, and a `suggestsCare` check-in acknowledgment. The
/// landing is identical in structure for all three; only a single quiet
/// welcome line acknowledges the doorway entries, so nobody is dropped into
/// a scene they did not choose.
enum CareEntrySource { tab, todayDoorway, checkInAcknowledgment }

/// The Care destination: one dark plum world where the ember is held closer.
///
/// Assembly responsibilities (design authority):
///  * **Mode landing.** The first question leads — "What feels closest
///    right now?" — followed immediately by the five modes named in their
///    own words ([CareMode.label]) as a broken grid of compact doors, each
///    with a small distinctive preview echoing its scene (coral release
///    rings, blue held weight, violet racing strands, a warm doorway,
///    amber bodily warmth). Guided breathing sits beside the last door as
///    the glowing fast path; the everyday-care path into
///    [CareToolkitExperience] stays secondary. Choice is deliberately
///    capped: five mode doors → one immersive scene → one visible primary
///    action at a time.
///  * **World crossing.** Entering a scene is the signature emissive
///    crossfade — the screen deepens to plum while the ember enlarges into
///    the held orb, then scene content fades up; exiting reverses it. Under
///    the platform reduced-motion setting — or the sanctioned
///    [performanceConstrained] jank escape hatch — the crossing degrades to
///    a plain fade with a shorter duration, and scenes render through
///    [CareSceneMotionPreference] as composed statics with identical copy
///    and controls.
///  * **Scene routing.** Each mode routes to its Flutter scene
///    ([CareReleaseScene], [CareHeavyScene], [CareFocusScene],
///    [CareBoundaryScene], [CareBodyScene]). The reserved [animationPort]
///    seam is where the future companion pass plugs in via
///    [CareAnimationPort] — per-mode scene builder, three motion
///    preferences, and shared scene signals — without changing this journey.
///  * **Interruption recovery.** Any scene interrupted — app backgrounded,
///    call, or exit tap — lands on a named recoverable state: "You were in
///    the middle of …" with *Continue*, an optional *check in* exit, and
///    *leave it here*. Nothing is recorded without the deliberate
///    completion; backgrounding and exit never persist.
///  * **Completion assembly.** A deliberate scene completion becomes a
///    validated [CareActionCompletion] handed to [CareCompletionFlow],
///    which owns the optional outcome, the separately dismissible
///    RecoveryReceipt opt-in, and the reflection offer. The unsaved
///    check-back has exactly three honest answers plus `Save this
///    check-back` and `Skip — nothing needs saving`; Skip (and
///    Android/system back) delegates to [CareCompletionFlow.onSkip], which
///    clears the completion here and lands back on the landing with zero
///    writes. The saved page's single exit — exactly `Return to daylight` —
///    is the only daylight route out of the completion stage.
///  * **Safety.** The deterministic [CareSafetyRoute] is reachable from a
///    quiet, persistent line on every Care surface this experience renders.
///
/// Entitlement is structurally absent here on purpose: acute care and
/// safety are never gated, and no locked premium surface ever interrupts
/// Care. Remembered-help copy on the landing renders only through
/// [ExperienceFoundation.gateMemoryEvidence] — the single shared gate — so
/// zero evidence always renders silence (or the honest accumulating line).
class CareExperience extends StatefulWidget {
  const CareExperience({
    super.key,
    required this.careMemoryRepository,
    this.saveReceipt,
    this.animationPort,
    this.loopKind,
    this.memoryEvidence = const <SupportActionPattern>[],
    this.regionCode,
    this.entrySource = CareEntrySource.tab,
    this.onLeaveCare,
    this.onRequestCheckIn,
    this.performanceConstrained = false,
    this.now,
  });

  /// Persistence for outcomes and reflections, handed to the completion
  /// flow. Nothing is written until a deliberate save inside that flow.
  final CareMemoryRepository careMemoryRepository;

  /// Receipt persistence seam, wired by the shell from the health-records
  /// repository. When null, the completion flow does not offer the receipt
  /// opt-in at all.
  final Future<RecoveryReceiptResult> Function(RecoveryReceiptDraft draft)?
  saveReceipt;

  /// The future animation seam. This build ships the honest, fully usable
  /// Flutter scenes; when the professional companion pass lands, its
  /// per-mode scene builder plugs in here with the same signals, motion
  /// preferences, ground plane, and journey — replacing rendering only.
  final CareAnimationPort? animationPort;

  /// Evidence inputs for the single shared memory gate, forwarded to the
  /// landing's remembered-help line and the everyday toolkit.
  final PreparationLoopKind? loopKind;
  final List<SupportActionPattern> memoryEvidence;

  /// Region code for the deterministic safety surface (988/911 for US/CA,
  /// the honest fallback elsewhere).
  final String? regionCode;

  /// Which of the three entries brought the person here. Drives one quiet
  /// welcome line on the landing; never changes structure or gates choice.
  final CareEntrySource entrySource;

  /// Leaves the Care world back to daylight (the shell switches back to the
  /// light world). When null, the experience attempts to pop its own route.
  final VoidCallback? onLeaveCare;

  /// The "check in" recovery/exit path: leaves Care so the person can make
  /// a quick moment check-in on Today. When null, the option is hidden.
  final VoidCallback? onRequestCheckIn;

  /// The sanctioned frame-budget escape hatch: when the world crossing
  /// cannot hold 60 fps, scenes and crossings degrade to
  /// [CareSceneMotionPreference.staticFallback] + a plain fade — composed
  /// statics, never a degraded afterthought.
  final bool performanceConstrained;

  /// Injectable clock for deterministic completion timestamps.
  final DateTime Function()? now;

  @override
  State<CareExperience> createState() => _CareExperienceState();
}

enum _CareStage { landing, scene, recovery, toolkit, completion }

class _CareExperienceState extends State<CareExperience>
    with WidgetsBindingObserver {
  _CareStage _stage = _CareStage.landing;

  // Active scene state.
  CareMode? _activeMode;
  int _activeStepIndex = 0;
  String? _sceneResumeHint;

  // Interruption recovery state — the named recoverable landing.
  CareMode? _interruptedMode;
  int _interruptedStepIndex = 0;
  bool _pausedMidScene = false;

  // Completion hand-off.
  CareActionCompletion? _activeCompletion;
  CareMode _completionMode = CareMode.physical;

  bool _memoryProposalDismissed = false;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Interruption: backgrounding mid-scene lands on a named recoverable state
  // with nothing recorded.
  // -------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_stage == _CareStage.scene && _activeMode != null) {
        _interruptedMode = _activeMode;
        _interruptedStepIndex = _activeStepIndex;
        _pausedMidScene = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedMidScene && mounted) {
        _pausedMidScene = false;
        setState(() => _stage = _CareStage.recovery);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Scene metadata — stable identities shared with the scene files.
  // -------------------------------------------------------------------------

  static String _sceneDisplayName(CareMode mode) {
    return switch (mode) {
      CareMode.explode => 'Release',
      CareMode.heavy => 'Heavy',
      CareMode.racing => 'Focus',
      CareMode.space => 'making some space',
      CareMode.physical => 'caring for your body',
    };
  }

  static int _lastStepIndex(CareMode mode) {
    return switch (mode) {
      CareMode.explode => CareReleaseScene.stepIds.length - 1,
      CareMode.heavy => 3, // CareHeavyScene's four paced steps (0–3).
      CareMode.racing => CareFocusScene.stepIds.length - 1,
      CareMode.space => CareBoundaryScene.stepIds.length - 1,
      CareMode.physical => CareBodyScene.stepIds.length - 1,
    };
  }

  static String _resumeHintFor(CareMode mode, int stepIndex) {
    return switch (mode) {
      CareMode.explode => CareReleaseScene.interruptionHint,
      CareMode.heavy => CareHeavyScene.interruptionResumeHint,
      CareMode.racing =>
        CareFocusScene.resumeHintFor(stepIndex) ??
            CareFocusScene.recoveryLandingLine,
      CareMode.space => CareBoundaryScene.interruptionRecoveryLine,
      CareMode.physical => CareBodyScene.defaultResumeHint,
    };
  }

  static String _actionIdFor(CareMode mode) {
    return switch (mode) {
      CareMode.explode => 'care.release.guided_scene',
      CareMode.heavy => 'care.heavy.guided_scene',
      CareMode.racing => 'care.focus.guided_scene',
      CareMode.space => 'care.boundary.guided_scene',
      CareMode.physical => 'care.body.guided_scene',
    };
  }

  static String _actionLabelFor(CareMode mode) {
    return switch (mode) {
      CareMode.explode => 'Release — letting the pressure out, safely',
      CareMode.heavy => 'Heavy — resting into support',
      CareMode.racing => 'Focus — choosing one thing',
      CareMode.space => 'Space — a room of your own',
      CareMode.physical => 'Body — comfort for a working body',
    };
  }

  // -------------------------------------------------------------------------
  // Navigation within the Care world.
  // -------------------------------------------------------------------------

  void _openScene(CareMode mode) {
    ExperienceHaptics.pick();
    setState(() {
      _activeMode = mode;
      _activeStepIndex = 0;
      _sceneResumeHint = null;
      _stage = _CareStage.scene;
    });
  }

  void _openToolkit() {
    ExperienceHaptics.pick();
    setState(() => _stage = _CareStage.toolkit);
  }

  Future<void> _openBreathing() async {
    ExperienceHaptics.pick();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) =>
            BreathFlow(onClose: () => Navigator.of(routeContext).pop()),
      ),
    );
  }

  void _resumeInterruptedScene() {
    final mode = _interruptedMode;
    if (mode == null) return;
    ExperienceHaptics.pick();
    setState(() {
      _activeMode = mode;
      _activeStepIndex = _interruptedStepIndex;
      _sceneResumeHint = _resumeHintFor(mode, _interruptedStepIndex);
      _interruptedMode = null;
      _stage = _CareStage.scene;
    });
  }

  void _leaveInterruptionHere() {
    // "Leave it here" — the recoverable state is cleared and nothing was
    // ever recorded.
    ExperienceHaptics.pick();
    setState(() {
      _interruptedMode = null;
      _stage = _CareStage.landing;
    });
  }

  /// Any scene exit that is not the deliberate final completion is an
  /// interruption: land on the named recoverable state.
  void _handleSceneExit() {
    final mode = _activeMode;
    if (mode == null) {
      setState(() => _stage = _CareStage.landing);
      return;
    }
    setState(() {
      _interruptedMode = mode;
      _interruptedStepIndex = _activeStepIndex;
      _stage = _CareStage.recovery;
    });
  }

  void _handleSceneSignal(CareSceneSignal signal) {
    switch (signal) {
      case CareSceneSignal.stepCompleted:
        if (_activeMode != null) {
          final last = _lastStepIndex(_activeMode!);
          if (_activeStepIndex < last) {
            _activeStepIndex += 1;
          }
        }
      case CareSceneSignal.sceneCompleted:
        _completeScene();
      case CareSceneSignal.sceneDismissed:
        setState(() {
          _activeMode = null;
          _interruptedMode = null;
          _stage = _CareStage.landing;
        });
      case CareSceneSignal.requestedSafety:
        _openSafety();
      case CareSceneSignal.requestedExit:
        _handleSceneExit();
      case CareSceneSignal.ready:
      case CareSceneSignal.primaryInteraction:
        break;
    }
  }

  /// The only recording path out of a scene: the deliberate completion
  /// action on its final step.
  void _completeScene() {
    final mode = _activeMode;
    if (mode == null) return;
    final completion = CareActionCompletion(
      mode: mode,
      actionId: _actionIdFor(mode),
      actionLabel: _actionLabelFor(mode),
      occurredAt: _now(),
    );
    setState(() {
      _activeCompletion = completion;
      _completionMode = mode;
      _activeMode = null;
      _interruptedMode = null;
      _stage = _CareStage.completion;
    });
  }

  Future<void> _handleRitualCompleted(CareActionCompletion completion) async {
    if (!mounted) return;
    setState(() {
      _activeCompletion = completion;
      _completionMode = completion.mode;
      _stage = _CareStage.completion;
    });
  }

  /// The unsaved check-back's Skip path (and Android/system back, which the
  /// flow routes to the same seam): the completed scene is consumed, zero
  /// persistence happens here, and the journey returns to the Care landing.
  /// The stage change reuses the world-crossing switcher like every other
  /// stage change; the completion flow itself is presentation-only and
  /// cannot self-navigate.
  void _skipCompletionToLanding() {
    setState(() {
      _activeCompletion = null;
      _stage = _CareStage.landing;
    });
  }

  void _openSafety() {
    ExperienceHaptics.pick();
    CareSafetyRoute.show(
      context,
      regionCode: widget.regionCode,
      careWorld: true,
    );
  }

  void _resetJourneyToLanding() {
    _activeMode = null;
    _activeStepIndex = 0;
    _sceneResumeHint = null;
    _interruptedMode = null;
    _interruptedStepIndex = 0;
    _pausedMidScene = false;
    _activeCompletion = null;
    _stage = _CareStage.landing;
  }

  void _leaveToDaylight() {
    ExperienceHaptics.pick();
    setState(_resetJourneyToLanding);
    final leave = widget.onLeaveCare;
    if (leave != null) {
      leave();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _requestCheckInOnToday() {
    final request = widget.onRequestCheckIn;
    if (request == null) return;
    ExperienceHaptics.pick();
    setState(_resetJourneyToLanding);
    request();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final motion = ExperienceFoundation.motionPreference(
      context,
      performanceConstrained: widget.performanceConstrained,
    );
    final fullMotion = motion == CareSceneMotionPreference.full;
    final duration = fullMotion
        ? ExperienceMotion.worldCrossing
        : ExperienceMotion.worldCrossingReduced;

    return Theme(
      data: ExperienceFoundation.careTheme(),
      child: Scaffold(
        backgroundColor: ExperienceColors.careSkyBottom,
        body: AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[...previousChildren, ?currentChild],
            );
          },
          transitionBuilder: (child, animation) =>
              _crossingTransition(child, animation, fullMotion),
          child: _stageBody(motion),
        ),
      ),
    );
  }

  /// The world-crossing transition. Full motion: an emissive crossfade in
  /// which the ember enlarges from its resting marker into the held orb
  /// while scene content fades up beneath it; reversing the stage change
  /// reverses the crossing into daylight. Reduced motion and the jank
  /// escape hatch render a plain fade.
  Widget _crossingTransition(
    Widget child,
    Animation<double> animation,
    bool fullMotion,
  ) {
    if (!fullMotion) {
      return FadeTransition(opacity: animation, child: child);
    }
    final curved = CurvedAnimation(
      parent: animation,
      curve: ExperienceMotion.crossingCurve,
    );
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, current) {
        final t = curved.value;
        final contentOpacity = ((t - 0.30) / 0.70).clamp(0.0, 1.0);
        final emberOpacity = t < 0.35
            ? 1.0
            : (1 - (t - 0.35) / 0.55).clamp(0.0, 1.0);
        final emberSize = 28 + 124 * t;
        return RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Opacity(opacity: contentOpacity, child: current),
              if (emberOpacity > 0)
                IgnorePointer(
                  child: Opacity(
                    opacity: emberOpacity,
                    child: Center(child: EmberOrb(size: emberSize)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _stageBody(CareSceneMotionPreference motion) {
    return switch (_stage) {
      _CareStage.landing => KeyedSubtree(
        key: const ValueKey<String>('care-landing'),
        child: _buildLanding(motion),
      ),
      _CareStage.scene => KeyedSubtree(
        key: ValueKey<String>('care-scene-${_activeMode?.name}'),
        child: _buildActiveScene(motion),
      ),
      _CareStage.recovery => KeyedSubtree(
        key: const ValueKey<String>('care-recovery'),
        child: _buildRecovery(motion),
      ),
      _CareStage.toolkit => KeyedSubtree(
        key: const ValueKey<String>('care-toolkit'),
        child: _buildToolkit(),
      ),
      _CareStage.completion => KeyedSubtree(
        key: ValueKey<String>(
          'care-completion-${_activeCompletion?.occurredAt.toIso8601String()}',
        ),
        child: _buildCompletion(motion),
      ),
    };
  }

  // -------------------------------------------------------------------------
  // Landing — the question first, then one scannable set of doors.
  // -------------------------------------------------------------------------

  String? get _entryLine {
    return switch (widget.entrySource) {
      CareEntrySource.tab => null,
      CareEntrySource.todayDoorway =>
        'You came through a hard moment. It can wait at the door.',
      CareEntrySource.checkInAcknowledgment =>
        'That check-in was heard. There is room for all of it here.',
    };
  }

  static String _modeDescriptor(CareMode mode) {
    return switch (mode) {
      CareMode.explode => 'Let the pressure out, safely.',
      CareMode.heavy => 'Put the weight down for a while.',
      CareMode.racing => 'Find one quiet thing to hold.',
      CareMode.space => 'A soft edge between you and everyone.',
      CareMode.physical => 'Warmth, position, and kindness for the body.',
    };
  }

  /// A deliberately conservative estimate of the vertical space the landing
  /// chrome (header, optional entry and memory lines, everyday-care card)
  /// occupies, so the phone door grid can be sized to sit fully above the
  /// pinned footer on the first viewport. Overestimation only leaves a
  /// little quiet space beneath the doors — it can never clip a tile.
  static double _estimatedLandingChrome({
    required double textScale,
    required bool hasEntry,
    required bool hasMemory,
  }) {
    var height =
        20 + // ember + eyebrow row
        8 +
        100 * textScale + // the question, two display lines (buffered)
        8 +
        3 + // acid rule
        8 +
        20 * textScale + // support line
        16; // estimation buffer
    if (hasEntry) {
      height += 46 * textScale + 4;
    }
    if (hasMemory) {
      height += 8 + 64;
    }
    return height;
  }

  /// Measures the compact door grid against its real tile widths before it
  /// is composed. Returns one required height per row when every door can
  /// render its full label — the mode doors wrap to at most three lines,
  /// the breathing fast path to two — or null when the tiles are too narrow
  /// and the landing must fall back to the roomier single-column rows.
  ///
  /// An intentional ellipsis never throws a Flutter overflow error, so this
  /// pre-paint measurement is the only honest guarantee that no Care mode
  /// label is ever clipped.
  List<double>? _measureCompactDoorRows(double maxWidth) {
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final labelStyle = ExperienceType.headline(ExperienceColors.careInk);
    final captionStyle = ExperienceType.caption(ExperienceColors.careInkSoft);

    TextPainter layoutText(
      String text,
      TextStyle style,
      double width, {
      int? maxLines,
    }) {
      return TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: maxLines,
      )..layout(maxWidth: width);
    }

    // Mirrors _PhoneDoorGrid's composition exactly: the staggered flexes,
    // the mode pairing, and the breathing fast path sharing the last row.
    const rowFlexes = <(int, int)>[(5, 4), (4, 5), (4, 5)];
    const rowModes = <(CareMode, CareMode?)>[
      (CareMode.explode, CareMode.heavy),
      (CareMode.racing, CareMode.space),
      (CareMode.physical, null), // the breathing fast path
    ];

    final usable = maxWidth - _LandingMetrics.doorGap;
    final heights = <double>[];
    for (var i = 0; i < rowFlexes.length; i++) {
      final (leftFlex, rightFlex) = rowFlexes[i];
      // 20 is the tile's horizontal padding; the extra 1 is a sub-pixel
      // guard so flex rounding can never wrap one line beyond the measure.
      final leftWidth = usable * leftFlex / (leftFlex + rightFlex) - 21;
      final rightWidth = usable * rightFlex / (leftFlex + rightFlex) - 21;

      double modeTileHeight(CareMode mode, double width) {
        final label = layoutText(mode.label, labelStyle, width);
        if (label.computeLineMetrics().length > 3) return -1;
        // top padding + preview + gap + label + bottom padding.
        return 10 + 40 + 8 + label.height + 10;
      }

      final leftHeight = modeTileHeight(rowModes[i].$1, leftWidth);
      if (leftHeight < 0) return null;
      var rowHeight = leftHeight;

      final rightMode = rowModes[i].$2;
      if (rightMode != null) {
        final rightHeight = modeTileHeight(rightMode, rightWidth);
        if (rightHeight < 0) return null;
        if (rightHeight > rowHeight) rowHeight = rightHeight;
      } else {
        final label = layoutText(_BreathingDoor._label, labelStyle, rightWidth);
        if (label.computeLineMetrics().length > 2) return null;
        final caption = layoutText(
          _BreathingDoor._caption,
          captionStyle,
          rightWidth - 12, // the fast-path dot and its gap
          maxLines: 2,
        );
        final breathingHeight =
            10 + 34 + 6 + label.height + 2 + caption.height + 10;
        if (breathingHeight > rowHeight) rowHeight = breathingHeight;
      }
      heights.add(rowHeight);
    }
    return heights;
  }

  Widget _buildLanding(CareSceneMotionPreference motion) {
    final entryLine = _entryLine;
    final memoryLine = _resolveLandingMemoryLine();

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ExperienceColors.careBackdrop),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700;
            final maxContentWidth = wide ? 820.0 : 560.0;
            // The broken door grid needs room for two labels side by side.
            // Narrow widths and large text fall back to a single column of
            // roomier rows — spacious, never cramped.
            final textScale = MediaQuery.textScalerOf(context).scale(1.0);
            final useGrid =
                wide || (constraints.maxWidth >= 352 && textScale <= 1.3);

            // Single-column: breathing leads the list as the fast path,
            // then the five doors at reading width. Rows grow with their
            // labels — every mode's own words render in full.
            Widget singleColumnContent() {
              final doors = <Widget>[
                for (final mode in CareMode.values)
                  _ModeDoor(
                    mode: mode,
                    descriptor: _modeDescriptor(mode),
                    stacked: false,
                    onTap: () => _openScene(mode),
                  ),
              ];
              final choices = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _BreathingDoor(onTap: _openBreathing),
                  const SizedBox(height: _LandingMetrics.doorGap),
                  ..._gapped(doors),
                ],
              );
              return ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: ExperienceSpacing.lg),
                children: <Widget>[
                  _LandingHeader(motion: motion, entryLine: entryLine),
                  if (memoryLine != null) ...<Widget>[
                    const SizedBox(height: ExperienceSpacing.sm),
                    memoryLine,
                  ],
                  const SizedBox(height: ExperienceSpacing.md),
                  choices,
                  const SizedBox(height: _LandingMetrics.doorGap),
                  _EverydayCareCard(onTap: _openToolkit),
                ],
              );
            }

            Widget footer() {
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _LandingSafetyLine(onTap: _openSafety),
                      const SizedBox(height: ExperienceSpacing.xs),
                      _LightPill(
                        label: 'Return to daylight',
                        semanticsLabel:
                            'Return to daylight. Exit is always available.',
                        onPressed: _leaveToDaylight,
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!useGrid) {
              return _landingFrame(
                maxContentWidth: maxContentWidth,
                content: singleColumnContent(),
                footer: footer(),
              );
            }

            if (wide) {
              final doors = <Widget>[
                for (final mode in CareMode.values)
                  _ModeDoor(
                    mode: mode,
                    descriptor: _modeDescriptor(mode),
                    stacked: true,
                    onTap: () => _openScene(mode),
                  ),
              ];
              return _landingFrame(
                maxContentWidth: maxContentWidth,
                content: ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: ExperienceSpacing.lg),
                  children: <Widget>[
                    _LandingHeader(motion: motion, entryLine: entryLine),
                    if (memoryLine != null) ...<Widget>[
                      const SizedBox(height: ExperienceSpacing.sm),
                      memoryLine,
                    ],
                    const SizedBox(height: ExperienceSpacing.md),
                    _WideDoorGrid(
                      doors: doors,
                      breathing: _BreathingDoor(
                        stacked: true,
                        onTap: _openBreathing,
                      ),
                    ),
                    const SizedBox(height: _LandingMetrics.doorGap),
                    _EverydayCareCard(onTap: _openToolkit),
                  ],
                ),
                footer: footer(),
              );
            }

            // Compact phone grid: the rows are sized from the measured space
            // above the pinned footer so all six choices land fully readable
            // on the first viewport — nothing is accidentally clipped. Each
            // row is then grown to whatever its labels actually need, so a
            // longer label is given room rather than an ellipsis. When the
            // space genuinely cannot hold them (very short viewports), the
            // same composition scrolls with complete rows.
            final compactDoors = <Widget>[
              for (final mode in CareMode.values)
                _CompactModeDoor(
                  mode: mode,
                  descriptor: _modeDescriptor(mode),
                  onTap: () => _openScene(mode),
                ),
            ];

            return _landingFrame(
              maxContentWidth: maxContentWidth,
              content: LayoutBuilder(
                builder: (context, content) {
                  final chrome = _estimatedLandingChrome(
                    textScale: textScale,
                    hasEntry: entryLine != null,
                    hasMemory: memoryLine != null,
                  );
                  final gridSpace =
                      content.maxHeight -
                      chrome -
                      12 - // after-header gap
                      (3 * _LandingMetrics.doorGap) - // row gaps + card gap
                      _LandingMetrics.cardEstimate;
                  final fitted = (gridSpace / 3).clamp(
                    _LandingMetrics.compactRowHeight,
                    _LandingMetrics.maxRowHeight,
                  );
                  final fittedRowHeight =
                      gridSpace / 3 >= _LandingMetrics.compactRowHeight
                      ? fitted
                      : _LandingMetrics.compactRowHeight;

                  // The broken grid keeps its place only while every door
                  // can show its full label; otherwise the landing falls
                  // back to the roomier single-column rows.
                  final measuredRows = _measureCompactDoorRows(
                    content.maxWidth,
                  );
                  if (measuredRows == null) {
                    return singleColumnContent();
                  }
                  final rowHeights = <double>[
                    for (final needed in measuredRows)
                      needed > fittedRowHeight ? needed : fittedRowHeight,
                  ];

                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _LandingHeader(motion: motion, entryLine: entryLine),
                        if (memoryLine != null) ...<Widget>[
                          const SizedBox(height: ExperienceSpacing.sm),
                          memoryLine,
                        ],
                        const SizedBox(height: 12),
                        _PhoneDoorGrid(
                          doors: compactDoors,
                          breathing: _BreathingDoor(
                            compact: true,
                            onTap: _openBreathing,
                          ),
                          rowHeights: rowHeights,
                        ),
                        const SizedBox(height: _LandingMetrics.doorGap),
                        _EverydayCareCard(onTap: _openToolkit),
                      ],
                    ),
                  );
                },
              ),
              footer: footer(),
            );
          },
        ),
      ),
    );
  }

  Widget _landingFrame({
    required double maxContentWidth,
    required Widget content,
    required Widget footer,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.sm,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: content,
              ),
            ),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          footer,
        ],
      ),
    );
  }

  static List<Widget> _gapped(List<Widget> tiles) {
    final out = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      out.add(tiles[i]);
      if (i < tiles.length - 1) {
        out.add(const SizedBox(height: _LandingMetrics.doorGap));
      }
    }
    return out;
  }

  /// The gated remembered-help line. This is the surface that replaces the
  /// prototype's broken "Last cycle, ____ helped you most." — copy renders
  /// only through the single shared gate, and only from real evidence.
  Widget? _resolveLandingMemoryLine() {
    // Care is a high-emotion surface. Do not turn one attempt, a neutral
    // result, or a preparation-loop state into a claim that something helps.
    // The landing only resurfaces a specific action after two deliberate
    // Better check-backs. Other screens may still show honest accumulating
    // evidence through the shared gate.
    final meaningfulEvidence = widget.memoryEvidence
        .where((item) => item.betterCount >= 2)
        .toList(growable: false);
    if (meaningfulEvidence.isEmpty) return null;

    final verdict = ExperienceFoundation.gateMemoryEvidence(
      loopKind: widget.loopKind,
      evidence: meaningfulEvidence,
    );

    String? line;
    var dismissible = false;
    switch (verdict) {
      case MemoryEvidenceVerdict.remembered:
        line = ExperienceMemoryGate.rememberedLine(meaningfulEvidence);
        break;
      case MemoryEvidenceVerdict.accumulating:
        // Unreachable for the filtered evidence above, but stay silent if
        // gate semantics change later.
        line = null;
        break;
      case MemoryEvidenceVerdict.proposal:
        if (!_memoryProposalDismissed) {
          line = ExperienceMemoryGate.rememberedLine(meaningfulEvidence);
          dismissible = line != null;
        }
        break;
      case MemoryEvidenceVerdict.silent:
        line = null;
        break;
    }
    if (line == null) return null;

    return _LandingMemoryLine(
      line: line,
      dismissible: dismissible,
      onDismiss: () {
        ExperienceHaptics.pick();
        setState(() => _memoryProposalDismissed = true);
      },
    );
  }

  // -------------------------------------------------------------------------
  // Scene routing
  // -------------------------------------------------------------------------

  Widget _buildActiveScene(CareSceneMotionPreference motion) {
    final mode = _activeMode;
    if (mode == null) {
      return _buildLanding(motion);
    }
    final animationPort = widget.animationPort;
    if (animationPort != null) {
      return animationPort.buildScene(
        context,
        mode: mode,
        motionPreference: motion,
        onSignal: _handleSceneSignal,
      );
    }
    final index = _activeStepIndex.clamp(0, _lastStepIndex(mode));
    final hint = _sceneResumeHint;

    return switch (mode) {
      CareMode.explode => CareReleaseScene(
        motionPreference: motion,
        onSignal: _handleSceneSignal,
        onExit: _handleSceneExit,
        onSafety: _openSafety,
        onCompleted: _completeScene,
        initialStepIndex: index,
        resumeHint: hint,
      ),
      CareMode.heavy => CareHeavyScene(
        motionPreference: motion,
        onSignal: _handleSceneSignal,
        onComplete: _completeScene,
        onExit: _handleSceneExit,
        onSafety: _openSafety,
        initialStepIndex: index,
        resumeHint: hint,
      ),
      CareMode.racing => CareFocusScene(
        motionPreference: motion,
        onSignal: _handleSceneSignal,
        onCompleted: _completeScene,
        onExit: _handleSceneExit,
        onSafety: _openSafety,
        initialStepIndex: index,
        resumeHint: hint,
      ),
      CareMode.space => CareBoundaryScene(
        motionPreference: motion,
        onSignal: _handleSceneSignal,
        onExit: _handleSceneExit,
        onSafety: _openSafety,
        onCompleted: _completeScene,
        onInterrupted: (stepIndex) {
          _activeStepIndex = stepIndex.clamp(0, _lastStepIndex(CareMode.space));
        },
        initialStepIndex: CareBoundaryScene.clampStepIndex(index),
        resumeHint: hint,
      ),
      CareMode.physical => CareBodyScene.build(
        motionPreference: motion,
        onSignal: _handleSceneSignal,
        onExit: _handleSceneExit,
        onSafety: _openSafety,
        onCompleted: _completeScene,
        resumeStepId: hint == null ? null : CareBodyScene.stepIds[index],
        resumeHint: hint ?? CareBodyScene.defaultResumeHint,
      ),
    };
  }

  // -------------------------------------------------------------------------
  // Recovery landing — the named recoverable state after interruption.
  // -------------------------------------------------------------------------

  Widget _buildRecovery(CareSceneMotionPreference motion) {
    final mode = _interruptedMode;
    if (mode == null) {
      return _buildLanding(motion);
    }
    final name = _sceneDisplayName(mode);

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ExperienceColors.careBackdrop),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ExperienceSpacing.screenMargin,
            ExperienceSpacing.md,
            ExperienceSpacing.screenMargin,
            ExperienceSpacing.md,
          ),
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Spacer(),
                Center(
                  child: EmberOrb(size: 96, breathing: true, motion: motion),
                ),
                const SizedBox(height: ExperienceSpacing.lg),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: Semantics(
                    header: true,
                    child: Text(
                      'You were in the middle of $name.',
                      style: ExperienceType.title(ExperienceColors.careInk),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: ExperienceSpacing.sm),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(2),
                  child: Text(
                    'Nothing was recorded. Pick up where you paused, or let '
                    'the moment rest right here.',
                    style: ExperienceType.body(ExperienceColors.careInkSoft),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: ExperienceSpacing.lg),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(3),
                  child: _EmberButton(
                    label: 'Continue',
                    onPressed: _resumeInterruptedScene,
                  ),
                ),
                if (widget.onRequestCheckIn != null)
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(4),
                    child: TextButton(
                      onPressed: _requestCheckInOnToday,
                      child: Text(
                        'Check in on Today instead',
                        style: ExperienceType.label(ExperienceColors.emberSoft),
                      ),
                    ),
                  ),
                const Spacer(),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(6),
                  child: _LandingSafetyLine(onTap: _openSafety),
                ),
                const SizedBox(height: ExperienceSpacing.sm),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(5),
                  child: _LightPill(
                    label: 'Leave it here',
                    semanticsLabel:
                        'Leave it here. Nothing was recorded. Exit is '
                        'always available.',
                    onPressed: _leaveInterruptionHere,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Toolkit and completion assembly
  // -------------------------------------------------------------------------

  Widget _buildToolkit() {
    return CareToolkitExperience(
      onRitualCompleted: _handleRitualCompleted,
      onExit: () {
        ExperienceHaptics.pick();
        setState(() => _stage = _CareStage.landing);
      },
      onSafety: _openSafety,
      loopKind: widget.loopKind,
      memoryEvidence: widget.memoryEvidence,
      now: widget.now,
    );
  }

  Widget _buildCompletion(CareSceneMotionPreference motion) {
    final completion = _activeCompletion;
    if (completion == null) {
      return _buildLanding(motion);
    }
    return CareCompletionFlow(
      mode: _completionMode,
      completion: completion,
      careMemoryRepository: widget.careMemoryRepository,
      saveReceipt: widget.saveReceipt,
      // The saved page's single exit — exactly "Return to daylight".
      onLeaveCare: _leaveToDaylight,
      // Skip (and Android/system back): consume the completion and return
      // to the landing with zero writes. The unsaved check-back has no
      // daylight exit of its own.
      onSkip: _skipCompletionToLanding,
      onOpenSafety: _openSafety,
      motionPreference: motion,
      now: widget.now,
    );
  }
}

// ---------------------------------------------------------------------------
// Landing pieces — compact dark-world material for the doorway surface.
// ---------------------------------------------------------------------------

/// Local landing metrics and accents: tighter than the world's content
/// rhythm because the landing is a doorway, not a reading surface.
abstract final class _LandingMetrics {
  static const double doorGap = 10;
  static const double previewSize = 48;
  static const double previewRadius = 14;
  static const double tileRadius = 16;
  static const double tilePadding = 12;

  /// Phone grid rows are given an explicit height so the whole set can be
  /// composed to fit above the pinned footer. The compact content is built
  /// to sit comfortably inside this minimum.
  static const double compactRowHeight = 132;
  static const double maxRowHeight = 190;

  /// Estimated height of the everyday-care row, for first-viewport fitting.
  static const double cardEstimate = 60;

  /// Aubergine door fill — lifted just enough off the plum backdrop that
  /// the six doors read as one distinct set.
  static const Color doorFill = Color(0xFF241A2A);

  /// One controlled acid editorial accent: the fast-path marker and the
  /// small rule beneath the question. Never a fill, never a glow.
  static const Color fastPath = Color(0xFFD9FF63);
}

/// The landing header: a small held ember and the question, leading. No long
/// explanation stands between the person and the doors.
class _LandingHeader extends StatelessWidget {
  const _LandingHeader({required this.motion, this.entryLine});

  final CareSceneMotionPreference motion;
  final String? entryLine;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            // The held ember, resting small — the same ember from the ring.
            // Decorative; the semantics live on the headers below.
            EmberOrb(size: 20, breathing: true, motion: motion),
            const SizedBox(width: 10),
            Text(
              'CARE',
              style: ExperienceType.eyebrow(ExperienceColors.careInkFaint),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(
            'What feels closest\nright now?',
            style: ExperienceType.display(ExperienceColors.careInk),
          ),
        ),
        const SizedBox(height: 8),
        // The single acid mark on this surface: a short editorial rule
        // anchoring the question. Static, decorative.
        ExcludeSemantics(
          child: Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              color: _LandingMetrics.fastPath,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (entryLine != null) ...<Widget>[
          Text(
            entryLine!,
            style: ExperienceType.body(ExperienceColors.careInkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
        ],
        Text(
          'One scene at a time — leave whenever you need to.',
          style: ExperienceType.bodySmall(ExperienceColors.careInkSoft),
        ),
      ],
    );
  }
}

/// Compact phone: the five doors and the breathing fast path as one
/// broken grid — staggered widths so the set reads as composed, not
/// templated. Each row takes an explicit height — measured from its real
/// labels before paint — so the whole set sits fully above the pinned
/// footer when it can, and every label always renders in full.
class _PhoneDoorGrid extends StatelessWidget {
  const _PhoneDoorGrid({
    required this.doors,
    required this.breathing,
    required this.rowHeights,
  });

  /// The five mode doors, in [CareMode.values] order.
  final List<Widget> doors;
  final Widget breathing;

  /// One height per row: the fitted first-viewport height, grown per row
  /// to whatever its tallest door actually needs. Rows may differ once a
  /// longer label asks for the room.
  final List<double> rowHeights;

  @override
  Widget build(BuildContext context) {
    Widget row(
      double height,
      Widget left,
      int leftFlex,
      Widget right,
      int rightFlex,
    ) {
      return SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: _LandingMetrics.doorGap),
            Expanded(flex: rightFlex, child: right),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        row(rowHeights[0], doors[0], 5, doors[1], 4),
        const SizedBox(height: _LandingMetrics.doorGap),
        row(rowHeights[1], doors[2], 4, doors[3], 5),
        const SizedBox(height: _LandingMetrics.doorGap),
        // The last door shares its row with the glowing fast path — kept
        // beside the choices, never buried beneath them.
        row(rowHeights[2], doors[4], 4, breathing, 5),
      ],
    );
  }
}

/// Wide layouts: all six doors in two calm rows of three.
class _WideDoorGrid extends StatelessWidget {
  const _WideDoorGrid({required this.doors, required this.breathing});

  final List<Widget> doors;
  final Widget breathing;

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> children) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: _LandingMetrics.doorGap),
              Expanded(child: children[i]),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        row(doors.sublist(0, 3)),
        const SizedBox(height: _LandingMetrics.doorGap),
        row(<Widget>[doors[3], doors[4], breathing]),
      ],
    );
  }
}

/// One door: the mode's own words and a small distinctive preview echoing
/// its scene. [stacked] renders the compact vertical door used in the
/// wide grid; the horizontal row is the roomier single-column fallback for
/// narrow widths and large text. The label always wraps in full — a door
/// that cannot say its own name is no door at all.
class _ModeDoor extends StatelessWidget {
  const _ModeDoor({
    required this.mode,
    required this.descriptor,
    required this.stacked,
    required this.onTap,
  });

  final CareMode mode;
  final String descriptor;
  final bool stacked;
  final VoidCallback onTap;

  static const BorderRadius _radius = BorderRadius.all(
    Radius.circular(_LandingMetrics.tileRadius),
  );

  @override
  Widget build(BuildContext context) {
    final Widget content = stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: ExperienceColors.careInkFaint,
                  ),
                ],
              ),
              _ModePreview(mode: mode),
              const SizedBox(height: 10),
              Text(
                mode.label,
                style: ExperienceType.headline(ExperienceColors.careInk),
              ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _ModePreview(mode: mode),
              const SizedBox(width: ExperienceSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      mode.label,
                      style: ExperienceType.headline(ExperienceColors.careInk),
                    ),
                    const SizedBox(height: ExperienceSpacing.xs),
                    Text(
                      descriptor,
                      style: ExperienceType.bodySmall(
                        ExperienceColors.careInkSoft,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ExperienceSpacing.xs),
              const Icon(
                Icons.chevron_right,
                color: ExperienceColors.careInkFaint,
              ),
            ],
          );

    return Semantics(
      button: true,
      label: '${mode.label}. $descriptor',
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: ExperienceSpacing.minTouchTarget,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _LandingMetrics.doorFill,
            borderRadius: _radius,
            border: Border.all(color: ExperienceColors.careGlassBorder),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: _radius,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(_LandingMetrics.tilePadding),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The phone-grid door: the same identity as [_ModeDoor], recomposed for a
/// bounded row height — the preview rests slightly smaller and the chevron
/// overlays the corner instead of claiming a row. The label wraps in full;
/// the grid's row heights are measured from these labels before paint, so
/// the tile can neither overflow nor clip.
class _CompactModeDoor extends StatelessWidget {
  const _CompactModeDoor({
    required this.mode,
    required this.descriptor,
    required this.onTap,
  });

  final CareMode mode;
  final String descriptor;
  final VoidCallback onTap;

  static const BorderRadius _radius = BorderRadius.all(
    Radius.circular(_LandingMetrics.tileRadius),
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${mode.label}. $descriptor',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _LandingMetrics.doorFill,
          borderRadius: _radius,
          border: Border.all(color: ExperienceColors.careGlassBorder),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: _radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _ModePreview(mode: mode, size: 40),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            mode.label,
                            style: ExperienceType.headline(
                              ExperienceColors.careInk,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: ExperienceColors.careInkFaint,
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

/// The fast path: guided breathing, rendered beside the doors. Its
/// distinction is deliberate rather than a stuck selected state — the same
/// aubergine door body as the others, set apart by a warm ember edge, the
/// one soft glow permitted on this surface, and the small acid fast-path
/// marker. [stacked] is the wide-grid vertical variant; [compact] is the
/// bounded phone-grid variant; the default is the single-column row.
class _BreathingDoor extends StatelessWidget {
  const _BreathingDoor({
    this.stacked = false,
    this.compact = false,
    required this.onTap,
  });

  final bool stacked;
  final bool compact;
  final VoidCallback onTap;

  static const BorderRadius _radius = BorderRadius.all(
    Radius.circular(_LandingMetrics.tileRadius),
  );

  static const String _label = 'Breathe with me';
  static const String _caption = 'A guided rhythm — quick to start.';

  Widget _iconWell(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ExperienceColors.ember.withValues(alpha: 0.18),
      ),
      child: Icon(
        Icons.air_outlined,
        color: ExperienceColors.emberSoft,
        size: size * 0.45,
      ),
    );
  }

  Widget get _fastPathLine {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _LandingMetrics.fastPath,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _caption,
            style: ExperienceType.caption(ExperienceColors.careInkSoft),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  BoxDecoration get _decoration {
    return BoxDecoration(
      color: _LandingMetrics.doorFill,
      borderRadius: _radius,
      border: Border.all(
        color: ExperienceColors.ember.withValues(alpha: 0.55),
        width: 1.2,
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: ExperienceColors.emberGlow.withValues(alpha: 0.30),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (compact) {
      // Bounded by the measured phone-grid row: the grid keeps this variant
      // only while the label fits in two lines, so the cap cannot clip.
      content = Padding(
        padding: const EdgeInsets.all(10),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _iconWell(34),
                const SizedBox(height: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          _label,
                          style: ExperienceType.headline(
                            ExperienceColors.careInk,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Flexible(child: _fastPathLine),
                    ],
                  ),
                ),
              ],
            ),
            const Positioned(
              top: 0,
              right: 0,
              child: Icon(
                Icons.chevron_right,
                size: 16,
                color: ExperienceColors.emberSoft,
              ),
            ),
          ],
        ),
      );
    } else if (stacked) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Spacer(),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: ExperienceColors.emberSoft,
              ),
            ],
          ),
          _iconWell(44),
          const SizedBox(height: 10),
          Text(
            _label,
            style: ExperienceType.headline(ExperienceColors.careInk),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          _fastPathLine,
        ],
      );
    } else {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _iconWell(44),
          const SizedBox(width: ExperienceSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _label,
                  style: ExperienceType.headline(ExperienceColors.careInk),
                ),
                const SizedBox(height: ExperienceSpacing.xs),
                _fastPathLine,
              ],
            ),
          ),
          const SizedBox(width: ExperienceSpacing.xs),
          const Icon(Icons.chevron_right, color: ExperienceColors.emberSoft),
        ],
      );
    }

    final padded = compact
        ? content
        : Padding(
            padding: const EdgeInsets.all(_LandingMetrics.tilePadding),
            child: content,
          );

    return Semantics(
      button: true,
      label: 'Breathe with me. One guided rhythm, with nothing to count.',
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: ExperienceSpacing.minTouchTarget,
        ),
        child: DecoratedBox(
          decoration: _decoration,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('care-breathe-entry'),
              borderRadius: _radius,
              onTap: onTap,
              child: padded,
            ),
          ),
        ),
      ),
    );
  }
}

/// The small scene echo on each door. Static by design: orientation, not
/// stimulation — identical under reduced motion and the performance
/// escape hatch.
class _ModePreview extends StatelessWidget {
  const _ModePreview({
    required this.mode,
    this.size = _LandingMetrics.previewSize,
  });

  final CareMode mode;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(_LandingMetrics.previewRadius),
          border: Border.all(color: ExperienceColors.careGlassBorder),
        ),
        child: CustomPaint(painter: _ModePreviewPainter(mode)),
      ),
    );
  }
}

/// Compact preview motifs derived from the five original scenes:
/// coral pressure rings (Release), blue rain over a held weight (Heavy),
/// violet racing strands (Focus), a warm doorway (Space), amber bodily
/// warmth (Body).
class _ModePreviewPainter extends CustomPainter {
  const _ModePreviewPainter(this.mode);

  final CareMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    switch (mode) {
      case CareMode.explode:
        _paintRelease(canvas, size);
      case CareMode.heavy:
        _paintHeavy(canvas, size);
      case CareMode.racing:
        _paintRacing(canvas, size);
      case CareMode.space:
        _paintSpace(canvas, size);
      case CareMode.physical:
        _paintBody(canvas, size);
    }
  }

  /// Release — pressure rings around a held ember core.
  void _paintRelease(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, 5, Paint()..color = ExperienceColors.emberBright);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const radii = <double>[10, 15.5, 21];
    const alphas = <double>[0.85, 0.45, 0.22];
    for (var i = 0; i < radii.length; i++) {
      ring.color = ExperienceColors.ember.withValues(alpha: alphas[i]);
      canvas.drawCircle(center, radii[i], ring);
    }
  }

  /// Heavy — blue rain settling onto a low, held weight.
  void _paintHeavy(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final glowCenter = Offset(w / 2, h * 0.74);
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: <Color>[
              ExperienceColors.phaseFollicular.withValues(alpha: 0.7),
              ExperienceColors.phaseFollicular.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCenter(
              center: glowCenter,
              width: w * 0.95,
              height: h * 0.55,
            ),
          );
    canvas.drawOval(
      Rect.fromCenter(center: glowCenter, width: w * 0.95, height: h * 0.5),
      glow,
    );
    final rain = Paint()
      ..color = ExperienceColors.phaseFollicular.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final x = w * (0.24 + i * 0.17);
      final dropLength = i.isEven ? 10.0 : 7.0;
      canvas.drawLine(
        Offset(x, h * 0.14),
        Offset(x, h * 0.14 + dropLength),
        rain,
      );
    }
    canvas.drawCircle(
      Offset(w / 2, h * 0.7),
      4.5,
      Paint()..color = ExperienceColors.phaseFollicular,
    );
  }

  /// Focus — violet strands that slow as they descend.
  void _paintRacing(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strand = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const alphas = <double>[0.85, 0.55, 0.3];
    for (var row = 0; row < 3; row++) {
      final cy = h * (0.3 + row * 0.2);
      final path = Path()..moveTo(5, cy);
      for (var x = 5.0; x <= w - 5; x += 2) {
        final phase = (x / (w - 10)) * math.pi * 2.2 + row * 1.1;
        path.lineTo(x, cy + math.sin(phase) * 3.2);
      }
      strand.color = ExperienceColors.phaseLuteal.withValues(
        alpha: alphas[row],
      );
      canvas.drawPath(path, strand);
    }
  }

  /// Space — a warm doorway with a threshold line.
  void _paintSpace(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final left = w * 0.32;
    final right = w * 0.68;
    final top = h * 0.2;
    final bottom = h * 0.8;
    final archRadius = (right - left) / 2;
    final arch = Path()
      ..moveTo(left, bottom)
      ..lineTo(left, top + archRadius)
      ..arcToPoint(
        Offset(right, top + archRadius),
        radius: Radius.circular(archRadius),
      )
      ..lineTo(right, bottom);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          ExperienceColors.emberSoft.withValues(alpha: 0.5),
          ExperienceColors.emberSoft.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTRB(left, top, right, bottom));
    canvas
      ..save()
      ..clipPath(arch)
      ..drawRect(Rect.fromLTRB(left, top, right, bottom), glow)
      ..restore();
    canvas.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = ExperienceColors.emberSoft.withValues(alpha: 0.9),
    );
    canvas.drawLine(
      Offset(left - 5, bottom),
      Offset(right + 5, bottom),
      Paint()
        ..color = ExperienceColors.emberSoft.withValues(alpha: 0.45)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Body — amber warmth radiating from the body's core.
  void _paintBody(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h * 0.58);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          ExperienceColors.emberSoft.withValues(alpha: 0.95),
          ExperienceColors.accentGravity.withValues(alpha: 0.55),
          ExperienceColors.accentGravity.withValues(alpha: 0),
        ],
        stops: const <double>[0, 0.45, 1],
      ).createShader(Rect.fromCircle(center: center, radius: w * 0.42));
    canvas.drawCircle(center, w * 0.42, glow);
    canvas.drawCircle(
      center,
      4,
      Paint()..color = ExperienceColors.careInk.withValues(alpha: 0.85),
    );
    final tick = Paint()
      ..color = ExperienceColors.emberSoft.withValues(alpha: 0.6)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.38, h * 0.24),
      Offset(w * 0.38, h * 0.16),
      tick,
    );
    canvas.drawLine(
      Offset(w * 0.62, h * 0.24),
      Offset(w * 0.62, h * 0.16),
      tick,
    );
  }

  @override
  bool shouldRepaint(_ModePreviewPainter oldDelegate) {
    return oldDelegate.mode != mode;
  }
}

/// Everyday care: deliberately secondary — a quiet outline row, not another
/// glowing door.
class _EverydayCareCard extends StatelessWidget {
  const _EverydayCareCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          'Everyday care. Small guided rituals — warmth, rest, gentle '
          'movement.',
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: ExperienceSpacing.minTouchTarget,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: ExperienceRadius.chipRadius,
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: ExperienceRadius.chipRadius,
                border: Border.all(
                  color: ExperienceColors.careGlassBorder.withValues(
                    alpha: 0.55,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceSpacing.sm,
                vertical: 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const Icon(
                    Icons.spa_outlined,
                    color: ExperienceColors.careInkSoft,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Everyday care',
                          style: ExperienceType.label(ExperienceColors.careInk),
                        ),
                        Text(
                          'Small guided rituals for steadier days.',
                          style: ExperienceType.caption(
                            ExperienceColors.careInkSoft,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: ExperienceSpacing.xs),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: ExperienceColors.careInkFaint,
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

class _LandingMemoryLine extends StatelessWidget {
  const _LandingMemoryLine({
    required this.line,
    required this.dismissible,
    required this.onDismiss,
  });

  final String line;
  final bool dismissible;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: line,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ExperienceColors.careGlass,
          borderRadius: ExperienceRadius.chipRadius,
          border: Border.all(color: ExperienceColors.careGlassBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ExperienceSpacing.sm,
            vertical: 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const EmberOrb(size: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  line,
                  style: ExperienceType.bodySmall(ExperienceColors.careInk),
                ),
              ),
              if (dismissible) ...<Widget>[
                const SizedBox(width: ExperienceSpacing.xs),
                Semantics(
                  button: true,
                  label: 'Dismiss remembered help',
                  child: InkWell(
                    borderRadius: ExperienceRadius.chipRadius,
                    onTap: onDismiss,
                    child: const Padding(
                      padding: EdgeInsets.all(ExperienceSpacing.xs),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: ExperienceColors.careInkSoft,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingSafetyLine extends StatelessWidget {
  const _LandingSafetyLine({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: CareSceneFoundation.defaultSafetyLine,
      child: Center(
        child: InkWell(
          borderRadius: ExperienceRadius.chipRadius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: ExperienceSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.favorite_border,
                    size: 14,
                    color: ExperienceColors.careInkSoft,
                  ),
                  const SizedBox(width: ExperienceSpacing.xs),
                  Flexible(
                    child: Text(
                      CareSceneFoundation.defaultSafetyLine,
                      style: ExperienceType.caption(
                        ExperienceColors.careInkSoft,
                      ),
                      textAlign: TextAlign.center,
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

class _EmberButton extends StatelessWidget {
  const _EmberButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: ExperienceSpacing.degreeTarget,
        ),
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: ExperienceColors.emberGradient,
              borderRadius: ExperienceRadius.heroRadius,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: ExperienceColors.emberGlow.withValues(alpha: 0.55),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: ExperienceRadius.heroRadius,
                onTap: onPressed,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ExperienceSpacing.lg,
                    vertical: ExperienceSpacing.sm,
                  ),
                  child: Text(
                    label,
                    style: ExperienceType.label(Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LightPill extends StatelessWidget {
  const _LightPill({
    required this.label,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: ExperienceSpacing.minTouchTarget,
        ),
        child: Material(
          color: ExperienceColors.careInk,
          borderRadius: ExperienceRadius.heroRadius,
          child: InkWell(
            borderRadius: ExperienceRadius.heroRadius,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceSpacing.lg,
                vertical: ExperienceSpacing.sm,
              ),
              child: Text(
                label,
                style: ExperienceType.label(ExperienceColors.careSkyBottom),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
