import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../domain/care_memory.dart';
import '../domain/care_mode.dart';
import 'care_haptics.dart';
import 'care_sound_engine.dart';
import 'prototype_scene_painter.dart';

enum CareBreakStage { context, active, landing, settled, extending }

enum PhysicalCareContext { cramps, nausea, headache, tension }

/// Shared chrome palette for the control layer. The five scene worlds keep
/// their own [CareBreakVisuals]; everything the user *operates* speaks one
/// quiet studio language — deep plum surfaces, soft ivory type, and a single
/// acid-lime point of life marking where the controls rest.
const Color _kChromeSurface = Color(0xFF241A2A);
const Color _kChromeIvory = Color(0xFFFFF8EC);
const Color _kChromeAccent = Color(0xFFD9FF63);

/// A finite, motion-first Care scene.
///
/// Selecting an emotional Care entrance opens its scene immediately. Physical
/// Care asks one short context question because that choice changes the motion.
/// Touches, lines, intensity, and the navigation result remain ephemeral.
class CareBreakFlow extends StatefulWidget {
  const CareBreakFlow({
    required this.mode,
    required this.onBack,
    this.onSafety,
    this.onCompleted,
    this.onCheckedIn,
    this.onDone,
    this.soundEngine,
    this.motionModel,
    this.sceneVariant = CareSceneVariant.productionHybrid,
    this.usesExternalCompletionFlow = false,
    this.initiallySettled = false,
    this.initialIntensity = 0.6,
    this.sceneSeconds = 90,
    super.key,
  }) : assert(initialIntensity >= 0 && initialIntensity <= 1),
       assert(sceneSeconds >= 30 && sceneSeconds <= 90);

  final CareMode mode;
  final VoidCallback onBack;
  final VoidCallback? onSafety;
  final VoidCallback? onCompleted;
  final ValueChanged<CareOutcome>? onCheckedIn;
  final VoidCallback? onDone;
  final CareSoundEngine? soundEngine;
  final PrototypeSceneModel? motionModel;
  final CareSceneVariant sceneVariant;

  /// When true, the owning experience presents the Better / Same / Worse
  /// check-back. The motion scene therefore hands off directly instead of
  /// opening its legacy moment-check sheet.
  final bool usesExternalCompletionFlow;
  final bool initiallySettled;
  final double initialIntensity;
  final double sceneSeconds;

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
  double? _explodeInteractionStartedAt;
  double _awayBoostSeconds = 0;
  bool _pressing = false;
  late double _intensity;
  bool _soundEnabled = false;
  Timer? _stillClock;
  double _lastHapticAt = 0;
  double _lastAudioEnvelopeAt = -1;

  /// Chrome state: controls wake briefly to teach where they live, then
  /// recede to two quiet anchors — Back on the left, the lime-dotted scene
  /// handle on the right — so the motion owns the canvas.
  bool _chromeAwake = false;
  bool _sceneMenuOpen = false;
  Timer? _chromeClock;

  /// The next point at which a settled extension offers its choices again.
  late double _sceneDuration;

  /// True when the user explicitly chose "Enough", bypassing minimum dwell.
  bool _forcedClose = false;

  CareBreakVisuals get _visuals => CareBreakVisuals.forMode(widget.mode);

