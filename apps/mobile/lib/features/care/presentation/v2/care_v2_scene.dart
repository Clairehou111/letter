import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/care_mode.dart';
import '../care_motion_flow.dart' show CareBreakVisuals;
import '../care_sound_engine.dart';
import 'care_v2_copy.dart';
import 'care_v2_kernel.dart';
import 'explode_v2_painter.dart';
import 'heavy_v2_painter.dart';

/// Care V2 scene shell for Explode and Heavy.
///
/// Shared behaviour, identical to V1 where it was already right:
/// - 90 second passive scene, quiet landing from 75 s, settled state at 90 s;
/// - bounded ending choices: stay another minute / check in when ready /
///   done for now;
/// - sound off by default, existing engine and asset mapping untouched, and
///   no volume change triggered by touch;
/// - no new haptic behaviour (V2 adds none);
/// - reduced motion renders a still composition with opacity transitions only.
///
/// What V2 changes is the interaction grammar: one optional contact that
/// yields locally, eases settling while it rests, and leaves one persistent
/// trace on release.
class CareSceneV2 extends StatefulWidget {
  const CareSceneV2({
    required this.mode,
    required this.onBack,
    this.onCheckIn,
    this.onDone,
    this.soundEngine,
    this.traceField,
    this.rainModel,
    super.key,
  }) : assert(
         mode == CareMode.explode || mode == CareMode.heavy,
         'Care V2 covers Explode and Heavy in this pass.',
       );

  final CareMode mode;
  final VoidCallback onBack;
  final VoidCallback? onCheckIn;
  final VoidCallback? onDone;
  final CareSoundEngine? soundEngine;
  final CareV2TraceField? traceField;
  final CareV2RainModel? rainModel;

  @override
  State<CareSceneV2> createState() => CareSceneV2State();
}

