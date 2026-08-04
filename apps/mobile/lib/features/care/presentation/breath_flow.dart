import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../design_system/letter_theme.dart';
import 'care_haptics.dart';

/// Breathing patterns offered in Care. Durations are in seconds and follow
/// widely used slow-breathing guidance:
/// - Coherent: 5.5s in / 5.5s out (~5.5 breaths per minute)
/// - Long exhale: 4s in / 6s out, for settling a fast heart rate
/// - Box: 4s in / 4s hold / 4s out / 4s hold
enum BreathPattern { coherent, longExhale, box }

enum BreathPhase { inhale, holdIn, exhale, holdOut }

@immutable
class BreathPatternConfig {
  const BreathPatternConfig({
    required this.pattern,
    required this.label,
    required this.note,
    required this.inhale,
    required this.holdIn,
    required this.exhale,
    required this.holdOut,
  });

  final BreathPattern pattern;
  final String label;
  final String note;
  final double inhale;
  final double holdIn;
  final double exhale;
  final double holdOut;

  double get cycle => inhale + holdIn + exhale + holdOut;

  String get id => pattern.name;
}

const breathPatterns = <BreathPatternConfig>[
  BreathPatternConfig(
    pattern: BreathPattern.coherent,
    label: 'Even breathing',
    note: 'in 5.5, out 5.5 — the easiest place to start',
    inhale: 5.5,
    holdIn: 0,
    exhale: 5.5,
    holdOut: 0,
  ),
  BreathPatternConfig(
    pattern: BreathPattern.longExhale,
    label: 'Longer out-breath',
    note: 'in 4, out 6 — for a racing heart',
    inhale: 4,
    holdIn: 0,
    exhale: 6,
    holdOut: 0,
  ),
  BreathPatternConfig(
    pattern: BreathPattern.box,
    label: 'Four corners',
    note: 'in 4, hold 4, out 4, hold 4 — when thoughts need a shape',
    inhale: 4,
    holdIn: 4,
    exhale: 4,
    holdOut: 4,
  ),
];

/// A breathing activity for the Care physical-comfort path.
///
/// No streaks, no scores, no records. It can be left at any second, and the
/// closing card never asks for anything back.
class BreathFlow extends StatefulWidget {
  const BreathFlow({
    required this.onClose,
    super.key,
    this.initialPattern = BreathPattern.coherent,
    this.intensity = 0.6,
  });

  final VoidCallback onClose;
  final BreathPattern initialPattern;

  /// Scales haptic strength, mirroring the Care motion scenes.
  final double intensity;

  @override
  State<BreathFlow> createState() => _BreathFlowState();
}

