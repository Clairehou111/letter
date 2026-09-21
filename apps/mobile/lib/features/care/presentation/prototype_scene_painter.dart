import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/care_mode.dart';
import 'care_motion_flow.dart' show CareBreakVisuals, PhysicalCareContext;

/// Parameter sets used for production and blinded pre-TestFlight captures.
///
/// [productionHybrid] applies the path-specific findings from the blinded
/// review. A/B/C remain stable references and do not change scene timing,
/// interaction timing, copy, or random seeds.
enum CareSceneVariant {
  productionHybrid,
  aBaseline,
  bConservative,
  cSimplified,
}

class _CareSceneTuning {
  const _CareSceneTuning({
    required this.heavyVelocityScale,
    required this.heavyDensityScale,
    required this.heavyFlowReduction,
    required this.heavyTrailCount,
    required this.heavyAlphaScale,
    required this.heavyDensityDecayExponent,
    required this.heavyMinimumDrops,
    required this.heavyHaloAlphaScale,
    required this.heavyHaloProgressScale,
    required this.heavyRadiusProgressScale,
    required this.racingStrandCount,
    required this.racingChaosSpeed,
    required this.racingAmplitudeScale,
    required this.racingTrailCount,
    required this.racingAlphaScale,
  });

  final double heavyVelocityScale;
  final double heavyDensityScale;
  final double heavyFlowReduction;
  final int heavyTrailCount;
  final double heavyAlphaScale;
  final double heavyDensityDecayExponent;
  final int heavyMinimumDrops;
  final double heavyHaloAlphaScale;
  final double heavyHaloProgressScale;
  final double heavyRadiusProgressScale;
  final int racingStrandCount;
  final double racingChaosSpeed;
  final double racingAmplitudeScale;
  final int racingTrailCount;
  final double racingAlphaScale;
}

extension on CareSceneVariant {
  _CareSceneTuning get tuning => switch (this) {
    CareSceneVariant.productionHybrid => const _CareSceneTuning(
      // Keep the baseline's clearly heavy opening, but use the conservative
      // candidate's lower velocity, shorter persistence, and opacity.
      heavyVelocityScale: 0.5,
      heavyDensityScale: 1,
      heavyFlowReduction: 0.96,
      heavyTrailCount: 6,
      heavyAlphaScale: 0.82,
      heavyDensityDecayExponent: 1.35,
      heavyMinimumDrops: 0,
      heavyHaloAlphaScale: 0.62,
      heavyHaloProgressScale: 0.18,
      heavyRadiusProgressScale: 0.08,
      // Default-intensity Racing starts from the simplified candidate.
      // High intensity is selected dynamically below.
      racingStrandCount: 16,
      racingChaosSpeed: 1.45,
      racingAmplitudeScale: 0.62,
      racingTrailCount: 4,
      racingAlphaScale: 0.62,
    ),
    CareSceneVariant.aBaseline => const _CareSceneTuning(
      heavyVelocityScale: 1,
      heavyDensityScale: 1,
      heavyFlowReduction: 0.85,
      heavyTrailCount: 8,
      heavyAlphaScale: 1,
      heavyDensityDecayExponent: 1,
      heavyMinimumDrops: 1,
      heavyHaloAlphaScale: 1,
      heavyHaloProgressScale: 0.32,
      heavyRadiusProgressScale: 0.1,
      racingStrandCount: 30,
      racingChaosSpeed: 3,
      racingAmplitudeScale: 1,
      racingTrailCount: 11,
      racingAlphaScale: 1,
    ),
    CareSceneVariant.bConservative => const _CareSceneTuning(
      heavyVelocityScale: 0.7,
      heavyDensityScale: 0.75,
      heavyFlowReduction: 0.92,
      heavyTrailCount: 6,
      heavyAlphaScale: 0.82,
      heavyDensityDecayExponent: 1,
      heavyMinimumDrops: 1,
      heavyHaloAlphaScale: 1,
      heavyHaloProgressScale: 0.32,
      heavyRadiusProgressScale: 0.1,
      racingStrandCount: 22,
      racingChaosSpeed: 2.1,
      racingAmplitudeScale: 0.8,
      racingTrailCount: 7,
      racingAlphaScale: 0.78,
    ),
    CareSceneVariant.cSimplified => const _CareSceneTuning(
      heavyVelocityScale: 0.45,
      heavyDensityScale: 0.5,
      heavyFlowReduction: 0.97,
      heavyTrailCount: 4,
      heavyAlphaScale: 0.68,
      heavyDensityDecayExponent: 1,
      heavyMinimumDrops: 1,
      heavyHaloAlphaScale: 1,
      heavyHaloProgressScale: 0.32,
      heavyRadiusProgressScale: 0.1,
      racingStrandCount: 16,
      racingChaosSpeed: 1.45,
      racingAmplitudeScale: 0.62,
      racingTrailCount: 4,
      racingAlphaScale: 0.62,
    ),
  };
}

_CareSceneTuning _tuningFor(
  CareSceneVariant variant,
  CareMode mode,
  double intensity,
) {
  if (variant == CareSceneVariant.productionHybrid &&
      mode == CareMode.racing &&
      intensity > 0.75) {
    return _productionHighRacingTuning;
  }
  return variant.tuning;
}

