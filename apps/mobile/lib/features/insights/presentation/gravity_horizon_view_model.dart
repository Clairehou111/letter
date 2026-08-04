import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../cycle/domain/cycle_prediction.dart';
import '../../cycle/domain/local_date.dart';

/// View-state for the Gravity Horizon curve on the Today screen.
///
/// Exposes the cycle energy topography as a set of Bezier control points
/// and a single "today" indicator position. The UI (CustomPainter) reads
/// this and renders a glowing Bezier curve with a dot.
///
/// Design spec: core_ui.md — Component 1.
final class GravityHorizonViewModel {
  const GravityHorizonViewModel({
    required this.curvePoints,
    required this.todayPosition,
    required this.todayLabel,
    required this.subtitle,
    required this.isInLutealValley,
    required this.backgroundColor,
    this.lutealStartLabel,
    this.lutealDipStartFraction = 0.70,
    this.lutealDipEndFraction = 0.95,
  });

  /// Ordered control points for the Bezier curve (x: day offset, y: energy).
  final List<Offset> curvePoints;

  /// Where on the curve today sits (fraction 0.0–1.0 along the x axis).
  final double todayPosition;

  /// Short lowercase label, e.g. "day 18".
  final String todayLabel;

  /// Plain subtitle that distinguishes estimated timing from lived experience.
  final String subtitle;

  /// Whether today is inside the predicted luteal window.
  final bool isInLutealValley;

  /// Canvas background: deep charcoal obsidian (#0B0C10).
  final Color backgroundColor;

  /// Human-readable luteal onset date for pre-window display, e.g. "from Jul 27".
  final String? lutealStartLabel;

  /// Depth of the luteal valley as a fraction of available height.
  /// Positive = downward (toward canvas bottom) to represent the "gravity"
  /// of the premenstrual window. At peak intensity the curve sinks to
  /// 0.5 + 0.45 = 0.95 (near bottom edge).
  static const _lutealValleyDepth = 0.45;

  /// Where the luteal descent begins along the cycle width, as a fraction
  /// 0.0–1.0. The painter uses this to position the cubic bezier control
  /// points so the valley aligns with the user's actual predicted window.
  final double lutealDipStartFraction;

  /// Where the luteal window ends (menses start), as a fraction 0.0–1.0.
  final double lutealDipEndFraction;

  /// Builds the view-state from a cycle prediction and today's date.
  /// Days before luteal onset that trigger the "approaching" subtitle.
  /// 3 days = the last ~3 days of the follicular plateau before the cliff.
  static const _preLutealDays = 3;

  factory GravityHorizonViewModel.fromPrediction({
    required CyclePrediction? prediction,
    required LocalDate today,
    required int? cycleDay,
    required double availableWidth,
    required double availableHeight,
    bool isPeriodInProgress = false,
  }) {
    if (prediction == null) {
      return const GravityHorizonViewModel(
        curvePoints: [],
        todayPosition: 0.5,
        todayLabel: 'no prediction yet',
        subtitle: 'your cycle record is still taking shape.',
        isInLutealValley: false,
        backgroundColor: Color(0xFF0B0C10),
      );
    }

    final day = cycleDay ?? 1;
    final totalDays = prediction.maximumCycleDays + 10;
    final points = <Offset>[];
    for (var i = 0; i <= totalDays; i++) {
      final x = i / totalDays;
      final isLuteal = _isInLutealWindow(i, prediction, today);
      final y = isLuteal
          ? 0.5 + _lutealValleyDepth * _lutealIntensity(i, prediction)
          : 0.5;
      points.add(Offset(x * availableWidth, y * availableHeight));
    }

    final todayX = (day / totalDays).clamp(0.0, 1.0);
    final inLuteal = prediction.lutealWindow.contains(today);
    final lutealStartLabel = _formatLutealLabel(prediction.predictedMensesStart);

    // Compute luteal dip fractions from the prediction data.
    final cycleStartEpoch = prediction.predictedMensesStart
        .addDays(-prediction.medianCycleDays)
        .epochDay;
    final lutealStartEpoch = prediction.predictedLutealStart.epochDay;
    final lutealEndEpoch = prediction.predictedLutealEnd.epochDay;
    final dipStartFraction = ((lutealStartEpoch - cycleStartEpoch) / totalDays)
        .clamp(0.0, 1.0);
    final dipEndFraction = ((lutealEndEpoch - cycleStartEpoch) / totalDays)
        .clamp(0.0, 1.0);

    // ── 4-stage subtitle mapped to curve geography ────────
    final daysToLuteal = lutealStartEpoch - today.epochDay;
    final approaching = daysToLuteal > 0 && daysToLuteal <= _preLutealDays;

    final subtitle = isPeriodInProgress
        ? 'the tide is flowing. the heavy weight is clearing out line by line.'
        : inLuteal
        ? 'estimated premenstrual window. gravity feels heavier today. '
            'you are safe to slow down.'
        : approaching
        ? 'the plateau before the wave. checking in to track the gentle shifts.'
        : 'horizon clear. your cosmic tide is light and calm. enjoy the space.';

    return GravityHorizonViewModel(
      curvePoints: points,
      todayPosition: todayX,
      todayLabel: 'day $day',
      subtitle: subtitle,
      isInLutealValley: inLuteal,
      backgroundColor: const Color(0xFF0B0C10),
      lutealStartLabel: inLuteal ? null : lutealStartLabel,
      lutealDipStartFraction: dipStartFraction,
      lutealDipEndFraction: dipEndFraction,
    );
  }