class _BreathFlowState extends State<BreathFlow>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  late BreathPatternConfig _config;
  bool _running = false;
  bool _done = false;
  double _elapsed = 0;
  int _breaths = 0;
  BreathPhase _phase = BreathPhase.inhale;

  @override
  void initState() {
    super.initState();
    _config = breathPatterns.firstWhere(
      (candidate) => candidate.pattern == widget.initialPattern,
    );
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Duration _lastTick = Duration.zero;

  void _onTick(Duration now) {
    final delta = _lastTick == Duration.zero
        ? const Duration(milliseconds: 16)
        : now - _lastTick;
    _lastTick = now;
    final seconds = delta.inMicroseconds / 1000000;
    final next = _elapsed + seconds;
    final phase = _phaseAt(next);
    final crossedBreath = (next ~/ _config.cycle) > (_elapsed ~/ _config.cycle);
    setState(() {
      _elapsed = next;
      if (phase != _phase) {
        _phase = phase;
        _cuePhase(phase);
      }
      if (crossedBreath) {
        _breaths += 1;
      }
    });
  }

  BreathPhase _phaseAt(double elapsed) {
    var t = elapsed % _config.cycle;
    if (t < _config.inhale) return BreathPhase.inhale;
    t -= _config.inhale;
    if (t < _config.holdIn) return BreathPhase.holdIn;
    t -= _config.holdIn;
    if (t < _config.exhale) return BreathPhase.exhale;
    return BreathPhase.holdOut;
  }

  /// 0 at fully emptied, 1 at fully filled.
  double get _fill {
    var t = _elapsed % _config.cycle;
    if (t < _config.inhale) {
      return Curves.easeInOut.transform((t / _config.inhale).clamp(0, 1));
    }
    t -= _config.inhale;
    if (t < _config.holdIn) return 1;
    t -= _config.holdIn;
    if (t < _config.exhale) {
      return 1 - Curves.easeInOut.transform((t / _config.exhale).clamp(0, 1));
    }
    return 0;
  }

  void _cuePhase(BreathPhase phase) {
    switch (phase) {
      case BreathPhase.inhale:
        CareHaptics.tick(widget.intensity);
      case BreathPhase.holdIn:
      case BreathPhase.holdOut:
        CareHaptics.tick(widget.intensity * 0.6);
      case BreathPhase.exhale:
        CareHaptics.settle(widget.intensity);
    }
  }

  void _start() {
    CareHaptics.arm();
    setState(() {
      _running = true;
      _done = false;
      _elapsed = 0;
      _breaths = 0;
      _phase = BreathPhase.inhale;
    });
    _lastTick = Duration.zero;
    _ticker.start();
    _cuePhase(BreathPhase.inhale);
  }

  void _stop() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    setState(() {
      _running = false;
      _done = true;
    });
  }

  void _choosePattern(BreathPatternConfig config) {
    setState(() {
      _config = config;
      _elapsed = 0;
      _phase = BreathPhase.inhale;
    });
  }

  String get _phaseLabel => switch (_phase) {
    BreathPhase.inhale => 'in',
    BreathPhase.holdIn => 'hold',
    BreathPhase.exhale => 'out',
    BreathPhase.holdOut => 'rest',
  };

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: LetterColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  child: Row(
                    children: [
                      IconButton(
                        key: const Key('breath-back'),
                        tooltip: 'Back to physical comfort',
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Expanded(
                        child: Text(
                          'Breathing',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: LetterColors.muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                    child: _done
                        ? _buildDone()
                        : _running
                        ? _buildSession(reduceMotion)
                        : _buildIntro(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Column(
      key: const ValueKey('breath-intro'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LetterEyebrow('Breathing', color: LetterColors.teal),
        const SizedBox(height: LetterSpacing.xs),
        const Text(
          'Let the ring set the pace.',
          style: TextStyle(
            color: LetterColors.ink,
            fontFamily: 'Newsreader',
            fontSize: 28,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: LetterSpacing.sm),
        const Text(
          'Nothing to count and nothing to get right. Follow it loosely, or '
          'just watch it. You can stop at any second.',
          style: TextStyle(
            color: LetterColors.muted,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: LetterSpacing.lg),
        for (final config in breathPatterns) ...[
          _PatternChoice(
            config: config,
            selected: config.pattern == _config.pattern,
            onPressed: () => _choosePattern(config),
          ),
          const SizedBox(height: LetterSpacing.sm),
        ],
        const SizedBox(height: LetterSpacing.xs),
        FilledButton.icon(
          key: const Key('breath-start'),
          onPressed: _start,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: LetterColors.teal,
            foregroundColor: LetterColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LetterRadius.control),
            ),
          ),
          icon: const Icon(Icons.air),
          label: const Text('Begin'),
        ),
      ],
    );
  }

  Widget _buildSession(bool reduceMotion) {
    return Column(
      key: const ValueKey('breath-session'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: LetterSpacing.md),
        Semantics(
          liveRegion: true,
          label: 'Breathe $_phaseLabel',
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              key: const Key('breath-ring'),
              painter: _BreathRingPainter(
                fill: reduceMotion ? 0.5 : _fill,
                phaseLabel: _phaseLabel,
              ),
            ),
          ),
        ),
        const SizedBox(height: LetterSpacing.lg),
        Text(
          _breaths == 0
              ? _config.note
              : '$_breaths ${_breaths == 1 ? 'breath' : 'breaths'} so far. '
                    'That already counts.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: LetterColors.muted,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: LetterSpacing.lg),
        FilledButton.icon(
          key: const Key('breath-finish'),
          onPressed: _stop,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: LetterColors.teal,
            foregroundColor: LetterColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LetterRadius.control),
            ),
          ),
          icon: const Icon(Icons.check),
          label: const Text('That is enough'),
        ),
      ],
    );
  }

  Widget _buildDone() {
    return Column(
      key: const ValueKey('breath-done'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: LetterSpacing.xl),
        const Icon(Icons.spa_outlined, size: 68, color: LetterColors.teal),
        const SizedBox(height: LetterSpacing.lg),
        const LetterEyebrow('Enough for now', color: LetterColors.teal),
        const SizedBox(height: LetterSpacing.xs),
        Text(
          _breaths <= 1
              ? 'You stopped when you needed to.'
              : 'You stayed for $_breaths breaths.',
          style: const TextStyle(
            color: LetterColors.ink,
            fontFamily: 'Newsreader',
            fontSize: 29,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: LetterSpacing.sm),
        const Text(
          'Letter has not recorded this. Go slowly going back.',
          style: TextStyle(
            color: LetterColors.muted,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: LetterSpacing.xl),
        OutlinedButton.icon(
          key: const Key('breath-again'),
          onPressed: _start,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: LetterColors.ink,
            backgroundColor: LetterColors.surface,
            side: const BorderSide(color: LetterColors.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LetterRadius.control),
            ),
          ),
          icon: const Icon(Icons.refresh),
          label: const Text('Stay a little longer'),
        ),
        const SizedBox(height: LetterSpacing.sm),
        FilledButton.icon(
          key: const Key('breath-close'),
          onPressed: widget.onClose,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: LetterColors.teal,
            foregroundColor: LetterColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LetterRadius.control),
            ),
          ),
          icon: const Icon(Icons.grid_view_outlined),
          label: const Text('Back to physical comfort'),
        ),
      ],
    );
  }
}

