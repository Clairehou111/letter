import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';

/// Shown the moment someone marks suicidal thoughts or self-harm, before the
/// safety boundary sheet.
///
/// It is not a distraction and not a substitute for help: it holds the moment
/// for a few seconds, says plainly that the body is still working for them,
/// and then hands over to real crisis contacts. Skippable at any point, and it
/// records nothing.
class CellSupportStage extends StatefulWidget {
  const CellSupportStage({
    required this.onContinue,
    super.key,
    this.duration = const Duration(seconds: 35),
  });

  /// Called when the sequence ends, or when the person skips ahead.
  final VoidCallback onContinue;
  final Duration duration;

  @override
  State<CellSupportStage> createState() => _CellSupportStageState();
}

class _CellSupportStageState extends State<CellSupportStage>
    with SingleTickerProviderStateMixin {
  static const _lines = <String>[
    'Right now, without being asked, your heart is still beating for you.',
    'Your lungs are still taking the next breath. Your blood is still '
        'carrying it everywhere it is needed.',
    'Millions of cells are working through this night on your behalf. None of '
        'them have given up on you.',
    'You are held by more than you can feel right now — and by more people '
        'than your mind is letting you count.',
    'This pain is real. It is also not the whole truth about your life.',
    'You do not have to carry this alone for one more minute.',
  ];

  late final AnimationController _controller;
  late final List<_Cell> _cells;

  @override
  void initState() {
    super.initState();
    final random = math.Random(7);
    _cells = List.generate(
      42,
      (index) => _Cell(
        origin: Offset(random.nextDouble(), random.nextDouble()),
        radius: 6 + random.nextDouble() * 16,
        phase: random.nextDouble() * math.pi * 2,
        speed: 0.35 + random.nextDouble() * 0.5,
        drift: (random.nextDouble() - 0.5) * 0.06,
      ),
    );
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          widget.onContinue();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _lineIndexFor(double t) {
    final index = (t * _lines.length).floor();
    return index.clamp(0, _lines.length - 1);
  }

  double _lineOpacityFor(double t) {
    final slot = 1 / _lines.length;
    final local = (t % slot) / slot;
    if (local < 0.18) return local / 0.18;
    if (local > 0.86) return (1 - local) / 0.14;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion && _controller.isAnimating) {
      // Keep the words, drop the motion.
      _controller.stop();
    }

    return Scaffold(
      backgroundColor: LetterColors.night,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => CustomPaint(
              key: const Key('cell-support-field'),
              painter: _CellFieldPainter(
                cells: _cells,
                time: reduceMotion ? 0.35 : _controller.value * 24,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'You are still here',
                          style: TextStyle(
                            color: Color(0xFFB9C4C6),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('cell-support-skip'),
                        onPressed: widget.onContinue,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(64, 44),
                          foregroundColor: const Color(0xFFB9C4C6),
                        ),
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            final t = _controller.value.clamp(0.0, 0.9999);
                            final index = _lineIndexFor(t);
                            return Semantics(
                              liveRegion: true,
                              child: Opacity(
                                opacity: reduceMotion
                                    ? 1
                                    : _lineOpacityFor(t).clamp(0.0, 1.0),
                                child: Text(
                                  _lines[index],
                                  key: const Key('cell-support-line'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFF2F4F1),
                                    fontFamily: 'Newsreader',
                                    fontSize: 25,
                                    height: 1.3,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    key: const Key('cell-support-continue'),
                    onPressed: widget.onContinue,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: LetterColors.safetyRed,
                      foregroundColor: LetterColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          LetterRadius.control,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.health_and_safety_outlined),
                    label: const Text('Reach someone now'),
                  ),
                  const SizedBox(height: LetterSpacing.xs),
                  const Text(
                    'Letter is not a crisis service. The next screen has real '
                    'people you can call or text.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9FAAAC),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class _Cell {
  const _Cell({
    required this.origin,
    required this.radius,
    required this.phase,
    required this.speed,
    required this.drift,
  });

  final Offset origin;
  final double radius;
  final double phase;
  final double speed;
  final double drift;
}

/// A slow field of soft, breathing cells — deliberately organic and quiet, not
/// clinical or alarming.
class _CellFieldPainter extends CustomPainter {
  _CellFieldPainter({required this.cells, required this.time});

  final List<_Cell> cells;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF161B1D), Color(0xFF0E1213)],
        ).createShader(Offset.zero & size),
    );

    for (final cell in cells) {
      final pulse = 0.5 + 0.5 * math.sin(time * cell.speed + cell.phase);
      final dy = math.sin(time * cell.speed * 0.4 + cell.phase) * cell.drift;
      final center = Offset(
        cell.origin.dx * size.width,
        ((cell.origin.dy + dy) % 1) * size.height,
      );
      final radius = cell.radius * (0.78 + pulse * 0.35);

      canvas.drawCircle(
        center,
        radius * 2.4,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = LetterColors.teal.withValues(alpha: 0.05 + pulse * 0.05),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = const Color(
            0xFF7FC4B6,
          ).withValues(alpha: 0.10 + pulse * 0.12),
      );
      canvas.drawCircle(
        center,
        radius * 0.34,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = LetterColors.moonMetal.withValues(
            alpha: 0.10 + pulse * 0.14,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_CellFieldPainter oldDelegate) =>
      oldDelegate.time != time;
}
