import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../design_system/letter_theme.dart';

/// A breathing activity inside "My body needs care".
///
/// Learned from what holds up in the calm apps that do this well:
/// Apple Breathe's single expanding ring with no numbers, Headspace naming the
/// pattern, Oak letting you pick a pace. What's deliberately left out: counters,
/// progress bars, a fixed session length, and any breath-holding by default —
/// holds can make anxiety and cramping worse.
///
/// Default is coherent breathing at ~5.5 breaths/min (5.5s in, 5.5s out), the
/// pattern with the strongest calming evidence. The visual is the instruction.
/// Haptics carry the rhythm so it works with eyes closed, phone face-down.
/// Nothing counts down; it runs until you leave.
///
/// Deliberately quieter to look at than the other scenes: this is the one
/// activity where nothing should be moving except your breathing, so it stays a
/// single ring rather than a generative field you could end up tracking.
///
/// The sound is a human voice, not a synth pad — the same thing Calm,
/// Headspace, Breathwrk and Oak all land on. Sparse words at the turning points
/// only, a long silence in between, and a very low warm bed underneath so the
/// silence isn't dead air. Off by default; `wordless` swaps the words for soft
/// hums for when language is too much.
enum BreathPattern { coherent, longExhale, box }

class BreathPhase {
  const BreathPhase(this.word, this.seconds, this.kind);
  final String word;
  final double seconds;

  /// 0 = inhale, 1 = hold, 2 = exhale
  final int kind;
}

class BreathPatternInfo {
  const BreathPatternInfo(this.id, this.label, this.note, this.phases);
  final BreathPattern id;
  final String label;
  final String note;
  final List<BreathPhase> phases;
}

const breathPatterns = <BreathPatternInfo>[
  BreathPatternInfo(
    BreathPattern.coherent,
    'Even breathing',
    'in 5.5, out 5.5 — the calm default, nothing held',
    [BreathPhase('in', 5.5, 0), BreathPhase('out', 5.5, 2)],
  ),
  BreathPatternInfo(
    BreathPattern.longExhale,
    'Longer out-breath',
    'in 4, out 8 — for when it tips into panic',
    [BreathPhase('in', 4, 0), BreathPhase('out', 8, 2)],
  ),
  BreathPatternInfo(
    BreathPattern.box,
    'Four corners',
    'in 4, hold 4, out 4, hold 4 — for scattered focus',
    [
      BreathPhase('in', 4, 0),
      BreathPhase('hold', 4, 1),
      BreathPhase('out', 4, 2),
      BreathPhase('hold', 4, 1),
    ],
  ),
];

BreathPatternInfo breathPatternInfo(BreathPattern p) =>
    breathPatterns.firstWhere((b) => b.id == p);