class CareSceneV2State extends State<CareSceneV2>
    with SingleTickerProviderStateMixin {
  late final AnimationController _session;
  late final CareSoundEngine _sound;
  late final CareV2TraceField _traces;
  late final CareV2RainModel _rain;
  final CareV2Settling _settling = CareV2Settling();

  CareV2Phase _phase = CareV2Phase.active;
  double _sceneDuration = CareV2Timeline.sceneSeconds;
  CareV2Contact? _contact;
  double? _sealedAt;
  bool _soundEnabled = false;

  /// Visible for tests: the persistent traces this run has accumulated.
  CareV2TraceField get traceField => _traces;

  CareV2Phase get phase => _phase;

  CareBreakVisuals get _visuals => CareBreakVisuals.forMode(widget.mode);

  double get _elapsed => _session.value * CareV2Timeline.controllerSeconds;

  @override
  void initState() {
    super.initState();
    _sound = widget.soundEngine ?? CareSoundEngine();
    _traces = widget.traceField ?? CareV2TraceField();
    _rain = widget.rainModel ?? CareV2RainModel();
    _session = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 600),
    )..addListener(_advancePhase);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _session.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _session.dispose();
    _sound.dispose();
    super.dispose();
  }

  /// The passive timeline always reaches the settled state, touched or not.
  void _advancePhase() {
    final next = CareV2Timeline.phaseFor(
      elapsed: _elapsed,
      sceneDuration: _sceneDuration,
      extending: _phase == CareV2Phase.extending,
    );
    if (next == _phase) return;
    if (next == CareV2Phase.settled) {
      _session.stop();
      _contact = null;
    }
    if (mounted) setState(() => _phase = next);
  }

  bool _still(BuildContext context) => MediaQuery.of(context).disableAnimations;

  bool get _interactive =>
      _phase == CareV2Phase.active || _phase == CareV2Phase.landing;

  Offset _unit(Offset local, Size size) => Offset(
    size.width == 0 ? 0.5 : local.dx / size.width,
    size.height == 0 ? 0.5 : local.dy / size.height,
  );

  void _contactDown(Offset local, Size size) {
    if (!_interactive || _still(context)) return;
    setState(() {
      _contact = CareV2Contact(
        position: _unit(local, size),
        startedAt: _elapsed,
        drift: 0,
      );
    });
  }

  void _contactMove(Offset local, Size size) {
    final current = _contact;
    if (current == null) return;
    setState(() => _contact = current.moveTo(_unit(local, size)));
  }

  /// Release leaves exactly one persistent consequence, merged into an
  /// existing trace when it lands close to one or when the cap is reached.
  void _contactUp() {
    final current = _contact;
    if (current == null) return;
    final held = current.heldFor(_elapsed);
    _settling.absorbHold(held);
    _traces.commit(current.position, at: _elapsed, held: held);
    setState(() => _contact = null);
  }

  void _stayAnotherMinute() {
    if (_phase != CareV2Phase.settled) return;
    _sceneDuration = _elapsed + CareV2Timeline.extensionSeconds;
    setState(() => _phase = CareV2Phase.extending);
    _session.forward(from: _session.value);
  }

  Future<void> _toggleSound() async {
    if (_soundEnabled) {
      setState(() => _soundEnabled = false);
      await _sound.stop();
      return;
    }
    final started = await _sound.play(widget.mode);
    if (!mounted) return;
    if (started) {
      setState(() => _soundEnabled = true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sound is not available in this prototype build.'),
      ),
    );
  }

  void _leave(VoidCallback callback) {
    _session.stop();
    _sound.stop();
    callback();
  }

  @override
  Widget build(BuildContext context) {
    final visuals = _visuals;
    final still = _still(context);

    return Scaffold(
      key: Key('care-v2-${widget.mode.name}'),
      backgroundColor: visuals.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) =>
                          _contactDown(event.localPosition, size),
                      onPointerMove: (event) =>
                          _contactMove(event.localPosition, size),
                      onPointerUp: (_) => _contactUp(),
                      onPointerCancel: (_) => _contactUp(),
                      child: AnimatedBuilder(
                        animation: _session,
                        builder: (context, _) => _sceneBody(size, still),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: _CareV2TopControls(
                        visuals: visuals,
                        soundEnabled: _soundEnabled,
                        soundAvailable: !still,
                        onBack: () => _leave(widget.onBack),
                        onToggleSound: _toggleSound,
                      ),
                    ),
                    if (_phase == CareV2Phase.settled)
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 16,
                        child: _CareV2SettledActions(
                          visuals: visuals,
                          onStayLonger: _stayAnotherMinute,
                          onCheckIn: () =>
                              _leave(widget.onCheckIn ?? widget.onBack),
                          onDone: () => _leave(widget.onDone ?? widget.onBack),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _sceneBody(Size size, bool still) {
    final visuals = _visuals;
    final elapsed = _elapsed;
    final contact = _contact;
    final hold = contact?.heldFor(elapsed) ?? 0;
    // Explode's material finishes closing before the landing, so the seal has
    // time to simply rest. Heavy's rain thins across the whole 90 seconds.
    final span = widget.mode == CareMode.explode ? 68.0 : 90.0;
    final settle = still
        ? 1.0
        : _settling.progress(elapsed, activeHold: hold, span: span);

    final landing = CareV2Timeline.landingProgress(elapsed);
    final traces = _traces.traces;
    final contactPoint = contact == null
        ? null
        : Offset(
            contact.position.dx * size.width,
            contact.position.dy * size.height,
          );

    if (widget.mode == CareMode.explode && settle >= 1 && _sealedAt == null) {
      _sealedAt = elapsed;
    }

    final painter = widget.mode == CareMode.explode
        ? ExplodeV2Painter(
            visuals: visuals,
            settle: settle,
            landing: landing,
            traces: traces,
            contact: contactPoint,
            contactHold: math.min(hold, 4),
            reducedMotion: still,
          )
        : HeavyV2Painter(
                visuals: visuals,
                rain: _rain,
                elapsed: elapsed,
                settle: settle,
                landing: landing,
                traces: traces,
                contact: contactPoint,
                contactHold: math.min(hold, 4),
                reducedMotion: still,
              )
              as CustomPainter;

    final sealedAt = _sealedAt;
    return Semantics(
      container: true,
      label: _phase == CareV2Phase.settled || _phase == CareV2Phase.extending
          ? visuals.settledSemantics
          : visuals.activeSemantics,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              key: Key('care-v2-canvas-${widget.mode.name}'),
              painter: painter,
              size: size,
            ),
          ),
          if (widget.mode == CareMode.explode && sealedAt != null)
            Align(
              alignment: const Alignment(0, -0.02),
              child: CareV2SealInscription(
                secondsSinceSeal: still ? 1 : elapsed - sealedAt,
                color: visuals.glow,
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: CareV2CopyLayer(
              elapsed: elapsed,
              lines: careV2Lines(widget.mode),
              color: visuals.foreground,
              glow: visuals.glow,
              phase: _phase,
              settledTitle: visuals.settledTitle,
              settledCue: visuals.settledCue,
              suppressed: contact != null,
              reducedMotion: still,
            ),
          ),
        ],
      ),
    );
  }
}

