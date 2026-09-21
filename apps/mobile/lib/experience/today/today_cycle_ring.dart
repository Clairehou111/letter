import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/today/today_cycle_ring_model.dart';
import '../theme/experience_foundation.dart';

/// The four-phase Today ring — the daylight face of the Ember in Orbit.
///
/// Contracts honored here (design authority):
///  * This widget **consumes [TodayCycleRingModel] only**. It never infers,
///    detects, or recalculates cycle phases, and it never calls
///    `TodayCycleRingModel.fromRecords`. When history is insufficient, the
///    caller renders [TodayCycleRing.empty] or [TodayCycleRing.forming] —
///    `insufficientHistory` is surfaced as an honest state, never caught
///    and faked.
///  * Estimated ovulation renders only as the range band the model provides;
///    no center-day marker is ever drawn, so a detected day cannot be read.
///  * Certainty is texture, not color: observed segments are solid, and
///    **every** estimated segment — the Estimated ovulation range band and
///    Luteal estimated alike — renders with the shared estimated texture:
///    reduced opacity **plus** a dashed stroke. The dash run/gap are
///    proportional to the compensated stroke weight, because a fixed small
///    pixel dash under a thick stroke merges into a solid-looking band;
///    dashes must stay visibly distinct at ring width, and the contrast the
///    dash rhythm costs is repaid with stroke weight, never saturation.
///  * Low-confidence models additionally carry the "Rough estimate"
///    caption; that treatment composes with the estimated texture (same
///    dashes, plus words) so the two never read as different meanings.
///  * Late cycles keep the today marker: the ember position is derived from
///    [TodayCycleRingModel.currentDay] against
///    [TodayCycleRingModel.displayCycleDays], which the model already
///    extends past the estimate.
///  * The ring is never a scrubber. A single tap (or keyboard activation)
///    opens meaning/source inspection through [onInspect]; the full
///    semantic description — including which segments are observed and
///    which are estimated — is exposed to screen readers.
final class TodayCycleRing extends StatelessWidget {
  /// The working ring, from a fully built [TodayCycleRingModel].
  const TodayCycleRing({
    super.key,
    required this.model,
    this.onInspect,
    this.size = 264,
    this.showLegend = true,
  }) : _visual = _RingVisual.ready,
       _formingObservedDays = null,
       _formingProjectedDays = null,
       _formingRemainingStarts = null;

  /// The honest "ring forming" state for partial history (1–2 period
  /// starts).
  ///
  /// [observedDays] fills the orbit with what is actually recorded.
  /// [remainingPeriodStarts] is the count **derived by the caller** from
  /// current records and the ring/prediction contracts — it is never
  /// hard-coded here. [projectedCycleDays] only sizes the canvas; it does
  /// not imply a prediction exists.
  const TodayCycleRing.forming({
    super.key,
    required int observedDays,
    required int remainingPeriodStarts,
    int? projectedCycleDays,
    this.onInspect,
    this.size = 264,
    this.showLegend = false,
  }) : assert(observedDays >= 1, 'observedDays must be at least 1'),
       assert(
         remainingPeriodStarts >= 1,
         'remainingPeriodStarts must be at least 1',
       ),
       model = null,
       _visual = _RingVisual.forming,
       _formingObservedDays = observedDays,
       _formingRemainingStarts = remainingPeriodStarts,
       _formingProjectedDays = projectedCycleDays;

  /// An honest fallback for histories that contain several period starts but
  /// still do not provide enough usable start-to-start intervals for the
  /// prediction contract. This is not a loading state: the ring remains
  /// incomplete until the underlying history can support a model.
  const TodayCycleRing.learning({
    super.key,
    required int observedDays,
    int? projectedCycleDays,
    this.onInspect,
    this.size = 264,
    this.showLegend = false,
  }) : assert(observedDays >= 1, 'observedDays must be at least 1'),
       model = null,
       _visual = _RingVisual.forming,
       _formingObservedDays = observedDays,
       _formingRemainingStarts = null,
       _formingProjectedDays = projectedCycleDays;

