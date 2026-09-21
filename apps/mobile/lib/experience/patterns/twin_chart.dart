import 'package:flutter/material.dart';

import '../../features/clinical/presentation/twin_matrix_view_model.dart';
import '../../features/health_records/domain/health_record.dart';
import '../../features/summary_export/domain/cycle_care_summary.dart';
import '../degree/degree_graphics.dart';
import '../source/source_panel.dart';
import '../theme/experience_foundation.dart';

/// Twin — the two-window comparison matrix (premium depth, free structural
/// preview).
///
/// The left window holds observed days −14…−1 before a subsequent observed
/// period start; the right window holds observed cycle days 1…14. This chart
/// renders [TwinMatrixViewModel] exactly as given:
///
///  * Null cells stay blank (empty outline + faint dot grid). Nothing is
///    inferred, smoothed, or carried across either axis.
///  * [TwinMatrixViewModel.accessibilitySummary] is exposed verbatim to
///    screen readers, and every cell individually exposes its value, day,
///    certainty, and evidence count.
///  * Cluster labels and scanability grouping come from
///    [TwinMatrixViewModel.clusterMap]; grouping never merges cell evidence.
///  * The locked (no-premium) state shows evidence readiness and a full
///    structural skeleton — never blurred, fabricated charts.
///
/// Disclosure order follows the shared chart grammar: plain-language
/// takeaway → chart → evidence. Twin's family accent is
/// [ExperienceColors.accentTwin]; it renders at full saturation only while
/// [expanded] and steps down one weight otherwise, so chart families never
/// compete in one viewport. Ember coral is never used as a chart accent.
final class TwinChart extends StatefulWidget {
  const TwinChart({
    super.key,
    required this.viewModel,
    this.isLoading = false,
    this.hasPremiumAccess = true,
    this.cyclesNeeded = 2,
    this.expanded = true,
    this.takeaway,
    this.onOpenPlus,
    this.onEditRecord,
    this.onRecordObservation,
  });

  /// The matrix to render. Null while [isLoading] (dot-grid skeleton) or
  /// when no records exist yet (structural preview with named next action).
  final TwinMatrixViewModel? viewModel;

  /// True while the repository computes. Twin over many records renders its
  /// own dot-grid chart skeleton — never a bare spinner over white.
  final bool isLoading;

  /// Premium depth gate. When false the chart renders the free structural
  /// preview: skeleton, evidence readiness, and a quiet Plus route.
  final bool hasPremiumAccess;

  /// How many recorded cycles Twin needs before its comparison carries
  /// weight. Drives the locked-state readiness line; derived, never
  /// hard-coded in copy elsewhere.
  final int cyclesNeeded;

  /// Accent hierarchy rule: only the expanded family renders at full
  /// saturation; collapsed sections step down one weight.
  final bool expanded;

  /// Serif takeaway rendered above the chart. Numeral-free by design rule;
  /// numerals in data contexts below are always sans tabular figures.
  final String? takeaway;

  /// Route to the Plus experience from the locked state.
  final VoidCallback? onOpenPlus;

  /// Route to edit a specific record from the SourcePanel.
  final ValueChanged<String>? onEditRecord;

  /// The named next action in the empty state (Today quick logging).
  final VoidCallback? onRecordObservation;

  /// Days in each window: −14…−1 and 1…14.
  static const int windowDays = 14;

  /// Day columns across both windows (14 + 14).
  static const int windowColumns = windowDays * 2;

  static const String _defaultTakeaway =
      'The days before bleeding, beside the days after it begins.';

  @override
  State<TwinChart> createState() => _TwinChartState();
}