  @override
  void initState() {
    super.initState();
    _sound = widget.soundEngine ?? CareSoundEngine();
    _motionModel = widget.motionModel ?? PrototypeSceneModel();
    _intensity = widget.initialIntensity;
    _sceneDuration = widget.sceneSeconds;
    _stage = widget.initiallySettled
        ? CareBreakStage.settled
        : widget.mode == CareMode.physical
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
    if (widget.initiallySettled) {
      _session.value = widget.sceneSeconds / 600;
    }
    if (_stage == CareBreakStage.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _session.forward(from: 0);
          // Briefly open the scene menu so the control grammar is learned
          // spatially, then let it dissolve back into the handle.
          _wakeChrome(openMenu: true, restAfter: const Duration(seconds: 6));
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_physicalContext == PhysicalCareContext.headache &&
          (_stage == CareBreakStage.active ||
              _stage == CareBreakStage.landing ||
              _stage == CareBreakStage.extending)) {
        _startStillClock();
        return;
      }
      if ((_stage == CareBreakStage.active ||
              _stage == CareBreakStage.landing ||
              _stage == CareBreakStage.extending) &&
          !_session.isCompleted) {
        _session.forward();
      }
      return;
    }
    _chromeClock?.cancel();
    _stillClock?.cancel();
    _session.stop();
    _sound.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chromeClock?.cancel();
    _session.dispose();
    _sound.dispose();
    _stillClock?.cancel();
    CareHaptics.stop();
    super.dispose();
  }

  /// Wake the chrome (and optionally open the scene menu). Without reduced
  /// motion it recedes again after [restAfter]; with reduced motion it simply
  /// stays visible so nothing is ever hidden behind timing.
  void _wakeChrome({
    bool openMenu = false,
    Duration restAfter = const Duration(seconds: 4),
  }) {
    if (!mounted || _stage == CareBreakStage.context) return;
    _chromeClock?.cancel();
    final reduced = MediaQuery.disableAnimationsOf(context);
    setState(() {
      _chromeAwake = true;
      _sceneMenuOpen = openMenu && !reduced;
    });
    if (!reduced) {
      _chromeClock = Timer(restAfter, _restChrome);
    }
  }

  void _restChrome() {
    if (!mounted) return;
    setState(() {
      _chromeAwake = false;
      _sceneMenuOpen = false;
    });
  }

  void _toggleSceneMenu() {
    if (_sceneMenuOpen) {
      _wakeChrome(openMenu: false, restAfter: const Duration(seconds: 3));
    } else {
      _wakeChrome(openMenu: true, restAfter: const Duration(seconds: 7));
    }
  }

  /// A touch on the scene dissolves the menu and returns the canvas.
  void _dismissSceneMenu() {
    if (!_sceneMenuOpen) return;
    _wakeChrome(openMenu: false, restAfter: const Duration(seconds: 3));
  }

  void _menuAdjust() {
    _restChrome();
    unawaited(_openAdjustments());
  }

  void _menuSound() {
    unawaited(_toggleSound());
    _wakeChrome(openMenu: true, restAfter: const Duration(seconds: 3));
  }

  void _menuSafety() {
    _restChrome();
    widget.onSafety?.call();
  }

  void _menuEnough() {
    _chromeClock?.cancel();
    _enough();
  }

  void _startPhysical(PhysicalCareContext context) {
    setState(() {
      _physicalContext = context;
      _stage = CareBreakStage.active;
    });
    if (context == PhysicalCareContext.headache) {
      _session.value = 0;
      _startStillClock();
    } else {
      _session.forward(from: 0);
      _wakeChrome(openMenu: true, restAfter: const Duration(seconds: 6));
    }
  }

  void _startStillClock() {
    _stillClock?.cancel();
    _stillClock = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted ||
          (_stage != CareBreakStage.active &&
              _stage != CareBreakStage.landing &&
              _stage != CareBreakStage.extending)) {
        timer.cancel();
        return;
      }
      _session.value = math.min(_sceneDuration / 600, _session.value + 1 / 600);
    });
  }

  void _recordGesture(Offset position, {required double movement}) {
    if ((_stage != CareBreakStage.active && _stage != CareBreakStage.landing) ||
        _isStill(context)) {
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
      if (widget.mode == CareMode.explode) {
        _explodeInteractionStartedAt ??= _elapsedSeconds;
      }
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
    if (widget.mode == CareMode.heavy && _soundEnabled) {
      unawaited(_sound.setInteraction(0.3 + _pointerSpeed * 0.7));
    }
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
    if (!_soundEnabled) return;
    if (widget.mode == CareMode.space) {
      unawaited(_sound.setOutside(_spaceOutside));
      return;
    }
    if (widget.mode != CareMode.heavy && widget.mode != CareMode.racing) {
      return;
    }
    final elapsed = _elapsedSeconds;
    if (_lastAudioEnvelopeAt >= 0 && elapsed - _lastAudioEnvelopeAt < 0.25) {
      return;
    }
    _lastAudioEnvelopeAt = elapsed;
    unawaited(_sound.setSceneProgress(_audioSceneProgress));
  }

  double get _audioSceneProgress => switch (widget.mode) {
    CareMode.heavy => (_elapsedSeconds / 90).clamp(0.0, 1.0),
    CareMode.racing =>
      _closeStartedAt == null
          ? _motionModel.calm.clamp(0.0, 1.0)
          : _closeProgress(widget.mode, _elapsedSeconds, _closeStartedAt!),
    _ => 0,
  };

  /// Per-scene haptic rhythm, throttled to avoid flooding the taptic engine.
  void _pumpHaptics() {
    if (_stage != CareBreakStage.active && _stage != CareBreakStage.landing) {
      return;
    }
    if (_isStill(context)) return;
    final elapsed = _elapsedSeconds;
    final mode = widget.mode;
    final landingScale = _stage == CareBreakStage.landing
        ? ((90 - elapsed) / 15).clamp(0.0, 1.0)
        : 1.0;
    final hapticIntensity = _intensity * landingScale;

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
        CareHaptics.charge(_gestureEnergy, hapticIntensity);
      case CareMode.heavy:
        CareHaptics.fall(hapticIntensity);
      case CareMode.racing:
        CareHaptics.tick(hapticIntensity);
      case CareMode.space:
        CareHaptics.enclose(hapticIntensity);
      case CareMode.physical:
        CareHaptics.warmth(hapticIntensity);
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
    if (widget.mode == CareMode.heavy && _soundEnabled) {
      unawaited(_sound.setInteraction(0));
      CareHaptics.fall(_intensity * 0.32);
    }
    if (mounted) {
      setState(() {});
    }
  }

  double get _elapsedSeconds {
    // Scale from the 600 s controller value to actual elapsed seconds.
    return _session.value * 600;
  }

  /// Move through a quiet landing instead of treating 90 seconds as an exit.
  /// Explode remains user-ended because its seal can be reopened repeatedly.
  void _checkSceneCompletion() {
    if (_forcedClose) return;
    if (widget.mode == CareMode.explode && widget.sceneSeconds >= 90) return;
    final elapsed = _elapsedSeconds;
    final landingStart = math.max(0, widget.sceneSeconds - 15);
    if (_stage == CareBreakStage.active && elapsed >= landingStart && mounted) {
      setState(() => _stage = CareBreakStage.landing);
    }
    if ((_stage == CareBreakStage.active || _stage == CareBreakStage.landing) &&
        elapsed >= widget.sceneSeconds &&
        mounted) {
      _settleScene();
      return;
    }
    if (_stage == CareBreakStage.extending &&
        elapsed >= _sceneDuration &&
        mounted) {
      _settleScene();
    }
  }

  void _settleScene() {
    if (_stage == CareBreakStage.settled) {
      return;
    }
    _session.stop();
    _stillClock?.cancel();
    _chromeClock?.cancel();
    if (_soundEnabled &&
        (widget.mode == CareMode.heavy || widget.mode == CareMode.racing)) {
      unawaited(_sound.setSceneProgress(1));
    }
    CareHaptics.stop();
    setState(() {
      _stage = CareBreakStage.settled;
      _touchPoint = null;
      _lastTouchPoint = null;
      _pressing = false;
      _forcedClose = false;
      _sceneMenuOpen = false;
      _chromeAwake = false;
    });
  }

  /// Hold the completed visual and quiet sound bed for another minute.
  void _stayLonger() {
    if (_stage != CareBreakStage.settled) return;
    _sceneDuration = _elapsedSeconds + 60;
    _forcedClose = false;
    _lastHapticAt = _elapsedSeconds;
    setState(() {
      _stage = CareBreakStage.extending;
      _touchPoint = null;
      _lastTouchPoint = null;
      _pressing = false;
    });
    _wakeChrome(restAfter: const Duration(seconds: 3));
    if (_physicalContext == PhysicalCareContext.headache) {
      _startStillClock();
    } else {
      _session.forward(from: _session.value);
    }
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
    // A forced settle must render the same calm endpoint as the natural
    // ending, rather than placing settled controls over an early scene frame.
    final completedValue = widget.sceneSeconds / 600;
    if (_session.value < completedValue) {
      _session.value = completedValue;
    }
    if (widget.mode == CareMode.racing && _closeStartedAt == null) {
      // Racing is gesture-driven, so complete its gather before settling.
      _closeStartedAt = _elapsedSeconds - 2.2;
    }
    _settleScene();
  }

  Future<void> _openAdjustments() async {
    final settleNow = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      barrierColor: LetterColors.ink.withValues(alpha: 0.44),
      backgroundColor: _kChromeSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kChromeIvory.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Adjust the scene',
                style: TextStyle(
                  color: _kChromeIvory,
                  fontFamily: 'Newsreader',
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Intensity changes the texture, not what you have to do.',
                style: TextStyle(
                  color: _kChromeIvory.withValues(alpha: 0.6),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Scene intensity',
                    style: TextStyle(
                      color: _kChromeIvory.withValues(alpha: 0.72),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _intensityLabel(_intensity),
                    style: const TextStyle(
                      color: _kChromeAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  activeTrackColor: _kChromeAccent,
                  inactiveTrackColor: _kChromeIvory.withValues(alpha: 0.16),
                  thumbColor: _kChromeAccent,
                  overlayColor: _kChromeAccent.withValues(alpha: 0.14),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                ),
                child: Slider(
                  key: const Key('care-motion-intensity'),
                  value: _intensity,
                  onChanged: (value) {
                    _setIntensity(value);
                    setSheetState(() {});
                  },
                  semanticFormatterCallback: (value) =>
                      '${_intensityLabel(value)} scene intensity',
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('care-adjust-settle-now'),
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: _kChromeIvory.withValues(alpha: 0.72),
                ),
                child: const Text('Move to the quiet ending'),
              ),
            ],
          ),
        ),
      ),
    );
    if (settleNow == true && mounted) {
      _enough();
    }
  }

  Future<void> _openMomentCheck() async {
    final outcome = await showModalBottomSheet<CareOutcome>(
      context: context,
      useSafeArea: true,
      barrierColor: LetterColors.ink.withValues(alpha: 0.4),
      backgroundColor: _kChromeSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _MomentCheckSheet(),
    );
    if (!mounted || outcome == null) return;
    final checkedIn = widget.onCheckedIn;
    if (checkedIn != null) {
      _leave(() => checkedIn(outcome));
    } else {
      _leave(widget.onCompleted ?? widget.onBack);
    }
  }

  void _handoffToExternalCompletion() {
    _leave(widget.onCompleted ?? widget.onBack);
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
      } else if (widget.mode == CareMode.heavy ||
          widget.mode == CareMode.racing) {
        await _sound.setSceneProgress(_audioSceneProgress);
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
    _chromeClock?.cancel();
    _stillClock?.cancel();
    _session.stop();
    _sound.stop();
    callback();
  }

  bool _isStill(BuildContext context) {
    return MediaQuery.of(context).disableAnimations ||
        (widget.mode == CareMode.physical &&
            _physicalContext == PhysicalCareContext.headache);
  }

  @override
  Widget build(BuildContext context) {
    final still = _isStill(context);
    final headache =
        widget.mode == CareMode.physical &&
        _physicalContext == PhysicalCareContext.headache;
    if (still && _session.isAnimating) {
      // Reduced-motion and headache scenes render their settled frame. Stop
      // driving an invisible 60 fps repaint loop once that frame is active.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isStill(context) && _session.isAnimating) {
          _session.stop();
        }
      });
    }
    if (still && _soundEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _soundEnabled) {
          _sound.stop();
          setState(() => _soundEnabled = false);
        }
      });
    }

    final contextStage = _stage == CareBreakStage.context;
    final settledStage = _stage == CareBreakStage.settled;
    final soundAvailable = !contextStage && !still;

    final chrome = _CareChrome(
      visuals: _visuals,
      contextStage: contextStage,
      still: still,
      settled: settledStage,
      awake: _chromeAwake,
      menuOpen: _sceneMenuOpen,
      onBack: () => _leave(widget.onBack),
      onToggleMenu: _toggleSceneMenu,
      onSafety: widget.onSafety,
      onEnough: _menuEnough,
    );

    final activeScene = _MotionStage(
      mode: widget.mode,
      sceneSeconds: widget.sceneSeconds,
      motionModel: _motionModel,
      visuals: _visuals,
      session: _session,
      physicalContext: _physicalContext,
      touchPoint: _touchPoint,
      gestureEnergy: _gestureEnergy,
      pointerSpeed: _pointerSpeed,
      closeStartedAt: _closeStartedAt,
      explodeInteractionStartedAt: _explodeInteractionStartedAt,
      pointerStartedAt: _pointerStartedAt,
      pressing: _pressing,
      awayBoostSeconds: _awayBoostSeconds,
      intensity: _intensity,
      still: still,
      landing: _stage == CareBreakStage.landing,
      settled: settledStage || _stage == CareBreakStage.extending,
      sceneVariant: widget.sceneVariant,
      onPointer: (position, {required movement}) {
        // A touch on the canvas dissolves any open menu and returns the
        // scene — the gesture always belongs to the motion first.
        _dismissSceneMenu();
        _recordGesture(position, movement: movement);
      },
      onPointerUp: _releaseGesture,
      onEnough: _enough,
    );

    final showSceneControls =
        _stage == CareBreakStage.active ||
        _stage == CareBreakStage.landing ||
        _stage == CareBreakStage.extending;

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
                  chrome,
                  Expanded(
                    child: SingleChildScrollView(
                      key: const Key('care-break-context-scroll'),
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: _PhysicalContextStage(
                        visuals: _visuals,
                        onSelected: _startPhysical,
                      ),
                    ),
                  ),
                ],
              ),
              CareBreakStage.active ||
              CareBreakStage.landing ||
              CareBreakStage.settled ||
              CareBreakStage.extending => Stack(
                fit: StackFit.expand,
                children: [
                  activeScene,
                  if (settledStage) ...[
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 340,
                      child: IgnorePointer(
                        child: _RiseIn(
                          index: 0,
                          distance: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  _visuals.background.withValues(alpha: 0),
                                  _visuals.background.withValues(alpha: 0.9),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _SettledAfterCare(
                        visuals: _visuals,
                        onStayLonger: _stayLonger,
                        onCheckIn: widget.usesExternalCompletionFlow
                            ? _handoffToExternalCompletion
                            : _openMomentCheck,
                        onDone: () => _leave(widget.onDone ?? widget.onBack),
                      ),
                    ),
                  ],
                  if (_sceneMenuOpen && !still && !contextStage)
                    Positioned(
                      top: 66,
                      right: 0,
                      child: _SceneMenu(
                        showAdjust:
                            _stage == CareBreakStage.active && !headache,
                        showEnough: showSceneControls,
                        onAdjust: _menuAdjust,
                        onEnough: _menuEnough,
                        onSafety: widget.onSafety == null ? null : _menuSafety,
                        soundEnabled: _soundEnabled,
                        soundAvailable: soundAvailable,
                        onToggleSound: _menuSound,
                      ),
                    ),
                  Align(alignment: Alignment.topCenter, child: chrome),
                ],
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// Staggered, cinematic entrance used by the settled after-care and any
/// transient chrome. Reduced motion renders the final state immediately.
class _RiseIn extends StatefulWidget {
  const _RiseIn({required this.child, this.index = 0, this.distance = 16});

  final Widget child;
  final int index;
  final double distance;

  @override
  State<_RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<_RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// Guards the one-shot entrance decision. Reduced motion snaps to the end
  /// state; otherwise the rise plays exactly once.
  bool _resolved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery is an inherited widget, so it cannot be read from
    // initState. Resolve the reduced-motion preference here instead — the
    // first legal point in the element lifecycle.
    if (MediaQuery.disableAnimationsOf(context)) {
      _resolved = true;
      _controller.value = 1;
      return;
    }
    if (!_resolved) {
      _resolved = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final begin = (widget.index * 0.16).clamp(0.0, 0.55);
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, 1, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, (1 - animation.value) * widget.distance),
          child: child,
        ),
      ),
    );
  }
}

