import 'package:flutter/painting.dart';

import '../../patterns/domain/personal_pattern.dart';
import '../../patterns/domain/pattern_source.dart';

/// View-state for the Spectrum Log (Insights view).
///
/// Replaces traditional line/bar charts with a single horizontal spectrum
/// strip — a gradient bar representing the 14-day premenstrual countdown
/// (Day -14 to Day -1), with blurred "nebula" color overlays derived from
/// the symptom severity matrix.
///
/// Design spec: core_ui.md — Component 2.
final class SpectrumLogViewModel {
  const SpectrumLogViewModel({
    required this.nebulaSegments,
    required this.dayLabels,
    required this.emptyMessage,
    required this.confirmedRatingCount,
    required this.observedDayCount,
  });

  /// One segment per day in the luteal window (-14 to -1).
  final List<SpectrumNebulaSegment> nebulaSegments;

  /// Day labels across the strip.
  final List<String> dayLabels;

  /// Shown when no pattern data exists yet.
  final String? emptyMessage;
  final int confirmedRatingCount;
  final int observedDayCount;

  /// Builds from the pattern engine's analysis.
  factory SpectrumLogViewModel.fromAnalysis(
    PersonalPatternAnalysis analysis, {
    PatternSourceSnapshot? source,
  }) {
    if (analysis.symptomPatterns.isEmpty) {
      return const SpectrumLogViewModel(
        nebulaSegments: [],
        dayLabels: [],
        emptyMessage: 'patterns gather quietly over cycles.',
        confirmedRatingCount: 0,
        observedDayCount: 0,
      );
    }

    // Collect all severity-by-days-before-menses data across all symptoms.
    final combinedMatrix = <int, List<double>>{};
    for (final pattern in analysis.symptomPatterns) {
      for (final entry in pattern.severityByDaysBeforeMenses.entries) {
        combinedMatrix.putIfAbsent(entry.key, () => []).add(entry.value);
      }
    }

    final segments = <SpectrumNebulaSegment>[];
    final labels = <String>[];
    for (var day = -14; day <= -1; day++) {
      labels.add('d$day');
      final severities = combinedMatrix[day];
      if (severities == null || severities.isEmpty) {
        segments.add(SpectrumNebulaSegment.empty(day));
        continue;
      }
      final avgSeverity =
          severities.fold(0.0, (sum, v) => sum + v) / severities.length;
      segments.add(
        SpectrumNebulaSegment(
          dayIndex: day,
          intensity: (avgSeverity / 6.0).clamp(0.0, 1.0),
          dominantHue: _hueForSeverity(avgSeverity),
          affectedSymptoms: severities.length,
        ),
      );
    }

    return SpectrumLogViewModel(
      nebulaSegments: segments,
      dayLabels: labels,
      emptyMessage: null,
      confirmedRatingCount: analysis.symptomPatterns.fold(
        0,
        (total, pattern) => total + pattern.count,
      ),
      observedDayCount: analysis.symptomPatterns
          .expand((pattern) => pattern.coveredDates)
          .toSet()
          .length,
    );
  }

  /// Maps severity to hue: low severity → cool indigo, high → warm
  /// bleeding velvet-crimson.
  static double _hueForSeverity(double avgSeverity) {
    // 0 = deep purple-blue (240°), 6 = crimson red (350°).
    return 240.0 + (avgSeverity / 6.0) * 110.0;
  }
}

/// A single day-segment in the spectrum strip.
final class SpectrumNebulaSegment {
  const SpectrumNebulaSegment({
    required this.dayIndex,
    required this.intensity,
    required this.dominantHue,
    required this.affectedSymptoms,
  });

  /// Days before menses (-14 to -1).
  final int dayIndex;

  /// 0.0 = no symptoms, 1.0 = maximum severity.
  final double intensity;

  /// HSL hue for the nebula blur (240°=cool indigo, 350°=velvet crimson).
  final double dominantHue;

  /// How many distinct symptom types were reported on this day.
  final int affectedSymptoms;

  /// An empty segment with no data.
  factory SpectrumNebulaSegment.empty(int dayIndex) {
    return SpectrumNebulaSegment(
      dayIndex: dayIndex,
      intensity: 0.0,
      dominantHue: 240.0,
      affectedSymptoms: 0,
    );
  }

  Color get fillColor => HSLColor.fromAHSL(
    1.0,
    dominantHue,
    0.6,
    intensity.clamp(0.15, 0.55),
  ).toColor();

  /// Blur radius for the nebula effect: 0 = crisp, higher = more diffuse.
  double get blurRadius => intensity < 0.2 ? 0.0 : 4.0 + intensity * 12.0;
}
