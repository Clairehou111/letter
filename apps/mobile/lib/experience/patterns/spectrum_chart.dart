import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/health_records/domain/health_record.dart';
import '../../features/insights/presentation/spectrum_log_view_model.dart';
import '../../features/summary_export/domain/cycle_care_summary.dart';
import '../degree/degree_graphics.dart';
import '../source/source_panel.dart';
import '../theme/experience_foundation.dart';

/// Spectrum — typical symptom level across the fourteen days before recorded
/// periods (day −14 … day −1).
///
/// Design-authority behavior preserved here:
///  * Typical (median) levels are shown, never cross-cycle maxima. The
///    [SpectrumData] contract already computes cycle-balanced medians; this
///    widget never derives its own statistics.
///  * Missing days stay blank — empty outline with a faint dot grid — and
///    are never smoothed, interpolated, or zeroed.
///  * Days resting on fewer than three cycles are visibly flagged as early
///    evidence (open-diamond mark + honest caption), never hidden.
///  * The cycle-by-cycle trend renders only from [SpectrumCycleTrend]
///    points, and only once three recorded cycles anchor the view.
///  * Filter labels come from [symptomLabels] only — catalog vocabulary.
///  * Every mark (day cell, trend point) opens the shared [SourcePanel]
///    with verbatim provenance. Keyboard focus has full parity with tap.
///  * Locked (no premium access) renders a structural preview with evidence
///    readiness ("2 of the 3 cycles…") and concrete value — never blurred
///    or fabricated charts.
///  * Chart grammar: serif takeaway first (no numerals adjacent to data —
///    numerals always render in sans tabular figures), chart second,
///    evidence last. Spectrum teal is the only accent; it steps down one
///    weight when this section is not the expanded one.
final class SpectrumChart extends StatefulWidget {
  const SpectrumChart({
    super.key,
    required this.viewModel,

    /// Whether the signed-in entitlement currently allows premium pattern
    /// depth. When false the chart renders its structural preview.
    this.premiumAccess = true,

    /// Whether Spectrum is the expanded/active family in the viewport.
    /// Collapsed sections render the accent at reduced weight so chart
    /// families never compete.
    this.emphasized = true,

    /// Called when the user chooses the Plus route from a locked preview.
    this.onOpenPlus,

    /// Called when the user chooses to record symptoms (routes into
    /// Cycle's day editor). The exact next action of every empty state.
    this.onRecordSymptoms,

    /// Route into editing a specific record, surfaced from SourcePanel
    /// entries. Receives the health-record id.
    this.onEditRecord,

    /// Which symptom family is selected initially.
    this.initialKey = SymptomKey.all,
  });

  final SpectrumLogViewModel viewModel;
  final bool premiumAccess;
  final bool emphasized;
  final VoidCallback? onOpenPlus;
  final VoidCallback? onRecordSymptoms;
  final ValueChanged<String>? onEditRecord;
  final SymptomKey initialKey;

  /// The evidence depth Spectrum needs before its depth view is meaningful.
  static const int cyclesNeeded = 3;

  @override
  State<SpectrumChart> createState() => _SpectrumChartState();
}

