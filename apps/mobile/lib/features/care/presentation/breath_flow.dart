import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../design_system/letter_theme.dart';

/// A breathing activity inside Care.
///
/// Painted on an accumulating canvas buffer washed back each frame — motion
/// leaves translucent trails instead of looking like a resizing widget. The
/// ambience swells with the in-breath and eases down with the out-breath, so
/// the pace can be followed with eyes closed or the phone face-down. Nothing
/// counts down; it runs until you leave.
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

// ── Mote: a tiny floating point of light that drifts with the breath ──

class _Mote {
  _Mote(this.a, this.d, this.r, this.tw, this.drift);
  double a; // angle
  double d; // distance in units of base radius
  double r; // dot radius
  double tw; // twinkle phase offset
  double drift; // slow angular drift direction (+1 or -1)
}

/// Full-screen breathing activity. Push as a MaterialPageRoute.
class BreathFlow extends StatefulWidget {
  const BreathFlow({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<BreathFlow> createState() => _BreathFlowState();
}

class _BreathFlowState extends State<BreathFlow>
    with SingleTickerProviderStateMixin {
  final _rnd = Random();
  final _repaint = ValueNotifier<int>(0);

  Ticker? _ticker;
  ui.Image? _buffer;

  // Audio
  SoLoud? _soloud;
  AudioSource? _audioSource;
  SoundHandle? _audioHandle;
  bool _audioReady = false;

  double _w = 0, _h = 0, _dpr = 1;
  double _t = 0;
  Duration _last = Duration.zero;

  BreathPattern _pattern = BreathPattern.coherent;
  bool _picking = false;
  int _phaseIndex = -1;
  bool _minutePassed = false;

  late final List<_Mote> _motes;

  /// eased 0..1 fullness of the breath, and which way it is travelling
  double _expand = 0;
  int _kind = 0;
  String _word = 'in';
  bool _sound = false;

  // ── Letter palette ────────────────────────────────────────────────
  static const _bg = LetterColors.night;
  static const _ink = LetterColors.canvas;
  static const _glow = LetterColors.moonMetal;
  static const _breathAsset = 'assets/audio/care/prototype/breath.mp3';

  @override
  void initState() {
    super.initState();
    _motes = List.generate(
      54,
      (i) => _Mote(
        _rnd.nextDouble() * pi * 2,
        1.15 + _rnd.nextDouble() * 3.6,
        0.7 + _rnd.nextDouble() * 1.7,
        _rnd.nextDouble() * pi * 2,
        (_rnd.nextBool() ? 1 : -1) * (0.02 + _rnd.nextDouble() * 0.07),
      ),
    );
    _ticker = createTicker(_tick)..start();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      _soloud = SoLoud.instance;
      await _soloud!.init();
      _audioSource = await _soloud!.loadAsset(_breathAsset);
      _audioReady = true;
    } catch (_) {
      // Audio unavailable — visual only.
    }
  }

  Future<void> _startAudio() async {
    if (!_audioReady || _audioSource == null || _audioHandle != null) return;
    try {
      _audioHandle = _soloud!.play(
        _audioSource!,
        volume: 0,
        looping: true,
      );
    } catch (_) {
      // Silently fail — audio is optional.
    }
  }

  Future<void> _stopAudio() async {
    if (_audioHandle != null) {
      try {
        await _soloud!.stop(_audioHandle!);
      } catch (_) {}
      _audioHandle = null;
    }
  }

  void _setAudioLevel(double level) {
    if (_audioHandle == null) return;
    try {
      _soloud!.setVolume(_audioHandle!, level.clamp(0.0, 0.6));
    } catch (_) {}
  }

  void _toggleSound() {
    final next = !_sound;
    setState(() => _sound = next);
    if (next) {
      _startAudio();
    } else {
      _setAudioLevel(0);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _buffer?.dispose();
    _stopAudio();
    _soloud?.deinit();
    super.dispose();
  }

  List<BreathPhase> get _phases => breathPatternInfo(_pattern).phases;
  double get _cycleSeconds => _phases.fold(0.0, (a, p) => a + p.seconds);

  ({BreathPhase phase, int index, double t}) _at(double seconds) {
    var x = seconds % _cycleSeconds;
    for (var i = 0; i < _phases.length; i++) {
      final p = _phases[i];
      if (x < p.seconds) return (phase: p, index: i, t: x / p.seconds);
      x -= p.seconds;
    }
    return (phase: _phases.last, index: _phases.length - 1, t: 1);
  }

  void _turn(BreathPhase phase) {
    switch (phase.kind) {
      case 0:
        HapticFeedback.lightImpact();
      case 1:
        HapticFeedback.mediumImpact();
      default:
        HapticFeedback.heavyImpact();
    }
  }

  void _tick(Duration now) {
    if (_w <= 0 || _h <= 0) return;
    final dt = min(0.05, max(0.0, (now - _last).inMicroseconds / 1e6));
    _last = now;
    if (dt <= 0) return;
    _t += dt;

    final at = _at(_t);
    _kind = at.phase.kind;
    _expand = switch (at.phase.kind) {
      0 => Curves.easeInOut.transform(at.t),
      1 => 1.0,
      _ => 1 - Curves.easeInOut.transform(at.t),
    };

    if (at.index != _phaseIndex) {
      _phaseIndex = at.index;
      _turn(at.phase);
      // Audio swells with the in-breath, eases with the out-breath.
      if (_sound) {
        _setAudioLevel(at.phase.kind == 2 ? 0.25 : 0.5);
      }
      if (_word != at.phase.word) {
        setState(() => _word = at.phase.word);
      }
    }
    if (!_minutePassed && _t > 60) {
      setState(() => _minutePassed = true);
    }

    _drawBuffer(dt);
  }

  // ── Generative canvas buffer ──────────────────────────────────────
  // Each frame draws the previous frame's image (creating motion trails),
  // washes it with a translucent background, then paints the current ring,
  // halos, and drifting motes on top.

  void _drawBuffer(double dt) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, _w * _dpr, _h * _dpr));
    canvas.scale(_dpr);

