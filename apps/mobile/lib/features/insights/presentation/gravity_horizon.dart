import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../../../design_system/lovable/letter_kit.dart' as lovable_kit;
import '../../../design_system/lovable/letter_theme.dart' as lovable;
import '../../cycle/domain/cycle_prediction.dart';
import '../../cycle/domain/local_date.dart';
import 'gravity_horizon_view_model.dart';

/// Paper-and-ink Gravity Horizon connected to production cycle data.
///
/// Solid teal segments mark recorded period dates by horizontal position. The
/// dashed curve is an ordinal estimated cycle-gravity tendency derived from
/// cycle timing.
class GravityHorizonView extends StatelessWidget {
  const GravityHorizonView({
    required this.viewModel,
    required this.onOpenCycle,
    super.key,
  });

  final GravityHorizonViewModel viewModel;
  final VoidCallback onOpenCycle;

  static const disclosure =
      'The curve follows cycle time from one period toward the next. Its '
      'vertical position is estimated cycle gravity: higher is lighter and '
      'lower is heavier.';

  @override
  Widget build(BuildContext context) {
    final prediction = viewModel.chartPrediction;
    return lovable_kit.LetterCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GRAVITY HORIZON · ESTIMATED',
                  style: lovable.letterEyebrow(),
                ),
                const SizedBox(height: LetterSpacing.xs),
                Semantics(
                  header: true,
                  child: Text(
                    primaryStatus,
                    key: const Key('gravity-primary-status'),
                    style: lovable.letterSerif(
                      size: context.isLetterNarrow ? 22 : 26,
                    ),
                  ),
                ),
                const SizedBox(height: LetterSpacing.xs),
                Text(
                  supportingStatus,
                  key: const Key('gravity-supporting-status'),
                  style: lovable.letterBody(
                    size: 14,
                    height: 1.5,
                    color: lovable.LetterTokens.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: LetterSpacing.md),
          Semantics(
            label: 'Gravity Horizon chart. ${accessibleSummary(context)}',
            button: true,
            excludeSemantics: true,
            child: InkWell(
              key: const Key('today-gravity-horizon'),
              onTap: onOpenCycle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: lovable.LetterTokens.tapTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _HorizonChart(viewModel: viewModel),
                ),
              ),
            ),
          ),
          const SizedBox(height: LetterSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: lovable_kit.LegendRow(
              items: [
                (
                  shape: lovable_kit.LegendShape.solidLine,
                  color: lovable.LetterTokens.teal,
                  label: 'Recorded period dates',
                ),
                if (prediction != null)
                  (
                    shape: lovable_kit.LegendShape.dashedLine,
                    color: lovable.LetterColors.clinicalBlue,
                    label: 'Estimated cycle gravity',
                  ),
                if (prediction != null)
                  (
                    shape: lovable_kit.LegendShape.hatchedBlock,
                    color: lovable.LetterColors.clinicalBlue,
                    label: 'Next-period range',
                  ),
                (
                  shape: lovable_kit.LegendShape.verticalRule,
                  color: lovable.LetterTokens.ink,
                  label: 'Today',
                ),
              ],
            ),
          ),
          const SizedBox(height: LetterSpacing.lg),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (prediction != null) ...[
                  Wrap(
                    spacing: LetterSpacing.xs,
                    runSpacing: LetterSpacing.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const lovable_kit.ProvenanceTag(observed: false),
                      Text(
                        '${prediction.confidence.label} confidence · from '
                        '${prediction.intervalCount} recorded '
                        '${prediction.intervalCount == 1 ? 'interval' : 'intervals'}.',
                        key: const Key('gravity-evidence'),
                        style: lovable.letterHelper(size: 12.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: LetterSpacing.sm),
                ],
                Text(disclosure, style: lovable.letterHelper(size: 12.5)),
                const SizedBox(height: LetterSpacing.md),
                SizedBox(
                  width: context.isLetterNarrow || context.isLetterLargeText
                      ? double.infinity
                      : null,
                  child: lovable_kit.PrimaryButton(
                    key: const Key('today-open-cycle'),
                    label: viewModel.hasHistory
                        ? 'Open Cycles'
                        : 'Record a period in Cycles',
                    onPressed: onOpenCycle,
                    expand: context.isLetterNarrow || context.isLetterLargeText,
                    semanticHint:
                        'Opens the Cycle tab to record or edit period dates',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get primaryStatus {
    final open = viewModel.openPeriod;
    if (open != null) {
      final days = viewModel.recordedPeriodDay ?? 1;
      return 'Period day $days · $days bleeding '
          '${days == 1 ? 'day' : 'days'} recorded';
    }
    if (!viewModel.hasHistory) return 'No period dates recorded yet.';
    final cycleDay = viewModel.cycleDay;
    final prediction = viewModel.chartPrediction;
    if (prediction == null) {
      return cycleDay == null
          ? 'Your cycle record is taking shape.'
          : 'Cycle day $cycleDay from your recorded start.';
    }
    switch (prediction.timingFor(viewModel.today)) {
      case PredictionTiming.laterThanEstimate:
        final days =
            viewModel.today.epochDay - prediction.predictedMensesEnd.epochDay;
        return '$days ${days == 1 ? 'day' : 'days'} later than the estimated range.';
      case PredictionTiming.currentWindow:
        return cycleDay == null
            ? 'Inside the estimated period range.'
            : 'Cycle day $cycleDay · inside the estimated period range.';
      case PredictionTiming.upcoming:
        if (viewModel.isTodayInEstimatedPremenstrualWindow) {
          return cycleDay == null
              ? 'In the estimated premenstrual window.'
              : 'Cycle day $cycleDay · in the estimated premenstrual window.';
        }
        return cycleDay == null
            ? 'Your next estimate is ahead.'
            : 'Cycle day $cycleDay · next estimate ahead.';
    }
  }

  String get supportingStatus {
    final open = viewModel.openPeriod;
    if (open != null) {
      return 'Started ${_shortDate(open.startDate)}. No end date recorded yet.';
    }
    if (!viewModel.hasHistory) {
      return 'Record a period in Cycles to begin a private timeline.';
    }
    final prediction = viewModel.chartPrediction;
    if (prediction == null) {
      return 'More recorded period starts are needed before Letter Within estimates a range.';
    }
    final range = _dateRange(
      prediction.predictedMensesStart,
      prediction.predictedMensesEnd,
    );
    switch (prediction.timingFor(viewModel.today)) {
      case PredictionTiming.laterThanEstimate:
        return 'No new period start is recorded yet. This is a date comparison, not a health conclusion.';
      case PredictionTiming.currentWindow:
        return '$range was calculated from your recorded period starts.';
      case PredictionTiming.upcoming:
        return 'Estimated next period: $range.';
    }
  }

  String accessibleSummary(BuildContext context) {
    final fullDate = MaterialLocalizations.of(
      context,
    ).formatFullDate(viewModel.today.asLocalDateTime);
    final parts = <String>['Today is $fullDate.'];
    final open = viewModel.openPeriod;
    if (open != null) {
      parts.add(
        'A recorded period is in progress since ${_shortDate(open.startDate)}, '
        'day ${viewModel.recordedPeriodDay}.',
      );
    } else if (viewModel.cycleDay != null) {
      parts.add(
        'Cycle day ${viewModel.cycleDay}, counted from the recorded start on '
        '${_shortDate(viewModel.lastPeriodStart!)}.',
      );
    } else {
      parts.add('No period dates recorded, so there is no cycle day.');
    }
    final prediction = viewModel.chartPrediction;
    if (prediction == null) {
      parts.add(
        viewModel.hasHistory
            ? 'No estimated range yet: more recorded periods are needed.'
            : 'No estimated range.',
      );
    } else {
      parts.add(
        'Estimated range ${_shortDate(prediction.predictedMensesStart)} to '
        '${_shortDate(prediction.predictedMensesEnd)}, confidence '
        '${prediction.confidence.label.toLowerCase()}, from '
        '${prediction.intervalCount} recorded intervals.',
      );
      if (prediction.timingFor(viewModel.today) ==
          PredictionTiming.laterThanEstimate) {
        final days =
            viewModel.today.epochDay - prediction.predictedMensesEnd.epochDay;
        parts.add('Today is $days days after that range.');
      }
    }
    parts.add(
      'Left to right follows continuous cycle time from one period toward the next. '
      'Higher on the chart means lighter estimated cycle gravity. '
      'Lower means potentially heavier estimated cycle gravity before the period. '
      'Double tap to open Cycle.',
    );
    return parts.join(' ');
  }
}

class _HorizonChart extends StatelessWidget {
  const _HorizonChart({required this.viewModel});

  final GravityHorizonViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final height = (168 * math.min(textScale, 1.35))
        .clamp(168.0, 226.0)
        .toDouble();
    return SizedBox(
      height: height,
      child: ClipRect(
        child: CustomPaint(
          painter: GravityHorizonPainter(
            viewModel: viewModel,
            textScale: textScale,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class GravityHorizonPainter extends CustomPainter {
  GravityHorizonPainter({required this.viewModel, required this.textScale});

  final GravityHorizonViewModel viewModel;
  final double textScale;

  double get _labelSize => 9.5 * math.min(textScale, 1.35);
  double get _plotLeft => 56 * math.min(textScale, 1.25);
  static const _plotRightInset = 8.0;

  double _x(LocalDate date, double width) {
    final window = viewModel.chartWindow;
    final span = window.end.epochDay - window.start.epochDay;
    if (span <= 0) return _plotLeft;
    final value = (date.epochDay - window.start.epochDay) / span;
    return _plotLeft +
        value.clamp(0.0, 1.0) * (width - _plotLeft - _plotRightInset);
  }

  double _y(LocalDate date, double lighter, double heavier) {
    final gravity = viewModel.estimatedGravityLevel(date) ?? 0.5;
    return heavier - gravity * (heavier - lighter);
  }

  Path _curve(
    LocalDate from,
    LocalDate to,
    double width,
    double lighter,
    double heavier,
  ) {
    final path = Path();
    final steps = math.max(to.epochDay - from.epochDay, 1);
    for (var index = 0; index <= steps; index++) {
      final date = from.addDays(index);
      final point = Offset(_x(date, width), _y(date, lighter, heavier));
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 7.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var position = 0.0;
      while (position < metric.length) {
        final next = math.min(position + dash, metric.length);
        canvas.drawPath(metric.extractPath(position, next), paint);
        position = next + gap;
      }
    }
  }

  TextPainter _text(String value, Color color) {
    return TextPainter(
      text: TextSpan(
        text: value,
        style: lovable
            .letterEyebrow(color: color)
            .copyWith(
              fontSize: _labelSize,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
            ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lighter = 22.0;
    final heavier = size.height - 56;
    final railY = size.height - 40;
    final axisY = size.height - _labelSize - 2;
    final plotRight = size.width - _plotRightInset;
    final window = viewModel.chartWindow;
    final prediction = viewModel.chartPrediction;
    final lastStart = viewModel.lastPeriodStart;

    if (prediction != null) {
      _paintHatchedRange(
        canvas,
        prediction.predictedMensesStart,
        prediction.predictedMensesEnd,
        size.width,
        lighter - 8,
        railY + 6,
      );
    }

    final guidePaint = Paint()
      ..color = lovable.LetterTokens.line
      ..strokeWidth = 1;
    _drawDashedLine(
      canvas,
      Offset(_plotLeft, lighter),
      Offset(plotRight, lighter),
      guidePaint,
      dash: 1,
      gap: 4,
    );
    _drawDashedLine(
      canvas,
      Offset(_plotLeft, heavier),
      Offset(plotRight, heavier),
      guidePaint,
      dash: 1,
      gap: 4,
    );
    _paintScaleLabel(canvas, 'LIGHTER', lighter);
    _paintScaleLabel(canvas, 'HEAVIER', heavier);

    final estimatedPaint = Paint()
      ..color = lovable.LetterColors.clinicalBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (prediction != null && lastStart != null) {
      final curveStart = window.start;
      final curve = _curve(
        curveStart,
        window.end,
        size.width,
        lighter,
        heavier,
      );
      final fill = Path.from(curve)
        ..lineTo(_x(window.end, size.width), heavier)
        ..lineTo(_x(curveStart, size.width), heavier)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lovable.LetterColors.clinicalBlue.withValues(alpha: 0.12),
              lovable.LetterColors.clinicalBlue.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTRB(_plotLeft, lighter, plotRight, heavier)),
      );
      _drawDashed(canvas, curve, estimatedPaint);
    }

    canvas.drawLine(
      Offset(_plotLeft, railY),
      Offset(plotRight, railY),
      Paint()
        ..color = lovable.LetterTokens.line
        ..strokeWidth = 1,
    );
    for (final record in viewModel.records) {
      final recordEnd = record.endDate ?? viewModel.today;
      if (recordEnd.isBefore(window.start) ||
          record.startDate.isAfter(window.end)) {
        continue;
      }
      final x1 = _x(record.startDate, size.width);
      final x2 = _x(recordEnd, size.width);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x1, railY - 3, math.max(x2 - x1, 4), 6),
          const Radius.circular(3),
        ),
        Paint()..color = lovable.LetterTokens.teal,
      );
    }

    final todayX = _x(viewModel.today, size.width);
    canvas.drawLine(
      Offset(todayX, lighter - 10),
      Offset(todayX, railY + 8),
      Paint()
        ..color = lovable.LetterTokens.ink.withValues(alpha: 0.58)
        ..strokeWidth = 1,
    );
    if (prediction != null && lastStart != null) {
      final point = Offset(todayX, _y(viewModel.today, lighter, heavier));
      canvas.drawCircle(
        point,
        6,
        Paint()..color = lovable.LetterTokens.surface,
      );
      canvas.drawCircle(point, 3.4, Paint()..color = lovable.LetterTokens.ink);
    }

    _paintDateAnchors(canvas, size.width, axisY, todayX, prediction);
  }

  void _paintHatchedRange(
    Canvas canvas,
    LocalDate from,
    LocalDate to,
    double width,
    double top,
    double bottom,
  ) {
    final left = _x(from, width);
    final right = _x(to, width);
    final rect = Rect.fromLTRB(left, top, math.max(left + 5, right), bottom);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..color = lovable.LetterColors.clinicalBlue.withValues(alpha: 0.05),
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)));
    final hatch = Paint()
      ..color = lovable.LetterColors.clinicalBlue.withValues(alpha: 0.27)
      ..strokeWidth = 1;
    for (var x = rect.left - rect.height; x < rect.right; x += 7) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height, rect.top),
        hatch,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..color = lovable.LetterColors.clinicalBlue.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    var x = from.dx;
    while (x < to.dx) {
      canvas.drawLine(
        Offset(x, from.dy),
        Offset(math.min(x + dash, to.dx), to.dy),
        paint,
      );
      x += dash + gap;
    }
  }

  void _paintScaleLabel(Canvas canvas, String value, double y) {
    final painter = _text(value, lovable.LetterTokens.muted);
    painter.paint(
      canvas,
      Offset(_plotLeft - painter.width - 8, y - painter.height / 2),
    );
  }

  void _paintDateAnchors(
    Canvas canvas,
    double width,
    double y,
    double todayX,
    CyclePrediction? prediction,
  ) {
    final anchors = <({double x, String label, bool today})>[];
    final start = viewModel.lastPeriodStart;
    if (start != null) {
      anchors.add((
        x: _x(start, width),
        label: _shortDate(start),
        today: false,
      ));
    }
    anchors.add((x: todayX, label: 'TODAY', today: true));
    if (prediction != null) {
      anchors.add((
        x: _x(prediction.predictedMensesStart, width),
        label: _shortDate(prediction.predictedMensesStart),
        today: false,
      ));
    }
    anchors.sort((a, b) => a.x.compareTo(b.x));
    final placed = <({double x, String label, bool today})>[];
    for (final anchor in anchors) {
      if (placed.isEmpty || anchor.x - placed.last.x > 46) {
        placed.add(anchor);
      } else if (anchor.today) {
        placed[placed.length - 1] = anchor;
      }
    }
    for (final anchor in placed) {
      final color = anchor.today
          ? lovable.LetterTokens.ink
          : lovable.LetterTokens.muted;
      final painter = _text(anchor.label, color);
      final left = (anchor.x - painter.width / 2)
          .clamp(_plotLeft, math.max(_plotLeft, width - painter.width))
          .toDouble();
      painter.paint(canvas, Offset(left, y));
    }
  }

  @override
  bool shouldRepaint(covariant GravityHorizonPainter oldDelegate) {
    return oldDelegate.viewModel != viewModel ||
        oldDelegate.textScale != textScale;
  }
}

// Legacy private helpers kept temporarily while the generated kit is shared
// with Cycle and Spectrum; they are not part of the rendered Lovable tree.
// ignore: unused_element
class _Legend extends StatelessWidget {
  const _Legend({required this.showRange});

  final bool showRange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _LegendItem(
          kind: _LegendKind.solid,
          color: LetterColors.teal,
          label: 'Observed — dates you recorded',
        ),
        const SizedBox(height: LetterSpacing.xxs),
        const _LegendItem(
          kind: _LegendKind.dashed,
          color: LetterColors.blue,
          label: 'Estimated — calculated dates',
        ),
        if (showRange) ...[
          const SizedBox(height: LetterSpacing.xxs),
          const _LegendItem(
            kind: _LegendKind.hatched,
            color: LetterColors.blue,
            label: 'Estimated range',
          ),
        ],
        const SizedBox(height: LetterSpacing.xxs),
        const _LegendItem(
          kind: _LegendKind.vertical,
          color: LetterColors.ink,
          label: 'Today',
        ),
      ],
    );
  }
}