final class _SpectrumChartState extends State<SpectrumChart>
    with SingleTickerProviderStateMixin {
  late SymptomKey _key = widget.initialKey;

  /// First-paint draw-on, once per appearance. Skipped (settled instantly)
  /// under the platform reduced-motion setting.
  late final AnimationController _drawOn = AnimationController(
    vsync: this,
    duration: ExperienceMotion.chartDrawOn,
  );

  /// Horizontal-scrub focus cursor (a relative day in −14…−1), with haptic
  /// ticks at day boundaries. Null when the pointer is not scrubbing.
  int? _scrubbedDay;

  SpectrumData get _data => widget.viewModel.data;

  Color get _accent => widget.emphasized
      ? ExperienceColors.accentSpectrum
      : ExperienceColors.accentSpectrum.withValues(alpha: 0.45);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ExperienceMotion.reducedMotion(context)) {
        _drawOn.value = 1;
      } else {
        _drawOn.forward();
      }
    });
  }

  @override
  void didUpdateWidget(SpectrumChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel.data.id != widget.viewModel.data.id) {
      // Data updates crossfade (AnimatedSwitcher below); the draw-on
      // animation runs only on first paint, never on refresh.
      _drawOn.value = 1;
    }
  }

  @override
  void dispose() {
    _drawOn.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Derived, display-only projections (no statistics are computed here).
  // -------------------------------------------------------------------------

  Map<int, SpectrumDaySummary> get _summaries => _data.summariesFor(_key);
  List<SpectrumCycleTrend> get _trends => _data.trendsFor(_key);
  int get _cyclesCovered => _data.cyclesCoveredFor(_key);
  int get _confirmedCount => _data.confirmedCountFor(_key);

  bool get _hasAnyValue => _summaries.values.any((summary) => summary.hasValue);

  bool get _hasLimitedEvidence {
    if (_confirmedCount == 0) return false;
    if (_cyclesCovered > 0 && _cyclesCovered < SpectrumChart.cyclesNeeded) {
      return true;
    }
    return _summaries.values.any((summary) => summary.hasLimitedEvidence);
  }

  int _relativeDayOf(SourceRecord record) =>
      record.date.epochDay - record.anchorPeriodStart.epochDay;

  List<SourceRecord> _recordsForDay(int day) {
    final records =
        _data.records
            .where(
              (record) =>
                  (_key == SymptomKey.all || record.symptom == _key) &&
                  _relativeDayOf(record) == day,
            )
            .toList()
          ..sort((left, right) {
            final byDate = left.date.compareTo(right.date);
            return byDate == 0 ? left.id.compareTo(right.id) : byDate;
          });
    return records;
  }

  List<SourceRecord> _recordsForCycle(SpectrumCycleTrend trend) {
    final records =
        _data.records
            .where(
              (record) =>
                  (_key == SymptomKey.all || record.symptom == _key) &&
                  record.anchorPeriodStart == trend.anchorPeriodStart,
            )
            .toList()
          ..sort((left, right) {
            final byDate = left.date.compareTo(right.date);
            return byDate == 0 ? left.id.compareTo(right.id) : byDate;
          });
    return records;
  }

  // -------------------------------------------------------------------------
  // Copy — takeaway is serif and never carries numerals; all numerals render
  // in sans tabular figures.
  // -------------------------------------------------------------------------

  String get _takeaway {
    if (_confirmedCount == 0 || !_hasAnyValue) {
      return 'These two weeks are still unwritten';
    }
    var peakDay = 0;
    var peakValue = -1.0;
    for (final entry in _summaries.entries) {
      final typical = entry.value.typical;
      if (typical != null && typical > peakValue) {
        peakValue = typical;
        peakDay = entry.key;
      }
    }
    if (peakDay >= -5) {
      return 'Levels tend to gather close to your period';
    }
    if (peakDay <= -10) {
      return 'Levels tend to sit earlier in the two weeks before';
    }
    return 'Levels spread across the two weeks before your period';
  }

  /// The factual data line beneath the takeaway — numerals in
  /// [ExperienceType.data] only.
  List<InlineSpan> _dataLineSpans() {
    final ink = ExperienceColors.ink;
    final inkSoft = ExperienceColors.inkSoft;
    if (_confirmedCount == 0 || !_hasAnyValue) {
      return <InlineSpan>[
        TextSpan(
          text:
              'Confirmed ratings will anchor to the fourteen days before '
              'each recorded period.',
          style: ExperienceType.bodySmall(inkSoft),
        ),
      ];
    }
    var peakDay = 0;
    var peakValue = -1.0;
    var peakCycles = 0;
    for (final entry in _summaries.entries) {
      final typical = entry.value.typical;
      if (typical != null && typical > peakValue) {
        peakValue = typical;
        peakDay = entry.key;
        peakCycles = entry.value.cycleCount;
      }
    }
    final daysBefore = -peakDay;
    return <InlineSpan>[
      TextSpan(
        text: 'Typical level peaks at ',
        style: ExperienceType.bodySmall(inkSoft),
      ),
      TextSpan(
        text: '${_formatLevel(peakValue)} of 5',
        style: ExperienceType.data(ink, size: 14),
      ),
      TextSpan(
        text:
            ', $daysBefore day${daysBefore == 1 ? '' : 's'} before a recorded period · ',
        style: ExperienceType.bodySmall(inkSoft),
      ),
      TextSpan(text: '$peakCycles', style: ExperienceType.data(ink, size: 14)),
      TextSpan(
        text: ' ${peakCycles == 1 ? 'cycle' : 'cycles'} on that day · ',
        style: ExperienceType.bodySmall(inkSoft),
      ),
      TextSpan(
        text: '$_cyclesCovered',
        style: ExperienceType.data(ink, size: 14),
      ),
      TextSpan(
        text: ' ${_cyclesCovered == 1 ? 'cycle' : 'cycles'} anchored',
        style: ExperienceType.bodySmall(inkSoft),
      ),
    ];
  }

  static String _formatLevel(double value) {
    final rounded = value.roundToDouble();
    return (value - rounded).abs() < 0.05
        ? rounded.toInt().toString()
        : value.toStringAsFixed(1);
  }

  // -------------------------------------------------------------------------
  // Source inspection
  // -------------------------------------------------------------------------

  SourcePanelEntry _entryFor(SourceRecord record) {
    final day = _relativeDayOf(record);
    final severity = SymptomSeverity.values.firstWhere(
      (value) => value.score == record.rating,
      orElse: () => SymptomSeverity.moderate,
    );
    return SourcePanelEntry(
      title: record.symptomLabel,
      certainty: ExperienceCertainty.observed,
      dateLabel: summaryDateLabel(record.date),
      provenanceLabel: record.provenanceLabel,
      sourceLabel: 'User-confirmed health record · local only',
      details: <String>[
        'Severity: ${severity.label} (${record.rating} of 5)',
        '${-day} day${day == -1 ? '' : 's'} before the next recorded period',
        record.cycleLabel,
      ],
      onEdit: widget.onEditRecord == null
          ? null
          : () => widget.onEditRecord!(record.id),
    );
  }

  void _openDayPanel(int day) {
    final summary = _summaries[day];
    final entries = _recordsForDay(day).map(_entryFor).toList();
    final daysBefore = -day;
    final subtitle = summary != null && summary.hasValue
        ? 'Typical level ${_formatLevel(summary.typical!)} of 5 '
              '(${summary.minimum}–${summary.maximum} observed) across '
              '${summary.cycleCount} '
              '${summary.cycleCount == 1 ? 'cycle' : 'cycles'}. '
              'Missing days stay blank — never zero.'
        : 'Nothing is recorded on this relative day yet. '
              'Blank means missing, never zero.';
    SourcePanel.show(
      context,
      title:
          'Records $daysBefore day${daysBefore == 1 ? '' : 's'} '
          'before a recorded period',
      subtitle: subtitle,
      entries: entries,
      certainty: entries.isEmpty
          ? ExperienceCertainty.unknown
          : ExperienceCertainty.observed,
    );
  }

  void _openTrendPanel(SpectrumCycleTrend trend) {
    final entries = _recordsForCycle(trend).map(_entryFor).toList();
    SourcePanel.show(
      context,
      title: 'Cycle anchored ${summaryDateLabel(trend.anchorPeriodStart)}',
      subtitle:
          'Cycle-balanced typical '
          '${_formatLevel(trend.typical)} of 5 across '
          '${trend.ratedDayCount} rated '
          '${trend.ratedDayCount == 1 ? 'day' : 'days'} '
          '(${trend.ratingCount} confirmed '
          '${trend.ratingCount == 1 ? 'rating' : 'ratings'}). '
          'One cycle never counts twice on the same day.',
      entries: entries,
      certainty: entries.isEmpty
          ? ExperienceCertainty.unknown
          : ExperienceCertainty.observed,
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final content = widget.premiumAccess && _hasAnyValue
        ? _buildDepthView(context)
        : _buildStructuralPreview(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey<String>('${_data.id}|$_key|${widget.premiumAccess}'),
        child: content,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            _takeaway,
            style: ExperienceType.title(ExperienceColors.ink),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        Text.rich(TextSpan(children: _dataLineSpans())),
        const SizedBox(height: ExperienceSpacing.sm),
        _FilterRow(
          selected: _key,
          accent: _accent,
          onSelected: (key) {
            ExperienceHaptics.pick();
            setState(() => _key = key);
          },
        ),
      ],
    );
  }

  Widget _buildDepthView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildHeader(context),
        if (_hasLimitedEvidence) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.xs + 4),
          _LimitedEvidenceLine(cyclesCovered: _cyclesCovered),
        ],
        const SizedBox(height: ExperienceSpacing.sm),
        _ChartLegend(accent: _accent),
        const SizedBox(height: ExperienceSpacing.xs + 4),
        _DayChart(
          summaries: _summaries,
          accent: _accent,
          drawOn: _drawOn,
          scrubbedDay: _scrubbedDay,
          onScrub: (day) {
            if (day != _scrubbedDay) {
              ExperienceHaptics.pick();
              setState(() => _scrubbedDay = day);
            }
          },
          onScrubEnd: () => setState(() => _scrubbedDay = null),
          onOpenDay: _openDayPanel,
        ),
        const SizedBox(height: ExperienceSpacing.xs + 4),
        _AxisLabels(),
        const SizedBox(height: ExperienceSpacing.sm),
        _TrendSection(
          trends: _trends,
          accent: _accent,
          onOpenTrend: _openTrendPanel,
        ),
        const SizedBox(height: ExperienceSpacing.xs + 4),
        Text(
          _data.note,
          style: ExperienceType.caption(ExperienceColors.inkSoft),
        ),
      ],
    );
  }

  Widget _buildStructuralPreview(BuildContext context) {
    final covered = _cyclesCovered;
    final ready = covered >= SpectrumChart.cyclesNeeded;
    final lockedOut = !widget.premiumAccess;

    final String readiness;
    if (lockedOut && ready) {
      readiness = 'Your records are ready — Plus opens this depth.';
    } else if (ready) {
      readiness = 'Three recorded cycles now anchor these days.';
    } else {
      readiness =
          'You have $covered of the ${SpectrumChart.cyclesNeeded} '
          'cycles Spectrum needs — keep recording.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            _confirmedCount == 0
                ? 'These two weeks are still unwritten'
                : 'What Spectrum will show you',
            style: ExperienceType.title(ExperienceColors.ink),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          'Typical levels for each of the fourteen days before your period, '
          'drawn only from your confirmed records. Blank days stay blank.',
          style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        _FilterRow(
          selected: _key,
          accent: _accent,
          onSelected: (key) {
            ExperienceHaptics.pick();
            setState(() => _key = key);
          },
        ),
        const SizedBox(height: ExperienceSpacing.xs + 4),
        Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: CertaintySwatch(
                  certainty: ready
                      ? ExperienceCertainty.observed
                      : ExperienceCertainty.unknown,
                  color: _accent,
                ),
              ),
              const SizedBox(width: ExperienceSpacing.xs + 4),
              Expanded(
                child: Text(
                  readiness,
                  style: ExperienceType.bodyStrong(ExperienceColors.ink),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        const _SkeletonChart(),
        const SizedBox(height: ExperienceSpacing.xs + 4),
        _AxisLabels(),
        const SizedBox(height: ExperienceSpacing.sm),
        Wrap(
          spacing: ExperienceSpacing.xs + 4,
          runSpacing: ExperienceSpacing.xs,
          children: <Widget>[
            if (widget.onRecordSymptoms != null)
              FilledButton.tonalIcon(
                onPressed: widget.onRecordSymptoms,
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: const Text('Record symptoms in Cycle'),
              ),
            if (lockedOut && widget.onOpenPlus != null)
              TextButton(
                onPressed: widget.onOpenPlus,
                child: const Text('See what Plus adds'),
              ),
          ],
        ),
        if (lockedOut)
          Padding(
            padding: const EdgeInsets.only(top: ExperienceSpacing.xs),
            child: Text(
              'Tracking, prediction, and your records stay free. '
              'Plus adds this pattern depth.',
              style: ExperienceType.caption(ExperienceColors.inkSoft),
            ),
          )
        else if (_confirmedCount == 0)
          Padding(
            padding: const EdgeInsets.only(top: ExperienceSpacing.xs),
            child: Text(
              _data.note,
              style: ExperienceType.caption(ExperienceColors.inkSoft),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Filter row — vocabulary from symptomLabels only.
// ---------------------------------------------------------------------------

final class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selected,
    required this.accent,
    required this.onSelected,
  });

  final SymptomKey selected;
  final Color accent;
  final ValueChanged<SymptomKey> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final key in SymptomKey.values)
            Padding(
              padding: const EdgeInsets.only(right: ExperienceSpacing.xs + 4),
              child: _FilterChip(
                label: symptomLabels[key]!,
                selected: key == selected,
                accent: accent,
                onTap: () => onSelected(key),
              ),
            ),
        ],
      ),
    );
  }
}

