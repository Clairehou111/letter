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
  static const _rowAlt = Color(0xFFF5F3EF);
  static const _grid = Color(0xFFD8D6D0);
  static const _center = Color(0xFF555555);
  // The header has three metadata lines. Keep enough vertical separation for
  // the axis labels below it, including when the report is shown at phone
  // width or with large text settings.
  static const _headerHeight = 108.0;
  static const _footerHeight = 52.0;

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

  double _contentHeight(Size size) =>
      size.height - _headerHeight - _footerHeight;

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
      fontSize: 9,
      fontFamily: 'Courier',
    );
    final subStyle = const TextStyle(
      color: _muted,
      fontSize: 8.5,
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
      text: TextSpan(text: 'scale 1–5', style: subStyle),
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
      fontSize: 10,
      fontFamily: 'Courier',
      fontWeight: FontWeight.w600,
    );

    void drawCell(TwinMatrixCell cell, double x, double y, bool isToday) {
      final severity = cell.severity;
      if (severity == null) return;
      final height = (severity / 5.0).clamp(0.05, 1.0) * barMaxHeight;
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
            fontSize: 8,
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
          cluster.beforePeriodCells[index],
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
      fontSize: 9,
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
            '${viewModel.totalObservations} records · ${viewModel.mappedObservations} mapped · ${viewModel.cyclesCovered} cycles with symptom ratings',
        style: metaStyle,
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width - 20);
    diagnostics.paint(canvas, Offset(10, 8 + title.height + meta.height + 4));
    final coverage = TextPainter(
      text: TextSpan(
        text:
            '${viewModel.observedRelativeDays}/28 relative days observed · ${viewModel.blankRelativeDays} blank · ${viewModel.sameDayObservations} same-day · ${viewModel.laterRecallObservations} later recall',
        style: metaStyle,
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width - 20);
    coverage.paint(
      canvas,
      Offset(10, 8 + title.height + meta.height + diagnostics.height + 6),
    );
    canvas.drawLine(
      Offset(0, _headerHeight - 2),
      Offset(size.width, _headerHeight - 2),
      Paint()
        ..color = _grid
        ..strokeWidth = 0.6,
    );
  }

  void _paintFooter(Canvas canvas, Size size) {
    final y = size.height - _footerHeight + 4;
    canvas.drawLine(
      Offset(0, y - 2),
      Offset(size.width, y - 2),
      Paint()
        ..color = _grid
        ..strokeWidth = 0.6,
    );
    const style = TextStyle(
      color: _muted,
      fontSize: 8.5,
      fontFamily: 'Courier',
    );
    final first = TextPainter(
      text: const TextSpan(
        text:
            'bars = cycle-balanced average on the recorded 1–5 scale; blank = no observation.',
        style: style,
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 20);
    first.paint(canvas, Offset(10, y + 2));
    final second = TextPainter(
      text: TextSpan(
        text:
            'Provenance: ${viewModel.sameDayObservations} same-day, ${viewModel.laterRecallObservations} later recall. Local records; not a diagnosis.',
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 620) {
            return _TwinMatrixMobile(viewModel: viewModel);
          }
          final reportWidth = constraints.maxWidth < 620
              ? 620.0
              : constraints.maxWidth;
          return SingleChildScrollView(
            key: const Key('twin-matrix-horizontal-scroll'),
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: reportWidth,
              child: Container(
                color: const Color(0xFFFAF9F6),
                child: AspectRatio(
                  aspectRatio: 1.45,
                  child: CustomPaint(
                    key: const Key('twin-matrix-canvas'),
                    painter: TwinMatrixPainter(viewModel: viewModel),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TwinMatrixMobile extends StatelessWidget {
  const _TwinMatrixMobile({required this.viewModel});

  final TwinMatrixViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('twin-matrix-mobile'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cyclical symptom summary',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '${viewModel.cycleLabel} · ${viewModel.cyclesCovered} '
            '${viewModel.cyclesCovered == 1 ? 'cycle' : 'cycles'} with '
            'symptom ratings',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _TwinHalf(
            title: 'Before period',
            subtitle: '14 days leading to a recorded period',
            beforePeriod: true,
            viewModel: viewModel,
          ),
          const SizedBox(height: 20),
          _TwinHalf(
            title: 'Cycle days',
            subtitle: 'Days 1–14 after a recorded period starts',
            beforePeriod: false,
            viewModel: viewModel,
          ),
        ],
      ),
    );
  }
}

class _TwinHalf extends StatelessWidget {
  const _TwinHalf({
    required this.title,
    required this.subtitle,
    required this.beforePeriod,
    required this.viewModel,
  });

  final String title;
  final String subtitle;
  final bool beforePeriod;
  final TwinMatrixViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final oppositeIds = <String>{
      for (final cluster in viewModel.clusters)
        for (final cell
            in beforePeriod ? cluster.cycleCells : cluster.beforePeriodCells)
          for (final item in cell.evidence) item.recordId,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8D6D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          for (final cluster in viewModel.clusters) ...[
            Text(
              cluster.label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            _TwinCellGrid(
              cells: beforePeriod
                  ? cluster.beforePeriodCells
                  : cluster.cycleCells,
              beforePeriod: beforePeriod,
              oppositeIds: oppositeIds,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _TwinCellGrid extends StatelessWidget {
  const _TwinCellGrid({
    required this.cells,
    required this.beforePeriod,
    required this.oppositeIds,
  });

  final List<TwinMatrixCell> cells;
  final bool beforePeriod;
  final Set<String> oppositeIds;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 18) / 7;
        return Wrap(
          spacing: 3,
          runSpacing: 3,
          children: [
            for (var index = 0; index < cells.length; index += 1)
              SizedBox(
                width: width,
                height: 48,
                child: _TwinCellButton(
                  cell: cells[index],
                  day: beforePeriod ? -14 + index : index + 1,
                  beforePeriod: beforePeriod,
                  sharedSource: cells[index].evidence.any(
                    (item) => oppositeIds.contains(item.recordId),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TwinCellButton extends StatelessWidget {
  const _TwinCellButton({
    required this.cell,
    required this.day,
    required this.beforePeriod,
    required this.sharedSource,
  });

  final TwinMatrixCell cell;
  final int day;
  final bool beforePeriod;
  final bool sharedSource;

  @override
  Widget build(BuildContext context) {
    final severity = cell.severity;
    final label = beforePeriod ? 'd$day' : '$day';
    return Semantics(
      button: severity != null,
      label: severity == null
          ? '$label, no observation'
          : '$label, ${_twinSeverityLabel(severity)}, ${cell.observationCount} records',
      child: InkWell(
        key: Key('twin-${beforePeriod ? 'before' : 'cycle'}-$day'),
        onTap: severity == null ? null : () => _showCell(context),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: severity == null
                ? Colors.transparent
                : Color.lerp(
                    const Color(0xFFE8E4DF),
                    const Color(0xFF176D67),
                    ((severity - 1) / 4).clamp(0, 1),
                  ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFD8D6D0)),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: severity != null && severity >= 3.5
                        ? Colors.white
                        : const Color(0xFF555555),
                  ),
                ),
              ),
              if (sharedSource)
                const Positioned(
                  right: 4,
                  top: 3,
                  child: Icon(Icons.link, size: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCell(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                beforePeriod
                    ? '${day.abs()} days before period'
                    : 'Cycle day $day',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                '${_twinSeverityLabel(cell.severity!)} · '
                '${cell.observationCount} ${cell.observationCount == 1 ? 'record' : 'records'} '
                'across ${cell.cycleCount} ${cell.cycleCount == 1 ? 'cycle' : 'cycles'}',
              ),
              if (sharedSource) ...[
                const SizedBox(height: 8),
                const Text(
                  'Linked records also appear in the other timing view.',
                  style: TextStyle(color: Color(0xFF176D67)),
                ),
              ],
              const SizedBox(height: 16),
              for (final item in cell.evidence)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${item.symptom.label} · ${item.severity.label}\n'
                    '${item.experiencedDate} · ${item.provenance.label}',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _twinSeverityLabel(double value) {
  const labels = ['Minimal', 'Mild', 'Moderate', 'Severe', 'Extreme'];
  if (value == value.roundToDouble()) return labels[value.round() - 1];
  return '${labels[value.floor().clamp(1, 5) - 1]}–'
      '${labels[value.ceil().clamp(1, 5) - 1]}';
}