enum _LegendKind { solid, dashed, hatched, vertical }

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.kind,
    required this.color,
    required this.label,
  });

  final _LegendKind kind;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CustomPaint(
          size: const Size(22, 12),
          painter: _LegendPainter(kind: kind, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: LetterColors.muted,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendPainter extends CustomPainter {
  const _LegendPainter({required this.kind, required this.color});

  final _LegendKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    switch (kind) {
      case _LegendKind.solid:
        canvas.drawLine(
          Offset(0, size.height / 2),
          Offset(size.width, size.height / 2),
          paint,
        );
      case _LegendKind.dashed:
        for (var x = 0.0; x < size.width; x += 7) {
          canvas.drawLine(
            Offset(x, size.height / 2),
            Offset(math.min(x + 4, size.width), size.height / 2),
            paint,
          );
        }
      case _LegendKind.hatched:
        final rect = Rect.fromLTWH(0, 2, size.width, size.height - 4);
        canvas.drawRect(rect, paint..strokeWidth = 1);
        for (var x = -size.height; x < size.width; x += 6) {
          canvas.drawLine(
            Offset(x, rect.bottom),
            Offset(x + size.height, rect.top),
            paint,
          );
        }
      case _LegendKind.vertical:
        canvas.drawLine(
          Offset(size.width / 2, 0),
          Offset(size.width / 2, size.height),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _LegendPainter oldDelegate) => false;
}

// ignore: unused_element
class _ConfidenceLine extends StatelessWidget {
  const _ConfidenceLine({required this.prediction});

  final CyclePrediction prediction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LetterSpacing.sm,
        vertical: LetterSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: LetterColors.blueSoft,
        borderRadius: BorderRadius.circular(LetterRadius.control),
      ),
      child: Text(
        '${prediction.confidence.label} confidence · based on '
        '${prediction.intervalCount} recorded '
        '${prediction.intervalCount == 1 ? 'interval' : 'intervals'}.',
        style: const TextStyle(fontSize: 12, height: 1.35),
      ),
    );
  }
}