    final prev = _buffer;
    if (prev != null) {
      canvas.drawImageRect(
        prev,
        Rect.fromLTWH(0, 0, prev.width.toDouble(), prev.height.toDouble()),
        Rect.fromLTWH(0, 0, _w, _h),
        Paint(),
      );
    }

    _draw(canvas, dt);

    final pic = rec.endRecording();
    final img = pic.toImageSync((_w * _dpr).round(), (_h * _dpr).round());
    pic.dispose();
    _buffer?.dispose();
    _buffer = img;
    _repaint.value++;
  }

  Paint _add(Color c, double a) => Paint()
    ..blendMode = BlendMode.plus
    ..color = c.withValues(alpha: a.clamp(0.0, 1.0))
    ..isAntiAlias = true;

  void _draw(Canvas canvas, double dt) {
    final full = Rect.fromLTWH(0, 0, _w, _h);

    // translucent wash that turns old motion into trails
    canvas.drawRect(full, Paint()..color = _bg.withValues(alpha: 0.18));

    final center = Offset(_w / 2, _h * 0.44);
    final base = min(_w, _h) * 0.16;
    final k = 0.35 + 0.65; // full intensity
    final r = base + base * 0.85 * _expand;

    // deep field wash, warming as the breath fills
    canvas.drawRect(
      full,
      _add(_glow, (0.012 + 0.020 * _expand) * k)
        ..shader = ui.Gradient.radial(
          center,
          max(_w, _h) * 0.78,
          [
            _glow.withValues(alpha: (0.05 + 0.07 * _expand) * k),
            const Color(0x00000000),
          ],
          [0.0, 1.0],
        ),
    );

    // halos trailing the ring — warmth spreading
    for (var i = 4; i >= 1; i--) {
      final f = i / 4;
      canvas.drawCircle(
        center,
        r * (1 + f * 0.5),
        _add(_glow, (0.014 * (1 - f) + 0.010) * k)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16 + 30 * f),
      );
    }

    // the ring itself: a bloom and a hairline
    canvas.drawCircle(
      center,
      r,
      _add(_glow, (0.030 + 0.030 * _expand) * k)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.drawCircle(
      center,
      r,
      _add(_ink, (0.10 + 0.11 * _expand) * k)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );

    // motes drift inward on in-breath, outward on out-breath —
    // nothing on screen stands still
    final pull = _kind == 0 ? -1.0 : (_kind == 1 ? 0.0 : 1.0);
    for (final m in _motes) {
      m.d += pull * dt * (0.16 + 0.20);
      m.a += m.drift * dt;
      if (m.d < 1.0) m.d = 1.0 + (1.0 - m.d) * 0.5;
      if (m.d > 4.9) m.d = 4.9 - (m.d - 4.9) * 0.5;
      final wob = sin(_t * 0.32 + m.tw) * 5;
      final pos = center +
          Offset(
            cos(m.a) * (base * m.d + wob),
            sin(m.a) * (base * m.d + wob) * 0.74,
          );
      final tw = 0.55 + 0.45 * sin(_t * 0.7 + m.tw);
      canvas.drawCircle(
        pos,
        m.r * (0.85 + 0.3 * _expand),
        _add(_glow, (0.05 + 0.07 * _expand) * tw * k),
      );
    }
  }

  // ── UI ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: LayoutBuilder(
        builder: (context, box) {
          final dpr = MediaQuery.of(context).devicePixelRatio;
          if (box.maxWidth != _w ||
              box.maxHeight != _h ||
              dpr != _dpr) {
            _w = box.maxWidth;
            _h = box.maxHeight;
            _dpr = dpr;
            _buffer?.dispose();
            _buffer = null;
          }

          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(_w, _h),
                    painter: _BufferPainter(this, _repaint),
                  ),
                ),
              ),
              // the word, low in the frame — no counter, no progress bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 148,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 700),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.18),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: anim,
                            curve: Curves.easeOut,
                          ),
                        ),
                        child: child,
                      ),
                    ),
                    child: Text(
                      _word,
                      key: ValueKey(_word),
                      style: TextStyle(
                        fontFamily: 'Newsreader',
                        fontSize: 30,
                        letterSpacing: 1,
                        color: _glow
                            .withValues(alpha: _kind == 1 ? 0.55 : 0.88),
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
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _glow.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              // Per-activity sound toggle (top-right)
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, right: 12),
                    child: _Ghost(
                      label: _sound ? 'sound on' : 'sound off',
                      glow: _glow,
                      onTap: _toggleSound,
                    ),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24),
                            child: ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 384),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
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
                    padding: const EdgeInsets.only(
                        bottom: 28, left: 20, right: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _Ghost(
                          label: 'Back',
                          glow: _glow,
                          onTap: widget.onClose,
                        ),
                        _Ghost(
                          label: breathPatternInfo(_pattern)
                              .label
                              .toLowerCase(),
                          glow: _glow,
                          onTap: () =>
                              setState(() => _picking = !_picking),
                        ),
                        _Ghost(
                          label: "that's enough",
                          glow: _glow,
                          onTap: widget.onClose,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Buffer painter (renders the accumulating canvas) ────────────────

class _BufferPainter extends CustomPainter {
  _BufferPainter(this.state, Listenable repaint) : super(repaint: repaint);

  final _BreathFlowState state;

  @override
  void paint(Canvas canvas, Size size) {
    final img = state._buffer;
    if (img == null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = _BreathFlowState._bg,
      );
      return;
    }
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(covariant _BufferPainter old) => true;
}

// ── Pattern picker ──────────────────────────────────────────────────

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
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.label,
                    style: TextStyle(
                        fontSize: 14,
                        color: glow.withValues(alpha: 0.9))),
                const SizedBox(height: 3),
                Text(info.note,
                    style: TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: glow.withValues(alpha: 0.5))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Ghost extends StatelessWidget {
  const _Ghost({
    required this.label,
    required this.glow,
    required this.onTap,
  });

  final String label;
  final Color glow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: glow.withValues(alpha: 0.65),
        textStyle:
            const TextStyle(fontSize: 11.5, letterSpacing: 0.6),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: Text(label),
    );
  }
}