const _productionHighRacingTuning = _CareSceneTuning(
  heavyVelocityScale: 0.5,
  heavyDensityScale: 1,
  heavyFlowReduction: 0.96,
  heavyTrailCount: 6,
  heavyAlphaScale: 0.82,
  heavyDensityDecayExponent: 1.35,
  heavyMinimumDrops: 0,
  heavyHaloAlphaScale: 0.62,
  heavyHaloProgressScale: 0.18,
  heavyRadiusProgressScale: 0.08,
  // Keep B's readable intermediate transformation while moving its density,
  // speed, persistence, and contrast modestly toward C.
  racingStrandCount: 20,
  racingChaosSpeed: 1.8,
  racingAmplitudeScale: 0.72,
  racingTrailCount: 6,
  racingAlphaScale: 0.72,
);

/// Mutable scene data translated directly from the prototype's SceneStage.
/// Math.random() at canvas mount becomes one Random-backed initialization here.
class PrototypeSceneModel {
  PrototypeSceneModel({math.Random? random})
    : _random = random ?? math.Random() {
    _strands = List.generate(30, (index) {
      return _Strand(
        phase: _random.nextDouble() * math.pi * 2,
        speed: 0.4 + _random.nextDouble() * 1.6,
        y: (index + 0.5) / 30,
        amplitude: 12 + _random.nextDouble() * 40,
      );
    });
    _drops = List.generate(40, (_) {
      return _Drop(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        velocity: 0.055 + _random.nextDouble() * 0.16,
        length: 30 + _random.nextDouble() * 120,
        width: 1 + _random.nextDouble() * 2.5,
      );
    });
    _crowd = List.generate(9, (index) {
      return _CrowdPerson(
        x: _random.nextDouble(),
        depth: 0.35 + _random.nextDouble() * 0.5,
        velocity:
            (_random.nextBool() ? 1 : -1) *
            (0.03 + _random.nextDouble() * 0.08),
        sway: _random.nextDouble() * math.pi * 2,
        swaySpeed: 1.2 + _random.nextDouble() * 1.4,
      );
    });
    _chatter = List.generate(22, (_) {
      return _Chatter(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        radius: 0.8 + _random.nextDouble() * 1.6,
        velocity: 0.06 + _random.nextDouble() * 0.16,
        alpha: 0.2 + _random.nextDouble() * 0.5,
      );
    });
    _motes = List.generate(34, (_) {
      return _Mote(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        radius: 0.6 + _random.nextDouble() * 1.8,
        vx: (_random.nextDouble() - 0.5) * 0.012,
        vy: -0.006 - _random.nextDouble() * 0.014,
        twinkle: _random.nextDouble() * math.pi * 2,
      );
    });
  }

  final math.Random _random;
  late final List<_Strand> _strands;
  late final List<_Drop> _drops;
  late final List<_CrowdPerson> _crowd;
  late final List<_Chatter> _chatter;
  late final List<_Mote> _motes;
  final List<_Fragment> _fragments = [];

  /// Sparks spraying outward during the explode hold phase — this is the
  /// "snowball getting bigger" feel the prototype delivers through particle
  /// ejection around the expanding pressure rings.
  final List<_Spark> _sparks = [];
  double _lastElapsed = 0;
  double _lastSparkAt = 0;
  double calm = 0;

  /// Clears the close state so the user can re-press the seal and keep
  /// releasing. Called from the gesture handler when the seal is tapped.
  void resetExplodeClose() {
    _fragments.clear();
    _sparks.clear();
    _lastSparkAt = 0;
  }

  /// Selects a reduced strand count without cropping the field vertically.
  /// Strands are stored from top to bottom, so taking the first N strands
  /// incorrectly confines production motion to the upper part of the canvas.
  Iterable<_Strand> _racingStrands(int count) sync* {
    final selectedCount = math.min(count, _strands.length);
    if (selectedCount <= 0) return;
    if (selectedCount == _strands.length) {
      yield* _strands;
      return;
    }
    for (var position = 0; position < selectedCount; position++) {
      final index = math.min(
        _strands.length - 1,
        ((position + 0.5) * _strands.length / selectedCount).floor(),
      );
      yield _strands[index];
    }
  }