// ignore: unused_element
class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    required this.term,
    required this.value,
    required this.observed,
    required this.last,
  });

  final String term;
  final String value;
  final bool? observed;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: last
              ? BorderSide.none
              : const BorderSide(color: LetterColors.line),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 330 || context.isLetterLargeText;
          final termWidget = Text(
            term,
            style: const TextStyle(color: LetterColors.muted, fontSize: 12),
          );
          final valueWidget = Wrap(
            alignment: stacked ? WrapAlignment.start : WrapAlignment.end,
            spacing: LetterSpacing.xs,
            runSpacing: LetterSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                value,
                textAlign: stacked ? TextAlign.start : TextAlign.end,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (observed != null) _ProvenanceTag(observed: observed!),
            ],
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                termWidget,
                const SizedBox(height: LetterSpacing.xxs),
                valueWidget,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: termWidget),
              const SizedBox(width: LetterSpacing.sm),
              Flexible(flex: 2, child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

class _ProvenanceTag extends StatelessWidget {
  const _ProvenanceTag({required this.observed});

  final bool observed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: observed ? LetterColors.tealSoft : LetterColors.blueSoft,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        observed ? 'OBSERVED' : 'ESTIMATED',
        style: TextStyle(
          color: observed ? LetterColors.tealDark : LetterColors.blue,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

String _shortDate(LocalDate date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

String _dateRange(LocalDate start, LocalDate end) {
  if (start.year == end.year && start.month == end.month) {
    return '${_shortDate(start)}–${end.day}';
  }
  return '${_shortDate(start)} – ${_shortDate(end)}';
}