class _PatternChoice extends StatelessWidget {
  const _PatternChoice({
    required this.config,
    required this.selected,
    required this.onPressed,
  });

  final BreathPatternConfig config;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: Key('breath-pattern-${config.id}'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(62),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        alignment: Alignment.centerLeft,
        foregroundColor: LetterColors.ink,
        backgroundColor: selected ? LetterColors.tealSoft : LetterColors.surface,
        side: BorderSide(
          color: selected ? LetterColors.teal : LetterColors.line,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.control),
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 22,
            color: selected ? LetterColors.teal : LetterColors.muted,
          ),
          const SizedBox(width: LetterSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  config.label,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  config.note,
                  style: const TextStyle(
                    color: LetterColors.muted,
                    fontSize: 13,
                    height: 1.3,
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

class _BreathRingPainter extends CustomPainter {
  _BreathRingPainter({required this.fill, required this.phaseLabel});

  final double fill;
  final String phaseLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - 8;
    final minRadius = maxRadius * 0.42;
    final radius = minRadius + (maxRadius - minRadius) * fill.clamp(0, 1);

    canvas.drawCircle(
      center,
      maxRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = LetterColors.line,
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = LetterColors.tealSoft.withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = LetterColors.teal.withValues(alpha: 0.55),
    );

    final painter = TextPainter(
      text: TextSpan(
        text: phaseLabel,
        style: const TextStyle(
          color: LetterColors.tealDark,
          fontFamily: 'Newsreader',
          fontSize: 30,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_BreathRingPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.phaseLabel != phaseLabel;
}