/// The physical context question, composed as an editorial index rather than
/// a stack of boxed buttons: oversized display type, numbered rows, and
/// hairline separators so the choice feels considered, not administrative.
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
          'Where is\nit today?',
          style: TextStyle(
            color: visuals.foreground,
            fontFamily: 'Newsreader',
            fontSize: 42,
            height: 0.98,
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
        Container(height: 1, color: visuals.foreground.withValues(alpha: 0.12)),
        _ContextOption(
          buttonKey: const Key('care-context-cramps'),
          index: '01',
          title: 'Cramps or back pain',
          detail: 'A warm knot, softening',
          visuals: visuals,
          onPressed: () => onSelected(PhysicalCareContext.cramps),
        ),
        _ContextOption(
          buttonKey: const Key('care-context-nausea'),
          index: '02',
          title: 'Nausea or bloating',
          detail: 'Disturbed water, settling flat',
          visuals: visuals,
          onPressed: () => onSelected(PhysicalCareContext.nausea),
        ),
        _ContextOption(
          buttonKey: const Key('care-context-headache'),
          index: '03',
          title: 'Headache or migraine',
          detail: 'Quiet, dim, and motionless',
          visuals: visuals,
          onPressed: () => onSelected(PhysicalCareContext.headache),
        ),
        _ContextOption(
          buttonKey: const Key('care-context-tension'),
          index: '04',
          title: 'General tension',
          detail: 'Warm rings widening into one line',
          visuals: visuals,
          onPressed: () => onSelected(PhysicalCareContext.tension),
          showDivider: false,
        ),
        Container(height: 1, color: visuals.foreground.withValues(alpha: 0.12)),
      ],
    );
  }
}