  void advance({
    required CareMode mode,
    required CareSceneVariant variant,
    required double intensity,
    required double elapsed,
    required double progress,
    required double closeProgress,
    required Offset? pointer,
    required double pointerSpeed,
    required bool pressing,
    required Size size,
  }) {
    final rawDt = (elapsed - _lastElapsed).clamp(0.0, 0.05);
    _lastElapsed = elapsed;
    if (rawDt <= 0) return;
    // Frame-equivalent factor matching the prototype's dt * 60 normalization.
    // Without this, animations run at 1/60th speed because the prototype
    // arithmetic expects a factor of ~1.0 at 60 fps, not ~0.0167 seconds.
    final dt = rawDt * 60;

    if (mode == CareMode.heavy) {
      final tuning = _tuningFor(variant, mode, intensity);
      final flow = 1 - progress * tuning.heavyFlowReduction;
      for (final drop in _drops) {
        drop.y += drop.velocity * flow * dt * tuning.heavyVelocityScale;
        if (drop.y > 1.2) {
          drop.y = -0.2;
          drop.x = _random.nextDouble();
        }
      }
    }

    if (mode == CareMode.racing) {
      final tuning = _tuningFor(variant, mode, intensity);
      final strands = _racingStrands(tuning.racingStrandCount);
      var tamed = 0.0;
      for (final strand in strands) {
        if (pointer != null && closeProgress == 0) {
          final distance = (pointer.dy - strand.y * size.height).abs();
          final proximity = math.exp(-distance / 90);
          strand.tame = math.min(
            1,
            strand.tame + proximity * (0.9 - pointerSpeed * 0.5) * dt * 0.9,
          );
          strand.momentum = math.min(
            1,
            strand.momentum + proximity * pointerSpeed * dt * 3,
          );
        }
        strand.momentum = math.max(0, strand.momentum - dt * 0.6);
        tamed += strand.tame;
      }
      calm = tamed / tuning.racingStrandCount;
    }

    // Explode hold phase: spray sparks outward so pressure feels like a
    // snowball that's accumulating mass, not just rings getting bigger.
    if (mode == CareMode.explode &&
        closeProgress == 0 &&
        pressing &&
        pointer != null) {
      final sparkInterval =
          0.04 - progress * 0.025; // faster as pressure builds
      if (elapsed - _lastSparkAt >= sparkInterval) {
        _lastSparkAt = elapsed;
        final angle = _random.nextDouble() * math.pi * 2;
        final speed = 80 + _random.nextDouble() * 220 * progress;
        _sparks.add(
          _Spark(
            x: size.width / 2,
            y: size.height / 2,
            vx: math.cos(angle) * speed,
            vy: math.sin(angle) * speed,
            life: 1.0,
            radius: 1.2 + _random.nextDouble() * 2.8,
            hot: _random.nextBool(),
          ),
        );
        // Cap to prevent unbounded growth.
        while (_sparks.length > 200) {
          _sparks.removeAt(0);
        }
      }
    }
    // Advance existing sparks.
    for (var i = _sparks.length - 1; i >= 0; i--) {
      final s = _sparks[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.life -= 0.008 * dt;
      s.vx *= 0.995;
      s.vy *= 0.995;
      if (s.life <= 0) {
        _sparks.removeAt(i);
      }
    }

    if (mode == CareMode.explode && closeProgress > 0 && _fragments.isEmpty) {
      final extent = math.max(size.width, size.height);
      for (var index = 0; index < 120; index++) {
        final radius = 40 + _random.nextDouble() * extent * 0.55;
        _fragments.add(
          _Fragment(
            angle: _random.nextDouble() * math.pi * 2,
            radius: radius,
            size: 1 + _random.nextDouble() * 3.5,
            hot: _random.nextBool(),
          ),
        );
      }
    }

    if (mode == CareMode.space) {
      final ease = progress * progress * (3 - 2 * progress);
      final outside = math.pow(1 - ease, 1.25).toDouble();
      for (final person in _crowd) {
        person.x += person.velocity * dt * (0.25 + outside * 0.75);
        if (person.x > 1.15) person.x -= 1.3;
        if (person.x < -0.15) person.x += 1.3;
        person.sway += dt * person.swaySpeed * (0.3 + outside);
      }
      for (final fleck in _chatter) {
        fleck.y -= fleck.velocity * dt * (0.3 + outside);
        if (fleck.y < -0.05) {
          fleck.y = 1.05;
          fleck.x = _random.nextDouble();
        }
      }
      if (ease > 0.5) {
        for (final mote in _motes) {
          mote
            ..x += mote.vx * dt
            ..y += mote.vy * dt
            ..twinkle += dt * 0.8;
          if (mote.y < -0.05) {
            mote.y = 1.05;
            mote.x = _random.nextDouble();
          }
          if (mote.x < -0.05) mote.x += 1.1;
          if (mote.x > 1.05) mote.x -= 1.1;
        }
      }
    }
  }
}

class PrototypeScenePainter extends CustomPainter {
  PrototypeScenePainter({
    required this.model,
    required this.mode,
    required this.elapsedSeconds,
    required this.progress,
    required this.closeProgress,
    required this.touchPoint,
    required this.pointerSpeed,
    required this.pressing,
    required this.intensity,
    required this.visuals,
    required this.physicalContext,
    required this.still,
    this.variant = CareSceneVariant.aBaseline,
    this.breath = false,
  });

  final PrototypeSceneModel model;
  final CareMode mode;
  final double elapsedSeconds;
  final double progress;
  final double closeProgress;
  final Offset? touchPoint;
  final double pointerSpeed;
  final bool pressing;
  final double intensity;
  final CareBreakVisuals visuals;
  final PhysicalCareContext? physicalContext;
  final bool still;
  final CareSceneVariant variant;
  final bool breath;

  double get energy => 0.35 + intensity * 0.65;

  /// Accumulation factor compensating for the prototype's frame-to-frame
  /// persistence (22% background wash ≈ 4.5× luminance build-up over time).
  /// Care scenes have no multi-pass trail rendering, so a single multiplier
  /// approximates the steady-state brightness.
  static const double _careAccum = 3.8;

  /// Heavy scene gradient/lamp elements have no trail rendering, so they need
  /// accumulation. The drops already have their own 8-frame trail loop.
  static const double _heavyAccum = 3.5;