  /// The empty-orbit state: a quiet outlined ring with one ember at rest.
  /// Care, safety, tracking, and backup remain fully available; this state
  /// is presence, not a locked door.
  const TodayCycleRing.empty({
    super.key,
    this.onInspect,
    this.size = 264,
    this.showLegend = false,
  }) : model = null,
       _visual = _RingVisual.empty,
       _formingObservedDays = null,
       _formingRemainingStarts = null,
       _formingProjectedDays = null;

  /// Tap/keyboard activation opens the meaning/source panel (what is
  /// observed, what is estimated, from which records). Null = not
  /// tappable.
  final VoidCallback? onInspect;

  /// Requested square side; the ring shrinks to fit bounded width.
  final double size;

  /// Whether the observed/estimated texture legend renders under the
  /// ring.
  final bool showLegend;

  /// The model this ring renders. Null in the [TodayCycleRing.empty] and
  /// [TodayCycleRing.forming] honest states.
  final TodayCycleRingModel? model;

  final _RingVisual _visual;
  final int? _formingObservedDays;
  final int? _formingProjectedDays;
  final int? _formingRemainingStarts;

  /// The full screen-reader description of a working ring. It names the
  /// day, the current phase and its certainty, **every segment grouped by
  /// observed vs estimated**, states that estimated ovulation is a range
  /// band rather than a detected day, and flags a rough estimate when the
  /// model has limited confidence. Also usable by consumers (Cycle
  /// destination, tests) that need identical wording.
  static String describeModel(TodayCycleRingModel model) {
    final buffer = StringBuffer(
      'Day ${model.currentDay}; usual cycle about '
      '${model.typicalCycleDays} days',
    );
    final phase = model.currentPhase;
    if (phase != null) {
      buffer.write(', ${phase.label} phase');
      final segment = model.segmentFor(phase);
      if (segment != null) {
        buffer.write(
          segment.certainty == CycleRingCertainty.observed
              ? ', observed'
              : ', estimated',
        );
      }
    } else {
      buffer.write(', phase not yet determined');
    }
    buffer.write('.');

    // Certainty is never color alone: announce exactly which segments are
    // observed and which are estimated, mirroring the solid/dashed
    // texture system one-to-one.
    final observedLabels = <String>[
      for (final segment in model.segments)
        if (segment.certainty == CycleRingCertainty.observed)
          segment.phase.label,
    ];
    final estimatedLabels = <String>[
      for (final segment in model.segments)
        if (segment.certainty == CycleRingCertainty.estimated)
          segment.phase.label,
    ];
    if (observedLabels.isNotEmpty) {
      buffer.write(' Observed on the ring: ${observedLabels.join(', ')}.');
    }
    if (estimatedLabels.isNotEmpty) {
      buffer.write(' Estimated on the ring: ${estimatedLabels.join(', ')}.');
      buffer.write(' Estimated ovulation is a range band, not a detected day.');
    }
    if (model.hasLimitedEstimate) {
      buffer.write(' This is a rough estimate based on limited history.');
    }
    return buffer.toString();
  }

  String get _semanticsDescription {
    switch (_visual) {
      case _RingVisual.ready:
        return describeModel(model!);
      case _RingVisual.empty:
        return 'Cycle ring, no periods recorded yet. '
            'Your cycle story starts with one recorded period.';
      case _RingVisual.forming:
        final remaining = _formingRemainingStarts;
        if (remaining == null) {
          return 'Cycle ring learning. ${_formingObservedDays!} days '
              'observed. The cycle pattern is not ready from the current '
              'recorded dates.';
        }
        final startsText = remaining == 1
            ? 'one more recorded period start begins the ring'
            : '$remaining more recorded period starts begin the ring';
        return 'Cycle ring forming. ${_formingObservedDays!} days '
            'observed. $startsText.';
    }
  }

