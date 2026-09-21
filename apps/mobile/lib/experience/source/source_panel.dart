import 'package:flutter/material.dart';

import '../../features/health_records/domain/health_record.dart';
import '../../features/patterns/domain/personal_pattern.dart';
import '../../features/summary_export/domain/cycle_care_summary.dart';
import '../theme/experience_foundation.dart';

/// One piece of evidence behind a ring position, chart mark, or pattern
/// claim. Provenance and source labels are rendered verbatim from
/// [HealthRecordProvenance] and summary source labels — nothing is inferred,
/// smoothed, or paraphrased.
final class SourcePanelEntry {
  const SourcePanelEntry({
    required this.title,
    required this.certainty,
    this.dateLabel,
    this.provenanceLabel,
    this.sourceLabel,
    this.details = const <String>[],
    this.onEdit,
  });

  /// What this record is (symptom label, action label, record kind).
  final String title;

  /// Observed / estimated / unknown — rendered with the shared texture
  /// system, never color alone.
  final ExperienceCertainty certainty;

  /// Plain date label ("5/31/2026") when the record is dated.
  final String? dateLabel;

  /// Verbatim provenance wording ("Same day", "Later recall",
  /// "Factual Care event").
  final String? provenanceLabel;

  /// Verbatim source wording ("User-confirmed health record · local only").
  final String? sourceLabel;

  /// Supporting factual lines (severity, functional impacts, cycle-day
  /// anchoring). Rendered as given.
  final List<String> details;

  /// Optional route into editing this exact record. The sheet closes first,
  /// then the route runs.
  final VoidCallback? onEdit;

  /// A confirmed health record, labeled with its own provenance.
  factory SourcePanelEntry.fromHealthRecord(
    HealthRecord record, {
    VoidCallback? onEdit,
  }) {
    final impacts = record.functionalImpacts.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return SourcePanelEntry(
      title: record.symptom.label,
      certainty: ExperienceCertainty.observed,
      dateLabel: summaryDateLabel(record.experiencedDate),
      provenanceLabel: record.provenance.label,
      sourceLabel: 'User-confirmed health record · local only',
      details: <String>[
        'Severity: ${record.severity.label}',
        if (impacts.isNotEmpty)
          'Affects: ${impacts.map((i) => i.label).join(', ')}',
      ],
      onEdit: onEdit,
    );
  }

  /// A health row exactly as a summary/export presents it — provenance and
  /// source labels pass through verbatim.
  factory SourcePanelEntry.fromSummaryHealthRow(
    SummaryHealthRow row, {
    VoidCallback? onEdit,
  }) {
    final impacts = row.functionalImpacts.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return SourcePanelEntry(
      title: row.symptom.label,
      certainty: ExperienceCertainty.observed,
      dateLabel: summaryDateLabel(row.date),
      provenanceLabel: row.provenance.label,
      sourceLabel: row.sourceLabel,
      details: <String>[
        'Severity: ${row.severity.label}',
        if (row.cycleDay != null) 'Cycle day ${row.cycleDay}',
        if (row.daysBeforeMenses != null)
          '${-row.daysBeforeMenses!} day'
              '${row.daysBeforeMenses == -1 ? '' : 's'} before the next period',
        if (impacts.isNotEmpty)
          'Affects: ${impacts.map((i) => i.label).join(', ')}',
      ],
      onEdit: onEdit,
    );
  }

  /// A saved Care event exactly as a summary/export presents it.
  factory SourcePanelEntry.fromSummaryCareRow(
    SummaryCareRow row, {
    VoidCallback? onEdit,
  }) {
    return SourcePanelEntry(
      title: row.actionLabel,
      certainty: ExperienceCertainty.observed,
      dateLabel: summaryDateLabel(row.date),
      provenanceLabel: row.provenance.label,
      sourceLabel: row.sourceLabel,
      details: <String>[if (row.cycleDay != null) 'Cycle day ${row.cycleDay}'],
      onEdit: onEdit,
    );
  }

  /// A pattern source reference — the record a pattern claim rests on.
  factory SourcePanelEntry.fromPatternSource(
    PatternSourceReference reference, {
    VoidCallback? onEdit,
  }) {
    final isCare = reference.kind == PatternSourceKind.careRecord;
    return SourcePanelEntry(
      title: isCare ? 'Care event' : 'Health record',
      certainty: ExperienceCertainty.observed,
      dateLabel: summaryDateLabel(reference.date),
      sourceLabel: isCare
          ? 'Saved Care event · local only'
          : 'User-confirmed health record · local only',
      onEdit: onEdit,
    );
  }
}