  Paint _paint(Color color, double alpha, {PaintingStyle? style}) {
    return Paint()
      ..blendMode = BlendMode.plus
      ..style = style ?? PaintingStyle.fill
      ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bg = mode == CareMode.physical && still
        ? const Color(0xFF08060A)
        : visuals.background;
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    if (still && variant != CareSceneVariant.aBaseline) {
      canvas.save();
      canvas.clipRect(Offset.zero & size);
      _reducedMotionFrame(canvas, size);
      canvas.restore();
      return;
    }
    model.advance(
      mode: mode,
      variant: variant,
      intensity: intensity,
      elapsed: elapsedSeconds,
      progress: progress,
      closeProgress: closeProgress,
      pointer: touchPoint,
      pointerSpeed: pointerSpeed,
      pressing: pressing,
      size: size,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    switch (mode) {
      case CareMode.explode:
        _explode(canvas, size);
      case CareMode.heavy:
        _heavy(canvas, size);
      case CareMode.racing:
        _racing(canvas, size);
      case CareMode.space:
        _away(canvas, size);
      case CareMode.physical:
        _care(canvas, size);
    }
    canvas.restore();
  }

  void _reducedMotionFrame(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    switch (mode) {
      case CareMode.explode:
        _seal(canvas, size, 1);
      case CareMode.heavy:
        canvas.drawCircle(
          Offset(size.width / 2, size.height * 0.52),
          size.shortestSide * 0.42,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader =
                RadialGradient(
                  colors: [
                    const Color(0xFFFFD9A8).withValues(alpha: 0.28),
                    visuals.accent.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ).createShader(
                  Rect.fromCircle(
                    center: Offset(size.width / 2, size.height * 0.52),
                    radius: size.shortestSide * 0.42,
                  ),
                ),
        );
      case CareMode.racing:
        canvas.drawLine(
          Offset(size.width * 0.18, center.dy),
          Offset(size.width * 0.82, center.dy),
          _paint(visuals.glow, 0.52, style: PaintingStyle.stroke)
            ..strokeWidth = 1.6,
        );
      case CareMode.space:
        canvas.drawCircle(
          center,
          size.shortestSide * 0.28,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    visuals.glow.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ).createShader(
                  Rect.fromCircle(
                    center: center,
                    radius: size.shortestSide * 0.28,
                  ),
                ),
        );
      case CareMode.physical:
        _care(canvas, size);
    }
  }

  void _seal(Canvas canvas, Size size, double amount) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * (0.1 + 0.02 * amount);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF0A0403), Color(0xFF140604), Color(0xFF1D0907)],
          stops: [0, 0.75, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius,
      _paint(visuals.glow, 0.5 * amount, style: PaintingStyle.stroke)
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      center,
      radius * 1.06,
      _paint(visuals.accent, 0.22 * amount, style: PaintingStyle.stroke)
        ..strokeWidth = 6,
    );
  }

  void _explode(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    if (closeProgress <= 0) {
      // Canvas2D keeps earlier frames under a 22% background wash. Replaying
      // those decayed frames is the Flutter equivalent of that accumulation.
      for (var trail = 13; trail >= 0; trail--) {
        final decay = math.pow(0.78, trail).toDouble();
        final time = math.max(0, elapsedSeconds - trail / 60);
        final pressure = pressing
            ? math.max(0, progress - trail * 0.012)
            : progress;
        final shake = pressure * 6 * energy;
        for (var index = 0; index < 5; index++) {
          final radius =
              (60 +
                  index * 34 +
                  math.sin(time * (2 + pressure * 8) + index) *
                      (6 + pressure * 22 * energy)) *
              (1 + pressure * 0.35 * energy);
          canvas.drawCircle(
            center +
                Offset(
                  math.sin(time * 30 + index) * shake,
                  math.cos(time * 27 + index) * shake,
                ),
            radius,
            _paint(
              index.isOdd ? visuals.glow : visuals.accent,
              (0.14 + pressure * 0.5) * energy * decay,
              style: PaintingStyle.stroke,
            )..strokeWidth = 1.5 + pressure * 4 * energy,
          );
        }
        final coreRadius = 70 + pressure * 90 * energy;
        canvas.drawCircle(
          center,
          coreRadius,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = RadialGradient(
              colors: [
                visuals.glow.withValues(
                  alpha: ((0.25 + pressure * 0.6) * energy * decay).clamp(
                    0.0,
                    1.0,
                  ),
                ),
                Colors.transparent,
              ],
            ).createShader(Rect.fromCircle(center: center, radius: coreRadius)),
        );
      }
      // Sparks spraying outward — the "snowball accumulating mass" feel.
      for (final spark in model._sparks) {
        final sx = spark.x;
        final sy = spark.y;
        final alpha = spark.life * 0.8;
        if (alpha <= 0.02) continue;
        canvas.drawCircle(
          Offset(sx, sy),
          spark.radius,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = (spark.hot ? visuals.glow : visuals.accent).withValues(
              alpha: alpha.clamp(0.0, 1.0),
            ),
        );
      }
      return;
    }

    if (closeProgress >= 1) {
      final breath = 0.5 + 0.5 * math.sin(elapsedSeconds * 0.42);
      final radius = size.shortestSide * 0.1;
      for (var index = 0; index < 3; index++) {
        canvas.drawCircle(
          center,
          radius * (1.25 + index * 0.4 + breath * 0.16),
          _paint(
            index.isOdd ? visuals.glow : visuals.accent,
            0.1 * (1 - index * 0.25) * energy,
            style: PaintingStyle.stroke,
          )..strokeWidth = 1.2,
        );
      }
      _seal(canvas, size, 0.85 + breath * 0.15);
      return;
    }

    final sealRadius = size.shortestSide * 0.1;
    for (var trail = 13; trail >= 0; trail--) {
      final decay = math.pow(0.78, trail).toDouble();
      final prior = math.max(0, closeProgress - trail / (2.4 * 60));
      final eased = 1 - math.pow(1 - prior, 3).toDouble();
      for (final fragment in model._fragments) {
        final radius = fragment.radius + (sealRadius - fragment.radius) * eased;
        final point =
            center +
            Offset(math.cos(fragment.angle), math.sin(fragment.angle)) * radius;
        canvas.drawCircle(
          point,
          fragment.size * (1 - prior * 0.4),
          _paint(
            fragment.hot ? visuals.glow : visuals.accent,
            (0.25 + 0.5 * (1 - prior)) * energy * decay,
          ),
        );
      }
      for (var index = 0; index < 4; index++) {
        canvas.drawCircle(
          center,
          sealRadius + (1 - eased) * (90 + index * 60),
          _paint(
            index.isOdd ? visuals.glow : visuals.accent,
            0.25 * (1 - prior) * energy * decay,
            style: PaintingStyle.stroke,
          )..strokeWidth = 1.5,
        );
      }
    }
    _seal(canvas, size, 1 - math.pow(1 - closeProgress, 3).toDouble());
  }

  void _heavy(Canvas canvas, Size size) {
    final tuning = _tuningFor(variant, mode, intensity);
    final p = progress.clamp(0.0, 1.0);
    final flow = 1 - p * tuning.heavyFlowReduction;
    final available = (model._drops.length * tuning.heavyDensityScale).round();
    final densityEnvelope = math
        .pow(1 - p, tuning.heavyDensityDecayExponent)
        .toDouble();
    final live = math.max(
      tuning.heavyMinimumDrops,
      (available * densityEnvelope).round(),
    );
    for (var index = 0; index < live; index++) {
      final drop = model._drops[index];
      final x = drop.x * size.width;
      final length = drop.length * (0.25 + flow * 0.75);
      for (var trail = tuning.heavyTrailCount; trail >= 0; trail--) {
        final decay = math.pow(0.78, trail).toDouble();
        final y = (drop.y - drop.velocity * flow * trail / 60) * size.height;
        canvas.drawLine(
          Offset(x, y - length),
          Offset(x, y),
          Paint()
            ..blendMode = BlendMode.plus
            ..strokeWidth = drop.width
            ..shader = LinearGradient(
              colors: [
                Colors.transparent,
                visuals.accent.withValues(
                  alpha:
                      ((0.08 + 0.24 * flow) *
                              energy *
                              decay *
                              tuning.heavyAlphaScale)
                          .clamp(0.0, 1.0),
                ),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(Rect.fromLTWH(x - 2, y - length, 4, length)),
        );
      }
    }
    final lower = Rect.fromLTWH(
      0,
      size.height * 0.25,
      size.width,
      size.height * 0.75,
    );
    canvas.drawRect(
      lower,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            visuals.secondary.withValues(
              alpha:
                  ((0.3 * (1 - p * 0.6) +
                              math.sin(elapsedSeconds * 0.2) * 0.04) *
                          energy *
                          _heavyAccum)
                      .clamp(0.0, 1.0),
            ),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(lower),
    );
    final wobble = breath ? 0.5 + 0.5 * math.sin(elapsedSeconds * 0.31) : 0.5;
    final radius =
        size.shortestSide *
        (0.1 + p * tuning.heavyRadiusProgressScale + wobble * 0.05) *
        (0.7 + energy * 0.3);
    final center = Offset(size.width / 2, size.height * 0.52);
    final haloAlphaScale = tuning.heavyHaloAlphaScale * (breath ? 1.25 : 1.0);
    canvas.drawCircle(
      center,
      radius * 2.2,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFD9A8).withValues(
              alpha:
                  ((0.1 + p * tuning.heavyHaloProgressScale) *
                          energy *
                          _heavyAccum *
                          haloAlphaScale)
                      .clamp(0, 1),
            ),
            visuals.accent.withValues(
              alpha:
                  ((0.1 + p * tuning.heavyHaloProgressScale) *
                          energy *
                          _heavyAccum *
                          haloAlphaScale)
                      .clamp(0, 1),
            ),
            Colors.transparent,
          ],
          stops: const [0, 0.35, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 2.2)),
    );

    // Optional grounding response: a finger temporarily clears a small patch
    // of rain and leaves a soft water ring. The global rain envelope remains
    // time-driven, so the scene still resolves without any interaction.
    final pointer = touchPoint;
    if (pointer != null) {
      final wipeRadius = size.shortestSide * (0.13 + pointerSpeed * 0.035);
      canvas.drawCircle(
        pointer,
        wipeRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              visuals.background.withValues(alpha: 0.72),
              visuals.background.withValues(alpha: 0.34),
              Colors.transparent,
            ],
            stops: const [0, 0.58, 1],
          ).createShader(Rect.fromCircle(center: pointer, radius: wipeRadius)),
      );
      canvas.drawCircle(
        pointer,
        wipeRadius * (0.72 + pointerSpeed * 0.12),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = visuals.accent.withValues(
            alpha: (0.18 + pointerSpeed * 0.12) * (1 - p * 0.55),
          ),
      );
    }
  }

  void _racing(Canvas canvas, Size size) {
    final tuning = _tuningFor(variant, mode, intensity);
    final gather = closeProgress.clamp(0.0, 1.0);
    final gathered = gather * gather * (3 - 2 * gather);
    final near = touchPoint != null;
    for (final strand in model._racingStrands(tuning.racingStrandCount)) {
      final base =
          strand.y * size.height +
          (size.height / 2 - strand.y * size.height) * gathered;
      final chaos = (1 - strand.tame) * (1 - gathered);
      for (var trail = tuning.racingTrailCount; trail >= 0; trail--) {
        final decay = math.pow(0.86, trail).toDouble();
        final time = math.max(0, elapsedSeconds - trail / 60);
        final path = Path();
        for (var x = 0.0; x <= size.width; x += 8) {
          final wave =
              math.sin(
                x * (0.02 + chaos * 0.05) +
                    time *
                        strand.speed *
                        (0.6 + chaos * tuning.racingChaosSpeed) +
                    strand.phase,
              ) *
              strand.amplitude *
              tuning.racingAmplitudeScale *
              (0.15 + chaos) *
              energy;
          final pull = near
              ? math.exp(-(x - touchPoint!.dx).abs() / 130) *
                    (touchPoint!.dy - strand.y * size.height) *
                    (0.28 + strand.momentum * 0.25)
              : 0.0;
          final y = base + (wave + pull) * (1 - gathered);
          if (x == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(
          path,
          _paint(
            strand.tame > 0.5 ? visuals.glow : visuals.accent,
            (0.1 + strand.tame * 0.25) *
                energy *
                (1 - gathered) *
                decay *
                tuning.racingAlphaScale,
            style: PaintingStyle.stroke,
          )..strokeWidth = 1 + strand.tame * 1.4,
        );
      }
    }
    if (gathered > 0.05) {
      final y = size.height / 2;
      final start = size.width * 0.16;
      final settledPulse = still
          ? 0.5
          : 0.5 + 0.5 * math.sin(elapsedSeconds * 0.35);
      final acknowledgment = near ? 1.0 : 0.0;
      final focusLength =
          size.width *
          (0.6 +
              gathered * 0.02 +
              settledPulse * 0.012 +
              acknowledgment * 0.01);
      canvas.drawLine(
        Offset(start, y),
        Offset(start + focusLength * gathered, y),
        _paint(
          visuals.glow,
          gathered *
              (0.58 + settledPulse * 0.12 + acknowledgment * 0.12) *
              energy,
          style: PaintingStyle.stroke,
        )..strokeWidth = 1.5 + acknowledgment * 0.35,
      );
      if (gathered > 0.85) {
        canvas.drawCircle(
          Offset(start + focusLength * gathered + 12, y),
          2.6 + settledPulse * 0.8 + acknowledgment * 1.1,
          _paint(
            visuals.glow,
            ((gathered - 0.85) / 0.15) * (0.58 + acknowledgment * 0.24),
          ),
        );
      }
    }
  }

  void _away(Canvas canvas, Size size) {
    final shut = progress.clamp(0.0, 1.0);
    final eased = shut * shut * (3 - 2 * shut);
    final outside = math.pow(1 - eased, 1.25).toDouble();
    final cozy = shut >= 1 ? ((elapsedSeconds - 12) / 5).clamp(0.0, 1.0) : 0.0;
    final flicker =
        1 +
        math.sin(elapsedSeconds * 1.4) * 0.03 +
        math.sin(elapsedSeconds * 0.57) * 0.022;
    final door = Rect.fromLTWH(
      size.width * 0.1,
      size.height * 0.1,
      size.width * 0.8,
      size.height * 0.74,
    );
    final gap = door.width * (1 - eased * 0.985);

    canvas.save();
    canvas.clipRect(door);
    final opening = Rect.fromLTWH(door.left, door.top, gap, door.height);
    canvas.save();
    canvas.clipRect(opening);
    canvas.drawRect(
      opening,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFC4D6F0).withValues(alpha: 0.5 * outside + 0.02),
            const Color(0xFF96AED0).withValues(alpha: 0.42 * outside + 0.02),
            const Color(0xFF60708A).withValues(alpha: 0.3 * outside + 0.02),
          ],
          stops: const [0, 0.5, 1],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(opening),
    );
    for (final person in model._crowd) {
      final height = door.height * (0.3 + person.depth * 0.14);
      final width = height * 0.2;
      final x =
          door.left +
          person.x * door.width +
          math.sin(person.sway) * 3 * energy;
      final bottom = door.bottom;
      final body = Path()
        ..moveTo(x - width * 0.42, bottom)
        ..lineTo(x - width * 0.5, bottom - height * 0.6)
        ..quadraticBezierTo(
          x - width * 0.5,
          bottom - height * 0.72,
          x - width * 0.2,
          bottom - height * 0.76,
        )
        ..lineTo(x + width * 0.2, bottom - height * 0.76)
        ..quadraticBezierTo(
          x + width * 0.5,
          bottom - height * 0.72,
          x + width * 0.5,
          bottom - height * 0.6,
        )
        ..lineTo(x + width * 0.42, bottom)
        ..close();
      final bodyPaint = Paint()
        ..color = const Color(
          0xFF050609,
        ).withValues(alpha: 0.9 * (0.08 + outside * 0.92));
      canvas.drawPath(body, bodyPaint);
      canvas.drawCircle(
        Offset(x, bottom - height * 0.86),
        height * 0.085,
        bodyPaint,
      );
    }
    for (final fleck in model._chatter) {
      final center = Offset(
        door.left + fleck.x * door.width,
        door.top + fleck.y * door.height,
      );
      final radius = fleck.radius * energy * (1 + eased * 1.6);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              const Color(
                0xFFD6E4F8,
              ).withValues(alpha: fleck.alpha * 0.5 * math.pow(outside, 1.5)),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
    canvas.restore();

    final panel = Rect.fromLTWH(
      door.left + gap,
      door.top,
      door.width - gap,
      door.height,
    );
    if (panel.width > 0.5) {
      canvas.drawRect(
        panel,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF261912), Color(0xFF1A110C), Color(0xFF0D0907)],
            stops: [0, 0.12, 1],
          ).createShader(panel),
      );
      final seamWidth = (2 + 26 * outside) * energy;
      final seamRect = Rect.fromLTWH(
        panel.left - seamWidth,
        panel.top,
        seamWidth * 1.3,
        panel.height,
      );
      canvas.drawRect(
        seamRect,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              const Color(0xFFCEDEF6).withValues(alpha: 0.35 + 0.4 * outside),
              Colors.transparent,
            ],
            stops: const [0, 0.7, 1],
          ).createShader(seamRect),
      );
      final railPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * energy
        ..color = const Color(0xFFFFD0A0).withValues(alpha: 0.05 + cozy * 0.06);
      for (var index = 0; index < 2; index++) {
        final rail = Rect.fromLTWH(
          panel.left + panel.width * 0.16,
          door.top + door.height * (0.16 + index * 0.42),
          panel.width * 0.68,
          door.height * 0.3,
        );
        if (rail.width > 6 * energy) canvas.drawRect(rail, railPaint);
      }
      if (panel.width > size.width * 0.3) {
        final handle = Offset(
          panel.left + panel.width * 0.1,
          door.top + door.height * 0.56,
        );
        canvas.drawCircle(
          handle,
          26 * energy,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader =
                RadialGradient(
                  colors: [
                    const Color(
                      0xFFFFD6A8,
                    ).withValues(alpha: 0.3 + cozy * 0.25),
                    Colors.transparent,
                  ],
                ).createShader(
                  Rect.fromCircle(center: handle, radius: 26 * energy),
                ),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: handle,
            width: 10 * energy,
            height: 14 * energy,
          ),
          Paint()..color = const Color(0xFFD6B084).withValues(alpha: 0.75),
        );
      }
    }
    canvas.restore();

    canvas.drawRect(
      door,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * energy
        ..color = const Color(0xFFFFCE9E).withValues(alpha: 0.06 + cozy * 0.07),
    );
    if (eased > 0.9) {
      final underRect = Rect.fromLTWH(
        door.left,
        door.bottom,
        door.width,
        14 * energy,
      );
      canvas.drawRect(
        underRect,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(
            colors: [
              const Color(0xFFBED0EC).withValues(
                alpha: 0.16 * ((eased - 0.9) / 0.1) * (1 - cozy * 0.6),
              ),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(underRect),
      );
    }
    final lampCenter = Offset(size.width * 0.22, size.height * 0.9);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: Alignment(
            lampCenter.dx / size.width * 2 - 1,
            lampCenter.dy / size.height * 2 - 1,
          ),
          radius: 1.05,
          colors: [
            visuals.glow.withValues(
              alpha: (0.05 + eased * 0.17 + cozy * 0.06) * flicker,
            ),
            visuals.secondary.withValues(
              alpha: (0.05 + eased * 0.17 + cozy * 0.06) * flicker,
            ),
            Colors.transparent,
          ],
          stops: const [0, 0.34, 1],
        ).createShader(Offset.zero & size),
    );
    if (eased > 0.5) {
      for (final mote in model._motes) {
        final alpha = math.max(
          0,
          (0.16 + math.sin(mote.twinkle) * 0.1) *
              (eased - 0.5) *
              2 *
              (0.4 + cozy * 0.6),
        );
        canvas.drawCircle(
          Offset(mote.x * size.width, mote.y * size.height),
          mote.radius * energy,
          _paint(visuals.glow, alpha.toDouble()),
        );
      }
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          radius: 0.86,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.5 + eased * 0.38),
          ],
          stops: [
            (size.shortestSide *
                    (0.52 - eased * 0.2) /
                    (size.longestSide * 0.86))
                .clamp(0.0, 0.95),
            1,
          ],
        ).createShader(Offset.zero & size),
    );
  }

  void _care(Canvas canvas, Size size) {
    if (still || physicalContext == PhysicalCareContext.headache) {
      final center = Offset(size.width / 2, size.height * 0.58);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  const Color(0xFFFFE0AB).withValues(alpha: 0.18),
                  const Color(0xFFE8A34A).withValues(alpha: 0.065),
                  Colors.transparent,
                ],
                stops: const [0, 0.38, 1],
              ).createShader(
                Rect.fromCircle(
                  center: center,
                  radius: size.longestSide * 0.62,
                ),
              ),
      );
      canvas.drawLine(
        Offset(size.width * 0.24, center.dy),
        Offset(size.width * 0.76, center.dy),
        Paint()
          ..color = const Color(0xFFFFE0AB).withValues(alpha: 0.14)
          ..strokeWidth = 1.1,
      );
      return;
    }
    final p = progress.clamp(0.0, 1.0);
    final eased = p * p * (3 - 2 * p);
    switch (physicalContext ?? PhysicalCareContext.tension) {
      case PhysicalCareContext.nausea:
        _water(canvas, size, eased);
      case PhysicalCareContext.cramps:
        _knot(canvas, size, eased);
      case PhysicalCareContext.tension:
        _rings(canvas, size, eased);
      case PhysicalCareContext.headache:
        break;
    }
  }

  void _water(Canvas canvas, Size size, double settle) {
    for (var index = 0; index < 7; index++) {
      final y = size.height * (0.3 + index * 0.062);
      final path = Path();
      for (var x = 0.0; x <= size.width; x += 8) {
        final amplitude = (26 - settle * 24) * energy;
        final yy =
            y +
            math.sin(
                  x * 0.012 + elapsedSeconds * (1.5 - settle * 1.3) + index,
                ) *
                amplitude +
            math.sin(x * 0.031 - elapsedSeconds * (0.9 - settle * 0.8)) *
                amplitude *
                0.4 *
                (1 - settle);
        if (x == 0) {
          path.moveTo(x, yy);
        } else {
          path.lineTo(x, yy);
        }
      }
      canvas.drawPath(
        path,
        _paint(
          index.isOdd ? visuals.glow : visuals.accent,
          (0.12 + settle * 0.18) * energy * _careAccum,
          style: PaintingStyle.stroke,
        )..strokeWidth = 1 + settle * 1.2,
      );
    }
    final rect = Rect.fromLTWH(
      0,
      size.height * 0.2,
      size.width,
      size.height * 0.6,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            visuals.glow.withValues(
              alpha: ((0.06 + settle * 0.1) * energy * _careAccum).clamp(0, 1),
            ),
            Colors.transparent,
          ],
          stops: const [0, 0.5, 1],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
    );
  }

  void _knot(Canvas canvas, Size size, double eased) {
    final knot = 1 - eased;
    final swell = 0.5 + 0.5 * math.sin(elapsedSeconds * (0.5 - eased * 0.32));
    final center = Offset(size.width / 2, size.height * (0.46 - eased * 0.04));
    final radius =
        size.shortestSide *
        (0.16 + eased * 0.4 + swell * 0.04 * (0.4 + knot)) *
        (0.7 + energy * 0.3);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF0D2).withValues(
              alpha: ((0.28 + swell * 0.16) * energy * _careAccum).clamp(0, 1),
            ),
            visuals.glow.withValues(
              alpha: ((0.28 + swell * 0.16) * energy * _careAccum).clamp(0, 1),
            ),
            visuals.accent.withValues(
              alpha: ((0.28 + swell * 0.16) * energy * _careAccum).clamp(0, 1),
            ),
            Colors.transparent,
          ],
          stops: [0, 0.25 + eased * 0.2, 0.6, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    for (var index = 0; index < 3; index++) {
      canvas.drawCircle(
        center +
            Offset(
              math.sin(elapsedSeconds * (1.2 - eased) + index) *
                  8 *
                  knot *
                  energy,
              math.cos(elapsedSeconds * (1.1 - eased) + index) *
                  8 *
                  knot *
                  energy,
            ),
        radius * (0.3 + index * 0.16) * (0.7 + knot * 0.3),
        _paint(
          visuals.glow,
          0.14 * knot * energy * _careAccum,
          style: PaintingStyle.stroke,
        )..strokeWidth = 1 + knot,
      );
    }
  }

  void _rings(Canvas canvas, Size size, double eased) {
    final center = Offset(size.width / 2, size.height * 0.5);
    final radius =
        size.shortestSide * (0.18 + eased * 0.34) * (0.7 + energy * 0.3);
    canvas.drawCircle(
      center,
      radius * 1.6,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            visuals.glow.withValues(
              alpha: ((0.3 + eased * 0.2) * energy * _careAccum).clamp(0, 1),
            ),
            visuals.accent.withValues(
              alpha: ((0.3 + eased * 0.2) * energy * _careAccum).clamp(0, 1),
            ),
            Colors.transparent,
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.6)),
    );
    for (var index = 0; index < 4; index++) {
      final rr = radius * (0.5 + index * 0.28) * (1 + eased * 0.3);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: rr * 2,
          height: rr * (1 - eased * 0.92) * 2,
        ),
        _paint(
          visuals.glow,
          0.16 * (1 - eased * 0.5) * energy * _careAccum,
          style: PaintingStyle.stroke,
        )..strokeWidth = 1,
      );
    }
    canvas.drawLine(
      Offset(size.width * 0.2 - size.width * 0.04 * (1 - eased), center.dy),
      Offset(size.width * 0.8 + size.width * 0.04 * (1 - eased), center.dy),
      _paint(
        visuals.glow,
        0.4 * eased * energy * _careAccum,
        style: PaintingStyle.stroke,
      )..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant PrototypeScenePainter oldDelegate) => true;
}

