import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/cycle/domain/cycle_prediction.dart';
import '../../features/cycle/domain/local_date.dart';
import '../../features/cycle/domain/period_record.dart';
import '../../features/insights/presentation/gravity_horizon_view_model.dart';
import '../../features/summary_export/domain/cycle_care_summary.dart';
import '../source/source_panel.dart';
import '../theme/experience_foundation.dart';

/// The estimated cycle-gravity chart — the free, lead chart of Patterns.
///
/// Gravity is the orbit seen edge-on: a horizon the ember descends toward.
/// Every pixel is traceable:
///  * the curve is sampled exclusively from
///    [GravityHorizonViewModel.estimatedGravityLevel], which itself renders
///    only [GravityHorizonViewModel.chartPrediction] — an open period
///    suppresses the estimated curve, and this widget never works around
///    that suppression;
///  * observed period bands come from [PeriodRecord]s and render solid;
///  * estimated windows render with the dashed "est." texture and are
///    labeled everywhere as estimates from the predicted luteal window —
///    never a measurement, never a clinical conclusion.
///
/// All five [HorizonStateId]s are honored: [HorizonStateId.noHistory] and
/// [HorizonStateId.insufficientHistory] render structural previews naming the
/// exact next action with a remaining count derived from the records (never
/// hard-coded); [HorizonStateId.periodInProgress] explains the resting curve;
/// [HorizonStateId.pastEstimatedRange] is honest about being later than the
/// estimate without alarm.
///
/// Order of disclosure follows the shared chart grammar: plain-language
/// takeaway (serif, numeral-free) → chart → evidence (legend, source panel).
/// Any tap, keyboard activation, or horizontal scrub opens the SourcePanel
/// with the records and estimates behind the mark. First paint draws the
/// curve on once per appearance (600 ms); under the platform reduced-motion
/// setting the chart appears settled and data updates crossfade instantly.
final class GravityChart extends StatefulWidget {
  const GravityChart({
    super.key,
    required this.viewModel,
    this.expanded = true,
    this.onRecordPeriodStart,
    this.onBackfillPastPeriod,
    this.onEditRecord,
  });

  /// The presentation adapter. This widget adds no phase math and no
  /// inference of its own — it renders the view model verbatim.
  final GravityHorizonViewModel viewModel;

  /// Accent hierarchy rule: only the expanded family renders at full accent
  /// saturation within a viewport. Collapsed sections pass `false` and the
  /// Gravity accent steps down one weight so families never compete.
  final bool expanded;

  /// Route into recording a period start — the named next action of the
  /// structural previews.
  final VoidCallback? onRecordPeriodStart;

  /// Route into whole-cycle backfill — the fastest honest path to a working
  /// estimate when history is partial.
  final VoidCallback? onBackfillPastPeriod;

  /// Route into editing a specific recorded period, offered from the
  /// SourcePanel's evidence rows.
  final void Function(PeriodRecord record)? onEditRecord;

  @override
  State<GravityChart> createState() => _GravityChartState();
}

/// The shared estimated-texture dash renderer, used by the skeleton and the
/// live painter alike so the estimated treatment is identical everywhere.
void _drawDashedPath(
  Canvas canvas,
  Path path,
  Paint paint,
  List<double> pattern,
) {
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    var draw = true;
    var index = 0;
    while (distance < metric.length) {
      final length = pattern[index % pattern.length];
      if (draw) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            math.min(distance + length, metric.length),
          ),
          paint,
        );
      }
      distance += length;
      draw = !draw;
      index++;
    }
  }
}