class _TwinChartState extends State<TwinChart>
    with SingleTickerProviderStateMixin {
  /// First-paint draw-on (600 ms), fired once per appearance. Data updates
  /// crossfade; nothing loops. Under the platform reduced-motion setting the
  /// draw-on is skipped and the chart appears settled.
  late final AnimationController _drawOn = AnimationController(
    vsync: this,
    duration: ExperienceMotion.chartDrawOn,
  );
  bool _drawOnStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_drawOnStarted) return;
    _drawOnStarted = true;
    if (ExperienceMotion.reducedMotion(context)) {
      _drawOn.value = 1;
    } else {
      _drawOn.forward();
    }
  }

  @override
  void dispose() {
    _drawOn.dispose();
    super.dispose();
  }

  /// Row reveal for the draw-on: later rows fade in slightly after earlier
  /// ones. Settled (1) once the draw-on completes, under reduced motion, and
  /// for structural previews.
  double _reveal(int row, int totalRows) {
    if (widget.viewModel == null) return 1;
    final value = _drawOn.value;
    if (value >= 1) return 1;
    final begin = 0.55 * (row / totalRows);
    const span = 0.45;
    final t = ((value - begin) / span).clamp(0.0, 1.0);
    return Curves.easeOut.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final locked = !widget.hasPremiumAccess;
    final loading = widget.isLoading && vm == null;
    final accent = widget.expanded
        ? ExperienceColors.accentTwin
        : ExperienceColors.accentTwin.withValues(alpha: 0.45);

    // The compact text alternative is exposed verbatim whenever the matrix
    // exists; cells beneath it keep their own per-mark semantics.
    final summary = locked
        ? 'Twin, two-window comparison. Structural preview. Twin places the '
              'two weeks before your period beside the first two weeks of your '
              'cycle, cell by cell, once Plus depth is active.'
        : vm?.accessibilitySummary ??
              (loading
                  ? 'Twin, two-window comparison. Loading.'
                  : 'Twin, two-window comparison. No records map to these '
                        'windows yet.');

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: summary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.takeaway ?? TwinChart._defaultTakeaway,
            style: ExperienceType.title(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          if (locked) ...<Widget>[
            _LockedTwinCard(
              cyclesCovered: vm?.cyclesCovered ?? 0,
              cyclesNeeded: widget.cyclesNeeded < 1 ? 1 : widget.cyclesNeeded,
              accent: accent,
              onOpenPlus: widget.onOpenPlus,
            ),
            const SizedBox(height: ExperienceSpacing.sm),
            _buildMatrix(context, accent),
          ] else if (loading)
            _buildMatrix(context, accent, showPreparing: true)
          else ...<Widget>[
            AnimatedBuilder(
              animation: _drawOn,
              builder: (context, _) => _buildMatrix(context, accent),
            ),
            const SizedBox(height: ExperienceSpacing.sm),
            if (vm != null) _TwinEvidenceLine(viewModel: vm),
            if (vm == null || vm.mappedObservations == 0) ...<Widget>[
              const SizedBox(height: ExperienceSpacing.xs + 4),
              _TwinGuidanceCard(onRecord: widget.onRecordObservation),
            ],
          ],
          const SizedBox(height: ExperienceSpacing.sm),
          _TwinLegend(accent: accent),
        ],
      ),
    );
  }

  // --- Matrix --------------------------------------------------------------

  Widget _buildMatrix(
    BuildContext context,
    Color accent, {
    bool showPreparing = false,
  }) {
    final vm = widget.viewModel;
    final clusterLabels = TwinMatrixViewModel.clusterMap;
    final clusterCount = vm?.clusters.length ?? clusterLabels.length;
    final totalRows = clusterCount * 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showPreparing)
          Padding(
            padding: const EdgeInsets.only(bottom: ExperienceSpacing.xs + 4),
            child: Semantics(
              liveRegion: true,
              label: 'Twin is loading',
              child: Text(
                'Preparing the two windows…',
                style: ExperienceType.caption(ExperienceColors.inkSoft),
              ),
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var i = 0; i < clusterCount; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: ExperienceSpacing.md),
                _TwinClusterSection(
                  label: vm == null
                      ? (clusterLabels[i + 1] ?? 'Cluster ${i + 1}')
                      : (clusterLabels[i + 1] ?? vm.clusters[i].label),
                  observedSummary: vm == null
                      ? null
                      : _observedSummary(vm.clusters[i]),
                  beforeRow: _TwinWindowRow(
                    axisLabel: 'Days before your period · 14 → 1',
                    cells: vm?.clusters[i].beforePeriodCells,
                    beforePeriodWindow: true,
                    accent: accent,
                    reveal: _reveal(2 * i, totalRows),
                    onCellOpen: vm == null
                        ? null
                        : (index) => _openCell(
                            context,
                            vm.clusters[i],
                            vm.clusters[i].beforePeriodCells[index],
                            'day ${TwinChart.windowDays - index} '
                            'before your period',
                          ),
                  ),
                  cycleRow: _TwinWindowRow(
                    axisLabel: 'Cycle days · 1 → 14',
                    cells: vm?.clusters[i].cycleCells,
                    beforePeriodWindow: false,
                    accent: accent,
                    reveal: _reveal(2 * i + 1, totalRows),
                    todayDay: vm?.todayDay,
                    onCellOpen: vm == null
                        ? null
                        : (index) => _openCell(
                            context,
                            vm.clusters[i],
                            vm.clusters[i].cycleCells[index],
                            'cycle day ${index + 1}',
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _observedSummary(TwinMatrixCluster cluster) {
    var observed = 0;
    for (final cell in cluster.beforePeriodCells) {
      if (cell.severity != null) observed++;
    }
    for (final cell in cluster.cycleCells) {
      if (cell.severity != null) observed++;
    }
    return '$observed of ${TwinChart.windowColumns} day columns hold records';
  }

  // --- Source inspection ---------------------------------------------------

  /// Tap or keyboard activation on any mark — including a blank — opens the
  /// shared source-inspection sheet with provenance and a route to edit.
  void _openCell(
    BuildContext context,
    TwinMatrixCluster cluster,
    TwinMatrixCell cell,
    String dayLabel,
  ) {
    final valued = cell.severity != null;
    SourcePanel.show(
      context,
      title: 'Behind $dayLabel',
      subtitle: valued
          ? '${cluster.label} — average '
                '${cell.severity!.toStringAsFixed(1)} of 5 from '
                '${cell.observationCount} ratings across ${cell.cycleCount} '
                '${cell.cycleCount == 1 ? 'cycle' : 'cycles'}. '
                'Nothing is inferred from the other window.'
          : '${cluster.label} — nothing is recorded for this day. '
                'Blank means missing, never zero.',
      certainty: valued
          ? ExperienceCertainty.observed
          : ExperienceCertainty.unknown,
      entries: <SourcePanelEntry>[
        for (final evidence in cell.evidence)
          SourcePanelEntry(
            title: evidence.symptom.label,
            certainty: ExperienceCertainty.observed,
            dateLabel: summaryDateLabel(evidence.experiencedDate),
            provenanceLabel: evidence.provenance.label,
            sourceLabel: 'User-confirmed health record · local only',
            details: <String>[
              'Severity: ${evidence.severity.label}',
              if (evidence.functionalImpacts.isNotEmpty)
                'Affects: ${(evidence.functionalImpacts.toList()..sort((a, b) => a.index.compareTo(b.index))).map((impact) => impact.label).join(', ')}',
            ],
            onEdit: widget.onEditRecord == null
                ? null
                : () => widget.onEditRecord!(evidence.recordId),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cluster section — scanability grouping only; each cell retains its
// evidence. Labels come from TwinMatrixViewModel.clusterMap.
// ---------------------------------------------------------------------------

class _TwinClusterSection extends StatelessWidget {
  const _TwinClusterSection({
    required this.label,
    required this.observedSummary,
    required this.beforeRow,
    required this.cycleRow,
  });

  final String label;
  final String? observedSummary;
  final Widget beforeRow;
  final Widget cycleRow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Wrap(
            spacing: ExperienceSpacing.xs * 2,
            runSpacing: ExperienceSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                label,
                style: ExperienceType.bodyStrong(ExperienceColors.ink),
              ),
              if (observedSummary != null)
                Text(
                  observedSummary!,
                  style: ExperienceType.caption(ExperienceColors.inkSoft),
                ),
            ],
          ),
        ),
        const SizedBox(height: ExperienceSpacing.xs + 4),
        beforeRow,
        const SizedBox(height: ExperienceSpacing.xs + 4),
        cycleRow,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Window row — one axis (before-period or cycle days) of 14 cells.
// ---------------------------------------------------------------------------

class _TwinWindowRow extends StatelessWidget {
  const _TwinWindowRow({
    required this.axisLabel,
    required this.cells,
    required this.beforePeriodWindow,
    required this.accent,
    required this.reveal,
    this.todayDay,
    this.onCellOpen,
  });

  final String axisLabel;

  /// Null renders the structural-preview skeleton (dot-grid blanks).
  final List<TwinMatrixCell>? cells;
  final bool beforePeriodWindow;
  final Color accent;
  final double reveal;
  final int? todayDay;
  final ValueChanged<int>? onCellOpen;

  @override
  Widget build(BuildContext context) {
    const count = TwinChart.windowDays;
    return Opacity(
      opacity: reveal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            // Constrained so axis labels re-flow under large text instead of
            // stretching the scroll width without bound.
            width: 240,
            child: Text(
              axisLabel,
              style: ExperienceType.caption(
                ExperienceColors.inkSoft,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var i = 0; i < count; i++)
                _TwinCell(
                  dayNumber: beforePeriodWindow ? '${count - i}' : '${i + 1}',
                  daySemantics: beforePeriodWindow
                      ? 'Day ${count - i} before your period'
                      : 'Cycle day ${i + 1}',
                  cell: cells == null ? null : cells![i],
                  accent: accent,
                  isToday: !beforePeriodWindow && todayDay == i + 1,
                  onOpenSource: cells == null || onCellOpen == null
                      ? null
                      : () => onCellOpen!(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cell — observed (solid border + severity notches) or blank (dot grid).
// Blank cells are still inspectable: the SourcePanel states honestly that
// nothing is recorded. Never color alone; the notch count carries degree.
// ---------------------------------------------------------------------------

class _TwinCell extends StatelessWidget {
  const _TwinCell({
    required this.dayNumber,
    required this.daySemantics,
    required this.cell,
    required this.accent,
    required this.isToday,
    this.onOpenSource,
  });

  final String dayNumber;
  final String daySemantics;

  /// Null → structural preview (non-interactive).
  final TwinMatrixCell? cell;
  final Color accent;
  final bool isToday;
  final VoidCallback? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final preview = cell == null;
    final valued = !preview && cell!.severity != null;
    final interactive = !preview && onOpenSource != null;

    final String semanticLabel;
    if (preview) {
      semanticLabel = '$daySemantics, preview';
    } else if (!valued) {
      semanticLabel =
          '$daySemantics, no confirmed records, missing'
          '${isToday ? ', this is today' : ''}'
          '${interactive ? '. Double-tap to inspect.' : ''}';
    } else {
      final c = cell!;
      semanticLabel =
          '$daySemantics, average severity '
          '${c.severity!.toStringAsFixed(1)} of 5, observed, '
          '${c.observationCount} '
          '${c.observationCount == 1 ? 'rating' : 'ratings'} across '
          '${c.cycleCount} ${c.cycleCount == 1 ? 'cycle' : 'cycles'}'
          '${isToday ? ', this is today' : ''}'
          '${interactive ? '. Double-tap to inspect the records.' : ''}';
    }

    final Widget visual;
    if (valued) {
      visual = Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: ExperienceColors.surface,
          borderRadius: BorderRadius.circular(8),
          // Observed texture: solid border on a solid mark.
          border: Border.all(color: accent, width: 1.5),
        ),
        child: CustomPaint(
          painter: _CellSeverityPainter(
            severity: cell!.severity!,
            accent: accent,
          ),
        ),
      );
    } else {
      // Unknown/missing texture: empty outline with a faint dot grid.
      visual = CertaintySwatch(
        certainty: ExperienceCertainty.unknown,
        size: 30,
        color: accent,
      );
    }

    return Semantics(
      button: interactive,
      label: semanticLabel,
      child: InkWell(
        onTap: interactive ? onOpenSource : null,
        borderRadius: BorderRadius.circular(10),
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: ExperienceSpacing.minTouchTarget,
              minHeight: ExperienceSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(height: 34, child: Center(child: visual)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        dayNumber,
                        style: ExperienceType.data(
                          isToday
                              ? ExperienceColors.ink
                              : ExperienceColors.inkFaint,
                          size: 11,
                          weight: isToday ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      if (isToday) ...<Widget>[
                        const SizedBox(width: 3),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: ExperienceColors.emberGradient,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Severity notches inside an observed cell: the shared five-notch ascending
/// vocabulary, fractionally filled to the cycle-balanced average. Count and
/// weight carry the degree; hue never does.
final class _CellSeverityPainter extends CustomPainter {
  const _CellSeverityPainter({required this.severity, required this.accent});

  final double severity;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const count = 5;
    final inset = size.shortestSide * 0.14;
    final area = Rect.fromLTWH(
      inset,
      inset,
      size.width - 2 * inset,
      size.height - 2 * inset,
    );
    final gap = area.width * 0.1;
    final barWidth = (area.width - gap * (count - 1)) / count;
    final empty = accent.withValues(alpha: 0.18);

    for (var i = 0; i < count; i++) {
      final heightFraction = 0.3 + 0.175 * i;
      final barHeight = area.height * heightFraction;
      final left = area.left + i * (barWidth + gap);
      final barRect = Rect.fromLTWH(
        left,
        area.bottom - barHeight,
        barWidth,
        barHeight,
      );
      final rrect = RRect.fromRectAndRadius(
        barRect,
        Radius.circular(barWidth * 0.4),
      );
      canvas.drawRRect(rrect, Paint()..color = empty);

      final fillFraction = (severity - i).clamp(0.0, 1.0);
      if (fillFraction > 0) {
        canvas.save();
        canvas.clipRRect(rrect);
        canvas.drawRect(
          Rect.fromLTWH(
            left,
            area.bottom - barHeight * fillFraction,
            barWidth,
            barHeight * fillFraction,
          ),
          Paint()..color = accent,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_CellSeverityPainter oldDelegate) {
    return oldDelegate.severity != severity || oldDelegate.accent != accent;
  }
}

// ---------------------------------------------------------------------------
// Evidence line — takeaway → chart → evidence. Factual counts only; numerals
// are always sans tabular figures.
// ---------------------------------------------------------------------------

class _TwinEvidenceLine extends StatelessWidget {
  const _TwinEvidenceLine({required this.viewModel});

  final TwinMatrixViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final cyclesNoun = vm.cyclesCovered == 1 ? 'cycle' : 'cycles';
    final semanticsLabel =
        '${vm.mappedObservations} of '
        '${vm.totalObservations} confirmed records map to these windows '
        'across ${vm.cyclesCovered} $cyclesNoun. '
        '${vm.sameDayObservations} recorded same-day, '
        '${vm.laterRecallObservations} later recall. '
        '${vm.blankRelativeDays} of ${vm.totalDays} day columns are blank. '
        'Blank means missing, never zero.';

    TextSpan num(int value) => TextSpan(
      text: '$value',
      style: ExperienceType.data(ExperienceColors.ink, size: 13),
    );
    TextSpan word(String text) => TextSpan(
      text: text,
      style: ExperienceType.caption(ExperienceColors.inkSoft),
    );

    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  num(vm.mappedObservations),
                  word(' of '),
                  num(vm.totalObservations),
                  word(' confirmed records map to these windows across '),
                  num(vm.cyclesCovered),
                  word(' $cyclesNoun · '),
                  num(vm.sameDayObservations),
                  word(' same-day · '),
                  num(vm.laterRecallObservations),
                  word(' later recall'),
                ],
              ),
            ),
            const SizedBox(height: ExperienceSpacing.xs),
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  num(vm.blankRelativeDays),
                  word(' of '),
                  num(vm.totalDays),
                  word(
                    ' day columns are blank — blank means missing, '
                    'never zero.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty-state guidance — the exact recording actions that will fill Twin.
// ---------------------------------------------------------------------------

class _TwinGuidanceCard extends StatelessWidget {
  const _TwinGuidanceCard({this.onRecord});

  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ExperienceColors.surface,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(color: ExperienceColors.hairline),
      ),
      padding: const EdgeInsets.all(ExperienceSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Nothing maps to these two windows yet.',
            style: ExperienceType.bodyStrong(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'Record symptoms on the days they happen. The days before a '
            'period and the first days of a cycle are the two windows Twin '
            'compares — every cell will trace back to a record.',
            style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
          ),
          if (onRecord != null) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onRecord,
                child: const Text("Record today's symptoms"),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Locked state — evidence readiness and concrete value, never a blurred
// fabricated chart. The real matrix skeleton renders below this card.
// ---------------------------------------------------------------------------

class _LockedTwinCard extends StatelessWidget {
  const _LockedTwinCard({
    required this.cyclesCovered,
    required this.cyclesNeeded,
    required this.accent,
    this.onOpenPlus,
  });

  final int cyclesCovered;
  final int cyclesNeeded;
  final Color accent;
  final VoidCallback? onOpenPlus;

  @override
  Widget build(BuildContext context) {
    final ready = cyclesCovered >= cyclesNeeded;
    final cyclesNoun = cyclesNeeded == 1 ? 'cycle' : 'cycles';

    final readiness = ready
        ? 'Your records already hold what Twin compares.'
        : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ExperienceColors.surface,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(color: ExperienceColors.hairline),
        boxShadow: ExperienceShadows.card,
      ),
      padding: const EdgeInsets.all(ExperienceSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Twin is part of Letter Within Plus.',
            style: ExperienceType.bodyStrong(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          if (readiness != null)
            Text(
              readiness,
              style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
            )
          else
            Semantics(
              label:
                  'You have $cyclesCovered of the $cyclesNeeded '
                  '$cyclesNoun Twin needs. Keep recording.',
              child: ExcludeSemantics(
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: 'You have ',
                        style: ExperienceType.bodySmall(
                          ExperienceColors.inkSoft,
                        ),
                      ),
                      TextSpan(
                        text: '$cyclesCovered',
                        style: ExperienceType.data(
                          ExperienceColors.ink,
                          size: 14,
                        ),
                      ),
                      TextSpan(
                        text: ' of the ',
                        style: ExperienceType.bodySmall(
                          ExperienceColors.inkSoft,
                        ),
                      ),
                      TextSpan(
                        text: '$cyclesNeeded',
                        style: ExperienceType.data(
                          ExperienceColors.ink,
                          size: 14,
                        ),
                      ),
                      TextSpan(
                        text: ' $cyclesNoun Twin needs — keep recording.',
                        style: ExperienceType.bodySmall(
                          ExperienceColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: ExperienceSpacing.xs + 4),
          Text(
            'Twin places the two weeks before your period beside the first '
            'two weeks of your cycle — cell by cell, with the records '
            'behind every mark.',
            style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
          ),
          if (onOpenPlus != null) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.xs + 4),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: onOpenPlus,
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent),
                  minimumSize: const Size(
                    ExperienceSpacing.minTouchTarget,
                    ExperienceSpacing.minTouchTarget,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: ExperienceRadius.chipRadius,
                  ),
                ),
                child: const Text('See what Plus adds'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Legend — certainty texture key plus the severity degree vocabulary.
// ---------------------------------------------------------------------------

class _TwinLegend extends StatelessWidget {
  const _TwinLegend({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'How to read Twin: cells with a solid border hold your recorded '
          'averages. Strength runs from Minimal to Extreme, shown by filled '
          'notches. Blank dotted cells mean nothing was recorded.',
      child: ExcludeSemantics(
        child: Wrap(
          spacing: ExperienceSpacing.sm,
          runSpacing: ExperienceSpacing.xs + 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            CertaintySwatch(
              certainty: ExperienceCertainty.observed,
              size: 14,
              color: accent,
            ),
            Text(
              'Has records',
              style: ExperienceType.caption(ExperienceColors.inkSoft),
            ),
            CertaintySwatch(
              certainty: ExperienceCertainty.unknown,
              size: 14,
              color: accent,
            ),
            Text(
              'Blank — no record',
              style: ExperienceType.caption(ExperienceColors.inkSoft),
            ),
            DegreeGraphics.severity(
              SymptomSeverity.minimal,
              showWord: false,
              size: 14,
            ),
            Text('to', style: ExperienceType.caption(ExperienceColors.inkSoft)),
            DegreeGraphics.severity(
              SymptomSeverity.extreme,
              showWord: false,
              size: 14,
            ),
            Text(
              'strength',
              style: ExperienceType.caption(ExperienceColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
