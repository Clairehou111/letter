import 'package:flutter/material.dart';

import 'gravity_horizon_view_model.dart';

class GravityHorizonPainter extends CustomPainter {
  GravityHorizonPainter({required this.viewModel});

  final GravityHorizonViewModel viewModel;

  @override
  void paint(Canvas canvas, Size size) {
    final points = viewModel.curvePoints;
    if (points.isEmpty) {
      _paintEmpty(canvas, size);
      return;
    }
    _paintCurve(canvas, size, points);
    _paintTodayDot(canvas, size, points);
  }

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

  void _paintCurve(Canvas canvas, Size size, List<Offset> points) {
    final path = _smoothPath(points);

    // Teal glow layer
    final glowPaint = Paint()
      ..color = const Color(0xFF176D67).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawPath(path, glowPaint);

    // Core line
    final linePaint = Paint()
      ..color = const Color(0xFFA7D4D1).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Luteal valley highlight
    if (viewModel.isInLutealValley) {
      final valleyPaint = Paint()
        ..color = const Color(0xFFC4A66A).withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      canvas.drawPath(path, valleyPaint);
    }
  }

  void _paintTodayDot(Canvas canvas, Size size, List<Offset> points) {
    final x = viewModel.todayPosition * size.width;
    final y = _interpolateY(points, x, size.height);

    // Outer glow
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
    canvas.drawCircle(Offset(x, y), 8.0, glowPaint);

    // Dot
    final dotPaint = Paint()
      ..color = const Color(0xFFF3F5F2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x, y), 3.5, dotPaint);

    // Label below dot
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
    label.paint(canvas, Offset(x - label.width / 2, y + 14));
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final midX = (points[i].dx + points[i + 1].dx) / 2;
      final midY = (points[i].dy + points[i + 1].dy) / 2;
      path.quadraticBezierTo(points[i].dx, points[i].dy, midX, midY);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  double _interpolateY(List<Offset> points, double x, double height) {
    if (points.isEmpty) return height * 0.5;
    for (var i = 0; i < points.length - 1; i++) {
      if (x >= points[i].dx && x <= points[i + 1].dx) {
        final t = (x - points[i].dx) / (points[i + 1].dx - points[i].dx);
        return points[i].dy + (points[i + 1].dy - points[i].dy) * t;
      }
    }
    return points.last.dy;
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
            child: Text(
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
          ),
        ],
      ),
    );
  }
}