  String? get _caption {
    switch (_visual) {
      case _RingVisual.ready:
        return null;
      case _RingVisual.empty:
        return 'Your cycle story starts with one recorded period.';
      case _RingVisual.forming:
        final remaining = _formingRemainingStarts;
        if (remaining == null) {
          return 'Cycle pattern still forming from your recorded dates.';
        }
        return remaining == 1
            ? 'Ring forming — one more recorded period start begins the '
                  'ring.'
            : 'Ring forming — $remaining more recorded period starts '
                  'begin the ring.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.hasBoundedWidth
            ? math.min(constraints.maxWidth, size)
            : size;
        final tappable = onInspect != null;
        final caption = _caption;

        Widget ring = SizedBox(
          width: side,
          height: side,
          child: CustomPaint(
            painter: _RingPainter(
              visual: _visual,
              model: model,
              formingObservedDays: _formingObservedDays,
              formingProjectedDays: _formingProjectedDays,
            ),
            child: _visual == _RingVisual.ready ? _buildCenter(side) : null,
          ),
        );

        if (tappable) {
          // InkWell supplies tap, keyboard focus, and activation; the
          // outer Semantics node carries the full ring description and the
          // accessibility tap action, so nothing is announced twice.
          ring = Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              focusColor: ExperienceColors.emberGlow,
              onTap: onInspect,
              child: ring,
            ),
          );
        }

