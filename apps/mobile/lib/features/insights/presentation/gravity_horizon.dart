import 'package:flutter/material.dart';

import 'gravity_horizon_view_model.dart';

class GravityHorizonPainter extends CustomPainter {
  GravityHorizonPainter({required this.viewModel});

  final GravityHorizonViewModel viewModel;

  // ═══════════════════════════════════════════════════════════
  // LOCKED GEOMETRY — device-independent, fractions of canvas.
  // The cliff X position (lutealDipStartFraction) is the only
  // data-driven value; all other constants are fixed visual design.
  // ═══════════════════════════════════════════════════════════

  /// Y of the flat follicular baseline (0=top). Higher = more drop room.
  static const _baselineY = 0.38;

  /// Y of the luteal valley floor. Lower = deeper gravity valley.
  static const _valleyY = 0.72;

  /// Width of the descent cliff as a fraction of canvas width.
  static const _cliffWidth = 0.14;

  /// Cubic bezier control points within the normalized cliff zone
  /// (0 = top-left of cliff, 1 = bottom-right).
  ///
  /// The "overhang cliff": C1 and C2 both stay at baseline Y, creating
  /// a plateau that holds flat until C2 (at 80% through the zone), then
  /// drops vertically to the valley floor in the final 20%.
  ///   P0 = (0,   0)  — cliff top
  ///   C1 = (0.05, 0) — barely nudge right, stay flat
  ///   C2 = (0.80, 0) — hold the overhang until the last moment
  ///   P3 = (1,   1)  — cliff bottom
  static const _c1x = 0.05;
  static const _c2x = 0.80;

  // Dot rendering
  static const _dotRadius = 4.5;
  static const _dotGlowRadius = 14.0;
  static const _dotGlowAlpha = 0.12;

  // ═══════════════════════════════════════════════════════════

  @override
  void paint(Canvas canvas, Size size) {
    if (viewModel.curvePoints.isEmpty) {
      _paintEmpty(canvas, size);
      return;
    }
    _paintHorizonCurve(canvas, size);
    _paintTodayDot(canvas, size);
  }

