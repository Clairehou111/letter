import 'package:flutter/material.dart';

import 'twin_matrix_view_model.dart';

/// Renders the Twin Matrix as a black-and-white clinical summary of confirmed
/// local observations.
///
/// X-axis: Days -14 to -1 (luteal) left of center, Days 1 to 14 (menses)
/// right of center. Y-axis: four reviewed symptom groupings.
///
/// Zero color, zero decorative elements. Ultra-thin bars, monospace text.
/// Optimized for 10-second doctor glance review.
class TwinMatrixPainter extends CustomPainter {
  TwinMatrixPainter({required this.viewModel});

  final TwinMatrixViewModel viewModel;

  static const _bgColor = Color(0xFF0B0C10);
  static const _textColor = Color(0xFFCCCCCC);
  static const _mutedColor = Color(0xFF555555);
  static const _barColor = Color(0xFFAAAAAA);
  static const _dividerColor = Color(0xFF2A2A2C);
  static const _centerLineColor = Color(0xFF888888);

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    _paintGrid(canvas, size);
    _paintAxisLabels(canvas, size);
    _paintClusters(canvas, size);
    _paintHeader(canvas, size);
    _paintFooter(canvas, size);
  }

  void _paintBackground(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _bgColor);
  }

  void _paintGrid(Canvas canvas, Size size) {
    final contentTop = _headerHeight(size);
    final contentHeight = _contentHeight(size);
    final rowHeight = contentHeight / 4;
    final labelWidth = _labelWidth(size);
    final dataWidth = size.width - labelWidth;
    final halfWidth = dataWidth / 2;

    // Horizontal row dividers.
    final rowDividerPaint = Paint()
      ..color = _dividerColor
      ..strokeWidth = 0.4;
    for (var row = 1; row < 4; row++) {
      final y = contentTop + row * rowHeight;
      canvas.drawLine(
        Offset(labelWidth, y),
        Offset(size.width, y),
        rowDividerPaint,
      );
    }

    // Vertical day dividers (very subtle, every 2 days).
    final dayWidth = halfWidth / 14;
    for (var i = 0; i <= 14; i += 2) {
      final x = labelWidth + i * dayWidth;
      canvas.drawLine(
        Offset(x, contentTop),
        Offset(x, contentTop + contentHeight),
        rowDividerPaint,
      );
    }

    // Center line (day 0 divider).
    final centerX = labelWidth + halfWidth;
    final centerLinePaint = Paint()
      ..color = _centerLineColor
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(centerX, contentTop),
      Offset(centerX, contentTop + contentHeight),
      centerLinePaint,
    );
  }

  void _paintAxisLabels(Canvas canvas, Size size) {
    final contentTop = _headerHeight(size);
    final labelWidth = _labelWidth(size);
    final dataWidth = size.width - labelWidth;
    final halfWidth = dataWidth / 2;
    final dayWidth = halfWidth / 14;
    final labelY = contentTop - 2;

    // X-axis: d-14 to d-1 (left), d1 to d14 (right).
    final axisTextStyle = TextStyle(
      color: _mutedColor,
      fontSize: 7,
      fontFamily: 'Courier',
      fontWeight: FontWeight.w300,
    );

    // Left side: days -14 to -1.
    for (var i = 0; i < 14; i += 2) {
      final text = TextPainter(
        text: TextSpan(text: 'd${-(14 - i)}', style: axisTextStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(
          labelWidth + i * dayWidth + dayWidth / 2 - text.width / 2,
          labelY,
        ),
      );
    }

    // Center: day 0.
    final centerText = TextPainter(
      text: TextSpan(
        text: 'd0',
        style: axisTextStyle.copyWith(fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    centerText.paint(
      canvas,
      Offset(labelWidth + halfWidth - centerText.width / 2, labelY),
    );

    // Right side: days 1 to 14.
    for (var i = 0; i < 14; i += 2) {
      final text = TextPainter(
        text: TextSpan(text: 'd${1 + i}', style: axisTextStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(
          labelWidth + halfWidth + i * dayWidth + dayWidth / 2 - text.width / 2,
          labelY,
        ),
      );
    }
  }

  void _paintClusters(Canvas canvas, Size size) {
    final contentTop = _headerHeight(size);
    final contentHeight = _contentHeight(size);
    final rowHeight = contentHeight / 4;
    final labelWidth = _labelWidth(size);
    final dataWidth = size.width - labelWidth;
    final halfWidth = dataWidth / 2;
    final dayWidth = halfWidth / 14;
    final barMaxHeight = rowHeight * 0.35;

    final barPaint = Paint()
      ..color = _barColor
      ..strokeWidth = 1.2;

    for (var row = 0; row < 4; row++) {
      final cluster = viewModel.clusters[row];
      final rowCenterY = contentTop + row * rowHeight + rowHeight / 2;

      // Cluster label (Y-axis).
      final label = TextPainter(
        text: TextSpan(
          text: cluster.label,
          style: const TextStyle(
            color: _textColor,
            fontSize: 8,
            fontFamily: 'Courier',
            fontWeight: FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: labelWidth - 8);
      label.paint(canvas, Offset(4, rowCenterY - label.height / 2));

      // Luteal bars (left side, days -14 to -1).
      if (cluster.lutealSeverities.isNotEmpty) {
        for (var i = 0; i < cluster.lutealSeverities.length && i < 14; i++) {
          final severity = cluster.lutealSeverities[i];
          if (severity <= 0) continue;
          final barHeight = (severity / 6.0).clamp(0.0, 1.0) * barMaxHeight;
          final x = labelWidth + i * dayWidth + dayWidth / 2;
          canvas.drawLine(
            Offset(x, rowCenterY + barHeight / 2),
            Offset(x, rowCenterY - barHeight / 2),
            barPaint,
          );
        }
      }

      // Menses bars (right side, days 1 to 14).
      if (cluster.mensesSeverities.isNotEmpty) {
        for (var i = 0; i < cluster.mensesSeverities.length && i < 14; i++) {
          final severity = cluster.mensesSeverities[i];
          if (severity <= 0) continue;
          final barHeight = (severity / 6.0).clamp(0.0, 1.0) * barMaxHeight;
          final x = labelWidth + halfWidth + i * dayWidth + dayWidth / 2;
          canvas.drawLine(
            Offset(x, rowCenterY + barHeight / 2),
            Offset(x, rowCenterY - barHeight / 2),
            barPaint,
          );
        }
      }
    }
  }

  void _paintHeader(Canvas canvas, Size size) {
    final titleStyle = TextStyle(
      color: _textColor,
      fontSize: 10,
      fontFamily: 'Courier',
      fontWeight: FontWeight.w600,
    );
    final metaStyle = TextStyle(
      color: _mutedColor,
      fontSize: 7,
      fontFamily: 'Courier',
      fontWeight: FontWeight.w300,
    );

    // Title.
    final title = TextPainter(
      text: TextSpan(text: 'cyclical symptom summary', style: titleStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    title.paint(canvas, const Offset(8, 8));

    // Metadata.
    final meta = TextPainter(
      text: TextSpan(
        text: '${viewModel.cycleLabel} · exported ${viewModel.exportTimestamp}',
        style: metaStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    meta.paint(canvas, Offset(8, 8 + title.height + 2));

    // Divider below header.
    final dividerY = _headerHeight(size) - 2;
    canvas.drawLine(
      Offset(0, dividerY),
      Offset(size.width, dividerY),
      Paint()
        ..color = _dividerColor
        ..strokeWidth = 0.6,
    );
  }

  void _paintFooter(Canvas canvas, Size size) {
    final footerY = size.height - 28;

    // Divider above footer.
    canvas.drawLine(
      Offset(0, footerY - 2),
      Offset(size.width, footerY - 2),
      Paint()
        ..color = _dividerColor
        ..strokeWidth = 0.6,
    );

    final medStyle = TextStyle(
      color: _mutedColor,
      fontSize: 7,
      fontFamily: 'Courier',
      fontWeight: FontWeight.w300,
    );
    final coverage = TextPainter(
      text: TextSpan(
        text: 'blank cells are missing observations; no values are imputed.',
        style: medStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    coverage.paint(canvas, Offset(8, footerY + 2));

    final provenance = TextPainter(
      text: TextSpan(
        text: 'source: user-confirmed local records. not a diagnosis.',
        style: medStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    provenance.paint(canvas, Offset(8, footerY + coverage.height + 4));
  }

  double _headerHeight(Size size) => 40.0;
  double _contentHeight(Size size) => size.height - _headerHeight(size) - 32.0;
  double _labelWidth(Size size) => size.width * 0.22;

  @override
  bool shouldRepaint(TwinMatrixPainter oldDelegate) =>
      viewModel != oldDelegate.viewModel;
}

class TwinMatrixReport extends StatelessWidget {
  const TwinMatrixReport({required this.viewModel, super.key});

  final TwinMatrixViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0C10),
      child: AspectRatio(
        aspectRatio: 1.2,
        child: CustomPaint(
          painter: TwinMatrixPainter(viewModel: viewModel),
          size: Size.infinite,
        ),
      ),
    );
  }
}