/// The shared source-inspection sheet.
///
/// Renders the records, provenance (same-day / later recall), certainty
/// texture, and evidence counts behind any ring position, chart mark, or
/// pattern claim, with routes to edit. Opened via [SourcePanel.show], which
/// uses the 28-radius sheet material with grab handle; in the Care world the
/// scrim never fully hides the world behind it. Fully traversable by screen
/// reader and keyboard.
final class SourcePanel extends StatelessWidget {
  const SourcePanel({
    super.key,
    required this.title,
    this.subtitle,
    this.entries = const <SourcePanelEntry>[],
    this.certainty = ExperienceCertainty.observed,
    this.careWorld = false,
  });

  /// What is being inspected ("What's behind day 9", "Behind this mark").
  final String title;

  /// Optional meaning line — e.g. what is observed, what is estimated, and
  /// from which records. Rendered verbatim; the panel never composes
  /// estimates itself.
  final String? subtitle;

  /// The evidence behind the inspected mark. May be empty — the panel then
  /// renders an honest empty state rather than implying missing data.
  final List<SourcePanelEntry> entries;

  /// The certainty of the inspected mark itself (a ring segment may be
  /// estimated while the records behind it are observed).
  final ExperienceCertainty certainty;

  /// Plum-glass material in the Care world; behavior is identical.
  final bool careWorld;