  // ── Empty state ──────────────────────────────────────────
  void _paintEmpty(Canvas canvas, Size size) {
    final text = TextPainter(
      text: TextSpan(
        text: viewModel.subtitle,
        style: const TextStyle(
          color: Color(0xFF888888),
          fontSize: 11,
          fontFamily: 'Arial',
          fontWeight: FontWeight.w300,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.85);
    text.paint(
      canvas,
      Offset((size.width - text.width) / 2, size.height * 0.5),
    );
  }

  // ── Horizon curve (unified cubic bezier) ─────────────────
  void _paintHorizonCurve(Canvas canvas, Size size) {
    final midY = size.height * _baselineY;
    final valleyY = size.height * _valleyY;
    final w = size.width;
    final cliffX = w * viewModel.lutealDipStartFraction;
    final dropW = w * _cliffWidth;
    final floorX = (cliffX + dropW).clamp(cliffX, w);

    final path = Path()..moveTo(0, midY);
    path.lineTo(cliffX, midY);
    // Overhang cliff: C2.y = midY (not valleyY). The curve holds flat
    // through C1 and C2, then drops to valleyY only at P3.
    path.cubicTo(
      cliffX + dropW * _c1x, midY,
      cliffX + dropW * _c2x, midY,
      floorX, valleyY,
    );
    path.lineTo(w, valleyY);

    // Teal under-glow
    final glowPaint = Paint()
      ..color = const Color(0xFF176D67).withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawPath(path, glowPaint);

    // White horizon line — Letter's signature restrained luminous feel
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Golden valley wash
    if (viewModel.isInLutealValley) {
      final valleyPath = Path()..moveTo(floorX, valleyY);
      valleyPath.lineTo(w, valleyY);
      final valleyPaint = Paint()
        ..color = const Color(0xFFC4A66A).withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      canvas.drawPath(valleyPath, valleyPaint);
    }
  }

  // ── Today dot — exact cubic bezier position ──────────────
  void _paintTodayDot(Canvas canvas, Size size) {
    final t = viewModel.todayPosition.clamp(0.0, 1.0);
    final dotX = size.width * t;
    final midY = size.height * _baselineY;
    final valleyY = size.height * _valleyY;
    final cliffX = size.width * viewModel.lutealDipStartFraction;
    final dropW = size.width * _cliffWidth;
    final floorX = (cliffX + dropW).clamp(cliffX, size.width);

    // Dot Y: three-zone model tied to the SAME cubic bezier as the curve.
    // Zone 1 (before cliff): flat at midY.
    // Zone 2 (cliff zone): exact cubic bezier Y via inverse parameter solve.
    // Zone 3 (after cliff): flat at valleyY.
    final dotY = dotX <= cliffX
        ? midY
        : dotX >= floorX
        ? valleyY
        : _bezierY(dotX, cliffX, dropW, midY, valleyY);

    // Outer glow
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: _dotGlowAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
    canvas.drawCircle(Offset(dotX, dotY), _dotGlowRadius, glowPaint);

    // Core dot
    canvas.drawCircle(
      Offset(dotX, dotY),
      _dotRadius,
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );

    // Label
    final label = TextPainter(
      text: TextSpan(
        text: viewModel.todayLabel,
        style: const TextStyle(
          color: Color(0xFF888888),
          fontSize: 9,
          fontFamily: 'Arial',
          fontWeight: FontWeight.w300,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(dotX - label.width / 2, dotY + 14));
  }

  // ═══════════════════════════════════════════════════════════
  // Exact cubic bezier math — shared by curve path and dot.
  // ═══════════════════════════════════════════════════════════

  /// Evaluates the exact Y coordinate on the overhang-cliff cubic bezier
  /// at a given canvas X within the cliff zone.
  ///
  /// With C1.y = C2.y = midY (overhang design), the formulas simplify:
  ///   B_x(u) = 3(1-u)²·u·c1x + 3(1-u)·u²·c2x + u³
  ///   B_y(u) = (1-u³)·midY + u³·valleyY
  ///
  /// Newton's method (3 iterations) inverts B_x to find u, giving
  /// sub-pixel precision on all device resolutions.
  static double _bezierY(
    double canvasX, double cliffX, double dropW, double mid, double bot,
  ) {
    final target = ((canvasX - cliffX) / dropW).clamp(0.0, 1.0);
    var u = target;
    for (var i = 0; i < 3; i++) {
      final u2 = u * u, v = 1.0 - u, v2 = v * v;
      final fx = 3 * v2 * u * _c1x + 3 * v * u2 * _c2x + u2 * u - target;
      final fpx = 3 * v2 * _c1x + 6 * v * u * (_c2x - _c1x) + 3 * u2 * (1 - _c2x);
      u = (u - fx / fpx).clamp(0.0, 1.0);
    }
    final u3 = u * u * u;
    return (1.0 - u3) * mid + u3 * bot;
  }

  @override
  bool shouldRepaint(GravityHorizonPainter oldDelegate) =>
      viewModel != oldDelegate.viewModel;
}

class GravityHorizonView extends StatelessWidget {
  const GravityHorizonView({required this.viewModel, super.key});

  final GravityHorizonViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: viewModel.backgroundColor,
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: GravityHorizonPainter(viewModel: viewModel),
              size: Size.infinite,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  viewModel.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 11,
                    fontFamily: 'Arial',
                    fontWeight: FontWeight.w300,
                    height: 1.5,
                  ),
                ),
                if (viewModel.lutealStartLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Premenstrual window from ${viewModel.lutealStartLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFC4A66A),
                      fontSize: 10,
                      fontFamily: 'Arial',
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
