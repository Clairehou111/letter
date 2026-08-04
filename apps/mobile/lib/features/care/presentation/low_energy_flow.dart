import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';

/// For the days when even choosing a feeling is too much.
///
/// Nothing here asks for a gesture, a choice, or a word. A dim field drifts,
/// a few lines arrive on their own, and it ends by itself. Records nothing.
class LowEnergyFlow extends StatefulWidget {
  const LowEnergyFlow({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  State<LowEnergyFlow> createState() => _LowEnergyFlowState();
}

class _LowEnergyFlowState extends State<LowEnergyFlow>
    with SingleTickerProviderStateMixin {
  static const _lines = <String>[
    'You do not have to pick anything.',
    'Nothing here needs an answer.',
    'You are still here. That was the hard part.',
    'Your body kept going while you had nothing left.',
    'This much is allowed to be all of it.',
    'Stay as long as you want. Leaving costs nothing.',
  ];

  late final AnimationController _controller;
  Timer? _advanceTimer;
  int _lineIndex = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 12))
          ..repeat();
    _advance();
  }

  void _advance() {
    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(seconds: 9), () {
      if (!mounted) {
        return;
      }
      if (_lineIndex >= _lines.length - 1) {
        setState(() => _finished = true);
        return;
      }
      setState(() => _lineIndex += 1);
      _advance();
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: LetterColors.night,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: reduceMotion
                  ? const ColoredBox(color: LetterColors.night)
                  : AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => CustomPaint(
                        painter: _StillFieldPainter(t: _controller.value),
                      ),
                    ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                key: const Key('low-energy-close'),
                tooltip: 'Leave',
                onPressed: widget.onClose,
                icon: const Icon(
                  Icons.close,
                  color: Color(0x99FFFFFF),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 900),
                        child: Text(
                          _lines[_lineIndex],
                          key: ValueKey(_lineIndex),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFF1EFE9),
                            fontFamily: 'Newsreader',
                            fontSize: 25,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_finished) ...[
                        const SizedBox(height: LetterSpacing.xl),
                        TextButton(
                          key: const Key('low-energy-done'),
                          onPressed: widget.onClose,
                          child: const Text(
                            'that is enough',
                            style: TextStyle(color: Color(0xB3FFFFFF)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StillFieldPainter extends CustomPainter {
  _StillFieldPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = LetterColors.night;
    canvas.drawRect(Offset.zero & size, base);
    for (var i = 0; i < 5; i++) {
      final phase = t * math.pi * 2 + i * 1.31;
      final cx = size.width * (0.22 + 0.16 * i) + math.sin(phase) * 14;
      final cy = size.height * (0.30 + 0.10 * i) + math.cos(phase * 0.7) * 18;
      final radius = size.shortestSide * (0.30 + 0.05 * i);
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            LetterColors.moonMetal.withValues(alpha: 0.10),
            LetterColors.night.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        );
      canvas.drawCircle(Offset(cx, cy), radius, glow);
    }
  }

  @override
  bool shouldRepaint(_StillFieldPainter oldDelegate) => oldDelegate.t != t;
}
