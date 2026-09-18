import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'care_v2_kernel.dart';

/// Care V2 copy layer.
///
/// Copy lives in an invisible reserved area — there is no visible panel, band,
/// or bottom-third chrome. The reserved box has a fixed height, so text
/// materialising or dissolving never moves the painter's bounds and never
/// reflows the scene.
///
/// One line at a time, at most three lines, long silent intervals between
/// them. Lines come into focus through blur and opacity in place; nothing
/// flies, slides, or shakes.
class CareV2CopyLayer extends StatelessWidget {
  const CareV2CopyLayer({
    required this.elapsed,
    required this.lines,
    required this.color,
    required this.glow,
    required this.phase,
    required this.settledTitle,
    required this.settledCue,
    this.suppressed = false,
    this.reducedMotion = false,
    super.key,
  });

  /// Reserved height. Fixed, so nothing below or above it ever shifts.
  static const double reservedHeight = 132;

  static const double firstLineAtSeconds = 7;
  static const double lineCycleSeconds = 16;
  static const double lineVisibleSeconds = 7;

  final double elapsed;
  final List<String> lines;
  final Color color;
  final Color glow;
  final CareV2Phase phase;
  final String settledTitle;
  final String settledCue;

  /// True while a finger rests on the scene: the material speaks instead.
  final bool suppressed;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: reservedHeight,
        child: Center(child: _content(context)),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();

    if (phase == CareV2Phase.settled || phase == CareV2Phase.extending) {
      return _line(context, settledCue, 1, 0);
    }
    if (phase == CareV2Phase.landing) {
      final into = CareV2Timeline.landingProgress(elapsed);
      final opacity = Curves.easeInOutCubic.transform(
        (into / 0.45).clamp(0.0, 1.0),
      );
      return _line(context, settledTitle, opacity, 0);
    }
    if (suppressed) return const SizedBox.shrink();

    if (elapsed < firstLineAtSeconds) return const SizedBox.shrink();
    final copyElapsed = elapsed - firstLineAtSeconds;
    final index = (copyElapsed / lineCycleSeconds).floor();
    if (index < 0 || index >= lines.length) return const SizedBox.shrink();
    final within = copyElapsed - index * lineCycleSeconds;
    if (within >= lineVisibleSeconds) return const SizedBox.shrink();

    final local = (within / lineVisibleSeconds).clamp(0.0, 1.0);
    final entering = Curves.easeInOutCubic.transform(
      (local / 0.32).clamp(0.0, 1.0),
    );
    final leaving = local < 0.66
        ? 1.0
        : 1 -
              Curves.easeInOutCubic.transform(
                ((local - 0.66) / 0.34).clamp(0.0, 1.0),
              );
    final opacity = math.min(entering, leaving).clamp(0.0, 1.0);
    final blur = reducedMotion
        ? 0.0
        : local < 0.32
        ? 7 * (1 - entering)
        : local > 0.66
        ? 5 * (1 - leaving)
        : 0.0;
    return _line(context, lines[index], opacity, blur);
  }

  Widget _line(BuildContext context, String text, double opacity, double blur) {
    final scaler = MediaQuery.textScalerOf(context);
    final child = Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Text(
          text,
          key: const Key('care-v2-copy-line'),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.fade,
          textScaler: scaler,
          style: TextStyle(
            color: color.withValues(alpha: 0.62),
            fontFamily: 'Newsreader',
            fontSize: 19,
            fontWeight: FontWeight.w400,
            height: 1.24,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
    if (blur < 0.2) return child;
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: child,
    );
  }
}

/// The single, subordinate confirmation inside the completed Explode seal.
///
/// It appears once, in place, through opacity and focus only: no shake, no
/// shrinking type, no repetition. The sealed material carries the meaning.
class CareV2SealInscription extends StatelessWidget {
  const CareV2SealInscription({
    required this.secondsSinceSeal,
    required this.color,
    super.key,
  });

  static const String text = 'anger is sealed';
  static const double visibleSeconds = 6;

  final double? secondsSinceSeal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final since = secondsSinceSeal;
    if (since == null || since < 0 || since >= visibleSeconds) {
      return const SizedBox.shrink();
    }
    final opacity =
        Curves.easeInOutCubic.transform((since / 1.4).clamp(0.0, 1.0)) *
        (1 -
            Curves.easeInOutCubic.transform(
              ((since - 4.2) / 1.8).clamp(0.0, 1.0),
            ));
    return IgnorePointer(
      child: Opacity(
        opacity: (opacity * 0.7).clamp(0.0, 1.0),
        child: Text(
          text,
          key: const Key('care-v2-seal-inscription'),
          textAlign: TextAlign.center,
          textScaler: MediaQuery.textScalerOf(
            context,
          ).clamp(maxScaleFactor: 1.4),
          style: TextStyle(
            color: color.withValues(alpha: 0.9),
            fontFamily: 'Newsreader',
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.2,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}