  /// Opens the inspection sheet.
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    List<SourcePanelEntry> entries = const <SourcePanelEntry>[],
    ExperienceCertainty certainty = ExperienceCertainty.observed,
    bool careWorld = false,
  }) {
    return showExperienceSheet<void>(
      context,
      careWorld: careWorld,
      child: SourcePanel(
        title: title,
        subtitle: subtitle,
        entries: entries,
        certainty: certainty,
        careWorld: careWorld,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = careWorld ? ExperienceColors.careInk : ExperienceColors.ink;
    final inkSoft = careWorld
        ? ExperienceColors.careInkSoft
        : ExperienceColors.inkSoft;
    final hairline = careWorld
        ? ExperienceColors.careGlassBorder
        : ExperienceColors.hairline;

    return FocusTraversalGroup(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          ExperienceSpacing.screenMargin,
          0,
          ExperienceSpacing.screenMargin,
          ExperienceSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(title, style: ExperienceType.headline(ink)),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: ExperienceSpacing.xs + 4),
              Text(subtitle!, style: ExperienceType.bodySmall(inkSoft)),
            ],
            const SizedBox(height: ExperienceSpacing.sm),
            _MarkCertaintyLine(certainty: certainty, careWorld: careWorld),
            const SizedBox(height: ExperienceSpacing.sm),
            Divider(color: hairline, height: 1),
            const SizedBox(height: ExperienceSpacing.sm),
            const _CertaintyLegend(),
            const SizedBox(height: ExperienceSpacing.sm),
            Divider(color: hairline, height: 1),
            const SizedBox(height: ExperienceSpacing.sm),
            if (entries.isEmpty)
              _EmptyEvidence(careWorld: careWorld)
            else ...<Widget>[
              _EvidenceCountLine(count: entries.length, careWorld: careWorld),
              const SizedBox(height: ExperienceSpacing.xs + 4),
              for (var i = 0; i < entries.length; i++) ...<Widget>[
                _EntryCard(entry: entries[i], careWorld: careWorld),
                if (i < entries.length - 1)
                  const SizedBox(height: ExperienceSpacing.xs + 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mark certainty
// ---------------------------------------------------------------------------

/// States the inspected mark's own certainty in words plus texture.
class _MarkCertaintyLine extends StatelessWidget {
  const _MarkCertaintyLine({required this.certainty, required this.careWorld});

  final ExperienceCertainty certainty;
  final bool careWorld;

  @override
  Widget build(BuildContext context) {
    final inkSoft = careWorld
        ? ExperienceColors.careInkSoft
        : ExperienceColors.inkSoft;
    final texture = CertaintyTexture.of(certainty);
    final wording = switch (certainty) {
      ExperienceCertainty.observed =>
        'This mark is observed — '
            'it comes from something you recorded.',
      ExperienceCertainty.estimated =>
        'This mark is estimated — '
            'a labeled estimate from your recorded history.',
      ExperienceCertainty.unknown =>
        'Nothing is recorded here — '
            'blank means missing, never zero.',
    };
    return Semantics(
      label: '${CertaintyTexture.semanticsLabel(certainty)}. $wording',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: CertaintySwatch(certainty: certainty, careWorld: careWorld),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texture.caption == null
                  ? wording
                  : '$wording (${texture.caption})',
              style: ExperienceType.caption(inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Certainty legend — observed solid, estimated dashed + est., missing dots.
// ---------------------------------------------------------------------------

class _CertaintyLegend extends StatelessWidget {
  const _CertaintyLegend();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'How to read marks: Observed marks are solid. Estimated marks '
          'are dashed and labeled estimate. Missing marks are empty with '
          'faint dots.',
      child: const Wrap(
        spacing: ExperienceSpacing.sm,
        runSpacing: ExperienceSpacing.xs + 4,
        children: <Widget>[
          _LegendItem(
            certainty: ExperienceCertainty.observed,
            label: 'Observed',
          ),
          _LegendItem(
            certainty: ExperienceCertainty.estimated,
            label: 'Estimated',
          ),
          _LegendItem(certainty: ExperienceCertainty.unknown, label: 'Missing'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.certainty, required this.label});

  final ExperienceCertainty certainty;
  final String label;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final careWorld = brightness == Brightness.dark;
    final inkSoft = careWorld
        ? ExperienceColors.careInkSoft
        : ExperienceColors.inkSoft;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CertaintySwatch(certainty: certainty, careWorld: careWorld),
        const SizedBox(width: 6),
        Text(label, style: ExperienceType.caption(inkSoft)),
      ],
    );
  }
}

/// The shared certainty mark: observed = solid fill + solid border;
/// estimated = reduced-opacity fill + dashed border; unknown = empty outline
/// with a faint dot grid. Identical texture recipe everywhere in the system.
class CertaintySwatch extends StatelessWidget {
  const CertaintySwatch({
    super.key,
    required this.certainty,
    this.careWorld = false,
    this.size = 18,
    this.color,
  });

  final ExperienceCertainty certainty;
  final bool careWorld;
  final double size;

  /// Accent color for the mark; defaults to the world ink so the swatch
  /// reads as a texture key rather than a chart accent.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final texture = CertaintyTexture.of(certainty);
    final base =
        color ??
        (careWorld ? ExperienceColors.careInkSoft : ExperienceColors.inkSoft);
    final hairline = careWorld
        ? ExperienceColors.careGlassBorder
        : ExperienceColors.hairline;

    final Widget visual = switch (certainty) {
      ExperienceCertainty.observed => Container(
        decoration: BoxDecoration(
          color: base.withValues(alpha: texture.fillOpacity),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: base.withValues(alpha: texture.borderOpacity),
            width: 1.5,
          ),
        ),
      ),
      ExperienceCertainty.estimated => CustomPaint(
        painter: _DashedSwatchPainter(color: base, texture: texture),
      ),
      ExperienceCertainty.unknown => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: base.withValues(alpha: texture.borderOpacity),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CustomPaint(
            painter: DotGridPainter(
              color: careWorld ? ExperienceColors.careInkFaint : hairline,
              spacing: 5,
              dotRadius: 0.8,
            ),
          ),
        ),
      ),
    };

    return ExcludeSemantics(
      child: SizedBox(width: size, height: size, child: visual),
    );
  }
}

class _DashedSwatchPainter extends CustomPainter {
  const _DashedSwatchPainter({required this.color, required this.texture});

  final Color color;
  final CertaintyTexture texture;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.75),
      const Radius.circular(5),
    );
    if (texture.fillOpacity > 0) {
      canvas.drawRRect(
        rrect,
        Paint()..color = color.withValues(alpha: texture.fillOpacity),
      );
    }
    final borderPaint = Paint()
      ..color = color.withValues(alpha: texture.borderOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(rrect);
    final dash = texture.dashPattern;
    if (dash == null) {
      canvas.drawPath(path, borderPaint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      var index = 0;
      while (distance < metric.length) {
        final length = dash[index % dash.length];
        if (draw) {
          canvas.drawPath(
            metric.extractPath(distance, distance + length),
            borderPaint,
          );
        }
        distance += length;
        draw = !draw;
        index++;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedSwatchPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.texture != texture;
  }
}

// ---------------------------------------------------------------------------
// Evidence
// ---------------------------------------------------------------------------

class _EvidenceCountLine extends StatelessWidget {
  const _EvidenceCountLine({required this.count, required this.careWorld});

  final int count;
  final bool careWorld;

  @override
  Widget build(BuildContext context) {
    final ink = careWorld ? ExperienceColors.careInk : ExperienceColors.ink;
    final inkSoft = careWorld
        ? ExperienceColors.careInkSoft
        : ExperienceColors.inkSoft;
    final noun = count == 1 ? 'record' : 'records';
    return Semantics(
      label: '$count $noun behind this',
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(text: '$count', style: ExperienceType.data(ink)),
            TextSpan(
              text: ' $noun behind this',
              style: ExperienceType.bodySmall(inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.careWorld});

  final SourcePanelEntry entry;
  final bool careWorld;

  String get _semanticsLabel {
    final parts = <String>[
      entry.title,
      if (entry.dateLabel != null) entry.dateLabel!,
      CertaintyTexture.semanticsLabel(entry.certainty),
      if (entry.provenanceLabel != null) 'Recorded: ${entry.provenanceLabel}',
      ...entry.details,
      if (entry.sourceLabel != null) 'Source: ${entry.sourceLabel}',
    ];
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final ink = careWorld ? ExperienceColors.careInk : ExperienceColors.ink;
    final inkSoft = careWorld
        ? ExperienceColors.careInkSoft
        : ExperienceColors.inkSoft;
    final hairline = careWorld
        ? ExperienceColors.careGlassBorder
        : ExperienceColors.hairline;
    final cardColor = careWorld
        ? ExperienceColors.careGlass
        : ExperienceColors.surface;

    return Semantics(
      container: true,
      label: _semanticsLabel,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: ExperienceRadius.cardRadius,
          border: Border.all(color: hairline),
          boxShadow: careWorld ? null : ExperienceShadows.card,
        ),
        padding: const EdgeInsets.all(ExperienceSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    entry.title,
                    style: ExperienceType.bodyStrong(ink),
                  ),
                ),
                const SizedBox(width: ExperienceSpacing.xs + 4),
                CertaintySwatch(
                  certainty: entry.certainty,
                  careWorld: careWorld,
                ),
              ],
            ),
            if (entry.dateLabel != null ||
                entry.provenanceLabel != null) ...<Widget>[
              const SizedBox(height: ExperienceSpacing.xs + 4),
              Wrap(
                spacing: ExperienceSpacing.xs + 4,
                runSpacing: ExperienceSpacing.xs,
                children: <Widget>[
                  if (entry.dateLabel != null)
                    _MetaChip(
                      label: entry.dateLabel!,
                      semanticsPrefix: 'Date',
                      careWorld: careWorld,
                    ),
                  if (entry.provenanceLabel != null)
                    _MetaChip(
                      label: entry.provenanceLabel!,
                      semanticsPrefix: 'Recorded',
                      careWorld: careWorld,
                    ),
                ],
              ),
            ],
            if (entry.details.isNotEmpty) ...<Widget>[
              const SizedBox(height: ExperienceSpacing.xs + 4),
              for (final detail in entry.details)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: inkSoft,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          detail,
                          style: ExperienceType.bodySmall(ink),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (entry.sourceLabel != null) ...<Widget>[
              const SizedBox(height: ExperienceSpacing.xs + 4),
              Text(entry.sourceLabel!, style: ExperienceType.caption(inkSoft)),
            ],
            if (entry.onEdit != null) ...<Widget>[
              const SizedBox(height: ExperienceSpacing.xs + 4),
              Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  button: true,
                  label: 'Edit ${entry.title}',
                  child: InkWell(
                    borderRadius: ExperienceRadius.chipRadius,
                    onTap: () {
                      Navigator.of(context).pop();
                      entry.onEdit!();
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: ExperienceSpacing.minTouchTarget,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ExperienceSpacing.xs + 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: ExperienceColors.ember,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Edit this record',
                              style: ExperienceType.label(
                                ExperienceColors.ember,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.semanticsPrefix,
    required this.careWorld,
  });

  final String label;
  final String semanticsPrefix;
  final bool careWorld;

  @override
  Widget build(BuildContext context) {
    final inkSoft = careWorld
        ? ExperienceColors.careInkSoft
        : ExperienceColors.inkSoft;
    final hairline = careWorld
        ? ExperienceColors.careGlassBorder
        : ExperienceColors.hairline;
    return Semantics(
      label: '$semanticsPrefix: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: ExperienceRadius.chipRadius,
          border: Border.all(color: hairline),
        ),
        child: Text(label, style: ExperienceType.caption(inkSoft)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state — honest, never implying missing data is an error.
// ---------------------------------------------------------------------------

class _EmptyEvidence extends StatelessWidget {
  const _EmptyEvidence({required this.careWorld});

  final bool careWorld;

  @override
  Widget build(BuildContext context) {
    final ink = careWorld ? ExperienceColors.careInk : ExperienceColors.ink;
    final inkSoft = careWorld
        ? ExperienceColors.careInkSoft
        : ExperienceColors.inkSoft;
    return Semantics(
      label:
          'No records behind this yet. Records you save will appear here '
          'with how and when they were recorded.',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.md),
        child: Column(
          children: <Widget>[
            CertaintySwatch(
              certainty: ExperienceCertainty.unknown,
              careWorld: careWorld,
              size: 40,
            ),
            const SizedBox(height: ExperienceSpacing.xs + 8),
            Text(
              'No records behind this yet.',
              style: ExperienceType.bodyStrong(ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ExperienceSpacing.xs),
            Text(
              'Records you save will appear here with how and when '
              'they were recorded.',
              style: ExperienceType.bodySmall(inkSoft),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
