import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/care/domain/care_memory.dart';
import '../../features/cycle/domain/bleeding_flow.dart';
import '../../features/health_records/domain/health_record.dart';
import '../theme/experience_foundation.dart';

/// Shared accessible degree-graphic vocabulary — the single owner of how
/// flow, bleeding color, severity, pain, and outcome degrees are drawn.
///
/// Design-authority rules enforced here:
///  * Flow has exactly four degrees matching [BleedingFlow]; spotting is
///    visually and verbally a flow degree, never a period trigger.
///  * Severity renders exactly the five present degrees of
///    [SymptomSeverity] — there is no "not at all" option; deselection is
///    absence and is handled by the caller, not by a sixth glyph.
///  * Pain is recorded as pain symptoms (ObservationRecordingKind.pain)
///    with the same five named [SymptomSeverity] degrees, composed in one
///    card ([PainEntryCard]). There is no numeric pain score.
///  * Every glyph carries label + degree semantics and is distinguishable
///    by shape, fill level, count, or pattern — never by color alone
///    (grayscale safe).
abstract final class DegreeGraphics {
  // --- Contracts -----------------------------------------------------------

  /// The four flow degrees. Spotting is one of them — a flow degree, never
  /// a period start or extend trigger.
  static const List<BleedingFlow> flowDegrees = BleedingFlow.values;

  /// Exactly five present degrees. No "not at all" exists in this system.
  static const List<SymptomSeverity> severityDegrees = SymptomSeverity.values;

  static const List<CareOutcome> outcomes = CareOutcome.values;

  /// The approved Today severity palette. Every surface uses this same ramp
  /// so a degree never changes color when the user moves between Today,
  /// Cycle, Care, Patterns, or a report.
  static const List<Color> severityRamp = <Color>[
    Color(0xFFEACDBB),
    Color(0xFFE1AC8B),
    Color(0xFFD3895F),
    Color(0xFFC2663D),
    Color(0xFFA8482C),
  ];

  /// Quiet honesty copy shown once where spotting is chosen.
  static const String spottingHonestyNote =
      'Spotting is a flow degree. It is recorded like any other flow day '
      'and never starts or extends a period.';

  // --- Labels --------------------------------------------------------------

  static String outcomeLabel(CareOutcome outcome) {
    return switch (outcome) {
      CareOutcome.better => 'Better',
      CareOutcome.same => 'Same',
      CareOutcome.worse => 'Worse',
    };
  }

  static String flowSemanticsLabel(BleedingFlow flow) {
    return switch (flow) {
      BleedingFlow.spotting =>
        'Bleeding flow: Spotting — a flow degree, never a period start',
      _ => 'Bleeding flow: ${flow.label}',
    };
  }

  static String bleedingColorSemanticsLabel(BleedingColor color) =>
      'Bleeding color: ${color.label}';

  /// Exact approved Today fill for each optional bleeding-color observation.
  static Color bleedingColorFill(BleedingColor color) => switch (color) {
    BleedingColor.pink => const Color(0xFFF2A3B3),
    BleedingColor.brightRed => const Color(0xFFD2392B),
    BleedingColor.darkRed => const Color(0xFF8A2320),
    BleedingColor.brown => const Color(0xFF6E4A38),
  };

  static String severitySemanticsLabel(SymptomSeverity severity) =>
      'Severity: ${severity.label}, ${severity.score} of 5';

  static String outcomeSemanticsLabel(CareOutcome outcome) =>
      'Outcome: ${outcomeLabel(outcome)}';

  // --- Factories -----------------------------------------------------------

  static Widget flow(
    BleedingFlow flow, {
    Key? key,
    double size = 28,
    bool showWord = true,
    bool selected = false,
    bool careWorld = false,
  }) {
    return FlowDegreeGlyph(
      key: key,
      flow: flow,
      size: size,
      showWord: showWord,
      selected: selected,
      careWorld: careWorld,
    );
  }