class _Drop {
  _Drop({
    required this.x,
    required this.y,
    required this.velocity,
    required this.length,
    required this.width,
  });
  double x;
  double y;
  final double velocity;
  final double length;
  final double width;
}

class _Fragment {
  _Fragment({
    required this.angle,
    required this.radius,
    required this.size,
    required this.hot,
  });
  final double angle;
  final double radius;
  final double size;
  final bool hot;
}

class _Spark {
  _Spark({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.radius,
    required this.hot,
  });
  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double radius;
  final bool hot;
}

class _Strand {
  _Strand({
    required this.phase,
    required this.speed,
    required this.y,
    required this.amplitude,
  });
  final double phase;
  final double speed;
  final double y;
  final double amplitude;
  double tame = 0;
  double momentum = 0;
}

class _CrowdPerson {
  _CrowdPerson({
    required this.x,
    required this.depth,
    required this.velocity,
    required this.sway,
    required this.swaySpeed,
  });
  double x;
  final double depth;
  final double velocity;
  double sway;
  final double swaySpeed;
}

class _Chatter {
  _Chatter({
    required this.x,
    required this.y,
    required this.radius,
    required this.velocity,
    required this.alpha,
  });
  double x;
  double y;
  final double radius;
  final double velocity;
  final double alpha;
}

class _Mote {
  _Mote({
    required this.x,
    required this.y,
    required this.radius,
    required this.vx,
    required this.vy,
    required this.twinkle,
  });
  double x;
  double y;
  final double radius;
  final double vx;
  final double vy;
  double twinkle;
}