  /// Frontend UI policy: use 16-day countback (maximum inclusivity).
  /// The earliest possible luteal onset (14+2 days before menses) ensures
  /// the emotional-safety window opens before the first hormone drop,
  /// catching PMDD/PMS flare-ups that often begin at day -15/-16.
  ///
  /// Clinical reports (Twin Matrix) use the standard 14-day matrix; this
  /// label is only for the GravityHorizon user-facing display.
  static const _uiLutealCountbackDays = 16;

  static String _formatLutealLabel(LocalDate mensesStart) {
    final onset = mensesStart.addDays(-_uiLutealCountbackDays);
    final m = _monthAbbrev(onset.month);
    final d = onset.day;
    return '$m $d';
  }

  static String _monthAbbrev(int month) => switch (month) {
    1 => 'Jan', 2 => 'Feb', 3 => 'Mar', 4 => 'Apr',
    5 => 'May', 6 => 'Jun', 7 => 'Jul', 8 => 'Aug',
    9 => 'Sep', 10 => 'Oct', 11 => 'Nov', 12 => 'Dec',
    _ => '',
  };

  static bool _isInLutealWindow(
    int day,
    CyclePrediction prediction,
    LocalDate today,
  ) {
    final startDay = prediction.predictedLutealStart.epochDay;
    final endDay = prediction.predictedLutealEnd.epochDay;
    final cycleStart = prediction.predictedMensesStart
        .addDays(-prediction.medianCycleDays)
        .epochDay;
    final normalizedDay = cycleStart + day - 1;
    return normalizedDay >= startDay && normalizedDay <= endDay;
  }

  static double _lutealIntensity(int day, CyclePrediction prediction) {
    // Gentle bell-shaped intensity curve peaking at luteal midpoint.
    // Uses cosine easing for a smooth, organic valley rather than a
    // harsh V-shape. Intensity = 1.0 at midpoint, ~0.0 at edges.
    final startDay = prediction.predictedLutealStart.epochDay;
    final endDay = prediction.predictedLutealEnd.epochDay;
    final mid = (startDay + endDay) / 2.0;
    final cycleStart = prediction.predictedMensesStart
        .addDays(-prediction.medianCycleDays)
        .epochDay;
    final normalizedDay = (cycleStart + day - 1).toDouble();
    final halfRange = (endDay - startDay) / 2.0;
    if (halfRange <= 0) return 0.0;
    final t = ((normalizedDay - mid) / halfRange).clamp(-1.0, 1.0);
    // Cosine ease: cos(π·t) goes from 1 (at t=0) to 0 (at t=±1).
    return (math.cos(math.pi * t) + 1.0) / 2.0;
  }
}
