import 'package:flutter/material.dart';

import 'letter_theme.dart';

/// Approved Lovable card, copied without visual reinterpretation.
class LetterCard extends StatelessWidget {
  const LetterCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(LetterTokens.s16),
    this.dashed = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dashed ? LetterTokens.tealSoft : LetterTokens.surface,
        borderRadius: LetterTokens.brSurface,
        border: Border.all(color: LetterTokens.line),
      ),
      child: child,
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    super.key,
    this.onPressed,
    this.expand = false,
    this.semanticHint,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final child = AnimatedContainer(
      duration: context.lovableMotion(LetterTokens.durBase),
      curve: LetterTokens.ease,
      constraints: const BoxConstraints(
        minHeight: LetterTokens.tapTarget,
        minWidth: LetterTokens.tapTarget,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: LetterTokens.s20,
        vertical: LetterTokens.s12,
      ),
      decoration: BoxDecoration(
        color: disabled ? LetterTokens.canvas : LetterTokens.teal,
        borderRadius: LetterTokens.brControl,
        border: Border.all(
          color: disabled ? LetterTokens.line : LetterTokens.tealDark,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: letterBody(
          size: 14,
          weight: FontWeight.w500,
          color: disabled ? LetterTokens.muted : LetterTokens.surface,
          height: 1.3,
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: !disabled,
      hint: semanticHint,
      child: InkWell(
        onTap: onPressed,
        borderRadius: LetterTokens.brControl,
        child: expand ? SizedBox(width: double.infinity, child: child) : child,
      ),
    );
  }
}

class ProvenanceTag extends StatelessWidget {
  const ProvenanceTag({required this.observed, super.key});

  final bool observed;

  @override
  Widget build(BuildContext context) {
    final color = observed ? LetterTokens.teal : LetterColors.clinicalBlue;
    return Semantics(
      label: observed
          ? 'Observed, recorded by you'
          : 'Estimated, calculated from dates',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LetterTokens.s8,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: observed
              ? color.withValues(alpha: 0.10)
              : LetterTokens.surface,
          borderRadius: LetterTokens.brControl,
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (observed)
              Container(width: 8, height: 8, color: color)
            else
              SizedBox(
                width: 10,
                height: 8,
                child: Row(
                  children: [
                    for (var index = 0; index < 3; index++)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 1),
                          height: 2,
                          color: color,
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(width: LetterTokens.s4),
            Text(
              observed ? 'OBSERVED' : 'ESTIMATED',
              style: letterEyebrow(color: color).copyWith(
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LetterDataRow extends StatelessWidget {
  const LetterDataRow({
    required this.term,
    required this.value,
    super.key,
    this.observed,
    this.last = false,
    this.horizontalPadding = LetterTokens.gutter,
  });

  final String term;
  final String value;
  final bool? observed;
  final bool last;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final stacked = context.isLovableNarrow || context.isLovableLargeText;
    final termText = Text(
      term,
      style: letterBody(size: 14, color: LetterTokens.muted),
    );
    final valueText = Text(
      value,
      textAlign: stacked ? TextAlign.start : TextAlign.end,
      style: letterBody(size: 14.5, weight: FontWeight.w500, height: 1.4),
    );
    final tag = observed == null
        ? const SizedBox.shrink()
        : Padding(
            padding: EdgeInsets.only(
              right: stacked ? 0 : LetterTokens.s8,
              bottom: stacked ? LetterTokens.s4 : 0,
            ),
            child: ProvenanceTag(observed: observed!),
          );
    return Semantics(
      label:
          '$term: $value${observed == null
              ? ''
              : observed!
              ? ', observed'
              : ', estimated'}',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: LetterTokens.hairline),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: LetterTokens.s12,
        ),
        constraints: const BoxConstraints(minHeight: LetterTokens.tapTarget),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  termText,
                  const SizedBox(height: LetterTokens.s4),
                  if (observed != null) tag,
                  valueText,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: termText),
                  if (observed != null) tag,
                  Expanded(flex: 5, child: valueText),
                ],
              ),
      ),
    );
  }
}

enum LegendShape { solidLine, dashedLine, hatchedBlock, verticalRule }

class LegendRow extends StatelessWidget {
  const LegendRow({required this.items, super.key});

  final List<({LegendShape shape, Color color, String label})> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: LetterTokens.s16,
      runSpacing: LetterTokens.s8,
      children: [
        for (final item in items)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: _LegendGlyph(shape: item.shape, color: item.color),
                ),
                const SizedBox(width: LetterTokens.s8),
                Flexible(
                  child: Text(item.label, style: letterHelper(size: 12.5)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LegendGlyph extends StatelessWidget {
  const _LegendGlyph({required this.shape, required this.color});

  final LegendShape shape;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (shape) {
      case LegendShape.solidLine:
        return Container(width: 22, height: 3, color: color);
      case LegendShape.dashedLine:
        return SizedBox(
          width: 22,
          height: 3,
          child: Row(
            children: [
              for (var index = 0; index < 3; index++)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 3),
                    color: color,
                  ),
                ),
            ],
          ),
        );
      case LegendShape.hatchedBlock:
        return Container(
          width: 22,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            border: Border.all(color: color),
          ),
          child: CustomPaint(painter: _HatchPainter(color)),
        );
      case LegendShape.verticalRule:
        return Container(width: 2, height: 14, color: color);
    }
  }
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 5) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HatchPainter oldDelegate) =>
      oldDelegate.color != color;
}

class ConfidenceLine extends StatelessWidget {
  const ConfidenceLine({
    required this.confidence,
    required this.evidence,
    super.key,
  });

  final String confidence;
  final String evidence;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Confidence: $confidence',
            style: letterBody(size: 13, weight: FontWeight.w600),
          ),
          TextSpan(text: ' — $evidence', style: letterHelper(size: 13)),
        ],
      ),
    );
  }
}

class ActivityRow extends StatelessWidget {
  const ActivityRow({
    required this.kindLabel,
    required this.time,
    required this.title,
    super.key,
    this.detail,
    this.last = false,
  });

  final String kindLabel;
  final String time;
  final String title;
  final String? detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: LetterTokens.hairline),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: LetterTokens.gutter,
        vertical: LetterTokens.s12,
      ),
      constraints: const BoxConstraints(minHeight: LetterTokens.tapTarget),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: LetterTokens.s8,
            runSpacing: LetterTokens.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: LetterTokens.s8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: LetterTokens.tealSoft,
                  borderRadius: LetterTokens.brControl,
                ),
                child: Text(
                  kindLabel.toUpperCase(),
                  style: letterEyebrow(color: LetterTokens.teal),
                ),
              ),
              Text(time, style: letterHelper(size: 12)),
            ],
          ),
          const SizedBox(height: LetterTokens.s8),
          Text(title, style: letterBody(size: 14, weight: FontWeight.w500)),
          if (detail != null) ...[
            const SizedBox(height: LetterTokens.s4),
            Text(detail!, style: letterHelper(size: 12.5)),
          ],
        ],
      ),
    );
  }
}