class _ContextOption extends StatelessWidget {
  const _ContextOption({
    required this.buttonKey,
    required this.index,
    required this.title,
    required this.detail,
    required this.visuals,
    required this.onPressed,
    this.showDivider = true,
  });

  final Key buttonKey;
  final String index;
  final String title;
  final String detail;
  final CareBreakVisuals visuals;
  final VoidCallback onPressed;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: '$title. $detail',
          child: InkWell(
            key: buttonKey,
            onTap: onPressed,
            splashColor: _kChromeAccent.withValues(alpha: 0.06),
            highlightColor: visuals.foreground.withValues(alpha: 0.04),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        index,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          color: _kChromeAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: visuals.foreground.withValues(alpha: 0.95),
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            detail,
                            style: TextStyle(
                              color: visuals.foreground.withValues(alpha: 0.55),
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: visuals.foreground.withValues(alpha: 0.35),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showDivider)
          Container(
            height: 1,
            color: visuals.foreground.withValues(alpha: 0.12),
          ),
      ],
    );
  }
}

class _MotionStage extends StatelessWidget {
  const _MotionStage({
    required this.mode,
    required this.sceneSeconds,
    required this.motionModel,
    required this.visuals,
    required this.session,
    required this.physicalContext,
    required this.touchPoint,
    required this.gestureEnergy,
    required this.pointerSpeed,
    required this.closeStartedAt,
    required this.explodeInteractionStartedAt,
    required this.pointerStartedAt,
    required this.pressing,
    required this.awayBoostSeconds,
    required this.intensity,
    required this.still,
    required this.landing,
    required this.settled,
    required this.sceneVariant,
    required this.onPointer,
    required this.onPointerUp,
    required this.onEnough,
  });

