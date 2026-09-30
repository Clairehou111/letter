import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';

double _contrast(Color foreground, Color background) {
  final opaqueForeground = Color.alphaBlend(foreground, background);
  final foregroundLuminance = opaqueForeground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void _expectContrast({
  required String label,
  required Color foreground,
  required Color background,
  required double minimum,
}) {
  final ratio = _contrast(foreground, background);
  expect(
    ratio,
    greaterThanOrEqualTo(minimum),
    reason:
        '$label has ${ratio.toStringAsFixed(2)}:1 contrast; '
        'expected at least ${minimum.toStringAsFixed(1)}:1.',
  );
}

void main() {
  test('Quiet Dusk body ink meets the 4.5:1 text floor', () {
    const backgrounds = <String, Color>{
      'canvas': ExperienceColors.canvas,
      'surface': ExperienceColors.surface,
      'raised surface': ExperienceColors.surfaceWarm,
    };
    for (final entry in backgrounds.entries) {
      _expectContrast(
        label: 'Primary ink on ${entry.key}',
        foreground: ExperienceColors.ink,
        background: entry.value,
        minimum: ExperienceFoundation.minBodyContrastRatio,
      );
      _expectContrast(
        label: 'Soft ink on ${entry.key}',
        foreground: ExperienceColors.inkSoft,
        background: entry.value,
        minimum: ExperienceFoundation.minBodyContrastRatio,
      );
    }
    _expectContrast(
      label: 'Faint ink on canvas',
      foreground: ExperienceColors.inkFaint,
      background: ExperienceColors.canvas,
      minimum: ExperienceFoundation.minBodyContrastRatio,
    );
  });

  test('Deep Dusk body ink meets the 4.5:1 text floor', () {
    const backgrounds = <String, Color>{
      'care top': ExperienceColors.careSkyTop,
      'care bottom': ExperienceColors.careSkyBottom,
      'release': CareRefugeDepths.release,
      'heavy': CareRefugeDepths.heavy,
      'racing': CareRefugeDepths.racing,
      'space': CareRefugeDepths.space,
      'physical': CareRefugeDepths.physical,
      'headache': CareRefugeDepths.headacheStill,
    };
    for (final entry in backgrounds.entries) {
      for (final ink in <(String, Color)>[
        ('primary', ExperienceColors.careInk),
        ('soft', ExperienceColors.careInkSoft),
        ('faint', ExperienceColors.careInkFaint),
      ]) {
        _expectContrast(
          label: '${ink.$1} Care ink on ${entry.key}',
          foreground: ink.$2,
          background: entry.value,
          minimum: ExperienceFoundation.minBodyContrastRatio,
        );
      }
    }
  });

  test('warm-paper reading ink keeps text and graphic contrast', () {
    for (final background in <Color>[
      ExperiencePaper.canvas,
      ExperiencePaper.surface,
      ExperiencePaper.surfaceWarm,
    ]) {
      _expectContrast(
        label: 'Paper primary ink',
        foreground: ExperiencePaper.ink,
        background: background,
        minimum: ExperienceFoundation.minBodyContrastRatio,
      );
      _expectContrast(
        label: 'Paper soft ink',
        foreground: ExperiencePaper.inkSoft,
        background: background,
        minimum: ExperienceFoundation.minBodyContrastRatio,
      );
      _expectContrast(
        label: 'Paper faint ink',
        foreground: ExperiencePaper.inkFaint,
        background: background,
        minimum: ExperienceFoundation.minBodyContrastRatio,
      );
    }
  });

  test('chart accents and dusk hairlines meet the 3:1 graphic floor', () {
    for (final accent in <(String, Color)>[
      ('period', ExperienceColors.phasePeriod),
      ('follicular', ExperienceColors.phaseFollicular),
      ('ovulation', ExperienceColors.phaseOvulation),
      ('luteal', ExperienceColors.phaseLuteal),
      ('gravity', ExperienceColors.accentGravity),
      ('spectrum', ExperienceColors.accentSpectrum),
      ('twin', ExperienceColors.accentTwin),
    ]) {
      _expectContrast(
        label: '${accent.$1} accent on surface',
        foreground: accent.$2,
        background: ExperienceColors.surface,
        minimum: ExperienceFoundation.minLargeGraphicContrastRatio,
      );
    }
    for (final background in <Color>[
      ExperienceColors.canvas,
      ExperienceColors.surface,
      ExperienceColors.surfaceWarm,
    ]) {
      _expectContrast(
        label: 'Dusk hairline',
        foreground: ExperienceColors.hairline,
        background: background,
        minimum: ExperienceFoundation.minLargeGraphicContrastRatio,
      );
    }
  });

  test('ember action ink meets the 4.5:1 text floor at every stop', () {
    for (final stop in ExperienceColors.emberActionGradient.colors) {
      _expectContrast(
        label: 'Ember action ink',
        foreground: ExperienceColors.onEmber,
        background: stop,
        minimum: ExperienceFoundation.minBodyContrastRatio,
      );
    }
  });
}
