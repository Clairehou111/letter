import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../domain/care_mode.dart';
import 'care_haptics.dart';
import 'care_safety_boundary_sheet.dart';
import 'care_sound_engine.dart';
import 'prototype_scene_painter.dart';

enum CareBreakStage { context, active, outcome }

enum PhysicalCareContext { cramps, nausea, headache, tension }

/// A finite, motion-first Care scene.
///
/// Selecting an emotional Care entrance opens its scene immediately. Physical
/// Care asks one short context question because that choice changes the motion.
/// Touches, lines, intensity, and the navigation result remain ephemeral.
class CareBreakFlow extends StatefulWidget {
  const CareBreakFlow({
    required this.mode,
    required this.onBack,
    required this.onLeaveCare,
    required this.onPracticalHelp,
    this.onCompleted,
    this.soundEngine,
    this.motionModel,
    super.key,
  });

  final CareMode mode;
  final VoidCallback onBack;
  final VoidCallback onLeaveCare;
  final VoidCallback onPracticalHelp;
  final VoidCallback? onCompleted;
  final CareSoundEngine? soundEngine;
  final PrototypeSceneModel? motionModel;

  @override
  State<CareBreakFlow> createState() => _CareBreakFlowState();
}

class _CareBreakFlowState extends State<CareBreakFlow>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _session;
  late final CareSoundEngine _sound;
  late CareBreakStage _stage;
  final List<Offset> _gestureTrail = [];
  late final PrototypeSceneModel _motionModel;

  PhysicalCareContext? _physicalContext;
  Offset? _touchPoint;
  Offset? _lastTouchPoint;
  double _gestureEnergy = 0;
  double _pointerTravel = 0;
  double _pointerSpeed = 0;
  double? _pointerStartedAt;
  double? _closeStartedAt;
  double _awayBoostSeconds = 0;
  bool _pressing = false;
  double _intensity = 0.6;
  bool _soundEnabled = false;
  bool _breath = false;
  Timer? _hapticTimer;
  double _lastHapticAt = 0;

  /// Minimum scene duration in seconds. "Stay longer" adds 60 s.
  double _sceneDuration = 90;

  /// True when the user explicitly chose "Enough", bypassing minimum dwell.
  bool _forcedClose = false;

  CareBreakVisuals get _visuals => CareBreakVisuals.forMode(widget.mode);

  @override
  void initState() {
    super.initState();
    _sound = widget.soundEngine ?? CareSoundEngine();
    _motionModel = widget.motionModel ?? PrototypeSceneModel();
    _stage = widget.mode == CareMode.physical
        ? CareBreakStage.context
        : CareBreakStage.active;
    WidgetsBinding.instance.addObserver(this);
    // Long ceiling so "Stay longer" can extend the scene without recreating
    // the controller. Completion is managed manually via _sceneDuration.
    _session =
        AnimationController(vsync: this, duration: const Duration(seconds: 600))
          ..addListener(_syncPrototypeAudio)
          ..addListener(_pumpHaptics)
          ..addListener(_checkSceneCompletion)
          ..addStatusListener((status) {
            // Explode runs indefinitely so the seal can be re-opened.
            if (status == AnimationStatus.completed &&
                widget.mode == CareMode.explode &&
                mounted) {
              _session.forward(from: 0);
            }
          });
    if (_stage == CareBreakStage.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _session.forward(from: 0);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_stage == CareBreakStage.active && !_session.isCompleted) {
        _session.forward();
      }
      return;
    }
    _session.stop();
    _sound.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.dispose();
    _sound.dispose();
    _hapticTimer?.cancel();
    CareHaptics.stop();
    super.dispose();
  }

  void _startPhysical(PhysicalCareContext context) {
    setState(() {
      _physicalContext = context;
      _stage = CareBreakStage.active;
    });
    _session.forward(from: 0);
  }

  void _recordGesture(Offset position, {required double movement}) {
    if (_stage != CareBreakStage.active || _isStill(context)) {
      return;
    }
    // Explode re-press: if the seal is closed but the scene hasn't ended,
    // tapping the sealed circle re-opens it so the user can keep releasing.
    if (widget.mode == CareMode.explode &&
        _closeStartedAt != null &&
        _closeProgress(widget.mode, _elapsedSeconds, _closeStartedAt!) >= 1) {
      _closeStartedAt = null;
      _gestureEnergy = 0;
      _motionModel.resetExplodeClose();
    }
    final prior = _lastTouchPoint;
    if (prior == null) {
      _pointerTravel = 0;
      _pointerStartedAt = _elapsedSeconds;
      _pressing = true;
      CareHaptics.arm();
    }
    final actualMovement = prior == null
        ? movement
        : math.max(movement, (position - prior).distance);
    _lastTouchPoint = position;
    _pointerSpeed = (actualMovement / 30).clamp(0.0, 1.0);
    _pointerTravel += actualMovement;
    final lastTrail = _gestureTrail.isEmpty ? null : _gestureTrail.last;
    if (lastTrail == null || (lastTrail - position).distance >= 7) {
      _gestureTrail.add(position);
      if (_gestureTrail.length > 36) {
        _gestureTrail.removeAt(0);
      }
    }
    _touchPoint = position;
    _gestureEnergy = math.min(1, _gestureEnergy + 0.018 + actualMovement / 720);
    setState(() {});
  }

  double get _spaceOutside {
    final currentBoost = _pressing && _pointerStartedAt != null
        ? (_elapsedSeconds - _pointerStartedAt!) * 2.2
        : 0.0;
    final shut = ((_elapsedSeconds + _awayBoostSeconds + currentBoost) / 12)
        .clamp(0.0, 1.0);
    final eased = Curves.easeInOutCubic.transform(shut);
    return math.pow(1 - eased, 1.25).toDouble();
  }

  void _syncPrototypeAudio() {
    if (!_soundEnabled || widget.mode != CareMode.space) return;
    unawaited(_sound.setOutside(_spaceOutside));
  }

  /// Per-scene haptic rhythm, throttled to avoid flooding the taptic engine.
  void _pumpHaptics() {
    if (_stage != CareBreakStage.active) return;
    final elapsed = _elapsedSeconds;
    final mode = widget.mode;

    double interval;
    switch (mode) {
      case CareMode.explode:
        if (!_pressing) return;
        // Faster buzz as pressure builds: 0.42s → 0.12s
        interval = 0.42 - _gestureEnergy * 0.3;
      case CareMode.heavy:
        interval = 3.2;
      case CareMode.racing:
        if (_touchPoint == null) return;
        // Quieter tick as strands calm: 0.5s → 3.0s
        interval = 0.5 + _motionModel.calm * 2.5;
      case CareMode.space:
        if (_pressing) {
          interval = 2.4;
        } else {
          return;
        }
      case CareMode.physical:
        interval = 7.0;
    }

    if (elapsed - _lastHapticAt < interval) return;
    _lastHapticAt = elapsed;

    switch (mode) {
      case CareMode.explode:
        CareHaptics.charge(_gestureEnergy, _intensity);
      case CareMode.heavy:
        CareHaptics.fall(_intensity);
      case CareMode.racing:
        CareHaptics.tick(_intensity);
      case CareMode.space:
        CareHaptics.enclose(_intensity);
      case CareMode.physical:
        CareHaptics.warmth(_intensity);
    }
  }

  void _releaseGesture() {
    final startedAt = _pointerStartedAt;
    final elapsed = _elapsedSeconds;
    if (widget.mode == CareMode.space && startedAt != null) {
      _awayBoostSeconds += math.max(0, elapsed - startedAt) * 2.2;
    }
    final tap = _pointerTravel < 12;
    final heldLongEnough = startedAt != null && elapsed - startedAt > 1 / 6;
    if (_closeStartedAt == null &&
        ((widget.mode == CareMode.explode && (tap || heldLongEnough)) ||
            (widget.mode == CareMode.racing &&
                (tap || _motionModel.calm >= 0.96)))) {
      _closeStartedAt = elapsed;
      if (widget.mode == CareMode.explode) {
        CareHaptics.burst(_intensity);
      } else if (widget.mode == CareMode.racing) {
        CareHaptics.settle(_intensity);
      }
    }
    _pressing = false;
    _pointerStartedAt = null;
    _lastTouchPoint = null;
    _pointerSpeed = 0;
    if (widget.mode != CareMode.space) {
      _touchPoint = null;
    }
    if (mounted) {
      setState(() {});
    }
  }

  double get _elapsedSeconds {
    // Scale from the 600 s controller value to actual elapsed seconds.
    return _session.value * 600;
  }

  /// Auto-complete the scene when its natural duration is reached.
  /// Explode never auto-completes — the seal stays tappable indefinitely so
  /// the user can re-open it and keep releasing.
  void _checkSceneCompletion() {
    if (_stage != CareBreakStage.active || _forcedClose) return;
    if (widget.mode == CareMode.explode) return;
    if (_elapsedSeconds >= _sceneDuration && mounted) {
      _finishScene();
    }
  }

  void _finishScene() {
    if (_stage == CareBreakStage.outcome) {
      return;
    }
    _session.stop();
    _sound.stop();
    CareHaptics.stop();
    setState(() {
      _stage = CareBreakStage.outcome;
      _soundEnabled = false;
      _touchPoint = null;
      _lastTouchPoint = null;
      _pressing = false;
      _forcedClose = false;
    });
  }

  /// Extend the scene by 60 seconds from the outcome stage.
  void _stayLonger() {
    if (_stage != CareBreakStage.outcome) return;
    _sceneDuration += 60;
    _resumeFromOverlay();
  }

  /// Dismiss the rest overlay without extending — just let the user look
  /// at the settled canvas. Matches the prototype's "stay a moment."
  void _stayMoment() {
    if (_stage != CareBreakStage.outcome) return;
    _resumeFromOverlay();
  }

  void _resumeFromOverlay() {
    _forcedClose = false;
    _closeStartedAt = null;
    _gestureEnergy = 0;
    _gestureTrail.clear();
    _lastHapticAt = _elapsedSeconds;
    setState(() {
      _stage = CareBreakStage.active;
      _touchPoint = null;
      _lastTouchPoint = null;
      _pressing = false;
    });
    _session.forward(from: _session.value);
  }

  /// Force-close the scene, bypassing the minimum dwell.
  /// For Explode this simply leaves — the seal is meant to be re-opened,
  /// not "completed."
  void _enough() {
    if (widget.mode == CareMode.explode) {
      _leave(widget.onCompleted ?? widget.onBack);
      return;
    }
    _forcedClose = true;
    _finishScene();
  }

  Future<void> _toggleSound() async {
    if (_soundEnabled) {
      setState(() => _soundEnabled = false);
      _sound.stop();
      return;
    }
    final started = await _sound.play(widget.mode, intensity: _intensity);
    if (!mounted) {
      return;
    }
    if (started) {
      if (widget.mode == CareMode.space) {
        await _sound.setOutside(_spaceOutside);
        if (!mounted) return;
      }
      setState(() => _soundEnabled = true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sound could not start. Check this tab or device volume, then restart the app.',
        ),
      ),
    );
  }

  void _setIntensity(double value) {
    setState(() => _intensity = value);
    if (_soundEnabled) unawaited(_sound.setIntensity(value));
  }

  void _leave(VoidCallback callback) {
    _session.stop();
    _sound.stop();
    callback();
  }

  bool _isStill(BuildContext context) {
    return MediaQuery.of(context).disableAnimations ||
        (widget.mode == CareMode.physical &&
            _physicalContext == PhysicalCareContext.headache);
  }

  Future<void> _openSafetyBoundary() async {
    final resumeScene = _stage == CareBreakStage.active && _session.isAnimating;
    if (resumeScene) {
      _session.stop();
    }
    await _sound.stop();
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: LetterColors.ink.withValues(alpha: 0.56),
      builder: (context) => CareSafetyBoundarySheet(
        kind: widget.mode.safetyKind,
        onLeaveCare: () {
          Navigator.of(context).pop();
          _leave(widget.onLeaveCare);
        },
      ),
    );
    if (mounted &&
        resumeScene &&
        _stage == CareBreakStage.active &&
        !_session.isCompleted) {
      _session.forward();
      if (_soundEnabled) {
        await _sound.play(widget.mode, intensity: _intensity);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final still = _isStill(context);
    if (still && _soundEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _soundEnabled) {
          _sound.stop();
          setState(() => _soundEnabled = false);
        }
      });
    }

    final header = _CareBreakHeader(
      onBack: () => _leave(widget.onBack),
      soundEnabled: _soundEnabled,
      soundAvailable: _stage == CareBreakStage.active && !still,
      onToggleSound: _toggleSound,
      foreground: _visuals.foreground,
    );
    final safety = _CareSafetyFooter(
      mode: widget.mode,
      foreground: _visuals.foreground,
      onPressed: _openSafetyBoundary,
    );
    final activeScene = _MotionStage(
      mode: widget.mode,
      motionModel: _motionModel,
      visuals: _visuals,
      session: _session,
      physicalContext: _physicalContext,
      touchPoint: _touchPoint,
      gestureEnergy: _gestureEnergy,
      pointerSpeed: _pointerSpeed,
      closeStartedAt: _closeStartedAt,
      pointerStartedAt: _pointerStartedAt,
      pressing: _pressing,
      awayBoostSeconds: _awayBoostSeconds,
      intensity: _intensity,
      still: still,
      breath: _breath,
      onPointer: _recordGesture,
      onPointerUp: _releaseGesture,
      onIntensity: _setIntensity,
      onEnough: _enough,
      onToggleBreath: () => setState(() => _breath = !_breath),
    );

    // The scene canvas stays visible behind the outcome overlay so "Stay
    // longer" replays the animation in place instead of navigating away.
    final showOverlay = _stage == CareBreakStage.outcome;

    return Scaffold(
      key: Key('care-break-${widget.mode.name}'),
      backgroundColor: _visuals.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: switch (_stage) {
              CareBreakStage.context => Column(
                children: [
                  header,
                  Expanded(
                    child: SingleChildScrollView(
                      key: const Key('care-break-context-scroll'),
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                      child: _PhysicalContextStage(
                        visuals: _visuals,
                        onSelected: _startPhysical,
                      ),
                    ),
                  ),
                  safety,
                ],
              ),
              CareBreakStage.active || CareBreakStage.outcome => Stack(
                fit: StackFit.expand,
                children: [
                  activeScene,
                  if (!showOverlay) ...[
                    Align(alignment: Alignment.topCenter, child: header),
                    Align(alignment: Alignment.bottomCenter, child: safety),
                  ],
                  if (showOverlay)
                    _RestOverlay(
                      visuals: _visuals,
                      mode: widget.mode,
                      onStayLonger: _stayLonger,
                      onStayMoment: _stayMoment,
                      onLeave: () =>
                          _leave(widget.onCompleted ?? widget.onBack),
                    ),
                ],
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _PhysicalContextStage extends StatelessWidget {
  const _PhysicalContextStage({
    required this.visuals,
    required this.onSelected,
  });

  final CareBreakVisuals visuals;
  final ValueChanged<PhysicalCareContext> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('care-break-context'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Where is it today?',
          style: TextStyle(
            color: visuals.foreground,
            fontFamily: 'Newsreader',
            fontSize: 34,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: LetterSpacing.sm),
        Text(
          'This only changes how the screen moves. It is not a diagnosis.',
          style: TextStyle(
            color: visuals.foreground.withValues(alpha: 0.62),
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: LetterSpacing.lg),
        _ContextButton(
          buttonKey: const Key('care-context-cramps'),
          title: 'Cramps or back pain',
          detail: 'A warm knot, softening',
          visuals: visuals,
          onPressed: () => onSelected(PhysicalCareContext.cramps),
        ),
        const SizedBox(height: LetterSpacing.sm),
        _ContextButton(
          buttonKey: const Key('care-context-nausea'),
          title: 'Nausea or bloating',
          detail: 'Disturbed water, settling flat',
          visuals: visuals,
          onPressed: () => onSelected(PhysicalCareContext.nausea),
        ),
        const SizedBox(height: LetterSpacing.sm),
        _ContextButton(
          buttonKey: const Key('care-context-headache'),
          title: 'Headache or migraine',
          detail: 'Quiet, dim, and motionless',
          visuals: visuals,
          onPressed: () => onSelected(PhysicalCareContext.headache),
        ),
        const SizedBox(height: LetterSpacing.sm),
        _ContextButton(
          buttonKey: const Key('care-context-tension'),
          title: 'General tension',
          detail: 'Warm rings widening into one line',
          visuals: visuals,
          onPressed: () => onSelected(PhysicalCareContext.tension),
        ),
      ],
    );
  }
}

class _ContextButton extends StatelessWidget {
  const _ContextButton({
    required this.buttonKey,
    required this.title,
    required this.detail,
    required this.visuals,
    required this.onPressed,
  });

  final Key buttonKey;
  final String title;
  final String detail;
  final CareBreakVisuals visuals;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: buttonKey,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(68),
        alignment: Alignment.centerLeft,
        foregroundColor: visuals.foreground,
        backgroundColor: visuals.foreground.withValues(alpha: 0.045),
        side: BorderSide(color: visuals.foreground.withValues(alpha: 0.17)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(
            detail,
            style: TextStyle(
              color: visuals.foreground.withValues(alpha: 0.52),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MotionStage extends StatelessWidget {
  const _MotionStage({
    required this.mode,
    required this.motionModel,
    required this.visuals,
    required this.session,
    required this.physicalContext,
    required this.touchPoint,
    required this.gestureEnergy,
    required this.pointerSpeed,
    required this.closeStartedAt,
    required this.pointerStartedAt,
    required this.pressing,
    required this.awayBoostSeconds,
    required this.intensity,
    required this.still,
    required this.breath,
    required this.onPointer,
    required this.onPointerUp,
    required this.onIntensity,
    required this.onEnough,
    required this.onToggleBreath,
  });

  final CareMode mode;
  final PrototypeSceneModel motionModel;
  final CareBreakVisuals visuals;
  final Animation<double> session;
  final PhysicalCareContext? physicalContext;
  final Offset? touchPoint;
  final double gestureEnergy;
  final double pointerSpeed;
  final double? closeStartedAt;
  final double? pointerStartedAt;
  final bool pressing;
  final double awayBoostSeconds;
  final double intensity;
  final bool still;
  final bool breath;
  final void Function(Offset position, {required double movement}) onPointer;
  final VoidCallback onPointerUp;
  final ValueChanged<double> onIntensity;
  final VoidCallback onEnough;
  final VoidCallback onToggleBreath;

  @override
  Widget build(BuildContext context) {
    final lines = _motionLines(mode, physicalContext);
    return Semantics(
      button: true,
      label: still ? visuals.settledSemantics : visuals.activeSemantics,
      hint: still
          ? 'Double tap when you are ready to check the moment'
          : _motionGuide(mode, physicalContext),
      onTap: onEnough,
      excludeSemantics: true,
      child: Listener(
        key: Key('care-break-surface-${mode.name}'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: still
            ? null
            : (event) => onPointer(event.localPosition, movement: 0),
        onPointerMove: still
            ? null
            : (event) => onPointer(
                event.localPosition,
                movement: event.delta.distance,
              ),
        onPointerUp: still ? null : (_) => onPointerUp(),
        onPointerCancel: still ? null : (_) => onPointerUp(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: session,
                builder: (context, _) {
                  final elapsed = _elapsedForSession(session);
                  final close = _closeProgress(mode, elapsed, closeStartedAt);
                  final sceneEnergy = mode == CareMode.racing
                      ? motionModel.calm
                      : gestureEnergy;
                  return CustomPaint(
                    painter: PrototypeScenePainter(
                      model: motionModel,
                      mode: mode,
                      progress: still
                          ? 1
                          : _sceneProgress(
                              mode,
                              elapsed,
                              close,
                              sceneEnergy,
                              pressing: pressing,
                              pointerStartedAt: pointerStartedAt,
                              awayBoostSeconds: awayBoostSeconds,
                            ),
                      elapsedSeconds: elapsed,
                      closeProgress: close,
                      touchPoint: touchPoint,
                      pointerSpeed: pointerSpeed,
                      visuals: visuals,
                      physicalContext: physicalContext,
                      pressing: pressing,
                      intensity: intensity,
                      still: still,
                      breath: breath,
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 26,
              right: 26,
              top: MediaQuery.sizeOf(context).height * 0.26,
              child: AnimatedBuilder(
                animation: session,
                builder: (context, _) => _MotionLine(
                  elapsedSeconds: _elapsedForSession(session),
                  lines: lines,
                  color: visuals.foreground,
                  glow: visuals.glow,
                  reducedMotion: still,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                // Keep the scene controls above the persistent safety footer.
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 100),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      visuals.background.withValues(alpha: 0),
                      visuals.background.withValues(alpha: 0.85),
                      visuals.background,
                    ],
                    stops: const [0, 0.35, 1],
                  ),
                ),
                child: Column(
                  children: [
                    if (!still) ...[
                      Row(
                        children: [
                          Text(
                            'INTENSITY',
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              color: visuals.foreground.withValues(alpha: 0.45),
                              fontSize: 9,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _intensityLabel(intensity).toUpperCase(),
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              color: visuals.foreground.withValues(alpha: 0.45),
                              fontSize: 9,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 28,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: visuals.glow,
                            inactiveTrackColor: visuals.foreground.withValues(
                              alpha: 0.17,
                            ),
                            thumbColor: visuals.glow,
                            overlayColor: visuals.glow.withValues(alpha: 0.1),
                            trackHeight: 1.5,
                          ),
                          child: Slider(
                            key: const Key('care-motion-intensity'),
                            value: intensity,
                            onChanged: onIntensity,
                          ),
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        OutlinedButton(
                          key: const Key('care-break-complete'),
                          onPressed: onEnough,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(88, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            foregroundColor: visuals.foreground,
                            side: BorderSide(
                              color: visuals.foreground.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Text(
                            mode == CareMode.explode ? 'Leave' : 'Enough',
                            textScaler: TextScaler.noScaling,
                          ),
                        ),
                        if (mode == CareMode.heavy)
                          OutlinedButton(
                            key: const Key('care-breath-toggle'),
                            onPressed: onToggleBreath,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(88, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              foregroundColor: visuals.foreground.withValues(
                                alpha: breath ? 0.85 : 0.55,
                              ),
                              side: BorderSide(
                                color: visuals.foreground.withValues(
                                  alpha: breath ? 0.3 : 0.18,
                                ),
                              ),
                            ),
                            child: Text(
                              breath ? 'breath: on' : 'offer a breath',
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        const Spacer(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _elapsedForSession(Animation<double> session) {
  // Scale from the 600 s controller value to actual elapsed seconds.
  return session.value * 600;
}

double _closeProgress(CareMode mode, double elapsed, double? closeStartedAt) {
  if (closeStartedAt == null) return 0;
  final duration = mode == CareMode.explode ? 2.4 : 2.2;
  return ((elapsed - closeStartedAt) / duration).clamp(0.0, 1.0);
}

double _sceneProgress(
  CareMode mode,
  double elapsed,
  double close,
  double gestureEnergy, {
  required bool pressing,
  required double? pointerStartedAt,
  required double awayBoostSeconds,
}) {
  const span = 90.0;
  return switch (mode) {
    CareMode.explode =>
      close > 0
          ? close
          : math.min(
              1,
              math.max(
                gestureEnergy,
                pressing && pointerStartedAt != null
                    ? (elapsed - pointerStartedAt) * 0.72
                    : 0,
              ),
            ),
    CareMode.heavy => (elapsed / span).clamp(0.0, 1.0),
    CareMode.racing => close > 0 ? close : gestureEnergy.clamp(0.0, 1.0),
    CareMode.space =>
      ((elapsed +
                  awayBoostSeconds +
                  (pressing && pointerStartedAt != null
                      ? (elapsed - pointerStartedAt) * 2.2
                      : 0)) /
              12)
          .clamp(0.0, 1.0),
    CareMode.physical => (elapsed / span).clamp(0.0, 1.0),
  };
}

class _MotionLine extends StatelessWidget {
  const _MotionLine({
    required this.elapsedSeconds,
    required this.lines,
    required this.color,
    required this.glow,
    required this.reducedMotion,
  });

  final double elapsedSeconds;
  final List<String> lines;
  final Color color;
  final Color glow;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }
    if (reducedMotion) {
      return Text(
        lines.first,
        key: const Key('care-motion-line'),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color.withValues(alpha: 0.82),
          fontFamily: 'Newsreader',
          fontSize: 25,
          height: 1.08,
        ),
      );
    }

    const lineCycle = 10.0;
    const lineDuration = 8.5;
    final index = (elapsedSeconds / lineCycle).floor();
    if (index >= lines.length) {
      return const SizedBox.shrink();
    }
    final withinCycle = elapsedSeconds - index * lineCycle;
    if (withinCycle >= lineDuration) {
      return const SizedBox.shrink();
    }
    final local = (withinCycle / lineDuration).clamp(0.0, 1.0);
    final entering = Curves.easeOutCubic.transform((local / 0.16).clamp(0, 1));
    final leaving = local < 0.74
        ? 1.0
        : 1 - Curves.easeInCubic.transform(((local - 0.74) / 0.26).clamp(0, 1));
    final opacity = math.min(entering, leaving).clamp(0.0, 1.0);
    final blur = local < 0.16
        ? 10 * (1 - entering)
        : local > 0.74
        ? 8 * (1 - leaving)
        : 0.0;
    final y = local < 0.16
        ? 10 * (1 - entering)
        : local > 0.74
        ? -8 * (1 - leaving)
        : 0.0;
    final spacing = local < 0.16
        ? 2.8 * (1 - entering)
        : local > 0.74
        ? 1.5 * (1 - leaving)
        : 0.1;

    return Transform.translate(
      offset: Offset(0, y),
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Opacity(
          opacity: opacity,
          child: Text(
            lines[index],
            key: const Key('care-motion-line'),
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: color.withValues(alpha: 0.88),
              fontFamily: 'Newsreader',
              fontSize: 25,
              height: 1.08,
              letterSpacing: spacing,
              shadows: [
                Shadow(color: glow.withValues(alpha: 0.3), blurRadius: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Semi-transparent overlay shown on top of the settled animation canvas.
/// Mirrors the prototype's minimal rest card: settled message + 3 buttons.
class _RestOverlay extends StatelessWidget {
  const _RestOverlay({
    required this.visuals,
    required this.mode,
    required this.onStayLonger,
    required this.onStayMoment,
    required this.onLeave,
  });

  final CareBreakVisuals visuals;
  final CareMode mode;
  final VoidCallback onStayLonger;
  final VoidCallback onStayMoment;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dimmed backdrop with blur — the canvas stays visible behind.
        Positioned.fill(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(color: visuals.background.withValues(alpha: 0.68)),
          ),
        ),
        // Minimal rest card centered.
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  visuals.settledTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: visuals.foreground,
                    fontFamily: 'Newsreader',
                    fontSize: 28,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  visuals.settledCue,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: visuals.foreground.withValues(alpha: 0.64),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                // Finish the activity or remain with the settled scene.
                OutlinedButton(
                  key: const Key('care-rest-leave'),
                  onPressed: onLeave,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: visuals.foreground.withValues(alpha: 0.8),
                    side: BorderSide(
                      color: visuals.foreground.withValues(alpha: 0.22),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                  ),
                  child: const Text(
                    'Finish and check in',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(fontSize: 13, letterSpacing: 0.8),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  key: const Key('care-stay-longer'),
                  onPressed: onStayLonger,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: visuals.foreground.withValues(alpha: 0.68),
                    side: BorderSide(
                      color: visuals.foreground.withValues(alpha: 0.17),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                  ),
                  child: const Text(
                    'stay longer',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(fontSize: 13, letterSpacing: 0.8),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  key: const Key('care-stay-moment'),
                  onPressed: onStayMoment,
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: visuals.foreground.withValues(alpha: 0.5),
                  ),
                  child: const Text(
                    'stay a moment',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(fontSize: 12, letterSpacing: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Dismiss button at top-right.
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            key: const Key('care-rest-dismiss'),
            onPressed: onLeave,
            icon: Icon(Icons.close_rounded, size: 22),
            color: visuals.foreground.withValues(alpha: 0.5),
            tooltip: 'Finish and check in',
          ),
        ),
      ],
    );
  }
}

class _CareBreakHeader extends StatelessWidget {
  const _CareBreakHeader({
    required this.onBack,
    required this.soundEnabled,
    required this.soundAvailable,
    required this.onToggleSound,
    required this.foreground,
  });

  final VoidCallback onBack;
  final bool soundEnabled;
  final bool soundAvailable;
  final VoidCallback onToggleSound;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            OutlinedButton(
              key: const Key('care-break-back'),
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: foreground.withValues(alpha: 0.72),
                backgroundColor: Colors.black.withValues(alpha: 0.18),
                side: BorderSide(color: foreground.withValues(alpha: 0.18)),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('BACK', textScaler: TextScaler.noScaling),
            ),
            const Spacer(),
            if (soundAvailable)
              Semantics(
                button: true,
                toggled: soundEnabled,
                label: soundEnabled ? 'Turn sound off' : 'Turn sound on',
                child: IconButton.outlined(
                  key: const Key('care-break-sound'),
                  onPressed: onToggleSound,
                  tooltip: soundEnabled ? 'Turn sound off' : 'Turn sound on',
                  color: foreground.withValues(alpha: 0.86),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.18),
                    minimumSize: const Size(48, 48),
                    side: BorderSide(color: foreground.withValues(alpha: 0.18)),
                  ),
                  icon: Icon(
                    soundEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                  ),
                ),
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _CareSafetyFooter extends StatelessWidget {
  const _CareSafetyFooter({
    required this.mode,
    required this.foreground,
    required this.onPressed,
  });

  final CareMode mode;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final physical = mode.safetyKind == CareSafetyKind.physical;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        border: Border(
          top: BorderSide(color: foreground.withValues(alpha: 0.12)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 5, 18, 8),
          child: TextButton.icon(
            key: const Key('care-break-safety'),
            onPressed: onPressed,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: foreground.withValues(alpha: 0.84),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LetterRadius.control),
              ),
            ),
            icon: Icon(
              physical
                  ? Icons.medical_services_outlined
                  : Icons.shield_outlined,
              size: 19,
            ),
            label: Text(
              physical ? 'This feels unusual or severe' : 'I may not be safe',
              textScaler: TextScaler.noScaling,
            ),
          ),
        ),
      ),
    );
  }
}

String _intensityLabel(double value) {
  if (value < 0.2) return 'barely there';
  if (value < 0.45) return 'gentle';
  if (value < 0.7) return 'present';
  if (value < 0.9) return 'strong';
  return 'full';
}

String _motionGuide(
  CareMode mode,
  PhysicalCareContext? physicalContext,
) => switch (mode) {
  CareMode.explode =>
    "Hold, or just tap once. It won't blow apart — it closes.",
  CareMode.heavy => 'Nothing to do. It falls on its own, and it thins out.',
  CareMode.racing =>
    'Comb across with one finger, or tap once to gather it all.',
  CareMode.space =>
    'The door swings shut on the loud room. Press anywhere to lean into it.',
  CareMode.physical => switch (physicalContext) {
    PhysicalCareContext.headache =>
      'No motion to follow. The screen stays quiet.',
    _ => 'No breathing to keep up with. The warmth does the work.',
  },
};

List<String> _motionLines(
  CareMode mode,
  PhysicalCareContext? physicalContext,
) => switch (mode) {
  CareMode.explode => const [
    'you are not too much.',
    'the pressure is real. it came from somewhere.',
    'nothing you feel right now has to be let out on anyone.',
    'it can be held instead. sealed, not spilled.',
    "you're still here. that's the whole ask.",
  ],
  CareMode.heavy => const [
    'crying is fine here.',
    'this is not you failing.',
    "you don't have to hold it up for the next minute.",
    'it gets lighter without you managing it.',
    "when you're ready: cold water on your skin, shoulders lowering, one step at a time.",
  ],
  CareMode.racing => const [
    "your mind isn't broken. it's loud.",
    "you don't have to answer every thought that arrives.",
    'they can all wait in one line.',
    'one line. and then a full stop.',
  ],
  CareMode.space => const [
    "you're allowed to need this.",
    'the noise stays out there.',
    'latched. no explanation given.',
    'no one out there needs you right now.',
    'stay on this side as long as you like.',
  ],
  CareMode.physical => const [
    'this is your body, not your weakness.',
    'it hurts and that is enough reason to stop.',
    'warmth, quiet, and lower shoulders.',
    'this was always allowed. nothing to make up for.',
  ],
};

@immutable
// Kept beside the prototype motion constants for reference; the UI intentionally
// renders only `_MotionLine` so state labels never compete with the motion.
// ignore: unused_element
class _MotionCueData {
  const _MotionCueData(this.label, this.hint);

  final String label;
  final String hint;
}

// ignore: unused_element
_MotionCueData _motionCue(
  CareMode mode,
  PhysicalCareContext? physicalContext,
  double progress,
  double gestureEnergy, {
  required double closeProgress,
  required bool pressing,
}) => switch (mode) {
  CareMode.explode =>
    closeProgress >= 1
        ? const _MotionCueData(
            'sealed, and breathing',
            'press again if there is more. it holds either way.',
          )
        : closeProgress > 0
        ? const _MotionCueData('pulling it in', 'no explosion. it gets held.')
        : pressing
        ? const _MotionCueData(
            'pressure rising',
            'nothing here needs you to be pleasant',
          )
        : gestureEnergy > 0.05
        ? const _MotionCueData(
            'let go when you want',
            'it gets pulled in and sealed',
          )
        : const _MotionCueData(
            'hold, or tap once',
            "it won't blow apart — it gets pulled in and sealed",
          ),
  CareMode.heavy =>
    progress > 0.72
        ? const _MotionCueData('almost quiet', 'one light is staying')
        : progress > 0.3
        ? const _MotionCueData('it is thinning out', 'nothing to press')
        : const _MotionCueData('crying is fine here', 'it falls without you'),
  CareMode.racing =>
    closeProgress >= 1
        ? const _MotionCueData(
            'one line, holding',
            'they can all wait here. nothing is queueing up.',
          )
        : closeProgress > 0
        ? const _MotionCueData('gathering it into one line', '')
        : gestureEnergy > 0.2
        ? const _MotionCueData(
            'combing them straight',
            'slow or fast is fine — nothing resets',
          )
        : const _MotionCueData(
            'comb across, or tap once',
            'slow or fast is fine — nothing resets',
          ),
  CareMode.space =>
    progress >= 1
        ? const _MotionCueData(
            'this side of the door',
            'no one out there needs you right now.',
          )
        : progress >= 0.85
        ? const _MotionCueData(
            'almost shut',
            'it closes on its own — press anywhere to lean into it.',
          )
        : progress >= 0.3
        ? const _MotionCueData(
            'the noise is getting thinner',
            'it closes on its own — press anywhere to lean into it.',
          )
        : gestureEnergy > 0.1
        ? const _MotionCueData(
            'leaning into the door',
            'it closes on its own — press anywhere to lean into it.',
          )
        : const _MotionCueData(
            'the room out there, still loud',
            'it closes on its own — press anywhere to lean into it.',
          ),
  CareMode.physical => switch (physicalContext) {
    PhysicalCareContext.nausea =>
      progress > 0.85
          ? const _MotionCueData('flat and level', 'nothing to keep up with')
          : const _MotionCueData('the water is settling', 'let it flatten out'),
    PhysicalCareContext.headache => const _MotionCueData(
      'still, and dim',
      'no light is moving',
    ),
    PhysicalCareContext.cramps =>
      progress > 0.85
          ? const _MotionCueData('soft and warm', 'comfort is enough')
          : const _MotionCueData('the knot is loosening', 'heat, and no plan'),
    _ =>
      progress > 0.85
          ? const _MotionCueData('one resting line', 'nothing to earn back')
          : const _MotionCueData(
              'widening out',
              'lower shoulders if they want to lower',
            ),
  },
};

@immutable
class CareBreakVisuals {
  const CareBreakVisuals({
    required this.background,
    required this.foreground,
    required this.accent,
    required this.accentForeground,
    required this.secondary,
    required this.glow,
    required this.settledTitle,
    required this.settledCue,
    required this.activeSemantics,
    required this.settledSemantics,
  });

  factory CareBreakVisuals.forMode(CareMode mode) => switch (mode) {
    CareMode.explode => const CareBreakVisuals(
      background: Color(0xFF1A0806),
      foreground: Color(0xFFF3EDE5),
      accent: Color(0xFFFF5A36),
      accentForeground: Colors.white,
      secondary: Color(0xFFC23220),
      glow: Color(0xFFFFD166),
      settledTitle: 'Sealed. Nothing broke.',
      settledCue: 'Press again if there is more. It holds either way.',
      activeSemantics: 'Luminous pressure rings gathering into a seal',
      settledSemantics: 'Pressure closed inside one resting seal',
    ),
    CareMode.heavy => const CareBreakVisuals(
      background: Color(0xFF070C14),
      foreground: Color(0xFFF3EDE5),
      accent: Color(0xFF8FB3D9),
      accentForeground: Color(0xFF101A25),
      secondary: Color(0xFF4B6B96),
      glow: Color(0xFFFFD9A8),
      settledTitle: 'One steady light left.',
      settledCue: 'You did not have to manage the rain.',
      activeSemantics: 'Blue rain thinning around one warm light',
      settledSemantics: 'Rain ended with one steady light',
    ),
    CareMode.racing => const CareBreakVisuals(
      background: Color(0xFF0A0910),
      foreground: Color(0xFFF3EDE5),
      accent: Color(0xFFA99CF0),
      accentForeground: Color(0xFF171226),
      secondary: Color(0xFF66559E),
      glow: Color(0xFFE6E1FF),
      settledTitle: 'One line. Full stop.',
      settledCue: 'The rest can wait outside this minute.',
      activeSemantics: 'Tangled luminous strands becoming one line',
      settledSemantics: 'Thought strands gathered into one line and period',
    ),
    CareMode.space => const CareBreakVisuals(
      background: Color(0xFF0B0A0D),
      foreground: Color(0xFFF3EDE5),
      accent: Color(0xFFFFD0A0),
      accentForeground: Color(0xFF2B1B13),
      secondary: Color(0xFF8A5C46),
      glow: Color(0xFFFFD0A0),
      settledTitle: 'Shut and latched.',
      settledCue: 'The loud room is still there. It is not yours right now.',
      activeSemantics: 'A door closing on a bright crowded room',
      settledSemantics: 'Closed door with a quiet lamp on this side',
    ),
    CareMode.physical => const CareBreakVisuals(
      background: Color(0xFF140D06),
      foreground: Color(0xFFF3EDE5),
      accent: Color(0xFFE8A34A),
      accentForeground: Color(0xFF2D211A),
      secondary: Color(0xFF9A6330),
      glow: Color(0xFFFFE0AB),
      settledTitle: 'Warm and broad. Resting.',
      settledCue: 'Comfort first. You do not need to explain it.',
      activeSemantics: 'Warm material becoming broad and quiet',
      settledSemantics: 'Warm material resting without movement',
    ),
  };

  final Color background;
  final Color foreground;
  final Color accent;
  final Color accentForeground;
  final Color secondary;
  final Color glow;
  final String settledTitle;
  final String settledCue;
  final String activeSemantics;
  final String settledSemantics;
}

class CareBreakPainter extends CustomPainter {
  const CareBreakPainter({
    required this.mode,
    required this.progress,
    required this.touchPoint,
    required this.visuals,
    this.elapsedSeconds = 0,
    this.sceneSpanSeconds = 90,
    this.closeProgress = 0,
    this.physicalContext,
    this.gestureTrail = const [],
    this.gestureEnergy = 0,
    this.pressing = false,
    this.pointerStartedAt,
    this.awayBoostSeconds = 0,
    this.intensity = 0.6,
    this.still = false,
  });

  final CareMode mode;
  final double progress;
  final double elapsedSeconds;
  final double sceneSpanSeconds;
  final double closeProgress;
  final Offset? touchPoint;
  final CareBreakVisuals visuals;
  final PhysicalCareContext? physicalContext;
  final List<Offset> gestureTrail;
  final double gestureEnergy;
  final bool pressing;
  final double? pointerStartedAt;
  final double awayBoostSeconds;
  final double intensity;
  final bool still;

  double get _energy => 0.35 + intensity * 0.65;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = visuals.background);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    switch (mode) {
      case CareMode.explode:
        _paintPressureSeal(canvas, size);
      case CareMode.heavy:
        _paintFallingWeight(canvas, size);
      case CareMode.racing:
        _paintThoughtStrands(canvas, size);
      case CareMode.space:
        _paintClosingDoor(canvas, size);
      case CareMode.physical:
        _paintPhysical(canvas, size);
    }
    if (!still) {
      _paintGestureTrail(canvas);
    }
    canvas.restore();
  }

  void _paintGestureTrail(Canvas canvas) {
    if (gestureTrail.length < 2) return;
    final path = Path()..moveTo(gestureTrail.first.dx, gestureTrail.first.dy);
    for (var index = 1; index < gestureTrail.length; index++) {
      final previous = gestureTrail[index - 1];
      final current = gestureTrail[index];
      path.quadraticBezierTo(
        previous.dx,
        previous.dy,
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30
        ..strokeCap = StrokeCap.round
        ..color = visuals.glow.withValues(alpha: 0.045 + gestureEnergy * 0.05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  void _paintPressureSeal(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pressure = closeProgress > 0
        ? 1.0
        : math.max(
            gestureEnergy,
            pressing && pointerStartedAt != null
                ? ((elapsedSeconds - pointerStartedAt!) * 0.72).clamp(0.0, 1.0)
                : 0,
          );
    final closing = 1 - math.pow(1 - closeProgress, 3).toDouble();
    final sealed = closeProgress >= 1;
    final breathe = sealed ? 0.5 + 0.5 * math.sin(elapsedSeconds * 0.42) : 0.0;
    final shake = still || closeProgress > 0 ? 0.0 : pressure * 6 * _energy;
    for (var index = 0; index < (sealed ? 3 : 5); index++) {
      final baseRadius = sealed
          ? size.shortestSide * 0.1 * (1.25 + index * 0.4 + breathe * 0.16)
          : 60 +
                index * 34 +
                math.sin(elapsedSeconds * (2 + pressure * 8) + index) *
                    (6 + pressure * 22 * _energy);
      final radius = sealed
          ? baseRadius
          : size.shortestSide * 0.1 +
                (baseRadius - size.shortestSide * 0.1) * (1 - closing);
      final shift = Offset(
        math.sin(elapsedSeconds * 30 + index) * shake,
        math.cos(elapsedSeconds * 27 + index) * shake,
      );
      canvas.drawCircle(
        center + shift,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sealed ? 1.2 : 1.5 + pressure * 4 * _energy
          ..color = (index.isEven ? visuals.accent : visuals.glow).withValues(
            alpha: sealed
                ? 0.1 * (1 - index * 0.25) * _energy
                : (0.14 + pressure * 0.5) * _energy * (1 - closeProgress),
          ),
      );
    }
    final coreRadius = sealed
        ? size.shortestSide * 0.1
        : (70 + pressure * 90 * _energy) * (1 - closing) +
              size.shortestSide * 0.1 * closing;
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            visuals.glow.withValues(
              alpha: sealed ? 0.08 : (0.25 + pressure * 0.6) * _energy,
            ),
            visuals.accent.withValues(alpha: sealed ? 0.12 : 0.2 * _energy),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: coreRadius)),
    );
    for (
      var index = 0;
      index < (closeProgress > 0 && closeProgress < 1 ? 120 : 0);
      index++
    ) {
      final angle = index * 2.399;
      final startRadius = 40 + ((index * 47) % 300).toDouble();
      final sealRadius = size.shortestSide * 0.1;
      final radius = startRadius + (sealRadius - startRadius) * closing;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(
        point,
        0.8 + index % 3,
        Paint()
          ..color = (index.isEven ? visuals.glow : visuals.accent).withValues(
            alpha: (0.25 + 0.5 * (1 - closeProgress)) * _energy,
          ),
      );
    }
    if (closing > 0.05 || sealed) {
      final sealRadius = size.shortestSide * 0.1;
      canvas.drawCircle(
        center,
        sealRadius,
        Paint()..color = const Color(0xFF120504).withValues(alpha: closing),
      );
      canvas.drawCircle(
        center,
        sealRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = visuals.glow.withValues(alpha: closing * 0.7),
      );
    }
  }

  void _paintFallingWeight(Canvas canvas, Size size) {
    final p = (elapsedSeconds / sceneSpanSeconds).clamp(0.0, 1.0);
    final live = math.max(1, (40 * (1 - p * 0.97)).round());
    final flow = 1 - p * 0.85;
    final lower = Rect.fromLTWH(
      0,
      size.height * 0.2,
      size.width,
      size.height * 0.8,
    );
    canvas.drawRect(
      lower,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            visuals.secondary.withValues(alpha: 0.38 * (1 - p * 0.55)),
          ],
        ).createShader(lower),
    );
    for (var index = 0; index < live; index++) {
      final x = size.width * (((index * 37) % 101) / 100);
      final seed = ((index * 23) % 97) / 97;
      final velocity = 0.055 + ((index * 17) % 100) / 100 * 0.16;
      final y = size.height * ((seed + elapsedSeconds * velocity * flow) % 1.2);
      final length = (30 + index % 7 * 17) * (0.25 + flow * 0.75);
      canvas.drawLine(
        Offset(x, y - length),
        Offset(x, y),
        Paint()
          ..strokeWidth = 1 + index % 3 * 0.7
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, visuals.accent],
          ).createShader(Rect.fromLTWH(x - 2, y - length, 4, length)),
      );
    }
    final light = Offset(size.width / 2, size.height * 0.52);
    final radius = size.shortestSide * (0.125 + p * 0.1) * _energy;
    canvas.drawCircle(
      light,
      radius * 2.2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            visuals.glow.withValues(alpha: (0.12 + p * 0.34) * _energy),
            visuals.accent.withValues(alpha: 0.1 * _energy),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: light, radius: radius * 2.2)),
    );
  }

  void _paintThoughtStrands(Canvas canvas, Size size) {
    final calm = gestureEnergy.clamp(0.0, 1.0);
    final gather = Curves.easeInOutCubic.transform(closeProgress);
    for (var strand = 0; strand < 30; strand++) {
      final baseY = size.height * ((strand + 0.5) / 30);
      final targetY = size.height * 0.5;
      final yCenter = baseY + (targetY - baseY) * gather;
      final path = Path();
      final amplitude =
          (12 + strand % 7 * 6) * (0.15 + 1 - calm) * (1 - gather);
      final speed = 0.4 + ((strand * 37) % 100) / 100 * 1.6;
      for (var x = 0.0; x <= size.width; x += 8) {
        final wave = math.sin(
          x * (0.022 + (1 - calm) * 0.045) +
              elapsedSeconds * speed * (0.6 + (1 - calm) * 3) +
              strand,
        );
        var y = yCenter + wave * amplitude * _energy;
        final touch = touchPoint;
        if (touch != null && !still) {
          final influence = math.exp(-((x - touch.dx).abs()) / 120);
          y += (touch.dy - baseY) * influence * 0.2 * (1 - gather);
        }
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + calm
          ..color = Color.lerp(
            visuals.secondary,
            visuals.glow,
            calm,
          )!.withValues(alpha: (0.14 + calm * 0.22) * (1 - gather * 0.55)),
      );
    }
    if (gather > 0.05) {
      final y = size.height * 0.5;
      final start = size.width * 0.16;
      final end = start + size.width * 0.62 * gather;
      canvas.drawLine(
        Offset(start, y),
        Offset(end, y),
        Paint()
          ..strokeWidth = 1.7
          ..strokeCap = StrokeCap.round
          ..color = visuals.glow.withValues(alpha: gather * 0.9),
      );
      if (gather > 0.85) {
        canvas.drawCircle(
          Offset(size.width * 0.81, y),
          3.4,
          Paint()..color = visuals.glow.withValues(alpha: gather),
        );
      }
    }
  }

  void _paintClosingDoor(Canvas canvas, Size size) {
    final currentBoost = pressing && pointerStartedAt != null
        ? (elapsedSeconds - pointerStartedAt!) * 2.2
        : 0.0;
    final shut = ((elapsedSeconds + awayBoostSeconds + currentBoost) / 12)
        .clamp(0.0, 1.0);
    final ease = Curves.easeInOutCubic.transform(shut);
    final outside = math.pow(1 - ease, 1.25).toDouble();
    final doorway = Rect.fromLTWH(
      size.width * 0.1,
      size.height * 0.08,
      size.width * 0.8,
      size.height * 0.72,
    );
    final gap = doorway.width * (1 - ease * 0.985);
    canvas.save();
    canvas.clipRect(doorway);
    final corridor = Rect.fromLTWH(
      doorway.left,
      doorway.top,
      gap,
      doorway.height,
    );
    canvas.drawRect(
      corridor,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFC4D6F0).withValues(alpha: 0.5 * outside + 0.02),
            const Color(0xFF60708A).withValues(alpha: 0.3 * outside + 0.02),
          ],
        ).createShader(corridor),
    );
    for (var index = 0; index < 9; index++) {
      final direction = index.isEven ? 1.0 : -1.0;
      final velocity = direction * (0.03 + (index % 5) * 0.012);
      final seedX = ((index * 31) % 103) / 100;
      final movingX = (seedX + elapsedSeconds * velocity) % 1.3;
      final x = doorway.left + doorway.width * (movingX - 0.15);
      final bodyHeight = doorway.height * (0.34 + index % 3 * 0.035);
      final base = doorway.bottom;
      final bodyPaint = Paint()
        ..color = const Color(0xFF050609).withValues(alpha: 0.82 * outside);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(
              x + math.sin(elapsedSeconds * (1.2 + index * 0.1)) * 3 * _energy,
              base - bodyHeight * 0.38,
            ),
            width: bodyHeight * 0.18,
            height: bodyHeight * 0.68,
          ),
          Radius.circular(bodyHeight * 0.08),
        ),
        bodyPaint,
      );
      canvas.drawCircle(
        Offset(
          x + math.sin(elapsedSeconds * (1.2 + index * 0.1)) * 3 * _energy,
          base - bodyHeight * 0.82,
        ),
        bodyHeight * 0.08,
        bodyPaint,
      );
    }
    final panel = Rect.fromLTWH(
      doorway.left + gap,
      doorway.top,
      doorway.width - gap,
      doorway.height,
    );
    if (panel.width > 0) {
      canvas.drawRect(
        panel,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF261912), Color(0xFF0D0907)],
          ).createShader(panel),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          panel.left - 12 * outside,
          panel.top,
          18 * outside + 2,
          panel.height,
        ),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              visuals.glow.withValues(alpha: 0.55),
              Colors.transparent,
            ],
          ).createShader(panel.inflate(16)),
      );
    }
    canvas.restore();
    canvas.drawRect(
      doorway,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = visuals.glow.withValues(alpha: 0.1 + ease * 0.08),
    );
    final lamp = Offset(size.width * 0.22, size.height * 0.9);
    canvas.drawCircle(
      lamp,
      size.shortestSide,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                visuals.glow.withValues(alpha: 0.06 + ease * 0.18),
                visuals.secondary.withValues(alpha: 0.04 + ease * 0.08),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: lamp, radius: size.shortestSide),
            ),
    );
    if (ease > 0.5) {
      for (var index = 0; index < 28; index++) {
        final point = Offset(
          size.width *
              ((((index * 37) % 101) / 100 + elapsedSeconds * 0.004) % 1),
          size.height *
              ((((index * 61) % 103) / 100 - elapsedSeconds * 0.006) % 1),
        );
        canvas.drawCircle(
          point,
          0.6 + index % 3 * 0.45,
          Paint()..color = visuals.glow.withValues(alpha: (ease - 0.5) * 0.22),
        );
      }
    }
  }

  void _paintPhysical(Canvas canvas, Size size) {
    switch (physicalContext ?? PhysicalCareContext.tension) {
      case PhysicalCareContext.cramps:
        _paintWarmKnot(canvas, size);
      case PhysicalCareContext.nausea:
        _paintSettlingWater(canvas, size);
      case PhysicalCareContext.headache:
        _paintHeadache(canvas, size);
      case PhysicalCareContext.tension:
        _paintRestingRings(canvas, size);
    }
  }

  void _paintWarmKnot(Canvas canvas, Size size) {
    final p = (elapsedSeconds / sceneSpanSeconds).clamp(0.0, 1.0);
    final ease = Curves.easeInOut.transform(p);
    final knot = 1 - ease;
    final swell = 0.5 + 0.5 * math.sin(elapsedSeconds * (0.5 - ease * 0.32));
    final center = Offset(size.width / 2, size.height * (0.46 - ease * 0.04));
    final radius =
        size.shortestSide *
        (0.16 + ease * 0.4 + swell * 0.04 * (0.4 + knot)) *
        _energy;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF0D2),
            visuals.glow,
            visuals.accent.withValues(alpha: 0.5),
            Colors.transparent,
          ],
          stops: [0, 0.25 + ease * 0.2, 0.6, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    for (var index = 0; index < 3; index++) {
      canvas.drawCircle(
        center +
            Offset(
                  math.sin(elapsedSeconds * (1.2 - ease) + index) * 8,
                  math.cos(elapsedSeconds * (1.1 - ease) + index) * 8,
                ) *
                knot *
                _energy,
        radius * (0.3 + index * 0.16) * (0.7 + knot * 0.3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + knot
          ..color = visuals.glow.withValues(alpha: 0.14 * knot * _energy),
      );
    }
  }

  void _paintSettlingWater(Canvas canvas, Size size) {
    final p = (elapsedSeconds / sceneSpanSeconds).clamp(0.0, 1.0);
    final settle = Curves.easeInOut.transform(p);
    for (var index = 0; index < 7; index++) {
      final y = size.height * (0.3 + index * 0.062);
      final path = Path();
      final amplitude = (26 - settle * 24) * _energy;
      for (var x = 0.0; x <= size.width; x += 8) {
        final wave =
            math.sin(
              x * 0.012 + elapsedSeconds * (1.5 - settle * 1.3) + index,
            ) *
            amplitude;
        final secondary =
            math.sin(x * 0.031 - elapsedSeconds * (0.9 - settle * 0.8)) *
            amplitude *
            0.4 *
            (1 - settle);
        if (x == 0) {
          path.moveTo(x, y + wave + secondary);
        } else {
          path.lineTo(x, y + wave + secondary);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + settle * 1.2
          ..color = (index.isEven ? visuals.glow : visuals.accent).withValues(
            alpha: (0.12 + settle * 0.18) * _energy,
          ),
      );
    }
  }

  void _paintHeadache(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.52);
    canvas.drawCircle(
      center,
      size.shortestSide * 0.48,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                visuals.accent.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: center, radius: size.shortestSide * 0.48),
            ),
    );
  }

  void _paintRestingRings(Canvas canvas, Size size) {
    final p = (elapsedSeconds / sceneSpanSeconds).clamp(0.0, 1.0);
    final ease = Curves.easeInOut.transform(p);
    final center = Offset(size.width / 2, size.height * 0.5);
    final radius = size.shortestSide * (0.18 + ease * 0.34) * _energy;
    canvas.drawCircle(
      center,
      radius * 1.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            visuals.glow,
            visuals.accent.withValues(alpha: 0.45),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.6)),
    );
    for (var index = 0; index < 4; index++) {
      final ring = radius * (0.52 + index * 0.28);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: ring * 2 * (1 + ease * 0.3),
          height: ring * 2 * (1 + ease * 0.3) * (1 - ease * 0.92),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = visuals.glow.withValues(
            alpha: 0.16 * (1 - ease * 0.5) * _energy,
          ),
      );
    }
    canvas.drawLine(
      Offset(size.width * (0.2 - 0.04 * (1 - ease)), center.dy),
      Offset(size.width * (0.8 + 0.04 * (1 - ease)), center.dy),
      Paint()
        ..strokeWidth = 1.5
        ..color = visuals.glow.withValues(alpha: ease * 0.4 * _energy),
    );
  }

  @override
  bool shouldRepaint(covariant CareBreakPainter oldDelegate) {
    return oldDelegate.mode != mode ||
        oldDelegate.progress != progress ||
        oldDelegate.elapsedSeconds != elapsedSeconds ||
        oldDelegate.sceneSpanSeconds != sceneSpanSeconds ||
        oldDelegate.closeProgress != closeProgress ||
        oldDelegate.touchPoint != touchPoint ||
        oldDelegate.physicalContext != physicalContext ||
        oldDelegate.gestureEnergy != gestureEnergy ||
        oldDelegate.pressing != pressing ||
        oldDelegate.pointerStartedAt != pointerStartedAt ||
        oldDelegate.awayBoostSeconds != awayBoostSeconds ||
        oldDelegate.intensity != intensity ||
        oldDelegate.still != still ||
        oldDelegate.gestureTrail.length != gestureTrail.length;
  }
}