  /// The approved Today selector cell, shared verbatim by Today and Cycle.
  /// A null value is the explicit "None" choice used only by Today.
  static Widget flowChoice(
    BleedingFlow? flow, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return BleedingFlowChoice(flow: flow, selected: selected, onTap: onTap);
  }

  static Widget bleedingColor(
    BleedingColor color, {
    Key? key,
    double size = 28,
    bool showWord = true,
    bool selected = false,
    bool careWorld = false,
  }) {
    return BleedingColorSwatch(
      key: key,
      color: color,
      size: size,
      showWord: showWord,
      selected: selected,
      careWorld: careWorld,
    );
  }

  /// The approved Today color choice, shared verbatim by Today and Cycle.
  static Widget bleedingColorChoice(
    BleedingColor color, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return BleedingColorChoice(color: color, selected: selected, onTap: onTap);
  }

  static Widget severity(
    SymptomSeverity severity, {
    Key? key,
    double size = 28,
    bool showWord = true,
    bool selected = false,
    bool careWorld = false,
  }) {
    return SeverityGlyph(
      key: key,
      severity: severity,
      size: size,
      showWord: showWord,
      selected: selected,
      careWorld: careWorld,
    );
  }

  /// The pain question as one severity-based card: the same five named
  /// [SymptomSeverity] degrees as every other observation.
  static Widget painEntry({
    Key? key,
    required SymptomSeverity? severity,
    ValueChanged<SymptomSeverity>? onSeverityChanged,
    VoidCallback? onCleared,
    bool careWorld = false,
    bool enabled = true,
  }) {
    return PainEntryCard(
      key: key,
      severity: severity,
      onSeverityChanged: onSeverityChanged,
      onCleared: onCleared,
      careWorld: careWorld,
      enabled: enabled,
    );
  }

  static Widget outcome(
    CareOutcome outcome, {
    Key? key,
    double size = 36,
    bool showWord = true,
    bool selected = false,
    bool careWorld = false,
  }) {
    return OutcomeGlyph(
      key: key,
      outcome: outcome,
      size: size,
      showWord: showWord,
      selected: selected,
      careWorld: careWorld,
    );
  }
}

// ---------------------------------------------------------------------------
// Flow — one stable terracotta droplet with a bottom-anchored internal fill
// level: spotting = 18%, light = 42%, medium = 68%, heavy = full. The upper
// region is empty rather than a lighter tint, so amount is never encoded by
// hue, darkness, saturation, opacity, or droplet count. Observed bleeding
// color remains the separate swatch vocabulary below. Label always paired.
// ---------------------------------------------------------------------------

class FlowDegreeGlyph extends StatelessWidget {
  const FlowDegreeGlyph({
    super.key,
    required this.flow,
    this.size = 28,
    this.showWord = true,
    this.selected = false,
    this.careWorld = false,
  });

  final BleedingFlow flow;
  final double size;
  final bool showWord;
  final bool selected;
  final bool careWorld;

  @override
  Widget build(BuildContext context) {
    final glyph = SizedBox(
      width: size * 0.72,
      height: size,
      child: CustomPaint(painter: _FlowLevelPainter(flow: flow)),
    );
    return Semantics(
      label: DegreeGraphics.flowSemanticsLabel(flow),
      selected: selected,
      image: true,
      child: showWord
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                glyph,
                const SizedBox(width: ExperienceSpacing.xs * 2),
                Text(
                  flow.label,
                  style: selected
                      ? ExperienceType.label(
                          careWorld
                              ? ExperienceColors.careInk
                              : ExperienceColors.ink,
                        )
                      : ExperienceType.caption(
                          careWorld
                              ? ExperienceColors.careInkSoft
                              : ExperienceColors.inkSoft,
                        ),
                ),
              ],
            )
          : glyph,
    );
  }
}

final class _FlowLevelPainter extends CustomPainter {
  const _FlowLevelPainter({required this.flow});

  final BleedingFlow flow;

  /// The product's stable flow color, identical for every flow degree,
  /// including spotting, in both worlds.
  static const Color _terracotta = Color(0xFFC95D3A);