class _GravityChartState extends State<GravityChart>
    with TickerProviderStateMixin {
  late final AnimationController _drawOn = AnimationController(
    vsync: this,
    duration: ExperienceMotion.chartDrawOn,
  );
  late final AnimationController _dataFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: 1,
  );
  final FocusNode _focusNode = FocusNode();

  /// Epoch day of the focus cursor moved by scrub or arrow keys.
  int? _cursorEpochDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ExperienceMotion.reducedMotion(context)) {
        // Reduced motion: draw-on is skipped; the chart appears settled.
        _drawOn.value = 1;
      } else {
        _drawOn.forward();
      }
    });
  }

  @override
  void didUpdateWidget(GravityChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.viewModel, widget.viewModel)) {
      // Data updates crossfade; the draw-on happens only once per appearance.
      if (ExperienceMotion.reducedMotion(context)) {
        _dataFade.value = 1;
      } else {
        _dataFade.forward(from: 0.35);
      }
    }
  }

  @override
  void dispose() {
    _drawOn.dispose();
    _dataFade.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Copy — takeaway-first, serif lines stay numeral-free; numerals always
  // render in sans tabular figures below.
  // -------------------------------------------------------------------------

  String _takeaway(HorizonStateId state) {
    return switch (state) {
      HorizonStateId.noHistory =>
        'Your gravity line begins with one recorded period',
      HorizonStateId.insufficientHistory =>
        'The curve is forming as your history grows',
      HorizonStateId.predictionAvailable =>
        'Gravity tends to gather before your estimated period',
      HorizonStateId.periodInProgress =>
        'Your period is here — the estimate steps back',
      HorizonStateId.pastEstimatedRange =>
        'This cycle is running later than the estimate',
    };
  }

  String _supportLine(HorizonStateId state) {
    return switch (state) {
      HorizonStateId.noHistory =>
        'Record a period start and this horizon begins to take shape.',
      HorizonStateId.insufficientHistory =>
        'Each recorded start sharpens the estimate drawn here.',
      HorizonStateId.predictionAvailable =>
        'A timing estimate from your predicted luteal window — '
            'never a measurement or a diagnosis.',
      HorizonStateId.periodInProgress =>
        'What you record leads. The estimated curve rests while this '
            'period is being recorded.',
      HorizonStateId.pastEstimatedRange =>
        'Estimates describe timing, not deadlines. Recording the start '
            'when it arrives keeps everything honest.',
    };
  }

  // -------------------------------------------------------------------------
  // Cursor + interaction
  // -------------------------------------------------------------------------

  LocalDate? _cursorDate() {
    final epoch = _cursorEpochDay;
    if (epoch == null) return null;
    final window = widget.viewModel.chartWindow;
    return window.start.addDays(epoch - window.start.epochDay);
  }

  void _setCursorFromDx(double dx, double width, {bool haptic = true}) {
    if (width <= 0) return;
    final window = widget.viewModel.chartWindow;
    final span = window.end.epochDay - window.start.epochDay;
    if (span <= 0) return;
    final fraction = (dx / width).clamp(0.0, 1.0);
    final epoch = window.start.epochDay + (span * fraction).round();
    if (epoch == _cursorEpochDay) return;
    setState(() => _cursorEpochDay = epoch);
    if (haptic) ExperienceHaptics.pick();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final window = widget.viewModel.chartWindow;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final delta = key == LogicalKeyboardKey.arrowLeft ? -1 : 1;
      final current = _cursorEpochDay ?? widget.viewModel.today.epochDay;
      final next =
          current.clamp(window.start.epochDay, window.end.epochDay) + delta;
      final clamped = next.clamp(window.start.epochDay, window.end.epochDay);
      if (clamped != _cursorEpochDay) {
        setState(() => _cursorEpochDay = clamped);
        ExperienceHaptics.pick();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      _openSourcePanel(focusDate: _cursorDate());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  PeriodRecord? _recordCovering(LocalDate date) {
    for (final record in widget.viewModel.records) {
      final end = record.endDate ?? widget.viewModel.today;
      if (!date.isBefore(record.startDate) && !date.isAfter(end)) {
        return record;
      }
    }
    return null;
  }

  String _cursorDescription() {
    final date = _cursorDate();
    if (date == null) return '';
    final buffer = StringBuffer(summaryDateLabel(date));
    final record = _recordCovering(date);
    if (record != null) {
      buffer.write(
        record.isOpen
            ? ' — observed period day, still being recorded'
            : ' — observed period day',
      );
      return buffer.toString();
    }
    final level = widget.viewModel.estimatedGravityLevel(date);
    if (level == null) {
      buffer.write(' — nothing recorded, no estimate here');
      return buffer.toString();
    }
    final word = level >= 0.66
        ? 'lighter'
        : level >= 0.34
        ? 'easing'
        : 'heavier';
    buffer.write(' — estimated gravity $word (est.)');
    return buffer.toString();
  }

  // -------------------------------------------------------------------------
  // Source inspection — the records and estimates behind any mark.
  // -------------------------------------------------------------------------

  Future<void> _openSourcePanel({LocalDate? focusDate}) {
    final viewModel = widget.viewModel;
    final window = viewModel.chartWindow;
    final prediction = viewModel.chartPrediction;

    final entries = <SourcePanelEntry>[];
    for (final record in viewModel.records) {
      final end = record.endDate ?? viewModel.today;
      if (record.startDate.isAfter(window.end) || end.isBefore(window.start)) {
        continue;
      }
      final recordRef = record;
      entries.add(
        SourcePanelEntry(
          title: record.isOpen ? 'Period being recorded' : 'Period recorded',
          certainty: ExperienceCertainty.observed,
          dateLabel:
              '${summaryDateLabel(record.startDate)} – ${record.endDate == null ? 'ongoing' : summaryDateLabel(record.endDate!)}',
          sourceLabel: 'Your cycle record · local only',
          details: const <String>[
            'Observed period band — drawn solid on the chart.',
          ],
          onEdit: widget.onEditRecord == null
              ? null
              : () => widget.onEditRecord!(recordRef),
        ),
      );
    }
    if (prediction != null) {
      entries.add(
        SourcePanelEntry(
          title: 'Estimated period window',
          certainty: ExperienceCertainty.estimated,
          dateLabel:
              '${summaryDateLabel(prediction.predictedMensesStart)} – ${summaryDateLabel(prediction.predictedMensesEnd)}',
          sourceLabel: 'Estimate from your recorded cycle history',
          details: <String>[
            'Based on ${prediction.intervalCount} recorded intervals; '
                'median about ${prediction.medianCycleDays} days.',
            'Confidence: ${prediction.confidence.label}.',
            'Drawn dashed and labeled "est." on the chart.',
          ],
        ),
      );
      entries.add(
        SourcePanelEntry(
          title: 'Estimated pre-period window',
          certainty: ExperienceCertainty.estimated,
          dateLabel:
              '${summaryDateLabel(prediction.predictedLutealStart)} – ${summaryDateLabel(prediction.predictedLutealEnd)}',
          sourceLabel: 'Estimate from the predicted luteal window',
          details: const <String>[
            'A calendar estimate counted back from the estimated period — '
                'not a detected phase.',
            'The gravity curve descends through this window toward the '
                'estimated period.',
          ],
        ),
      );
    }

    return SourcePanel.show(
      context,
      title: focusDate == null
          ? "What's behind this curve"
          : "What's behind ${summaryDateLabel(focusDate)}",
      subtitle:
          'Observed period bands come from your records. The curve and '
          'dashed ranges are labeled estimates from your predicted luteal '
          'window — never a clinical conclusion.',
      entries: entries,
      certainty: prediction != null
          ? ExperienceCertainty.estimated
          : ExperienceCertainty.observed,
    );
  }

  String _chartSemanticsLabel(HorizonStateId state) {
    final viewModel = widget.viewModel;
    final parts = <String>['Cycle gravity chart.', _takeaway(state)];
    final prediction = viewModel.chartPrediction;
    if (state == HorizonStateId.periodInProgress) {
      parts.add(
        'Your period is being recorded, so the estimated curve is resting.',
      );
    } else if (prediction != null) {
      parts.add(
        'Estimated period window '
        '${summaryDateLabel(prediction.predictedMensesStart)} to '
        '${summaryDateLabel(prediction.predictedMensesEnd)}, '
        'labeled estimate. Confidence ${prediction.confidence.label}.',
      );
    }
    parts.add(
      'Observed period bands are solid; dashed marks are estimates; '
      'blank areas mean nothing is recorded.',
    );
    parts.add(
      'An estimate of timing from your recorded history, not a measurement '
      'or a diagnosis.',
    );
    return parts.join(' ');
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final state = viewModel.stateId;
    final isPreview =
        state == HorizonStateId.noHistory ||
        state == HorizonStateId.insufficientHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            _takeaway(state),
            style: ExperienceType.title(ExperienceColors.ink),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.xs + 4),
        Text(
          _supportLine(state),
          style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        if (isPreview) _StructuralPreview(state: state, chart: widget),
        if (!isPreview) ...<Widget>[
          _chartSection(context, state),
          const SizedBox(height: ExperienceSpacing.xs + 8),
          const _GravityLegend(),
          const SizedBox(height: ExperienceSpacing.xs + 4),
          _stateFooter(context, state),
        ],
      ],
    );
  }

  Widget _chartSection(BuildContext context, HorizonStateId state) {
    final viewModel = widget.viewModel;
    final window = viewModel.chartWindow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          label: _chartSemanticsLabel(state),
          hint:
              'Double tap to inspect the records and estimates behind '
              'this chart. Use arrow keys to move the focus cursor.',
          button: true,
          child: Focus(
            focusNode: _focusNode,
            onKeyEvent: _handleKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    _setCursorFromDx(
                      details.localPosition.dx,
                      width,
                      haptic: false,
                    );
                    _openSourcePanel(focusDate: _cursorDate());
                  },
                  onLongPress: () => _openSourcePanel(),
                  onHorizontalDragStart: (details) =>
                      _setCursorFromDx(details.localPosition.dx, width),
                  onHorizontalDragUpdate: (details) =>
                      _setCursorFromDx(details.localPosition.dx, width),
                  child: FadeTransition(
                    opacity: _dataFade,
                    child: SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: AnimatedBuilder(
                        animation: _drawOn,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _GravityChartPainter(
                              viewModel: viewModel,
                              progress: _drawOn.value,
                              accentWeight: widget.expanded ? 1 : 0.45,
                              cursorEpochDay: _cursorEpochDay,
                            ),
                            child: const _GuideLabels(),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.xs + 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              summaryDateLabel(window.start),
              style: ExperienceType.data(
                ExperienceColors.inkFaint,
                size: 12,
                weight: FontWeight.w400,
              ),
            ),
            Text(
              'today',
              style: ExperienceType.caption(ExperienceColors.inkFaint),
            ),
            Text(
              summaryDateLabel(window.end),
              style: ExperienceType.data(
                ExperienceColors.inkFaint,
                size: 12,
                weight: FontWeight.w400,
              ),
            ),
          ],
        ),
        SizedBox(
          height: 22,
          child: _cursorEpochDay == null
              ? const SizedBox.shrink()
              : Semantics(
                  liveRegion: true,
                  child: Text(
                    _cursorDescription(),
                    style: ExperienceType.caption(ExperienceColors.inkSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _stateFooter(BuildContext context, HorizonStateId state) {
    final viewModel = widget.viewModel;
    final prediction = viewModel.chartPrediction;

    switch (state) {
      case HorizonStateId.predictionAvailable:
        final p = prediction;
        if (p == null) return const SizedBox.shrink();
        final lowConfidence = p.confidence == PredictionConfidence.low;
        return Padding(
          padding: const EdgeInsets.only(top: ExperienceSpacing.xs),
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: 'Estimated period window ',
                  style: ExperienceType.caption(ExperienceColors.inkSoft),
                ),
                TextSpan(
                  text:
                      '${summaryDateLabel(p.predictedMensesStart)} – '
                      '${summaryDateLabel(p.predictedMensesEnd)}',
                  style: ExperienceType.data(ExperienceColors.ink, size: 13),
                ),
                TextSpan(
                  text: ' (est.) · confidence ',
                  style: ExperienceType.caption(ExperienceColors.inkSoft),
                ),
                TextSpan(
                  text: p.confidence.label.toLowerCase(),
                  style: ExperienceType.data(ExperienceColors.ink, size: 13),
                ),
                if (lowConfidence)
                  TextSpan(
                    text: ' — rough estimate',
                    style: ExperienceType.caption(ExperienceColors.inkSoft),
                  ),
              ],
            ),
          ),
        );
      case HorizonStateId.periodInProgress:
        return Padding(
          padding: const EdgeInsets.only(top: ExperienceSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.water_drop_outlined,
                  size: 16,
                  color: ExperienceColors.phasePeriod,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Day ${viewModel.recordedPeriodDay ?? 1} of your recorded '
                  'period. The curve returns when this period is logged.',
                  style: ExperienceType.caption(ExperienceColors.inkSoft),
                ),
              ),
            ],
          ),
        );
      case HorizonStateId.pastEstimatedRange:
        final p = viewModel.prediction;
        return Padding(
          padding: const EdgeInsets.only(top: ExperienceSpacing.xs),
          child: Text(
            p == null
                ? 'Later than the estimate — your record stays the source '
                      'of truth.'
                : 'The estimated window was '
                      '${summaryDateLabel(p.predictedMensesStart)} – '
                      '${summaryDateLabel(p.predictedMensesEnd)}. Later than an '
                      'estimate is still normal variation — recording the start '
                      'when it arrives keeps everything honest.',
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
        );
      case HorizonStateId.noHistory:
      case HorizonStateId.insufficientHistory:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// Structural previews — noHistory and insufficientHistory. The skeleton shows
// what will appear and names the exact next action; the remaining count is
// derived from the records and the prediction contract, never hard-coded.
// ---------------------------------------------------------------------------

class _StructuralPreview extends StatelessWidget {
  const _StructuralPreview({required this.state, required this.chart});

  final HorizonStateId state;
  final GravityChart chart;

  @override
  Widget build(BuildContext context) {
    final records = chart.viewModel.records;
    final observedIntervals = CyclePredictionEngine.observedIntervalCount(
      records,
    );
    final remaining = math.max(
      0,
      CyclePredictionEngine.minimumIntervals - observedIntervals,
    );

    final String message = switch (state) {
      HorizonStateId.noHistory =>
        'Record your first period start and this chart begins to form.',
      _ =>
        remaining <= 1
            ? 'One more recorded period start will draw your estimate here.'
            : '$remaining more recorded period starts will draw your '
                  'estimate here.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          label: 'Preview of the cycle gravity chart. $message',
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: ExperienceColors.surface,
              borderRadius: ExperienceRadius.cardRadius,
              border: Border.all(color: ExperienceColors.hairline),
            ),
            child: ClipRRect(
              borderRadius: ExperienceRadius.cardRadius,
              child: const Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  CustomPaint(
                    painter: DotGridPainter(
                      color: ExperienceColors.hairline,
                      spacing: 12,
                    ),
                  ),
                  CustomPaint(painter: _GravitySkeletonPainter()),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.xs + 8),
        Text(message, style: ExperienceType.bodySmall(ExperienceColors.ink)),
        const SizedBox(height: ExperienceSpacing.xs + 8),
        Wrap(
          spacing: ExperienceSpacing.xs + 8,
          runSpacing: ExperienceSpacing.xs + 4,
          children: <Widget>[
            if (chart.onRecordPeriodStart != null)
              FilledButton(
                onPressed: chart.onRecordPeriodStart,
                style: FilledButton.styleFrom(
                  backgroundColor: ExperienceColors.ember,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, ExperienceSpacing.degreeTarget),
                  textStyle: ExperienceType.label(Colors.white),
                  shape: const RoundedRectangleBorder(
                    borderRadius: ExperienceRadius.chipRadius,
                  ),
                ),
                child: const Text('Record a period start'),
              ),
            if (chart.onBackfillPastPeriod != null)
              OutlinedButton(
                onPressed: chart.onBackfillPastPeriod,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ExperienceColors.ink,
                  side: const BorderSide(color: ExperienceColors.hairline),
                  minimumSize: const Size(0, ExperienceSpacing.degreeTarget),
                  textStyle: ExperienceType.label(ExperienceColors.ink),
                  shape: const RoundedRectangleBorder(
                    borderRadius: ExperienceRadius.chipRadius,
                  ),
                ),
                child: const Text('Backfill a past period'),
              ),
          ],
        ),
      ],
    );
  }
}

