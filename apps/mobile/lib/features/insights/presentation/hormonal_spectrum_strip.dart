import 'package:flutter/material.dart';

import 'spectrum_log_view_model.dart';

class SpectrumLogPainter extends CustomPainter {
  SpectrumLogPainter({required this.viewModel});

  final SpectrumLogViewModel viewModel;

  @override
  void paint(Canvas canvas, Size size) {
    final segments = viewModel.nebulaSegments;
    if (segments.isEmpty) {
      _paintEmpty(canvas, size);
      return;
    }
    _paintStrip(canvas, size, segments);
    _paintLabels(canvas, size, segments);
  }

  void _paintEmpty(Canvas canvas, Size size) {
    final text = TextPainter(
      text: TextSpan(
        text: viewModel.emptyMessage ?? 'patterns gather quietly over cycles.',
        style: const TextStyle(
          color: Color(0xFF555555),
          fontSize: 12,
          fontFamily: 'Arial',
          fontWeight: FontWeight.w300,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.8);
    text.paint(
      canvas,
      Offset((size.width - text.width) / 2, size.height * 0.4),
    );
  }

  void _paintStrip(
    Canvas canvas,
    Size size,
    List<SpectrumNebulaSegment> segments,
  ) {
    final segmentWidth = size.width / segments.length;
    final stripTop = size.height * 0.15;
    final stripHeight = size.height * 0.55;

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final rect = Rect.fromLTWH(
        i * segmentWidth,
        stripTop,
        segmentWidth,
        stripHeight,
      );

      if (segment.intensity > 0.0) {
        final nebulaPaint = Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.7,
            colors: [
              segment.fillColor,
              segment.fillColor.withValues(alpha: 0.3),
              Colors.transparent,
            ],
          ).createShader(rect)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, segment.blurRadius);

        final expandedRect = rect.inflate(segmentWidth * 0.5);
        canvas.drawRect(expandedRect, nebulaPaint);
      }

      // Segment divider (subtle)
      if (i > 0) {
        final dividerPaint = Paint()
          ..color = const Color(0xFF1C1C1E)
          ..strokeWidth = 0.4;
        canvas.drawLine(
          Offset(i * segmentWidth, stripTop),
          Offset(i * segmentWidth, stripTop + stripHeight),
          dividerPaint,
        );
      }
    }

    // Strip borders
    final borderPaint = Paint()
      ..color = const Color(0xFF2A2A2C)
      ..strokeWidth = 0.6;
    canvas.drawLine(
      Offset(0, stripTop),
      Offset(size.width, stripTop),
      borderPaint,
    );
    canvas.drawLine(
      Offset(0, stripTop + stripHeight),
      Offset(size.width, stripTop + stripHeight),
      borderPaint,
    );
  }

  void _paintLabels(
    Canvas canvas,
    Size size,
    List<SpectrumNebulaSegment> segments,
  ) {
    if (viewModel.dayLabels.length != segments.length) return;

    final segmentWidth = size.width / segments.length;
    final labelTop = size.height * 0.72;

    for (var i = 0; i < segments.length; i += 2) {
      final label = TextPainter(
        text: TextSpan(
          text: viewModel.dayLabels[i],
          style: TextStyle(
            color: segments[i].intensity > 0.3
                ? const Color(0xFF888888)
                : const Color(0xFF3A3A3C),
            fontSize: 8,
            fontFamily: 'Arial',
            fontWeight: FontWeight.w300,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      label.paint(
        canvas,
        Offset(i * segmentWidth + (segmentWidth - label.width) / 2, labelTop),
      );
    }
  }

  @override
  bool shouldRepaint(SpectrumLogPainter oldDelegate) =>
      viewModel != oldDelegate.viewModel;
}

class HormonalSpectrumStrip extends StatelessWidget {
  const HormonalSpectrumStrip({required this.viewModel, super.key});

  final SpectrumLogViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0C10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Spectrum Log',
              style: TextStyle(
                color: Color(0xFF555555),
                fontSize: 10,
                fontFamily: 'Arial',
                fontWeight: FontWeight.w300,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Text(
            '${viewModel.confirmedRatingCount} confirmed ratings across '
            '${viewModel.observedDayCount} observed days',
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 10,
              fontFamily: 'Arial',
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Only days anchored to a later observed period are colored. Blank areas are missing data.',
            style: TextStyle(
              color: Color(0xFF555555),
              fontSize: 9,
              fontFamily: 'Arial',
              height: 1.35,
            ),
          ),
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: SpectrumLogPainter(viewModel: viewModel),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Text(
                'd-14',
                style: TextStyle(
                  color: Color(0xFF3A3A3C),
                  fontSize: 8,
                  fontFamily: 'Arial',
                  fontWeight: FontWeight.w300,
                ),
              ),
              Spacer(),
              Text(
                'd-1',
                style: TextStyle(
                  color: Color(0xFF3A3A3C),
                  fontSize: 8,
                  fontFamily: 'Arial',
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
