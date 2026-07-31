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
  });

  /// Ordered control points for the Bezier curve (x: day offset, y: energy).
  final List<Offset> curvePoints;

  /// Where on the curve today sits (fraction 0.0–1.0 along the x axis).
  final double todayPosition;

  /// Short lowercase label, e.g. "day 18".
  final String todayLabel;

  /// Lowercase subtitle, e.g. "current tide: entering the luteal valley.
  /// gravity feels heavier today. you are safe to slow down."
  final String subtitle;

  /// Whether today is inside the predicted luteal window.
  final bool isInLutealValley;

  /// Canvas background: deep charcoal obsidian (#0B0C10).
  final Color backgroundColor;

  static final _lutealValleyDepth = -0.4;

  /// Builds the view-state from a cycle prediction and today's date.
  factory GravityHorizonViewModel.fromPrediction({
    required CyclePrediction? prediction,
    required LocalDate today,
    required int? cycleDay,
    required double availableWidth,
    required double availableHeight,
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

    return GravityHorizonViewModel(
      curvePoints: points,
      todayPosition: todayX,
      todayLabel: 'day $day',
      subtitle: inLuteal
          ? 'current tide: entering the luteal valley. '
              'gravity feels heavier today. you are safe to slow down.'
          : 'current tide: steady waters. your energy is holding.',
      isInLutealValley: inLuteal,
      backgroundColor: const Color(0xFF0B0C10),
    );
  }

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
    // Intensity peaks at the midpoint of the luteal window.
    final startDay = prediction.predictedLutealStart.epochDay;
    final endDay = prediction.predictedLutealEnd.epochDay;
    final mid = (startDay + endDay) / 2.0;
    final cycleStart = prediction.predictedMensesStart
        .addDays(-prediction.medianCycleDays)
        .epochDay;
    final normalizedDay = cycleStart + day - 1;
    final distFromMid = (normalizedDay - mid).abs();
    final halfRange = (endDay - startDay) / 2.0;
    return (1.0 - (distFromMid / halfRange).clamp(0.0, 1.0));
  }
}