class BreathFlow extends StatefulWidget {
  const BreathFlow({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<BreathFlow> createState() => _BreathFlowState();
}

class _BreathFlowState extends State<BreathFlow> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  BreathPattern _pattern = BreathPattern.coherent;
  bool _picking = false;
  int _phaseIndex = -1;
  bool _minutePassed = false;

  // Audio
  SoLoud? _soloud;
  AudioSource? _bedSource;
  SoundHandle? _bedHandle;
  bool _audioReady = false;
  bool _sound = false;

  // ── Letter palette ────────────────────────────────────────────────
  static const _bg = LetterColors.night;
  static const _ink = LetterColors.canvas;
  static const _glow = LetterColors.moonMetal;

  @override
  void initState() {
    super.initState();
    _initAudio();
    _ticker = createTicker((d) {
      setState(() => _elapsed = d);
      _onFrame(d.inMicroseconds / 1e6);
    })
      ..start();
  }

  static const _bedAsset = 'assets/audio/care/prototype/breath.mp3';

  Future<void> _initAudio() async {
    try {
      _soloud = SoLoud.instance;
      await _soloud!.init();
      _bedSource = await _soloud!.loadAsset(_bedAsset);
      _audioReady = true;
    } catch (_) {}
  }

  Future<void> _startBed() async {
    if (!_audioReady || _bedSource == null || _bedHandle != null) return;
    try {
      _bedHandle = _soloud!.play(_bedSource!, volume: 0, looping: true);
    } catch (_) {}
  }

  void _setSwell(double v) {
    if (_bedHandle == null || !_sound) return;
    try {
      _soloud!.setVolume(_bedHandle!, (v * 0.5).clamp(0.0, 0.5));
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker.dispose();
    if (_bedHandle != null) {
      try { _soloud!.stop(_bedHandle!); } catch (_) {}
    }
    _soloud?.deinit();
    super.dispose();
  }

  List<BreathPhase> get _phases => breathPatternInfo(_pattern).phases;
  double get _cycleSeconds => _phases.fold(0.0, (a, p) => a + p.seconds);

  /// Position inside the current cycle, and which phase that lands in.
  ({BreathPhase phase, int index, double t}) _at(double seconds) {
    var x = seconds % _cycleSeconds;
    for (var i = 0; i < _phases.length; i++) {
      final p = _phases[i];
      if (x < p.seconds) return (phase: p, index: i, t: x / p.seconds);
      x -= p.seconds;
    }
    return (phase: _phases.last, index: _phases.length - 1, t: 1);
  }

  void _toggleSound() {
    final next = !_sound;
    setState(() => _sound = next);
    if (next) {
      _startBed();
    } else {
      _setSwell(0);
    }
  }

  void _onFrame(double seconds) {
    if (!_minutePassed && seconds > 60) _minutePassed = true;
    final now = _at(seconds);
    if (now.index == _phaseIndex) return;
    _phaseIndex = now.index;
    // one soft cue at each turning point, nothing during the phase itself
    switch (now.phase.kind) {
      case 0: HapticFeedback.lightImpact();
      case 1: HapticFeedback.mediumImpact();
      default: HapticFeedback.heavyImpact();
    }
    _setSwell(now.phase.kind == 2 ? 0.72 : 1.16);
  }

String get _soundLabel => _sound ? 'sound on' : 'sound off';

  @override
  Widget build(BuildContext context) {
    // Letter palette
    final seconds = _elapsed.inMicroseconds / 1e6;
    final now = _at(seconds);

    // radius eases with the breath: fuller on the in-breath, held flat on holds
    final eased = switch (now.phase.kind) {
      0 => Curves.easeInOut.transform(now.t),
      1 => 1.0,
      _ => 1 - Curves.easeInOut.transform(now.t),
    };
    final hold = now.phase.kind == 1;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _BreathPainter(
                expand: eased,
                seconds: seconds,
                ink: _ink,
                glow: _glow,
                bg: _bg,
              ),
            ),
          ),
          // the word, low in the frame — no counter, no progress bar. It
          // cross-fades rather than snapping, so nothing arrives abruptly.
          Positioned(
            left: 0,
            right: 0,
            bottom: 148,
            child: Center(
              child: AnimatedOpacity(
                opacity: hold ? 0.5 : 0.85,
                duration: const Duration(milliseconds: 400),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 900),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: Text(
                    now.phase.word,
                    key: ValueKey('${now.phase.word}-${now.index}'),
                    style: TextStyle(
                      fontFamily: 'Newsreader',
                      fontSize: 30,
                      letterSpacing: 1,
                      color: _glow.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_minutePassed)
            Positioned(
              left: 24,
              right: 24,
              bottom: 112,
              child: Center(
                child: Text(
                  "that's a minute. stay as long as you like.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: _glow.withValues(alpha: 0.4)),
                ),
              ),
            ),
          if (_picking)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _picking = false),
                child: ColoredBox(
                  color: _bg.withValues(alpha: 0.88),
                  child: SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 384),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final b in breathPatterns)
                                _PatternChoice(
                                  info: b,
                                  selected: b.id == _pattern,
                                  glow: _glow,
                                  onTap: () => setState(() {
                                    _pattern = b.id;
                                    _phaseIndex = -1;
                                    _picking = false;
                                  }),
                                ),
                              const SizedBox(height: 10),
                              _PatternChoice(
                                info: BreathPatternInfo(
                                  _pattern,
                                  _sound ? 'Sound: on' : 'Sound: off',
                                  _sound
                                      ? 'ambient bed — swells with the breath'
                                      : 'silent — the ring and haptics are enough',
                                  const [],
                                ),
                                selected: _sound,
                                glow: _glow,
                                onTap: _toggleSound,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28, left: 20, right: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Ghost(label: 'Back', glow: _glow, onTap: widget.onClose),
                    _Ghost(
                      label: '${breathPatternInfo(_pattern).label.toLowerCase()}'
                          ' · $_soundLabel',
                      glow: _glow,
                      onTap: () => setState(() => _picking = !_picking),
                    ),
                    _Ghost(label: "that's enough", glow: _glow, onTap: widget.onClose),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternChoice extends StatelessWidget {
  const _PatternChoice({
    required this.info,
    required this.selected,
    required this.glow,
    required this.onTap,
  });

  final BreathPatternInfo info;
  final bool selected;
  final Color glow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: glow.withValues(alpha: selected ? 0.14 : 0.06),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.label,
                    style: TextStyle(fontSize: 14, color: glow.withValues(alpha: 0.9))),
                const SizedBox(height: 3),
                Text(info.note,
                    style: TextStyle(
                        fontSize: 11.5, height: 1.5, color: glow.withValues(alpha: 0.5))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Ghost extends StatelessWidget {
  const _Ghost({required this.label, required this.glow, required this.onTap});
  final String label;
  final Color glow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: glow.withValues(alpha: 0.65),
        textStyle: const TextStyle(fontSize: 11.5, letterSpacing: 0.6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: Text(label),
    );
  }
}

/// One soft ring, breathing. Concentric halos trail behind it so the motion
/// reads as warmth spreading rather than a shape resizing.
class _BreathPainter extends CustomPainter {
  _BreathPainter({
    required this.expand,
    required this.seconds,
    required this.ink,
    required this.glow,
    required this.bg,
  });

  final double expand;
  final double seconds;
  final Color ink;
  final Color glow;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.44);
    final base = min(size.width, size.height) * 0.16;
    final reach = base * 0.7;
    final r = base + reach * expand;

    // deep field wash
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [glow.withValues(alpha: 0.10 + 0.10 * expand), bg],
          stops: const [0, 1],
        ).createShader(Rect.fromCircle(center: center, radius: size.height * 0.8)),
    );

    // trailing halos
    for (var i = 4; i >= 1; i--) {
      final k = i / 4;
      canvas.drawCircle(
        center,
        r * (1 + k * 0.55),
        Paint()
          ..color = glow.withValues(alpha: 0.05 * (1 - k) + 0.03)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 + 26 * k),
      );
    }

    // the ring itself
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = glow.withValues(alpha: 0.16 + 0.12 * expand)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = ink.withValues(alpha: 0.45 + 0.35 * expand),
    );

    // a slow drift of motes so the field is never quite static
    final rnd = Random(7);
    for (var i = 0; i < 26; i++) {
      final a = rnd.nextDouble() * pi * 2;
      final d = base * (1.4 + rnd.nextDouble() * 3.4);
      final wob = sin(seconds * 0.22 + i) * 8;
      final p = center + Offset(cos(a) * (d + wob), sin(a) * (d + wob) * 0.72);
      canvas.drawCircle(
        p,
        0.9 + rnd.nextDouble() * 1.6,
        Paint()..color = glow.withValues(alpha: 0.05 + 0.09 * expand),
      );
    }
  }

  @override
  bool shouldRepaint(_BreathPainter old) => true;
}