final class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Filter: $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: ExperienceRadius.chipRadius,
        child: AnimatedContainer(
          duration: ExperienceMotion.chipSelect,
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.14)
                : ExperienceColors.surface,
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(
              color: selected ? accent : ExperienceColors.hairline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(label, style: ExperienceType.label(ExperienceColors.ink)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Limited-evidence flag — visible, honest, never alarm.
// ---------------------------------------------------------------------------

final class _LimitedEvidenceLine extends StatelessWidget {
  const _LimitedEvidenceLine({required this.cyclesCovered});

  final int cyclesCovered;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Early evidence. $cyclesCovered '
          '${cyclesCovered == 1 ? 'cycle' : 'cycles'} so far. Marks with an '
          'open diamond rest on fewer than three cycles.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.diamond_outlined,
              size: 14,
              color: ExperienceColors.inkSoft,
            ),
          ),
          const SizedBox(width: ExperienceSpacing.xs + 2),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: 'Early evidence — ',
                    style: ExperienceType.bodyStrong(ExperienceColors.inkSoft),
                  ),
                  TextSpan(
                    text: '$cyclesCovered',
                    style: ExperienceType.data(ExperienceColors.ink, size: 14),
                  ),
                  TextSpan(
                    text:
                        ' ${cyclesCovered == 1 ? 'cycle' : 'cycles'} so far. '
                        'Marks with an open diamond rest on fewer than three '
                        'cycles; each recorded cycle steadies this.',
                    style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Legend — texture key plus the five-degree severity scale reminder.
// ---------------------------------------------------------------------------

final class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final inkSoft = ExperienceColors.inkSoft;
    return Semantics(
      label:
          'How to read this chart: solid teal bars are typical recorded '
          'levels. Empty dotted cells are missing days, never zero. Levels '
          'use the five-degree severity scale.',
      child: Wrap(
        spacing: ExperienceSpacing.sm,
        runSpacing: ExperienceSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CertaintySwatch(
                certainty: ExperienceCertainty.observed,
                color: accent,
              ),
              const SizedBox(width: 6),
              Text('Typical level', style: ExperienceType.caption(inkSoft)),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CertaintySwatch(certainty: ExperienceCertainty.unknown),
              const SizedBox(width: 6),
              Text('Missing day', style: ExperienceType.caption(inkSoft)),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DegreeGraphics.severity(
                SymptomSeverity.moderate,
                size: 14,
                showWord: false,
              ),
              const SizedBox(width: 6),
              Text('Five-degree scale', style: ExperienceType.caption(inkSoft)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day chart — fourteen cells, blank-as-missing, scrub cursor, tap/focus
// source inspection. Re-flows horizontally under large text.
// ---------------------------------------------------------------------------

final class _DayChart extends StatelessWidget {
  const _DayChart({
    required this.summaries,
    required this.accent,
    required this.drawOn,
    required this.scrubbedDay,
    required this.onScrub,
    required this.onScrubEnd,
    required this.onOpenDay,
  });

  final Map<int, SpectrumDaySummary> summaries;
  final Color accent;
  final Animation<double> drawOn;
  final int? scrubbedDay;
  final ValueChanged<int> onScrub;
  final VoidCallback onScrubEnd;
  final ValueChanged<int> onOpenDay;

  static const double _chartHeight = 168;

  int _dayAtOffset(double dx, double cellWidth) {
    final index = (dx / cellWidth).floor().clamp(0, dayKeys.length - 1);
    return dayKeys[index];
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final cellWidth = math.max(22.0, 20.0 * textScale.clamp(1.0, 2.0));

    return LayoutBuilder(
      builder: (context, constraints) {
        final fitted = constraints.maxWidth / dayKeys.length;
        final width = math.max(fitted, cellWidth);
        final chartWidth = width * dayKeys.length;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragDown: (details) =>
                onScrub(_dayAtOffset(details.localPosition.dx, width)),
            onHorizontalDragUpdate: (details) =>
                onScrub(_dayAtOffset(details.localPosition.dx, width)),
            onHorizontalDragEnd: (_) => onScrubEnd(),
            onHorizontalDragCancel: onScrubEnd,
            child: SizedBox(
              width: chartWidth,
              height: _chartHeight,
              child: AnimatedBuilder(
                animation: drawOn,
                builder: (context, _) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final day in dayKeys)
                        SizedBox(
                          width: width,
                          child: _DayCell(
                            summary: summaries[day]!,
                            accent: accent,
                            progress: drawOn.value,
                            scrubbed: scrubbedDay == day,
                            onOpen: () => onOpenDay(day),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.summary,
    required this.accent,
    required this.progress,
    required this.scrubbed,
    required this.onOpen,
  });

  final SpectrumDaySummary summary;
  final Color accent;
  final double progress;
  final bool scrubbed;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final daysBefore = -summary.day;
    final String semanticsLabel;
    if (summary.hasValue) {
      semanticsLabel =
          'Day $daysBefore before a recorded period: typical '
          'level ${_formatLevel(summary.typical!)} of 5, observed, from '
          '${summary.cycleCount} '
          '${summary.cycleCount == 1 ? 'cycle' : 'cycles'}'
          '${summary.hasLimitedEvidence ? ', early evidence' : ''}. '
          'Activate to inspect the records.';
    } else {
      semanticsLabel =
          'Day $daysBefore before a recorded period: missing. '
          'No confirmed ratings. Activate to inspect.';
    }

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 12,
                child: summary.hasLimitedEvidence
                    ? const Icon(
                        Icons.diamond_outlined,
                        size: 10,
                        color: ExperienceColors.inkSoft,
                      )
                    : null,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final height = constraints.maxHeight;
                    final typical = summary.typical;
                    final minFraction = (summary.minimum ?? 0) / 5.0;
                    final maxFraction = (summary.maximum ?? 0) / 5.0;
                    final typicalFraction = (typical ?? 0) / 5.0 * progress;

                    return Stack(
                      alignment: Alignment.bottomCenter,
                      children: <Widget>[
                        if (summary.hasValue) ...<Widget>[
                          if (maxFraction > minFraction)
                            Positioned(
                              bottom: minFraction * height * progress,
                              child: Container(
                                width: 1.5,
                                height: math.max(
                                  2,
                                  (maxFraction - minFraction) *
                                      height *
                                      progress,
                                ),
                                color: accent.withValues(alpha: 0.5),
                              ),
                            ),
                          Container(
                            width: double.infinity,
                            height: math.max(3, typicalFraction * height),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.85),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                              border: Border.all(color: accent, width: 1.25),
                            ),
                          ),
                        ] else
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: ExperienceColors.inkFaint.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: const CustomPaint(
                                  painter: DotGridPainter(
                                    color: ExperienceColors.inkFaint,
                                    spacing: 7,
                                    dotRadius: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (scrubbed)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: ExperienceColors.ember,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatLevel(double value) {
    final rounded = value.roundToDouble();
    return (value - rounded).abs() < 0.05
        ? rounded.toInt().toString()
        : value.toStringAsFixed(1);
  }
}

final class _AxisLabels extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = ExperienceType.data(ExperienceColors.inkSoft, size: 12);
    return Semantics(
      label:
          'Horizontal axis: days before a recorded period, from fourteen '
          'to one.',
      child: Row(
        children: <Widget>[
          Text('14 days before', style: style),
          const Spacer(),
          Text('7', style: style),
          const Spacer(),
          Text('1 day before', style: style),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trend — cycle-balanced trend points only, once three cycles anchor.
// ---------------------------------------------------------------------------

final class _TrendSection extends StatelessWidget {
  const _TrendSection({
    required this.trends,
    required this.accent,
    required this.onOpenTrend,
  });

  final List<SpectrumCycleTrend> trends;
  final Color accent;
  final ValueChanged<SpectrumCycleTrend> onOpenTrend;

  @override
  Widget build(BuildContext context) {
    final inkSoft = ExperienceColors.inkSoft;
    if (trends.length < 3) {
      return Semantics(
        label:
            'Cycle-by-cycle trend is not shown yet. It appears once '
            'three recorded cycles anchor these days.',
        child: Text(
          'The cycle-by-cycle trend appears once three recorded cycles '
          'anchor these days.',
          style: ExperienceType.caption(inkSoft),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Cycle by cycle',
          style: ExperienceType.bodyStrong(ExperienceColors.ink),
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        SizedBox(
          height: 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < trends.length; i++)
                Expanded(
                  child: _TrendPoint(
                    trend: trends[i],
                    previous: i == 0 ? null : trends[i - 1],
                    accent: accent,
                    onOpen: () => onOpenTrend(trends[i]),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          'Each point is one recorded cycle — a cycle-balanced typical, '
          'never a raw maximum.',
          style: ExperienceType.caption(inkSoft),
        ),
      ],
    );
  }
}

final class _TrendPoint extends StatelessWidget {
  const _TrendPoint({
    required this.trend,
    required this.previous,
    required this.accent,
    required this.onOpen,
  });

  final SpectrumCycleTrend trend;
  final SpectrumCycleTrend? previous;
  final Color accent;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          'Cycle anchored ${summaryDateLabel(trend.anchorPeriodStart)}: '
          'cycle-balanced typical ${trend.typical.toStringAsFixed(1)} of 5 '
          'across ${trend.ratedDayCount} rated days. Activate to inspect '
          'the records.',
      child: InkWell(
        onTap: onOpen,
        child: CustomPaint(
          painter: _TrendPointPainter(
            value: trend.typical / 5.0,
            previousValue: previous == null ? null : previous!.typical / 5.0,
            accent: accent,
          ),
        ),
      ),
    );
  }
}

final class _TrendPointPainter extends CustomPainter {
  const _TrendPointPainter({
    required this.value,
    required this.previousValue,
    required this.accent,
  });

  final double value;
  final double? previousValue;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height * (1 - value) * 0.8 + size.height * 0.1;
    final center = Offset(size.width / 2, centerY);

    if (previousValue != null) {
      final previousY =
          size.height * (1 - previousValue!) * 0.8 + size.height * 0.1;
      canvas.drawLine(
        Offset(-size.width / 2, previousY),
        center,
        Paint()
          ..color = accent.withValues(alpha: 0.5)
          ..strokeWidth = 1.5,
      );
    }
    // Always draw the outgoing segment so the polyline reads continuously;
    // the next cell completes its own incoming half.
    canvas.drawCircle(center, 4, Paint()..color = accent);
    canvas.drawCircle(
      center,
      6.5,
      Paint()
        ..color = accent.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_TrendPointPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.previousValue != previousValue ||
        oldDelegate.accent != accent;
  }
}

// ---------------------------------------------------------------------------
// Structural skeleton — chart skeleton with dot-grid cells, never a bare
// spinner, never blurred fake data.
// ---------------------------------------------------------------------------

final class _SkeletonChart extends StatelessWidget {
  const _SkeletonChart();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Chart preview: fourteen empty day cells, one for each of the '
          'fourteen days before a recorded period. They fill as you record.',
      child: SizedBox(
        height: 168,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var i = 0; i < dayKeys.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: <Widget>[
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: ExperienceColors.inkFaint.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: const CustomPaint(
                              painter: DotGridPainter(
                                color: ExperienceColors.inkFaint,
                                spacing: 7,
                                dotRadius: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