        return Semantics(
          container: true,
          button: tappable,
          label: _semanticsDescription,
          hint: tappable
              ? 'Activates the panel explaining what this ring shows '
                    'and which records it comes from'
              : null,
          onTap: onInspect,
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ring,
                if (caption != null) ...<Widget>[
                  const SizedBox(height: ExperienceSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ExperienceSpacing.lg,
                    ),
                    child: Text(
                      caption,
                      style: ExperienceType.caption(ExperienceColors.inkSoft),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                if (_visual == _RingVisual.ready && showLegend) ...<Widget>[
                  const SizedBox(height: ExperienceSpacing.sm),
                  const _CertaintyLegend(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCenter(double side) {
    final ringModel = model!;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: side * 0.58),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Day',
                style: ExperienceType.headline(ExperienceColors.inkSoft),
              ),
              Text(
                '${ringModel.currentDay}',
                // Numerals in data contexts are always sans tabular
                // figures.
                style: ExperienceType.data(
                  ExperienceColors.ink,
                  size: 34,
                  weight: FontWeight.w700,
                ),
              ),
              Text(
                'usual ~${ringModel.typicalCycleDays} days',
                style: ExperienceType.caption(ExperienceColors.inkSoft),
                textAlign: TextAlign.center,
              ),
              if (ringModel.hasLimitedEstimate)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Rough estimate',
                    style: ExperienceType.caption(
                      ExperienceColors.inkFaint,
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _RingVisual { ready, forming, empty }

/// Paints the orbit, its four segments, and the ember today-marker. All
/// phase geometry comes straight from [TodayCycleRingModel.segments]; the
/// painter performs no cycle math of its own.
final class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.visual,
    this.model,
    this.formingObservedDays,
    this.formingProjectedDays,
  });

  final _RingVisual visual;
  final TodayCycleRingModel? model;
  final int? formingObservedDays;
  final int? formingProjectedDays;

  static const double _stroke = 14;

  /// Estimated segments compensate for the dashed contrast loss with
  /// stroke weight — never with saturation. Re-verified against the
  /// re-saturated phase accents at ring width.
  static const double _estimatedStroke = 17;
  static const double _emberRadius = 11;

  /// Reduced opacity from the shared estimated texture recipe
  /// ([CertaintyTexture.estimated]); identical meaning on the ring,
  /// Gravity, Spectrum, Twin, and report previews.
  ///
  /// The value mirrors `CertaintyTexture.estimated.fillOpacity` (0.55).
  /// It is written as a literal because instance-property reads on a
  /// const object are not valid const expressions, and this constant is
  /// part of the painter's compile-time texture recipe.
  static const double _estimatedOpacity = 0.55;

  /// Dash run/gap, derived from the compensated stroke weight itself.
  ///
  /// The shared texture recipe calls for a dashed treatment; on a ring
  /// stroke this thick, a fixed small pixel dash (e.g. 6/4) merges into a
  /// solid-looking band once stroke caps and anti-aliasing are accounted
  /// for — the exact defect the texture system exists to prevent. Sizing
  /// the rhythm from the stroke width keeps every dash visibly distinct
  /// at any ring diameter, honoring the recipe's *meaning* (reduced
  /// opacity + unmistakable dashes) rather than its small-mark pixel
  /// values.
  static final List<double> _estimatedDash = <double>[
    _estimatedStroke * 1.15,
    _estimatedStroke * 0.85,
  ];

  static Color _phaseColor(CycleRingPhase phase) {
    return switch (phase) {
      CycleRingPhase.period => ExperienceColors.phasePeriod,
      CycleRingPhase.follicular => ExperienceColors.phaseFollicular,
      CycleRingPhase.estimatedOvulation => ExperienceColors.phaseOvulation,
      CycleRingPhase.luteal => ExperienceColors.phaseLuteal,
    };
  }

  static Offset _pointOn(Offset center, double radius, double angle) {
    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  }

  static void _paintOrbitOutline(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = ExperienceColors.hairline,
    );
  }

  static void _paintEmber(Canvas canvas, Offset offset, double radius) {
    canvas.drawCircle(
      offset,
      radius * 1.7,
      Paint()
        ..color = ExperienceColors.emberGlow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      offset,
      radius + 2.5,
      Paint()..color = ExperienceColors.surface,
    );
    canvas.drawCircle(
      offset,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 0.95,
          colors: <Color>[
            ExperienceColors.emberBright,
            ExperienceColors.ember,
            ExperienceColors.emberDeep,
          ],
          stops: <double>[0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: offset, radius: radius)),
    );
  }

  static Path _dashedArc(
    Rect rect,
    double startAngle,
    double sweepAngle,
    double radius,
    List<double> dashPattern,
  ) {
    final path = Path();
    final totalLength = sweepAngle * radius;
    var travelled = 0.0;
    var on = true;
    var index = 0;
    while (travelled < totalLength) {
      final length = dashPattern[index % dashPattern.length];
      final run = math.min(length, totalLength - travelled);
      if (on && run > 0) {
        path.addArc(rect, startAngle + travelled / radius, run / radius);
      }
      travelled += length;
      on = !on;
      index += 1;
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final side = math.min(size.width, size.height);
    final radius = side / 2 - _emberRadius - 8;
    if (radius <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);

    switch (visual) {
      case _RingVisual.empty:
        _paintOrbitOutline(canvas, center, radius);
        _paintEmber(canvas, center + Offset(0, -radius), 8);

      case _RingVisual.forming:
        final observed = formingObservedDays!;
        // Canvas sizing only — no prediction is implied or invented.
        final projected = formingProjectedDays ?? math.max(observed + 7, 28);
        final dayAngle = (2 * math.pi) / projected;
        _paintOrbitOutline(canvas, center, radius);
        canvas.drawArc(
          rect,
          -math.pi / 2,
          observed * dayAngle,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _stroke
            ..strokeCap = StrokeCap.round
            ..color = ExperienceColors.phasePeriod,
        );
        final emberAngle = -math.pi / 2 + (observed - 0.5) * dayAngle;
        _paintEmber(canvas, _pointOn(center, radius, emberAngle), _emberRadius);

      case _RingVisual.ready:
        final ringModel = model!;
        final dayAngle = (2 * math.pi) / ringModel.displayCycleDays;
        final gap = math.min(0.09, dayAngle * 0.22);
        for (final segment in ringModel.segments) {
          final start =
              -math.pi / 2 + (segment.startDay - 1) * dayAngle + gap / 2;
          final sweep = segment.dayCount * dayAngle - gap;
          if (sweep <= 0) continue;
          final color = _phaseColor(segment.phase);
          if (segment.certainty == CycleRingCertainty.observed) {
            // Observed = solid fill, solid border. Full saturation, round
            // caps.
            canvas.drawArc(
              rect,
              start,
              sweep,
              false,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = _stroke
                ..strokeCap = StrokeCap.round
                ..color = color,
            );
          } else {
            // Estimated = reduced opacity PLUS the dashed treatment, for
            // every non-observed segment — the Estimated ovulation range
            // band and Luteal estimated alike. Butt caps keep each dash
            // distinct (round caps would bridge the proportional gaps and
            // re-solidify the band); the heavier stroke repays the dash
            // rhythm's contrast cost, never the saturation.
            canvas.drawPath(
              _dashedArc(rect, start, sweep, radius, _estimatedDash),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = _estimatedStroke
                ..strokeCap = StrokeCap.butt
                ..color = color.withValues(alpha: _estimatedOpacity),
            );
          }
        }
        // Late cycles keep the today marker: the model extends
        // displayCycleDays past the estimate, so the clamp is a no-op in
        // practice and a safety rail in theory.
        final todayDay = ringModel.currentDay.clamp(
          1,
          ringModel.displayCycleDays,
        );
        final emberAngle = -math.pi / 2 + (todayDay - 0.5) * dayAngle;
        _paintEmber(canvas, _pointOn(center, radius, emberAngle), _emberRadius);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.visual != visual ||
        oldDelegate.model != model ||
        oldDelegate.formingObservedDays != formingObservedDays ||
        oldDelegate.formingProjectedDays != formingProjectedDays;
  }
}

/// The shared observed/estimated texture key — the same legend grammar
/// used by every chart in the system. Low-confidence ("Rough estimate")
/// states reuse the estimated sample plus their caption, so the two
/// treatments never read as different meanings here.
final class _CertaintyLegend extends StatelessWidget {
  const _CertaintyLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const _LegendSample(
          dashed: false,
          semanticsLabel: 'Solid line sample meaning observed',
        ),
        const SizedBox(width: 6),
        Text(
          'Observed',
          style: ExperienceType.caption(ExperienceColors.inkSoft),
        ),
        const SizedBox(width: ExperienceSpacing.sm),
        const _LegendSample(
          dashed: true,
          semanticsLabel: 'Dashed line sample meaning estimated',
        ),
        const SizedBox(width: 6),
        Text(
          'Estimated',
          style: ExperienceType.caption(ExperienceColors.inkSoft),
        ),
      ],
    );
  }
}

final class _LegendSample extends StatelessWidget {
  const _LegendSample({required this.dashed, required this.semanticsLabel});

  final bool dashed;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: CustomPaint(
        size: const Size(30, 4),
        painter: _LegendSamplePainter(dashed: dashed),
      ),
    );
  }
}

final class _LegendSamplePainter extends CustomPainter {
  const _LegendSamplePainter({required this.dashed});

  final bool dashed;

  /// Run/gap wide enough to read as dashes at this stroke weight; butt
  /// caps keep the gaps open (round caps would close them and the sample
  /// would render solid, contradicting its own label).
  static const List<double> _pattern = <double>[7, 5];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ExperienceColors.inkSoft
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.butt;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    var x = 0.0;
    var on = true;
    var index = 0;
    while (x < size.width) {
      final length = _pattern[index % _pattern.length];
      if (on) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + length, size.width), y),
          paint,
        );
      }
      x += length;
      on = !on;
      index += 1;
    }
  }

  @override
  bool shouldRepaint(_LegendSamplePainter oldDelegate) {
    return oldDelegate.dashed != dashed;
  }
}