/// Scene copy, unchanged from V1: at most three short lines per path.
List<String> careV2Lines(CareMode mode) => switch (mode) {
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
  _ => const <String>[],
};

class _CareV2TopControls extends StatelessWidget {
  const _CareV2TopControls({
    required this.visuals,
    required this.soundEnabled,
    required this.soundAvailable,
    required this.onBack,
    required this.onToggleSound,
  });

  final CareBreakVisuals visuals;
  final bool soundEnabled;
  final bool soundAvailable;
  final VoidCallback onBack;
  final VoidCallback onToggleSound;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      child: Row(
        children: [
          IconButton(
            key: const Key('care-v2-back'),
            onPressed: onBack,
            tooltip: 'Leave this scene',
            iconSize: 20,
            color: visuals.foreground.withValues(alpha: 0.72),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const Spacer(),
          if (soundAvailable)
            IconButton(
              key: const Key('care-v2-sound'),
              onPressed: onToggleSound,
              tooltip: soundEnabled ? 'Turn sound off' : 'Turn sound on',
              iconSize: 20,
              color: visuals.foreground.withValues(alpha: 0.72),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(
                soundEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
              ),
            ),
        ],
      ),
    );
  }
}

/// Bounded ending choices, kept exactly as V1 offers them.
class _CareV2SettledActions extends StatelessWidget {
  const _CareV2SettledActions({
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
    final largeText = MediaQuery.textScalerOf(context).scale(12) >= 18;
    final stay = _actionButton(
      child: OutlinedButton(
        key: const Key('care-v2-stay-longer'),
        onPressed: onStayLonger,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: visuals.foreground.withValues(alpha: 0.72),
          side: BorderSide(color: visuals.foreground.withValues(alpha: 0.16)),
          shape: const StadiumBorder(),
        ),
        child: const Text(
          'Stay another minute',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ),
    );
    final checkIn = _actionButton(
      child: FilledButton(
        key: const Key('care-v2-check-in-when-ready'),
        onPressed: onCheckIn,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: visuals.background,
          backgroundColor: visuals.glow,
          shape: const StadiumBorder(),
        ),
        child: const Text(
          'Check in when ready',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: visuals.background.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: visuals.foreground.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (largeText) ...[
              stay,
              const SizedBox(height: 8),
              checkIn,
            ] else
              Row(
                children: [
                  Expanded(child: stay),
                  const SizedBox(width: 8),
                  Expanded(child: checkIn),
                ],
              ),
            TextButton(
              key: const Key('care-v2-done'),
              onPressed: onDone,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: visuals.foreground.withValues(alpha: 0.5),
              ),
              child: const Text('Done for now', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({required Widget child}) =>
      SizedBox(width: double.infinity, child: child);
}