  final CareMode mode;
  final double sceneSeconds;
  final PrototypeSceneModel motionModel;
  final CareBreakVisuals visuals;
  final Animation<double> session;
  final PhysicalCareContext? physicalContext;
  final Offset? touchPoint;
  final double gestureEnergy;
  final double pointerSpeed;
  final double? closeStartedAt;
  final double? explodeInteractionStartedAt;
  final double? pointerStartedAt;
  final bool pressing;
  final double awayBoostSeconds;
  final double intensity;
  final bool still;
  final bool landing;
  final bool settled;
  final CareSceneVariant sceneVariant;
  final void Function(Offset position, {required double movement}) onPointer;
  final VoidCallback onPointerUp;
  final VoidCallback onEnough;

  @override
  Widget build(BuildContext context) {
    final lines = _motionLines(mode, physicalContext);
    final headache =
        mode == CareMode.physical &&
        physicalContext == PhysicalCareContext.headache;
    final settledTitle = headache
        ? 'Still. Dim. Nothing asked.'
        : visuals.settledTitle;
    final settledCue = headache
        ? 'Stay with the quiet, or leave when you need'
        : visuals.settledCue;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: !settled,
      label: headache
          ? 'A dim resting horizon held without movement'
          : still || settled
          ? visuals.settledSemantics
          : visuals.activeSemantics,
      hint: still || settled
          ? headache
                ? 'No interaction is needed. Use back whenever you need'
                : 'Use the quiet controls below whenever you are ready'
          : _motionGuide(mode, physicalContext),
      onTap: settled ? null : onEnough,
      // Keep the scene itself actionable without hiding its intensity and
      // completion controls from assistive technology.
      excludeSemantics: false,
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
                              sceneSeconds: sceneSeconds,
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
                      breath: false,
                      variant: sceneVariant,
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 40,
              right: 40,
              top:
                  MediaQuery.sizeOf(context).height *
                  (mode == CareMode.explode ? 0.16 : 0.26),
              child: AnimatedBuilder(
                animation: session,
                builder: (context, _) {
                  final elapsed = _elapsedForSession(session);
                  return _MotionLine(
                    elapsedSeconds: elapsed,
                    lines: lines,
                    color: visuals.foreground,
                    glow: visuals.glow,
                    reducedMotion: MediaQuery.disableAnimationsOf(context),
                    landing: landing,
                    settled: settled,
                    interactionStartedAt: mode == CareMode.explode
                        ? explodeInteractionStartedAt
                        : null,
                    settledTitle: settledTitle,
                    settledCue: settledCue,
                  );
                },
              ),
            ),
            if (mode == CareMode.explode)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: session,
                    builder: (context, _) {
                      final elapsed = _elapsedForSession(session);
                      final close = _closeProgress(
                        mode,
                        elapsed,
                        closeStartedAt,
                      );
                      return _ExplodeSealInscription(
                        elapsedSinceSeal: close >= 1 && closeStartedAt != null
                            ? elapsed - closeStartedAt! - 2.4
                            : null,
                        color: visuals.foreground,
                        glow: visuals.glow,
                      );
                    },
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
  required double sceneSeconds,
}) {
  final span = sceneSeconds;
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
    required this.landing,
    required this.settled,
    required this.interactionStartedAt,
    required this.settledTitle,
    required this.settledCue,
  });

  final double elapsedSeconds;
  final List<String> lines;
  final Color color;
  final Color glow;
  final bool reducedMotion;
  final bool landing;
  final bool settled;
  final double? interactionStartedAt;
  final String settledTitle;
  final String settledCue;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }
    if (reducedMotion || settled) {
      return Text(
        settled ? settledCue : lines.first,
        key: const Key('care-motion-line'),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color.withValues(alpha: 0.64),
          fontFamily: 'Newsreader',
          fontSize: 19,
          fontWeight: FontWeight.w400,
          height: 1.16,
          letterSpacing: 0.15,
        ),
      );
    }

    if (landing) {
      final opacity = ((_elapsedForLanding(elapsedSeconds) - 2) / 6).clamp(
        0.0,
        1.0,
      );
      return Opacity(
        opacity: Curves.easeInOutCubic.transform(opacity),
        child: Text(
          settledTitle,
          key: const Key('care-motion-line'),
          textAlign: TextAlign.center,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontFamily: 'Newsreader',
            fontSize: 20,
            fontWeight: FontWeight.w400,
            height: 1.16,
            letterSpacing: 0.15,
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 2),
              Shadow(color: glow.withValues(alpha: 0.14), blurRadius: 16),
            ],
          ),
        ),
      );
    }

    const lineCycle = 16.0;
    const lineDuration = 7.0;
    final index = (elapsedSeconds / lineCycle).floor();
    if (index >= lines.length) {
      return const SizedBox.shrink();
    }
    final withinCycle = elapsedSeconds - index * lineCycle;
    if (withinCycle >= lineDuration) {
      return const SizedBox.shrink();
    }
    final local = (withinCycle / lineDuration).clamp(0.0, 1.0);
    final entering = Curves.easeInOutCubic.transform(
      (local / 0.32).clamp(0, 1),
    );
    final leaving = local < 0.66
        ? 1.0
        : 1 -
              Curves.easeInOutCubic.transform(
                ((local - 0.66) / 0.34).clamp(0, 1),
              );
    final interactionOpacity = interactionStartedAt == null
        ? 1.0
        : (1 - ((elapsedSeconds - interactionStartedAt!) / 0.4)).clamp(
            0.0,
            1.0,
          );
    final opacity = (math.min(entering, leaving) * interactionOpacity).clamp(
      0.0,
      1.0,
    );
    if (interactionOpacity <= 0.001) {
      return const SizedBox.shrink();
    }
    final blur = local < 0.32
        ? 8 * (1 - entering)
        : local > 0.66
        ? 6 * (1 - leaving)
        : 0.0;
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Opacity(
        opacity: opacity,
        child: Text(
          lines[index],
          key: const Key('care-motion-line'),
          textAlign: TextAlign.center,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: color.withValues(alpha: 0.64),
            fontFamily: 'Newsreader',
            fontSize: 19,
            fontWeight: FontWeight.w400,
            height: 1.16,
            letterSpacing: 0.15,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.32),
                offset: const Offset(0, 1),
                blurRadius: 1.5,
              ),
              Shadow(color: glow.withValues(alpha: 0.14), blurRadius: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExplodeSealInscription extends StatelessWidget {
  const _ExplodeSealInscription({
    required this.elapsedSinceSeal,
    required this.color,
    required this.glow,
  });

  final double? elapsedSinceSeal;
  final Color color;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    final elapsed = elapsedSinceSeal;
    const duration = 5.5;
    if (elapsed == null || elapsed < 0 || elapsed >= duration) {
      return const SizedBox.shrink();
    }
    final largeOpacity = _inscriptionOpacity(
      elapsed,
      fadeInStart: 0,
      fadeInEnd: 0.55,
      fadeOutStart: 1.35,
      fadeOutEnd: 2.0,
    );
    final mediumOpacity = _inscriptionOpacity(
      elapsed,
      fadeInStart: 1.35,
      fadeInEnd: 2.0,
      fadeOutStart: 3.15,
      fadeOutEnd: 3.85,
    );
    final smallOpacity = _inscriptionOpacity(
      elapsed,
      fadeInStart: 3.15,
      fadeInEnd: 3.85,
      fadeOutStart: 4.35,
      fadeOutEnd: duration,
    );

    return Center(
      child: Semantics(
        key: const Key('care-motion-line'),
        label: 'anger is sealed',
        child: ExcludeSemantics(
          child: SizedBox(
            width: 72,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _SealInscriptionLayer(
                  key: const Key('seal-inscription-large'),
                  opacity: largeOpacity,
                  fontSize: 13,
                  color: color,
                  glow: glow,
                ),
                _SealInscriptionLayer(
                  key: const Key('seal-inscription-medium'),
                  opacity: mediumOpacity,
                  fontSize: 10.75,
                  color: color,
                  glow: glow,
                ),
                _SealInscriptionLayer(
                  key: const Key('seal-inscription-small'),
                  opacity: smallOpacity,
                  fontSize: 8.75,
                  color: color,
                  glow: glow,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

double _inscriptionOpacity(
  double elapsed, {
  required double fadeInStart,
  required double fadeInEnd,
  required double fadeOutStart,
  required double fadeOutEnd,
}) {
  if (elapsed < fadeInStart || elapsed >= fadeOutEnd) return 0;
  if (elapsed < fadeInEnd) {
    return Curves.easeInOutCubic.transform(
      ((elapsed - fadeInStart) / (fadeInEnd - fadeInStart)).clamp(0, 1),
    );
  }
  if (elapsed <= fadeOutStart) return 1;
  return 1 -
      Curves.easeInOutCubic.transform(
        ((elapsed - fadeOutStart) / (fadeOutEnd - fadeOutStart)).clamp(0, 1),
      );
}

class _SealInscriptionLayer extends StatelessWidget {
  const _SealInscriptionLayer({
    required this.opacity,
    required this.fontSize,
    required this.color,
    required this.glow,
    super.key,
  });

  final double opacity;
  final double fontSize;
  final Color color;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Text(
        'anger\nis sealed',
        textAlign: TextAlign.center,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: color.withValues(alpha: 0.72),
          fontFamily: 'Newsreader',
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          height: 1.04,
          letterSpacing: 0.2,
          shadows: [
            Shadow(color: glow.withValues(alpha: 0.22), blurRadius: 10),
          ],
        ),
      ),
    );
  }
}

double _elapsedForLanding(double elapsedSeconds) =>
    (elapsedSeconds - 75).clamp(0.0, 15.0);

/// One small circular chrome target: a 48px hit region ringed by the same
/// 1px hairline every control surface uses. Used for Back, inline Support,
/// and anywhere a persistent anchor must stay visible without raising its
/// voice.
class _ChromeIconButton extends StatelessWidget {
  const _ChromeIconButton({
    required this.buttonKey,
    required this.onPressed,
    required this.tooltip,
    required this.icon,
  });

  final Key buttonKey;
  final VoidCallback onPressed;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey,
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: _kChromeIvory.withValues(alpha: 0.9),
        backgroundColor: _kChromeSurface.withValues(alpha: 0.38),
        side: BorderSide(
          width: 1,
          color: _kChromeIvory.withValues(alpha: 0.16),
        ),
        shape: const CircleBorder(),
      ),
      icon: Icon(icon, size: 18),
    );
  }
}

/// Persistent top chrome, reduced to two anchors while a scene runs: Back on
/// the left (always reachable, always visible) and the scene handle on the
/// right — two hairlines marked by a single acid-lime dot inside the same
/// hairline ring, the one signature that says "the controls rest here" in
/// every scene world. In still scenes the grammar flattens into quiet inline
/// controls so nothing hides.
class _CareChrome extends StatelessWidget {
  const _CareChrome({
    required this.visuals,
    required this.contextStage,
    required this.still,
    required this.settled,
    required this.awake,
    required this.menuOpen,
    required this.onBack,
    required this.onToggleMenu,
    required this.onSafety,
    required this.onEnough,
  });

  final CareBreakVisuals visuals;
  final bool contextStage;
  final bool still;
  final bool settled;
  final bool awake;
  final bool menuOpen;
  final VoidCallback onBack;
  final VoidCallback onToggleMenu;
  final VoidCallback? onSafety;
  final VoidCallback onEnough;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final fadeDuration = reduced
        ? Duration.zero
        : const Duration(milliseconds: 500);
    final onSafety = this.onSafety;
    final backOpacity = contextStage || still || awake ? 1.0 : 0.55;
    final handleOpacity = awake || menuOpen ? 1.0 : 0.6;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            AnimatedOpacity(
              duration: fadeDuration,
              opacity: backOpacity,
              child: _ChromeIconButton(
                buttonKey: const Key('care-break-back'),
                onPressed: onBack,
                tooltip: 'Back to Care',
                icon: Icons.arrow_back_rounded,
              ),
            ),
            const Spacer(),
            if (contextStage || still) ...[
              // Flat, always-visible quiet controls for the context question
              // and for still scenes, where nothing recedes behind timing.
              if (onSafety != null) ...[
                _ChromeIconButton(
                  buttonKey: const Key('care-break-safety'),
                  onPressed: onSafety,
                  tooltip: 'Support and safety',
                  icon: Icons.health_and_safety_outlined,
                ),
                const SizedBox(width: 8),
              ],
              if (!contextStage && !settled)
                TextButton(
                  key: const Key('care-break-complete'),
                  onPressed: onEnough,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(64, 48),
                    foregroundColor: _kChromeIvory.withValues(alpha: 0.78),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text(
                    'Enough for now',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ] else
              AnimatedOpacity(
                duration: fadeDuration,
                opacity: handleOpacity,
                child: Semantics(
                  button: true,
                  label: menuOpen
                      ? 'Hide scene controls'
                      : 'Show scene controls',
                  child: IconButton(
                    key: const Key('care-scene-menu'),
                    onPressed: onToggleMenu,
                    tooltip: menuOpen
                        ? 'Hide scene controls'
                        : 'Show scene controls',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: _kChromeIvory.withValues(alpha: 0.9),
                      side: BorderSide(
                        width: 1,
                        color: _kChromeIvory.withValues(alpha: 0.14),
                      ),
                      shape: const CircleBorder(),
                    ),
                    icon: menuOpen
                        ? const Icon(Icons.close_rounded, size: 18)
                        : const _SceneHandleGlyph(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The resting mark of the scene controls: two hairlines and one acid-lime
/// point of life. Identical in all five worlds.
class _SceneHandleGlyph extends StatelessWidget {
  const _SceneHandleGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        children: [
          Positioned(
            right: 1,
            top: 2,
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: _kChromeAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 17,
                  height: 1.4,
                  color: _kChromeIvory.withValues(alpha: 0.75),
                ),
                const SizedBox(height: 5),
                Container(
                  width: 10,
                  height: 1.4,
                  color: _kChromeIvory.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The transient scene menu, authored in the same light/line language as the
/// scenes rather than a stock popup: a smoked-plum shelf that grows out of
/// the scene's right edge — flush on one side, a single 24px sweep on the
/// other — drawn with one 1px hairline weight throughout. Rows are separated
/// by hairlines that run out to the edge, and the only color is the lime
/// point that marks live sound. It gathers Support, Sound, Adjust, and the
/// early ending into one recoverable place, sits in the upper corner clear
/// of the canvas focal point, and dissolves on any scene touch.
class _SceneMenu extends StatelessWidget {
  const _SceneMenu({
    required this.showAdjust,
    required this.showEnough,
    required this.onAdjust,
    required this.onEnough,
    required this.onSafety,
    required this.soundEnabled,
    required this.soundAvailable,
    required this.onToggleSound,
  });

  final bool showAdjust;
  final bool showEnough;
  final VoidCallback onAdjust;
  final VoidCallback onEnough;
  final VoidCallback? onSafety;
  final bool soundEnabled;
  final bool soundAvailable;
  final VoidCallback onToggleSound;

  static const _radius = BorderRadius.only(
    topLeft: Radius.circular(24),
    bottomLeft: Radius.circular(24),
  );

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    // Stay compact and edge-aware: never wider than the scene minus enough
    // room for the Back anchor and the motion line's left margin.
    final width = math.min(232.0, MediaQuery.sizeOf(context).width - 88);

    final rows = <Widget>[];
    void addRow(Widget row) {
      if (rows.isNotEmpty) {
        rows.add(
          Container(
            height: 1,
            margin: const EdgeInsets.only(left: 16),
            color: _kChromeIvory.withValues(alpha: 0.08),
          ),
        );
      }
      rows.add(row);
    }

    final onSafety = this.onSafety;
    if (onSafety != null) {
      addRow(
        _SceneMenuItem(
          buttonKey: const Key('care-break-safety'),
          icon: Icons.health_and_safety_outlined,
          label: 'Support',
          onTap: onSafety,
        ),
      );
    }
    if (soundAvailable) {
      addRow(
        Semantics(
          button: true,
          toggled: soundEnabled,
          label: soundEnabled ? 'Turn sound off' : 'Turn sound on',
          child: _SceneMenuItem(
            buttonKey: const Key('care-break-sound'),
            icon: soundEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            label: soundEnabled ? 'Sound on' : 'Sound off',
            onTap: onToggleSound,
            trailing: _SoundMark(enabled: soundEnabled),
          ),
        ),
      );
    }
    if (showAdjust) {
      addRow(
        _SceneMenuItem(
          buttonKey: const Key('care-scene-adjust'),
          icon: Icons.tune_rounded,
          label: 'Adjust',
          onTap: onAdjust,
        ),
      );
    }
    if (showEnough) {
      addRow(
        _SceneMenuItem(
          buttonKey: const Key('care-break-complete'),
          icon: Icons.bedtime_outlined,
          label: 'Enough for now',
          onTap: onEnough,
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(18 * (1 - t), 0),
          child: child,
        ),
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: width,
            decoration: BoxDecoration(
              color: _kChromeSurface.withValues(alpha: 0.86),
              borderRadius: _radius,
              border: Border(
                top: BorderSide(
                  width: 1,
                  color: _kChromeIvory.withValues(alpha: 0.12),
                ),
                bottom: BorderSide(
                  width: 1,
                  color: _kChromeIvory.withValues(alpha: 0.12),
                ),
                left: BorderSide(
                  width: 1,
                  color: _kChromeIvory.withValues(alpha: 0.12),
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: rows),
          ),
        ),
      ),
    );
  }
}

class _SceneMenuItem extends StatelessWidget {
  const _SceneMenuItem({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: buttonKey,
      onTap: onTap,
      splashColor: _kChromeAccent.withValues(alpha: 0.06),
      highlightColor: _kChromeIvory.withValues(alpha: 0.04),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 18, 0),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _kChromeIvory.withValues(alpha: 0.8)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _kChromeIvory.withValues(alpha: 0.92),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// The sound state mark: the menu's one point of acid lime when sound is
/// live, a hollow 1px hairline ring when it rests — the same dot/line
/// grammar as the scene handle.
class _SoundMark extends StatelessWidget {
  const _SoundMark({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: enabled ? _kChromeAccent : Colors.transparent,
        border: enabled
            ? null
            : Border.all(
                width: 1,
                color: _kChromeIvory.withValues(alpha: 0.35),
              ),
      ),
    );
  }
}

/// After-care, arrived at rather than appended: the scene holds, a low
/// gradient steadies the lower third, and the three choices rise in
/// sequence — one glowing focal action and two quieter ways to leave.
class _SettledAfterCare extends StatelessWidget {
  const _SettledAfterCare({
    required this.visuals,
    required this.onStayLonger,
    required this.onCheckIn,
    required this.onDone,
  });

  final CareBreakVisuals visuals;
  final VoidCallback onStayLonger;
  final VoidCallback onCheckIn;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RiseIn(
            index: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: visuals.glow.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: -8,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FilledButton(
                key: const Key('care-check-in-when-ready'),
                onPressed: onCheckIn,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  foregroundColor: visuals.background,
                  backgroundColor: visuals.glow,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Check how it felt',
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _RiseIn(
            index: 2,
            child: OutlinedButton(
              key: const Key('care-stay-longer'),
              onPressed: onStayLonger,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: visuals.foreground.withValues(alpha: 0.85),
                side: BorderSide(
                  color: visuals.foreground.withValues(alpha: 0.2),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'Stay a little longer',
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          _RiseIn(
            index: 3,
            child: TextButton(
              key: const Key('care-settled-done'),
              onPressed: onDone,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: visuals.foreground.withValues(alpha: 0.5),
              ),
              child: const Text(
                'Done for now',
                textScaler: TextScaler.noScaling,
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The moment check, kept deliberately weightless: three equally-lit rows
/// behind hairlines so no answer feels preferred, inside the shared plum
/// chrome surface.
class _MomentCheckSheet extends StatelessWidget {
  const _MomentCheckSheet();

  @override
  Widget build(BuildContext context) {
    Widget choice({
      required Key key,
      required String label,
      required CareOutcome outcome,
      bool showDivider = true,
    }) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          key: key,
          onTap: () => Navigator.of(context).pop(outcome),
          splashColor: _kChromeAccent.withValues(alpha: 0.06),
          highlightColor: _kChromeIvory.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: _kChromeIvory.withValues(alpha: 0.92),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: _kChromeIvory.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 18,
            endIndent: 18,
            color: _kChromeIvory.withValues(alpha: 0.1),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: _kChromeIvory.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'How is this moment now?',
            style: TextStyle(
              color: _kChromeIvory,
              fontFamily: 'Newsreader',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose only what feels true. You can stay with the scene instead.',
            style: TextStyle(
              color: _kChromeIvory.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kChromeIvory.withValues(alpha: 0.12)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                choice(
                  key: const Key('care-moment-easier'),
                  label: 'A little easier',
                  outcome: CareOutcome.better,
                ),
                choice(
                  key: const Key('care-moment-same'),
                  label: 'About the same',
                  outcome: CareOutcome.same,
                ),
                choice(
                  key: const Key('care-moment-harder'),
                  label: 'Harder',
                  outcome: CareOutcome.worse,
                  showDivider: false,
                ),
              ],
            ),
          ),
          TextButton(
            key: const Key('care-moment-not-sure'),
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              foregroundColor: _kChromeIvory.withValues(alpha: 0.55),
            ),
            child: const Text('Not sure — stay here'),
          ),
        ],
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
    'the pressure is real.',
    'nothing has to spill.',
  ],
  CareMode.heavy => const [
    'crying is fine here',
    'you do not have to hold this up',
    'let the rain get lighter on its own',
  ],
  CareMode.racing => const [
    'your mind is loud, not broken',
    'you do not have to answer every thought',
    'let them wait in one line',
  ],
  CareMode.space => const [
    'you are allowed to need space',
    'the noise can stay outside',
    'no explanation is needed',
  ],
  CareMode.physical => switch (physicalContext) {
    PhysicalCareContext.headache => const [
      'nothing to follow here',
      'dim, still, and quiet',
      'leave whenever you need',
    ],
    PhysicalCareContext.cramps => const [
      'pain is enough reason to stop',
      'let warmth do the work',
      'nothing to make up for',
    ],
    PhysicalCareContext.nausea => const [
      'you do not have to push through',
      'let the water become level',
      'nothing else is required',
    ],
    PhysicalCareContext.tension || null => const [
      'you can put the weight down',
      'let the space widen around you',
      'nothing to make up for',
    ],
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
      settledCue: 'Press again if there is more. It holds either way',
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
      settledCue: 'You did not have to manage the rain',
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
      settledCue: 'The rest can wait outside this minute',
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
      settledCue: 'The loud room is still there. It is not yours right now',
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
      settledCue: 'Comfort first. You do not need to explain it',
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
