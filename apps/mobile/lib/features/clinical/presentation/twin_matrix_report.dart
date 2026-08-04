import 'package:flutter/material.dart';

import 'twin_matrix_view_model.dart';

/// Renders a clinician-readable summary of confirmed local observations.
///
/// The report is descriptive only. Blank cells mean no observation; no value
/// is copied from the opposite side of the period boundary.
class TwinMatrixPainter extends CustomPainter {
  TwinMatrixPainter({required this.viewModel});

  final TwinMatrixViewModel viewModel;

  static const _background = Color(0xFFFAF9F6);
  static const _text = Color(0xFF1A1A1A);
  static const _muted = Color(0xFF777777);
  static const _bar = Color(0xFF2A2A2A);
  static const _today = Color(0xFF176D67);
  static const _zero = Color(0xFFAAAAAA);
  static const _rowAlt = Color(0xFFF5F3EF);
  static const _grid = Color(0xFFD8D6D0);
  static const _center = Color(0xFF555555);
  // The header has three metadata lines. Keep enough vertical separation for
  // the axis labels below it, including when the report is shown at phone
  // width or with large text settings.
  static const _headerHeight = 92.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _background);
    _paintRowBackgrounds(canvas, size);
    _paintGrid(canvas, size);
    _paintAxisLabels(canvas, size);
    _paintCells(canvas, size);
    _paintHeader(canvas, size);
    _paintFooter(canvas, size);
  }

  double _contentHeight(Size size) => size.height - _headerHeight - 44.0;

  double _labelWidth(Size size) => (size.width * 0.24).clamp(90.0, 140.0);

  double _rowHeight(Size size) =>
      _contentHeight(size) /
      (viewModel.clusters.isEmpty ? 1 : viewModel.clusters.length);

  void _paintRowBackgrounds(Canvas canvas, Size size) {
    final rowHeight = _rowHeight(size);
    for (var row = 0; row < viewModel.clusters.length; row++) {
      if (row.isOdd) {
        canvas.drawRect(
          Rect.fromLTWH(
            0,
            _headerHeight + row * rowHeight,
            size.width,
            rowHeight,
          ),
          Paint()..color = _rowAlt,
        );
      }
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final contentHeight = _contentHeight(size);
    final rowHeight = _rowHeight(size);
    final labelWidth = _labelWidth(size);
    final halfWidth = (size.width - labelWidth) / 2;
    final dayWidth = halfWidth / 14;
    final gridPaint = Paint()
      ..color = _grid
      ..strokeWidth = 0.5;

    for (var row = 1; row < viewModel.clusters.length; row++) {
      final y = _headerHeight + row * rowHeight;
      canvas.drawLine(
        Offset.zero.translate(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
    for (var index = 0; index <= 14; index += 2) {
      final leftX = labelWidth + index * dayWidth;
      final rightX = labelWidth + halfWidth + index * dayWidth;
      canvas.drawLine(
        Offset(leftX, _headerHeight),
        Offset(leftX, _headerHeight + contentHeight),
        gridPaint,
      );
      canvas.drawLine(
        Offset(rightX, _headerHeight),
        Offset(rightX, _headerHeight + contentHeight),
        gridPaint,
      );
    }
    canvas.drawLine(
      Offset(labelWidth + halfWidth, _headerHeight),
      Offset(labelWidth + halfWidth, _headerHeight + contentHeight),
      Paint()
        ..color = _center
        ..strokeWidth = 1,
    );
  }

  void _paintAxisLabels(Canvas canvas, Size size) {
    final labelWidth = _labelWidth(size);
    final halfWidth = (size.width - labelWidth) / 2;
    final dayWidth = halfWidth / 14;
    final numberY = _headerHeight - 31;
    final labelY = _headerHeight - 16;
    final dayStyle = const TextStyle(
      color: _muted,
      fontSize: 8,
      fontFamily: 'Courier',
    );
    final subStyle = const TextStyle(
      color: _muted,
      fontSize: 7,
      fontFamily: 'Courier',
    );

    void drawCentered(String text, double x, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(x - painter.width / 2, numberY));
    }

    for (var index = 0; index < 14; index += 2) {
      drawCentered(
        '${-(14 - index)}',
        labelWidth + index * dayWidth + dayWidth / 2,
        dayStyle,
      );
      drawCentered(
        '${1 + index}',
        labelWidth + halfWidth + index * dayWidth + dayWidth / 2,
        dayStyle,
      );
    }
    drawCentered(
      '0',
      labelWidth + halfWidth,
      dayStyle.copyWith(fontWeight: FontWeight.w700),
    );
    void drawPhaseLabel(String text, double x) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: subStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: halfWidth - 8);
      painter.paint(canvas, Offset(x - painter.width / 2, labelY));
    }

    drawPhaseLabel('days before period', labelWidth + halfWidth / 2);
    drawPhaseLabel('cycle days', labelWidth + halfWidth + halfWidth / 2);
    final scale = TextPainter(
      text: TextSpan(text: 'scale 1–6', style: subStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    scale.paint(canvas, Offset(labelWidth - scale.width - 6, labelY));
  }

  void _paintCells(Canvas canvas, Size size) {
    final rowHeight = _rowHeight(size);
    final labelWidth = _labelWidth(size);
    final halfWidth = (size.width - labelWidth) / 2;
    final dayWidth = halfWidth / 14;
    final barMaxHeight = rowHeight * 0.32;
    final barWidth = dayWidth * 0.55;
    final labelStyle = const TextStyle(
      color: _text,
      fontSize: 9,
      fontFamily: 'Courier',
      fontWeight: FontWeight.w600,
    );

    void drawCell(TwinMatrixCell cell, double x, double y, bool isToday) {
      final severity = cell.severity;
      if (severity == null) return;
      if (severity <= 0) {
        canvas.drawCircle(Offset(x, y), 1.5, Paint()..color = _zero);
        return;
      }
      final height = (severity / 6.0).clamp(0.05, 1.0) * barMaxHeight;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, y),
            width: barWidth,
            height: height,
          ),
          const Radius.circular(1.5),
        ),
        Paint()..color = isToday ? _today : _bar,
      );
      final score = TextPainter(
        text: TextSpan(
          text: severity.toStringAsFixed(1),
          style: const TextStyle(
            color: _text,
            fontSize: 7,
            fontFamily: 'Courier',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      score.paint(
        canvas,
        Offset(x - score.width / 2, y - height / 2 - score.height - 1),
      );
    }

    for (var row = 0; row < viewModel.clusters.length; row++) {
      final cluster = viewModel.clusters[row];
      final centerY = _headerHeight + row * rowHeight + rowHeight / 2;
      final label = TextPainter(
        text: TextSpan(text: cluster.label, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: labelWidth - 10);
      label.paint(canvas, Offset(5, centerY - label.height / 2));
      for (var index = 0; index < 14; index++) {
        drawCell(
          cluster.lutealCells[index],
          labelWidth + index * dayWidth + dayWidth / 2,
          centerY,
          viewModel.todayDay == -(14 - index),
        );
        drawCell(
          cluster.cycleCells[index],
          labelWidth + halfWidth + index * dayWidth + dayWidth / 2,
          centerY,
          viewModel.todayDay == 1 + index,
        );
      }
    }
  }

  void _paintHeader(Canvas canvas, Size size) {
    const titleStyle = TextStyle(
      color: _text,
      fontSize: 12,
      fontFamily: 'Courier',
      fontWeight: FontWeight.w700,
    );
    const metaStyle = TextStyle(
      color: _muted,
      fontSize: 8,
      fontFamily: 'Courier',
    );
    final title = TextPainter(
      text: const TextSpan(
        text: 'cyclical symptom summary · confirmed observations',
        style: titleStyle,
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width - 20);
    title.paint(canvas, const Offset(10, 8));
    final meta = TextPainter(
      text: TextSpan(
        text: '${viewModel.cycleLabel} · exported ${viewModel.exportTimestamp}',
        style: metaStyle,
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width - 20);
    meta.paint(canvas, Offset(10, 8 + title.height + 2));
    final diagnostics = TextPainter(
      text: TextSpan(
        text:
            '${viewModel.totalObservations} records · ${viewModel.lutealMapped} luteal-mapped · ${viewModel.cycleMapped} cycle-mapped',
        style: metaStyle,
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width - 20);
    diagnostics.paint(canvas, Offset(10, 8 + title.height + meta.height + 4));
    canvas.drawLine(
      Offset(0, _headerHeight - 2),
      Offset(size.width, _headerHeight - 2),
      Paint()
        ..color = _grid
        ..strokeWidth = 0.6,
    );
  }

  void _paintFooter(Canvas canvas, Size size) {
    final y = size.height - 40;
    canvas.drawLine(
      Offset(0, y - 2),
      Offset(size.width, y - 2),
      Paint()
        ..color = _grid
        ..strokeWidth = 0.6,
    );
    const style = TextStyle(color: _muted, fontSize: 7, fontFamily: 'Courier');
    final first = TextPainter(
      text: const TextSpan(
        text:
            'bars = average confirmed severity; dots = explicit zero; blank = no observation.',
        style: style,
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 20);
    first.paint(canvas, Offset(10, y + 2));
    final second = TextPainter(
      text: const TextSpan(
        text: 'Source: user-confirmed local records. This is not a diagnosis.',
        style: style,
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 20);
    second.paint(canvas, Offset(10, y + first.height + 4));
  }

  @override
  bool shouldRepaint(TwinMatrixPainter oldDelegate) =>
      viewModel != oldDelegate.viewModel;
}

class TwinMatrixReport extends StatelessWidget {
  const TwinMatrixReport({required this.viewModel, super.key});

  final TwinMatrixViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: viewModel.accessibilitySummary,
      child: Container(
        color: const Color(0xFFFAF9F6),
        child: AspectRatio(
          // Let the report use the available width; the previous, narrower
          // ratio made the matrix look like a small portrait card in exports.
          aspectRatio: 1.45,
          child: CustomPaint(
            painter: TwinMatrixPainter(viewModel: viewModel),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}
