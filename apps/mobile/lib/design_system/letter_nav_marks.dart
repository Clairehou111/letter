import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The five navigation marks for the 月信 tab bar.
///
/// 月信 means "a letter from your body". The marks are drawn rather than taken
/// from a stock icon set so the tab bar carries that idea instead of looking
/// like a default app: an envelope holding a moon, moon phases, a cupped
/// shelter, a stack of letters, and a wax seal.
enum LetterNavMark { todayLetter, moonPhases, shelter, letterStack, waxSeal }

class LetterNavMarkIcon extends StatelessWidget {
  const LetterNavMarkIcon({
    required this.mark,
    required this.color,
    super.key,
    this.active = false,
    this.size = 20,
  });

  final LetterNavMark mark;
  final Color color;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LetterNavMarkPainter(
          mark: mark,
          color: color,
          active: active,
        ),
      ),
    );
  }
}

class _LetterNavMarkPainter extends CustomPainter {
  _LetterNavMarkPainter({
    required this.mark,
    required this.color,
    required this.active,
  });

  final LetterNavMark mark;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 1.7 : 1.4
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: active ? 1 : 0.55);

    switch (mark) {
      case LetterNavMark.todayLetter:
        _paintTodayLetter(canvas, size, stroke, fill);
      case LetterNavMark.moonPhases:
        _paintMoonPhases(canvas, size, stroke, fill);
      case LetterNavMark.shelter:
        _paintShelter(canvas, size, stroke, fill);
      case LetterNavMark.letterStack:
        _paintLetterStack(canvas, size, stroke, fill);
      case LetterNavMark.waxSeal:
        _paintWaxSeal(canvas, size, stroke, fill);
    }
  }

  /// An envelope with a small moon resting inside its flap: today's letter.
  void _paintTodayLetter(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(w * 0.10, h * 0.26, w * 0.80, h * 0.50);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(w * 0.08)),
      stroke,
    );
    final flap = Path()
      ..moveTo(rect.left, rect.top + h * 0.03)
      ..lineTo(rect.center.dx, rect.top + h * 0.26)
      ..lineTo(rect.right, rect.top + h * 0.03);
    canvas.drawPath(flap, stroke);
    canvas.drawCircle(
      Offset(rect.center.dx, rect.top - h * 0.06),
      w * 0.11,
      fill,
    );
  }

  /// Three moon phases: the rhythm of a cycle.
  void _paintMoonPhases(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final w = size.width;
    final cy = size.height / 2;
    final r = w * 0.15;
    canvas.drawCircle(Offset(w * 0.18, cy), r, stroke);
    final half = Path()
      ..moveTo(w * 0.50, cy - r)
      ..arcToPoint(
        Offset(w * 0.50, cy + r),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..close();
    canvas.drawCircle(Offset(w * 0.50, cy), r, stroke);
    canvas.drawPath(half, fill);
    canvas.drawCircle(Offset(w * 0.82, cy), r, fill);
  }

  /// Two cupped hands sheltering a small point of warmth: stay here.
  void _paintShelter(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final w = size.width;
    final h = size.height;
    final bowl = Path()
      ..moveTo(w * 0.12, h * 0.48)
      ..quadraticBezierTo(w * 0.50, h * 0.98, w * 0.88, h * 0.48);
    canvas.drawPath(bowl, stroke);
    final inner = Path()
      ..moveTo(w * 0.26, h * 0.50)
      ..quadraticBezierTo(w * 0.50, h * 0.80, w * 0.74, h * 0.50);
    canvas.drawPath(inner, stroke);
    canvas.drawCircle(Offset(w * 0.50, h * 0.28), w * 0.11, fill);
  }

  /// A short stack of letters: the ones already received.
  void _paintLetterStack(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final w = size.width;
    final h = size.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.16, h * 0.20, w * 0.68, h * 0.22),
        Radius.circular(w * 0.06),
      ),
      stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.10, h * 0.44, w * 0.80, h * 0.36),
        Radius.circular(w * 0.07),
      ),
      stroke,
    );
    canvas.drawCircle(Offset(w * 0.50, h * 0.62), w * 0.09, fill);
  }

  /// A wax seal: what is yours, kept closed.
  void _paintWaxSeal(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.50, h * 0.52);
    final r = w * 0.30;
    final petals = Path();
    for (var i = 0; i < 10; i++) {
      final a = (i / 10) * math.pi * 2;
      final rr = i.isEven ? r : r * 0.86;
      final p = Offset(center.dx + math.cos(a) * rr, center.dy + math.sin(a) * rr);
      if (i == 0) {
        petals.moveTo(p.dx, p.dy);
      } else {
        petals.lineTo(p.dx, p.dy);
      }
    }
    petals.close();
    canvas.drawPath(petals, stroke);
    canvas.drawCircle(center, r * 0.38, fill);
  }

  @override
  bool shouldRepaint(_LetterNavMarkPainter oldDelegate) {
    return oldDelegate.mark != mark ||
        oldDelegate.color != color ||
        oldDelegate.active != active;
  }
}
