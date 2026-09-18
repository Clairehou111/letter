import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../care_motion_flow.dart' show CareBreakVisuals;
import 'care_v2_kernel.dart';

/// Heavy V2 — heavy rain gradually becomes lighter and stops.
///
/// The V2 change is the payoff: the rain is not deleted, it collects into a
/// quiet, still low surface. One warm lamp remains, unchanged from V1.
/// Contact opens one local sheltered area (drops skip it), eases the rain
/// slightly while the finger rests, and leaves a small warm clear patch after
/// release. Patches merge, maximum four.
///
/// There is no brightening reveal, no achievement cue, and nothing claims the
/// sadness has ended.
class HeavyV2Painter extends CustomPainter {
  HeavyV2Painter({
    required this.visuals,
    required this.rain,
    required this.elapsed,
    required this.settle,
    required this.landing,
    required this.traces,
    required this.contact,
    required this.contactHold,
    required this.reducedMotion,
  });

  final CareBreakVisuals visuals;
  final CareV2RainModel rain;
  final double elapsed;

  /// 0 → 1 material settling progress.
  final double settle;
  final double landing;
  final List<CareV2Trace> traces;
  final Offset? contact;
  final double contactHold;
  final bool reducedMotion;

  static const double shelterRadius = 62;

  static final Paint _fill = Paint()..style = PaintingStyle.fill;
  static final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  Color get _warm => visuals.glow;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, _fill..color = visuals.background);
    final dim = 1 - landing * 0.3;

    if (reducedMotion) {
      _paintPool(canvas, size, 1, dim);
      _paintLamp(canvas, size, dim);
      _paintPatches(canvas, size, dim);
      _paintStillRain(canvas, size, dim);
      return;
    }

    rain.advance(elapsed: elapsed, progress: settle);

    _paintPool(canvas, size, settle, dim);
    _paintLamp(canvas, size, dim);
    _paintPatches(canvas, size, dim);

    final shelter = contact;
    final poolTop = size.height * (1 - _poolLevel(settle));
    final active = rain.activeDropCount(settle);
    final drops = rain.drops;
    for (var index = 0; index < active; index++) {
      final drop = drops[index];
      final x = drop.x * size.width;
      final y = drop.y * poolTop;
      final point = Offset(x, y);
      if (shelter != null && (point - shelter).distance < shelterRadius) {
        continue;
      }
      if (_insidePatch(point, size)) continue;
      final length = drop.length * (0.45 + 0.55 * (1 - settle));
      canvas.drawLine(
        point,
        Offset(x, math.min(poolTop, y + length)),
        _stroke
          ..color = visuals.accent.withValues(alpha: 0.24 * dim)
          ..strokeWidth = drop.width,
      );
    }

    // Immediate local yield: the sheltered area under the finger.
    if (shelter != null) {
      final grow = (0.7 + contactHold * 0.2).clamp(0.7, 1.0);
      canvas.drawCircle(
        shelter,
        shelterRadius * grow,
        _fill..color = _warm.withValues(alpha: 0.05 * dim),
      );
      canvas.drawCircle(
        shelter,
        shelterRadius * grow,
        _stroke
          ..color = _warm.withValues(alpha: 0.10 * dim)
          ..strokeWidth = 1.2,
      );
    }
  }

  double _poolLevel(double settle) => 0.04 + 0.14 * settle;

  void _paintPool(Canvas canvas, Size size, double settle, double dim) {
    final level = _poolLevel(settle);
    final top = size.height * (1 - level);
    final surface = Color.lerp(visuals.background, visuals.secondary, 0.42)!;
    canvas.drawRect(
      Rect.fromLTRB(0, top, size.width, size.height),
      _fill..color = surface.withValues(alpha: 0.92),
    );
    canvas.drawLine(
      Offset(0, top),
      Offset(size.width, top),
      _stroke
        ..color = visuals.accent.withValues(alpha: (0.10 + 0.10 * settle) * dim)
        ..strokeWidth = 1,
    );
    // One very slow, low-contrast glimmer. No stripes, no flashing.
    final drift = math.sin(elapsed * 0.12) * size.width * 0.06;
    canvas.drawLine(
      Offset(size.width * 0.22 + drift, top + 10),
      Offset(size.width * 0.62 + drift, top + 10),
      _stroke
        ..color = _warm.withValues(alpha: 0.05 * dim)
        ..strokeWidth = 1,
    );
  }

  void _paintLamp(Canvas canvas, Size size, double dim) {
    final center = Offset(size.width * 0.5, size.height * 0.38);
    for (final entry in const <List<double>>[
      [58, 0.05],
      [34, 0.08],
      [16, 0.12],
    ]) {
      canvas.drawCircle(
        center,
        entry[0],
        _fill..color = _warm.withValues(alpha: entry[1] * dim),
      );
    }
  }

  /// Persistent consequence: small warm patches where the rain was held off.
  void _paintPatches(Canvas canvas, Size size, double dim) {
    for (final trace in traces) {
      final center = Offset(
        trace.position.dx * size.width,
        trace.position.dy * size.height,
      );
      final radius = 26 + trace.weight * 26;
      canvas.drawCircle(
        center,
        radius,
        _fill
          ..color = _warm.withValues(alpha: (0.05 + trace.weight * 0.05) * dim),
      );
      canvas.drawCircle(
        center,
        radius,
        _stroke
          ..color = _warm.withValues(alpha: 0.07 * dim)
          ..strokeWidth = 1,
      );
    }
  }

  bool _insidePatch(Offset point, Size size) {
    for (final trace in traces) {
      final center = Offset(
        trace.position.dx * size.width,
        trace.position.dy * size.height,
      );
      if ((point - center).distance < 26 + trace.weight * 26) return true;
    }
    return false;
  }

  /// Reduced motion: the same meaning without any travelling particle.
  void _paintStillRain(Canvas canvas, Size size, double dim) {
    final poolTop = size.height * (1 - _poolLevel(1));
    for (var index = 0; index < 6; index++) {
      final x = size.width * (0.14 + index * 0.14);
      final y = poolTop * (0.42 + (index % 3) * 0.12);
      canvas.drawLine(
        Offset(x, y),
        Offset(x, y + 14),
        _stroke
          ..color = visuals.accent.withValues(alpha: 0.12 * dim)
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HeavyV2Painter oldDelegate) {
    return oldDelegate.elapsed != elapsed ||
        oldDelegate.settle != settle ||
        oldDelegate.landing != landing ||
        oldDelegate.contact != contact ||
        oldDelegate.contactHold != contactHold ||
        oldDelegate.reducedMotion != reducedMotion ||
        oldDelegate.traces.length != traces.length;
  }
}