  static double _fillFraction(BleedingFlow flow) {
    return switch (flow) {
      BleedingFlow.spotting => 0.18,
      BleedingFlow.light => 0.42,
      BleedingFlow.medium => 0.68,
      BleedingFlow.heavy => 1.0,
    };
  }

  /// The soft teardrop silhouette established by the Today bleeding
  /// selector: it starts at the top center, curves to the lower center
  /// with a right control point at 110% width and 62% height, then returns
  /// to the top center with a left control point at -10% width and 62%
  /// height.
  static Path _dropPath({
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    final cx = left + width / 2;
    return Path()
      ..moveTo(cx, top)
      ..quadraticBezierTo(
        left + width * 1.1,
        top + height * 0.62,
        cx,
        top + height,
      )
      ..quadraticBezierTo(left - width * 0.1, top + height * 0.62, cx, top)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = math.max(1.2, size.height * 0.07);
    final dropHeight = size.height - strokeWidth;
    final dropWidth = math.min(size.width - strokeWidth, dropHeight * 0.72);
    final left = (size.width - dropWidth) / 2;
    final top = strokeWidth / 2;
    final drop = _dropPath(
      left: left,
      top: top,
      width: dropWidth,
      height: dropHeight,
    );
    final fillFraction = _fillFraction(flow);

    canvas.save();
    canvas.clipPath(drop);
    canvas.drawRect(
      Rect.fromLTRB(
        left,
        top + dropHeight * (1 - fillFraction),
        left + dropWidth,
        top + dropHeight,
      ),
      Paint()..color = _terracotta,
    );
    canvas.restore();

    canvas.drawPath(
      drop,
      Paint()
        ..color = _terracotta
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_FlowLevelPainter oldDelegate) {
    return oldDelegate.flow != flow;
  }
}

// ---------------------------------------------------------------------------
// Approved Today recording choices. These live here so Today and Cycle
// cannot drift into separate silhouettes, dimensions, colors, or selection
// treatments again.
// ---------------------------------------------------------------------------

class BleedingFlowChoice extends StatelessWidget {
  const BleedingFlowChoice({
    super.key,
    required this.flow,
    required this.selected,
    required this.onTap,
  });

  final BleedingFlow? flow;
  final bool selected;
  final VoidCallback onTap;

  static const Color _terra = Color(0xFFC95D3A);
  static const Color _terraDeep = Color(0xFFA8482C);
  static const Color _terraTint = Color(0xFFF6E4D8);
  static const Color _ink = Color(0xFF2A1626);
  static const Color _inkSoft = Color(0xFF6E675C);
  static const Color _hairline = Color(0xFFE7DFD0);

  @override
  Widget build(BuildContext context) {
    final label = flow?.label ?? 'None';
    return Semantics(
      button: true,
      selected: selected,
      label: flow == null
          ? 'Bleeding: None'
          : DegreeGraphics.flowSemanticsLabel(flow!),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? _terraTint : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _terra : _hairline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 20,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: flow == null
                      ? Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? _terra : _inkSoft,
                              width: 1.6,
                            ),
                          ),
                        )
                      : DegreeGraphics.flow(
                          flow!,
                          size: 20,
                          showWord: false,
                          selected: selected,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? _terraDeep : _ink,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BleedingColorChoice extends StatelessWidget {
  const BleedingColorChoice({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final BleedingColor color;
  final bool selected;
  final VoidCallback onTap;

  static const Color _terra = Color(0xFFC95D3A);
  static const Color _terraDeep = Color(0xFFA8482C);
  static const Color _inkSoft = Color(0xFF6E675C);

  @override
  Widget build(BuildContext context) {
    final fill = DegreeGraphics.bleedingColorFill(color);
    return Semantics(
      button: true,
      selected: selected,
      label: DegreeGraphics.bleedingColorSemanticsLabel(color),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 34,
              height: 34,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _terra : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: fill.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  color.label,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? _terraDeep : _inkSoft,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bleeding color — four patterned swatches (dot, solid, ring, diagonal
// hatch) so brown vs dark red never relies on hue.
// ---------------------------------------------------------------------------

class BleedingColorSwatch extends StatelessWidget {
  const BleedingColorSwatch({
    super.key,
    required this.color,
    this.size = 28,
    this.showWord = true,
    this.selected = false,
    this.careWorld = false,
  });

  final BleedingColor color;
  final double size;
  final bool showWord;
  final bool selected;
  final bool careWorld;

  @override
  Widget build(BuildContext context) {
    final glyph = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BleedingSwatchPainter(
          swatch: color,
          outlineColor: careWorld
              ? ExperienceColors.careGlassBorder
              : ExperienceColors.hairline,
          selectedOutline: careWorld
              ? ExperienceColors.emberSoft
              : ExperienceColors.ember,
          selected: selected,
        ),
      ),
    );
    return Semantics(
      label: DegreeGraphics.bleedingColorSemanticsLabel(color),
      selected: selected,
      image: true,
      child: showWord
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                glyph,
                const SizedBox(width: ExperienceSpacing.xs * 2),
                Text(
                  color.label,
                  style: selected
                      ? ExperienceType.label(
                          careWorld
                              ? ExperienceColors.careInk
                              : ExperienceColors.ink,
                        )
                      : ExperienceType.caption(
                          careWorld
                              ? ExperienceColors.careInkSoft
                              : ExperienceColors.inkSoft,
                        ),
                ),
              ],
            )
          : glyph,
    );
  }
}

final class _BleedingSwatchPainter extends CustomPainter {
  const _BleedingSwatchPainter({
    required this.swatch,
    required this.outlineColor,
    required this.selectedOutline,
    required this.selected,
  });

  final BleedingColor swatch;
  final Color outlineColor;
  final Color selectedOutline;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - (selected ? 3 : 1.5);
    final fill = DegreeGraphics.bleedingColorFill(swatch);

    if (selected) {
      canvas.drawCircle(
        center,
        size.shortestSide / 2 - 1,
        Paint()
          ..color = selectedOutline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(center, radius, Paint()..color = fill);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = selected ? Colors.white : outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2 : 1,
    );
  }

  @override
  bool shouldRepaint(_BleedingSwatchPainter oldDelegate) {
    return oldDelegate.swatch != swatch ||
        oldDelegate.outlineColor != outlineColor ||
        oldDelegate.selectedOutline != selectedOutline ||
        oldDelegate.selected != selected;
  }
}

// ---------------------------------------------------------------------------
// Severity — five-notch ascending bar glyph, exactly the five present
// degrees of SymptomSeverity. Distinguishable by count and weight, always
// paired with the word. There is no "not at all" degree.
// ---------------------------------------------------------------------------

class SeverityGlyph extends StatelessWidget {
  const SeverityGlyph({
    super.key,
    required this.severity,
    this.size = 28,
    this.showWord = true,
    this.selected = false,
    this.careWorld = false,
  });

  final SymptomSeverity severity;
  final double size;
  final bool showWord;
  final bool selected;
  final bool careWorld;

  @override
  Widget build(BuildContext context) {
    final glyph = SizedBox(
      width: size * 1.35,
      height: size,
      child: CustomPaint(
        painter: _SeverityBarsPainter(
          score: severity.score,
          filled: DegreeGraphics.severityRamp[severity.score - 1],
          empty: careWorld
              ? ExperienceColors.careGlassBorder
              : ExperienceColors.hairline,
        ),
      ),
    );
    return Semantics(
      label: DegreeGraphics.severitySemanticsLabel(severity),
      selected: selected,
      image: true,
      child: showWord
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                glyph,
                const SizedBox(width: ExperienceSpacing.xs * 2),
                Text(
                  severity.label,
                  style: selected
                      ? ExperienceType.label(
                          careWorld
                              ? ExperienceColors.careInk
                              : ExperienceColors.ink,
                        )
                      : ExperienceType.caption(
                          careWorld
                              ? ExperienceColors.careInkSoft
                              : ExperienceColors.inkSoft,
                        ),
                ),
              ],
            )
          : glyph,
    );
  }
}

final class _SeverityBarsPainter extends CustomPainter {
  const _SeverityBarsPainter({
    required this.score,
    required this.filled,
    required this.empty,
  });

  final int score;
  final Color filled;
  final Color empty;

  @override
  void paint(Canvas canvas, Size size) {
    const count = 5;
    final gap = size.width * 0.09;
    final barWidth = (size.width - gap * (count - 1)) / count;
    for (var i = 0; i < count; i++) {
      final fraction = 0.28 + 0.18 * i; // ascending heights
      final barHeight = size.height * fraction;
      final left = i * (barWidth + gap);
      final rect = Rect.fromLTWH(
        left,
        size.height - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barWidth * 0.45)),
        Paint()..color = i < score ? filled : empty,
      );
    }
  }

  @override
  bool shouldRepaint(_SeverityBarsPainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.filled != filled ||
        oldDelegate.empty != empty;
  }
}

// ---------------------------------------------------------------------------
// Pain — pain is recorded as pain symptoms (ObservationRecordingKind.pain)
// using the same five named SymptomSeverity degrees. This card composes the
// shared severity glyphs so the pain question reads as one question, never
// a numeric score.
// ---------------------------------------------------------------------------

/// The pain question as one card: the five shared severity degrees, chosen
/// or left unrecorded. Absence is simply not recording a degree.
class PainEntryCard extends StatelessWidget {
  const PainEntryCard({
    super.key,
    required this.severity,
    this.onSeverityChanged,
    this.onCleared,
    this.careWorld = false,
    this.enabled = true,
  });

