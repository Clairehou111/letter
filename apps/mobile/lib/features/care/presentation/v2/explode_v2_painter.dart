import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../care_motion_flow.dart' show CareBreakVisuals;
import 'care_v2_kernel.dart';

/// Explode V2 — the contraction / sealing metaphor, kept.
///
/// Passive: concentric pressure arcs travel inward and cool as the scene
/// settles, until one calm closed seal remains.
/// Contact: the arc nearest the finger cools and thickens locally (immediate
/// yield), settling accelerates slightly while the finger rests, and one
/// stable sealed arc segment remains after release.
///
/// Primitive budget: 1 background rect, 3 core circles, 4 arcs, up to
/// 4 trace arcs, 3 contact shapes. No saveLayer, no gradients, no per-frame
/// list allocation.
class ExplodeV2Painter extends CustomPainter {
  ExplodeV2Painter({
    required this.visuals,
    required this.settle,
    required this.landing,
    required this.traces,
    required this.contact,
    required this.contactHold,
    required this.reducedMotion,
  });

  static const int ringCount = 4;

  final CareBreakVisuals visuals;

  /// 0 → 1 material settling progress.
  final double settle;

  /// 0 → 1 over the 75–90 s landing window; decays brightness only.
  final double landing;

  final List<CareV2Trace> traces;
  final Offset? contact;
  final double contactHold;
  final bool reducedMotion;

  static final Paint _fill = Paint()..style = PaintingStyle.fill;
  static final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  Color get _cool => Color.lerp(visuals.accent, visuals.glow, 0.65)!;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, _fill..color = visuals.background);

    final center = size.center(Offset.zero);
    final extent = math.min(size.width, size.height) * 0.42;
    final dim = 1 - landing * 0.35;

    if (reducedMotion) {
      _paintSeal(canvas, center, extent * 0.34, 1, dim);
      _paintTraces(canvas, center, extent, 1, dim);
      return;
    }

    // Pressure arcs, gathering inward.
    for (var index = 0; index < ringCount; index++) {
      final spread = 0.42 + index * 0.19;
      final radius = extent * spread * (1 - 0.58 * settle);
      final heat = (1 - settle) * (1 - index * 0.12);
      final color = Color.lerp(_cool, visuals.accent, heat.clamp(0.0, 1.0))!;
      var width = 1.6 + heat * 2.2;
      var alpha = (0.10 + heat * 0.22) * dim;

      // Local yield: the arc nearest the finger cools and thickens.
      final point = contact;
      if (point != null) {
        final distance = ((point - center).distance - radius).abs();
        final nearness = math.exp(-distance / 46);
        width += nearness * 2.6;
        alpha += nearness * 0.10 * dim;
      }

      canvas.drawCircle(
        center,
        radius,
        _stroke
          ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
          ..strokeWidth = width,
      );
    }

    // Core: hot at the start, quiet and small once sealed.
    final coreRadius = extent * (0.30 - 0.08 * settle);
    _paintCore(canvas, center, coreRadius, settle, dim);

    _paintTraces(canvas, center, extent, settle, dim);

    // Immediate response under the finger: a cool, soft yield.
    final point = contact;
    if (point != null) {
      final grow = (0.55 + contactHold * 0.25).clamp(0.55, 1.0);
      canvas.drawCircle(
        point,
        30 * grow,
        _fill..color = _cool.withValues(alpha: 0.09 * dim),
      );
      canvas.drawCircle(
        point,
        18 * grow,
        _fill..color = _cool.withValues(alpha: 0.11 * dim),
      );
    }

    if (settle >= 1) {
      _paintSeal(canvas, center, extent * 0.34, 1, dim);
    }
  }

  void _paintCore(
    Canvas canvas,
    Offset center,
    double radius,
    double settle,
    double dim,
  ) {
    final hot = Color.lerp(visuals.accent, _cool, settle)!;
    canvas.drawCircle(
      center,
      radius * 1.5,
      _fill..color = hot.withValues(alpha: 0.05 * dim),
    );
    canvas.drawCircle(
      center,
      radius,
      _fill..color = hot.withValues(alpha: 0.10 * dim),
    );
    canvas.drawCircle(
      center,
      radius * 0.55,
      _fill..color = hot.withValues(alpha: 0.13 * dim),
    );
  }

  void _paintSeal(
    Canvas canvas,
    Offset center,
    double radius,
    double closed,
    double dim,
  ) {
    canvas.drawCircle(
      center,
      radius,
      _stroke
        ..color = visuals.glow.withValues(alpha: 0.30 * closed * dim)
        ..strokeWidth = 2.4,
    );
    canvas.drawCircle(
      center,
      radius * 0.62,
      _fill..color = _cool.withValues(alpha: 0.07 * closed * dim),
    );
  }

  /// Persistent consequence: each released contact leaves one stable, cooled
  /// arc segment on the sealing ring.
  void _paintTraces(
    Canvas canvas,
    Offset center,
    double extent,
    double settle,
    double dim,
  ) {
    if (traces.isEmpty) return;
    final radius = extent * (0.42 * (1 - 0.28 * settle) + 0.12);
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (final trace in traces) {
      final direction = Offset(
        trace.position.dx - 0.5,
        trace.position.dy - 0.5,
      );
      final angle = direction.distance < 0.001
          ? -math.pi / 2
          : math.atan2(direction.dy, direction.dx);
      final sweep = 0.5 + trace.weight * 0.7;
      canvas.drawArc(
        rect,
        angle - sweep / 2,
        sweep,
        false,
        _stroke
          ..color = visuals.glow.withValues(
            alpha: (0.16 + trace.weight * 0.20) * dim,
          )
          ..strokeWidth = 3 + trace.weight * 2.4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ExplodeV2Painter oldDelegate) {
    return oldDelegate.settle != settle ||
        oldDelegate.landing != landing ||
        oldDelegate.contact != contact ||
        oldDelegate.contactHold != contactHold ||
        oldDelegate.reducedMotion != reducedMotion ||
        oldDelegate.traces.length != traces.length;
  }
}