class _GravitySkeletonPainter extends CustomPainter {
  const _GravitySkeletonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = ExperienceColors.hairline
      ..strokeWidth = 1;
    _drawDashedPath(
      canvas,
      Path()
        ..moveTo(8, 12)
        ..lineTo(size.width - 8, 12),
      guidePaint,
      const <double>[4, 4],
    );
    _drawDashedPath(
      canvas,
      Path()
        ..moveTo(8, size.height - 12)
        ..lineTo(size.width - 8, size.height - 12),
      guidePaint,
      const <double>[4, 4],
    );
    // The placeholder curve: the horizon the ember will descend along,
    // drawn as an estimated-texture ghost.
    final ghost = Path()
      ..moveTo(8, 20)
      ..lineTo(size.width * 0.45, 20)
      ..cubicTo(
        size.width * 0.6,
        20,
        size.width * 0.7,
        size.height - 24,
        size.width - 12,
        size.height - 24,
      );
    _drawDashedPath(
      canvas,
      ghost,
      Paint()
        ..color = ExperienceColors.accentGravity.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
      const <double>[6, 4],
    );
  }

  @override
  bool shouldRepaint(_GravitySkeletonPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Guide labels — "lighter" / "heavier" anchors on the horizon.
// ---------------------------------------------------------------------------

class _GuideLabels extends StatelessWidget {
  const _GuideLabels();

  @override
  Widget build(BuildContext context) {
    final style = ExperienceType.caption(ExperienceColors.inkFaint);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(top: 2, left: 4, child: Text('lighter', style: style)),
          Positioned(bottom: 4, left: 4, child: Text('heavier', style: style)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Legend — the shared certainty texture key, identical across all charts.
// ---------------------------------------------------------------------------

class _GravityLegend extends StatelessWidget {
  const _GravityLegend();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'How to read this chart: solid bands are observed periods, '
          'dashed ranges are estimates labeled estimate, blank areas mean '
          'nothing is recorded, and the coral ember marks today.',
      child: Wrap(
        spacing: ExperienceSpacing.sm,
        runSpacing: ExperienceSpacing.xs + 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          const _LegendEntry(
            swatch: CertaintySwatch(
              certainty: ExperienceCertainty.observed,
              color: ExperienceColors.phasePeriod,
            ),
            label: 'Observed period',
          ),
          const _LegendEntry(
            swatch: CertaintySwatch(
              certainty: ExperienceCertainty.estimated,
              color: ExperienceColors.accentGravity,
            ),
            label: 'Estimated window',
          ),
          const _LegendEntry(
            swatch: CertaintySwatch(certainty: ExperienceCertainty.unknown),
            label: 'Missing',
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ExcludeSemantics(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: ExperienceColors.emberGradient,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Today',
                style: ExperienceType.caption(ExperienceColors.inkSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.swatch, required this.label});

  final CertaintySwatch swatch;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        swatch,
        const SizedBox(width: 6),
        Text(label, style: ExperienceType.caption(ExperienceColors.inkSoft)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Painter — observed bands solid, estimated ranges dashed + "est.", the
// estimated curve in the Gravity accent, and the ember at today.
// ---------------------------------------------------------------------------

class _GravityChartPainter extends CustomPainter {
  const _GravityChartPainter({
    required this.viewModel,
    required this.progress,
    required this.accentWeight,
    this.cursorEpochDay,
  });

  final GravityHorizonViewModel viewModel;

  /// Draw-on progress (0–1). One per appearance; 1 under reduced motion.
  final double progress;

  /// Accent hierarchy: 1 when expanded, stepped down when collapsed.
  final double accentWeight;

  /// Focus cursor epoch day (scrub / keyboard), or null when unset.
  final int? cursorEpochDay;

  /// Observed and estimated period bands occupy the lower band of the
  /// chart — the heavier end of the horizon.
  static const double _bandHeightFraction = 0.42;

  @override
  void paint(Canvas canvas, Size size) {
    final viewModel = this.viewModel;
    final window = viewModel.chartWindow;
    final spanDays = window.end.epochDay - window.start.epochDay;
    if (spanDays <= 0 || size.width <= 0 || size.height <= 0) return;

    double xForEpoch(int epoch) {
      return ((epoch - window.start.epochDay) / spanDays).clamp(0.0, 1.0) *
          size.width;
    }

    double xFor(LocalDate date) => xForEpoch(date.epochDay);
    double yFor(double level) => size.height * (1 - level);

    const accent = ExperienceColors.accentGravity;
    const periodColor = ExperienceColors.phasePeriod;

    // Horizon guides: the lighter guide above, the heavier guide below.
    final guidePaint = Paint()
      ..color = ExperienceColors.hairline
      ..strokeWidth = 1;
    _drawDashedPath(
      canvas,
      Path()
        ..moveTo(0, yFor(1))
        ..lineTo(size.width, yFor(1)),
      guidePaint,
      const <double>[4, 4],
    );
    _drawDashedPath(
      canvas,
      Path()
        ..moveTo(0, yFor(0.06))
        ..lineTo(size.width, yFor(0.06)),
      guidePaint,
      const <double>[4, 4],
    );

    // The curve renders only from chartPrediction — an open period leaves
    // this null and the estimated layers below simply do not paint.
    final prediction = viewModel.chartPrediction;

    // Estimated pre-period window — full-height dashed band.
    if (prediction != null) {
      final left = xFor(prediction.predictedLutealStart);
      final right = xFor(prediction.predictedLutealEnd);
      final rect = Rect.fromLTRB(
        math.min(left, right),
        4,
        math.max(left, right),
        size.height - 4,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(
        rrect,
        Paint()..color = accent.withValues(alpha: 0.08 * accentWeight),
      );
      _drawDashedPath(
        canvas,
        Path()..addRRect(rrect),
        Paint()
          ..color = accent.withValues(alpha: 0.55 * accentWeight)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
        const <double>[6, 4],
      );
      _paintEstLabel(canvas, Offset(rect.left + 6, rect.top + 6));
    }

    // Estimated period range — lower band, dashed.
    if (prediction != null) {
      final left = xFor(prediction.predictedMensesStart);
      final right = xFor(prediction.predictedMensesEnd);
      final top = size.height * (1 - _bandHeightFraction);
      final rect = Rect.fromLTRB(
        math.min(left, right),
        top,
        math.max(left, right),
        size.height - 4,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(
        rrect,
        Paint()..color = periodColor.withValues(alpha: 0.10 * accentWeight),
      );
      _drawDashedPath(
        canvas,
        Path()..addRRect(rrect),
        Paint()
          ..color = periodColor.withValues(alpha: 0.7 * accentWeight)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
        const <double>[6, 4],
      );
      _paintEstLabel(canvas, Offset(rect.left + 6, rect.top + 6));
    }

    // Observed period bands — solid fill + solid border, clamped to the
    // visible window. An open period runs to today.
    for (final record in viewModel.records) {
      final start = record.startDate;
      if (start.isAfter(window.end)) continue;
      final end = record.endDate ?? viewModel.today;
      if (end.isBefore(window.start)) continue;
      final left = xFor(start.isBefore(window.start) ? window.start : start);
      final right = xFor(end.isAfter(window.end) ? window.end : end);
      if (right <= left) continue;
      final top = size.height * (1 - _bandHeightFraction);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTRB(left, top, right, size.height - 4),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        rrect,
        Paint()..color = periodColor.withValues(alpha: 0.85 * accentWeight),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = periodColor.withValues(alpha: accentWeight)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // The estimated gravity curve, sampled day by day from the view model.
    final points = <Offset>[];
    for (
      var epoch = window.start.epochDay;
      epoch <= window.end.epochDay;
      epoch++
    ) {
      final date = window.start.addDays(epoch - window.start.epochDay);
      final level = viewModel.estimatedGravityLevel(date);
      if (level == null) continue;
      final clamped = level.clamp(0.05, 1.0).toDouble();
      points.add(Offset(xForEpoch(epoch), yFor(clamped)));
    }
    if (points.length >= 2) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      final curvePaint = Paint()
        ..color = accent.withValues(alpha: 0.95 * accentWeight)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final reveal = progress.clamp(0.0, 1.0);
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(
          metric.extractPath(0, metric.length * reveal),
          curvePaint,
        );
      }
    }

    // The ember — today — resting on the curve, or on the heavier guide
    // when no estimate exists at today.
    final todayFraction = viewModel.dateFraction(viewModel.today);
    if (progress + 0.001 >= todayFraction) {
      final cx = xFor(viewModel.today);
      final level = viewModel.estimatedGravityLevel(viewModel.today);
      final cy = level == null
          ? yFor(0.06)
          : yFor(level.clamp(0.05, 1.0).toDouble());
      final center = Offset(cx, cy);
      canvas.drawCircle(
        center,
        9,
        Paint()
          ..color = ExperienceColors.emberGlow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        center,
        6,
        Paint()
          ..shader = ExperienceColors.emberGradient.createShader(
            Rect.fromCircle(center: center, radius: 6),
          ),
      );
      canvas.drawCircle(
        center,
        6,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Focus cursor — scrub and keyboard parity, with haptic ticks at day
    // boundaries handled by the widget.
    final cursor = cursorEpochDay;
    if (cursor != null) {
      final cx = xForEpoch(cursor);
      final linePaint = Paint()
        ..color = ExperienceColors.inkSoft.withValues(alpha: 0.7)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(cx, 4), Offset(cx, size.height - 4), linePaint);
      canvas.drawCircle(
        Offset(cx, 4),
        3,
        Paint()..color = ExperienceColors.inkSoft,
      );
    }
  }

  void _paintEstLabel(Canvas canvas, Offset position) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'est.',
        style: ExperienceType.caption(
          ExperienceColors.inkSoft,
        ).copyWith(fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(_GravityChartPainter oldDelegate) {
    return !identical(oldDelegate.viewModel, viewModel) ||
        oldDelegate.progress != progress ||
        oldDelegate.accentWeight != accentWeight ||
        oldDelegate.cursorEpochDay != cursorEpochDay;
  }
}