  final SymptomSeverity? severity;
  final ValueChanged<SymptomSeverity>? onSeverityChanged;

  /// Clears the chosen degree at once — the honest "no pain to record"
  /// exit.
  final VoidCallback? onCleared;
  final bool careWorld;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ink = careWorld ? ExperienceColors.careInk : ExperienceColors.ink;
    final inkSoft = careWorld
        ? ExperienceColors.careInkSoft
        : ExperienceColors.inkSoft;

    final decoration = careWorld
        ? BoxDecoration(
            color: ExperienceColors.careGlass,
            borderRadius: ExperienceRadius.cardRadius,
            border: Border.all(color: ExperienceColors.careGlassBorder),
          )
        : BoxDecoration(
            color: ExperienceColors.surface,
            borderRadius: ExperienceRadius.cardRadius,
            border: Border.all(color: ExperienceColors.hairline),
            boxShadow: ExperienceShadows.card,
          );

    return Semantics(
      container: true,
      label:
          'Pain entry. One question: how strong it feels, in five degrees '
          'from Minimal to Extreme. Leaving it unrecorded means no pain.',
      child: Container(
        width: double.infinity,
        decoration: decoration,
        padding: const EdgeInsets.all(ExperienceSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Pain, if it is present', style: ExperienceType.headline(ink)),
            const SizedBox(height: ExperienceSpacing.xs),
            Text(
              'Choose the closest degree, or leave it unrecorded. '
              'Choosing the same degree again removes it.',
              style: ExperienceType.caption(inkSoft),
            ),
            const SizedBox(height: ExperienceSpacing.sm),
            Text('How strong it feels', style: ExperienceType.bodyStrong(ink)),
            const SizedBox(height: ExperienceSpacing.xs * 2),
            Wrap(
              spacing: ExperienceSpacing.xs * 2,
              runSpacing: ExperienceSpacing.xs * 2,
              children: <Widget>[
                for (final degree in DegreeGraphics.severityDegrees)
                  _PainSeverityOption(
                    degree: degree,
                    selected: severity == degree,
                    careWorld: careWorld,
                    enabled: enabled && onSeverityChanged != null,
                    onTap: () {
                      ExperienceHaptics.pick();
                      onSeverityChanged?.call(degree);
                    },
                  ),
              ],
            ),
            if (onCleared != null && severity != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: enabled ? onCleared : null,
                  child: const Text('Clear pain entry'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PainSeverityOption extends StatelessWidget {
  const _PainSeverityOption({
    required this.degree,
    required this.selected,
    required this.careWorld,
    required this.enabled,
    required this.onTap,
  });

  final SymptomSeverity degree;
  final bool selected;
  final bool careWorld;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? ExperienceColors.ember
        : (careWorld
              ? ExperienceColors.careGlassBorder
              : ExperienceColors.hairline);
    final background = selected
        ? (careWorld ? const Color(0x29FFFFFF) : ExperienceColors.surfaceWarm)
        : Colors.transparent;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: 'Pain, ${DegreeGraphics.severitySemanticsLabel(degree)}',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: ExperienceRadius.chipRadius,
        child: AnimatedContainer(
          duration: ExperienceMotion.chipSelect,
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.degreeTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(color: border, width: selected ? 1.5 : 1),
          ),
          child: DegreeGraphics.severity(
            degree,
            selected: selected,
            careWorld: careWorld,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Outcome — Better = ember brightened up-arc; Same = level line;
// Worse = softened down-arc. Each with its word; shape carries the meaning.
// ---------------------------------------------------------------------------

class OutcomeGlyph extends StatelessWidget {
  const OutcomeGlyph({
    super.key,
    required this.outcome,
    this.size = 36,
    this.showWord = true,
    this.selected = false,
    this.careWorld = false,
  });

  final CareOutcome outcome;
  final double size;
  final bool showWord;
  final bool selected;
  final bool careWorld;

  Color _color() {
    return switch (outcome) {
      CareOutcome.better =>
        careWorld ? ExperienceColors.emberBright : ExperienceColors.ember,
      CareOutcome.same =>
        careWorld ? ExperienceColors.careInkSoft : ExperienceColors.inkSoft,
      CareOutcome.worse =>
        careWorld ? ExperienceColors.careInkFaint : ExperienceColors.inkFaint,
    };
  }

  @override
  Widget build(BuildContext context) {
    final glyph = SizedBox(
      width: size * 1.6,
      height: size,
      child: CustomPaint(
        painter: _OutcomeArcPainter(outcome: outcome, color: _color()),
      ),
    );
    return Semantics(
      label: DegreeGraphics.outcomeSemanticsLabel(outcome),
      selected: selected,
      image: true,
      child: showWord
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                glyph,
                const SizedBox(height: ExperienceSpacing.xs),
                Text(
                  DegreeGraphics.outcomeLabel(outcome),
                  style: selected
                      ? ExperienceType.label(
                          careWorld
                              ? ExperienceColors.careInk
                              : ExperienceColors.ink,
                        )
                      : ExperienceType.caption(
                          careWorld
                              ? ExperienceColors.careInkSoft
                              : ExperienceColors.inkSoft,
                        ),
                ),
              ],
            )
          : glyph,
    );
  }
}

final class _OutcomeArcPainter extends CustomPainter {
  const _OutcomeArcPainter({required this.outcome, required this.color});

  final CareOutcome outcome;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.5, h * 0.12)
      ..strokeCap = StrokeCap.round;

    switch (outcome) {
      case CareOutcome.better:
        // Brightened up-arc: rises and ends high.
        final path = Path()
          ..moveTo(w * 0.06, h * 0.72)
          ..quadraticBezierTo(w * 0.5, -h * 0.22, w * 0.94, h * 0.3);
        canvas.drawPath(path, paint);
      case CareOutcome.same:
        // Level line.
        canvas.drawLine(
          Offset(w * 0.08, h * 0.5),
          Offset(w * 0.92, h * 0.5),
          paint,
        );
      case CareOutcome.worse:
        // Softened down-arc: sags and ends lower than it began.
        final path = Path()
          ..moveTo(w * 0.06, h * 0.28)
          ..quadraticBezierTo(w * 0.5, h * 1.18, w * 0.94, h * 0.66);
        canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_OutcomeArcPainter oldDelegate) {
    return oldDelegate.outcome != outcome || oldDelegate.color != color;
  }
}
