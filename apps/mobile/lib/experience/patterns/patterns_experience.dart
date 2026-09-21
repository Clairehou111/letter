import 'package:flutter/material.dart';

import '../../features/clinical/presentation/twin_matrix_view_model.dart';
import '../../features/entitlement/domain/entitlement.dart';
import '../../features/insights/presentation/gravity_horizon_view_model.dart';
import '../../features/insights/presentation/spectrum_log_view_model.dart';
import '../../features/patterns/domain/personal_pattern.dart';
import '../../features/preparation/domain/preparation_loop_state.dart';
import '../../features/summary_export/domain/cycle_care_summary.dart';
import '../source/source_panel.dart';
import '../theme/experience_foundation.dart';
import 'gravity_chart.dart';
import 'spectrum_chart.dart';
import 'twin_chart.dart';

/// The Patterns destination — takeaway-first, progressive, generous to free
/// users, and honest about what is not yet knowable.
///
/// Composition (design authority):
///  1. Today's plain-language line (serif, numeral-free).
///  2. Gravity, expanded — free forever, the lead chart.
///  3. Spectrum and Twin as collapsed sections showing one-line readiness;
///     exactly one section is expanded at a time, and only the expanded
///     family's accent renders at full saturation.
///  4. "From your records" narratives — SupportActionPattern memory and
///     observed symptom stories composed ONLY from [PersonalPatternAnalysis]
///     results. Memory copy renders through the single gating helper in the
///     foundation: remembered cards when evidence justifies them, the honest
///     accumulating line when evidence exists but has not closed the loop,
///     and silence under zero evidence. The prototype's confident sample
///     claims and the broken "Last cycle, ____ helped you most." line are
///     the canonical anti-patterns and are never recreated.
///  5. A quiet Reports route row.
///
/// Entitlement: Gravity and every honest readiness preview are free;
/// Spectrum depth gates on [LetterCapability.personalPatterns] and Twin
/// depth on [LetterCapability.longitudinalComparisons]. Locked sections
/// state concrete value and evidence readiness, never blurred fake charts,
/// and never interrupt Care. Losing entitlement never hides local data —
/// locked depth shows what the records already hold.
///
/// New users see structural previews with derived remaining-record actions
/// (rendered inside each chart), never dead empty pages.
final class PatternsExperience extends StatefulWidget {
  const PatternsExperience({
    super.key,
    required this.gravity,
    required this.spectrum,
    this.twin,
    this.twinLoading = false,
    this.analysis = PersonalPatternAnalysis.empty,
    required this.entitlement,
    this.preparationLoopKind,
    this.onOpenReports,
    this.onOpenPlus,
    this.onRecordPeriodStart,
    this.onBackfillPastPeriod,
    this.onRecordSymptoms,
    this.onEditHealthRecord,
    this.onEditPeriodRecord,
  });

  /// The free lead chart's view model (all five HorizonStateIds honored
  /// inside the chart, including structural previews).
  final GravityHorizonViewModel gravity;

  /// Spectrum's view model. Depth is premium-gated; the structural preview
  /// is free.
  final SpectrumLogViewModel spectrum;

  /// Twin's view model. Null while [twinLoading] or when nothing maps yet —
  /// the chart renders its own skeleton/structural preview in both cases.
  final TwinMatrixViewModel? twin;

  /// True while the Twin repository computes (dot-grid skeleton, never a
  /// bare spinner).
  final bool twinLoading;

  /// Factual narratives from [PersonalPatternEngine.analyze] — the ONLY
  /// source of SupportActionPattern and observed-symptom copy on this
  /// destination.
  final PersonalPatternAnalysis analysis;

  /// Current entitlement. Free capabilities never gate; premium depth gates
  /// without turning the destination into a paywall.
  final EntitlementState entitlement;

  /// The current preparation loop kind, when known. Fed into the single
  /// memory-evidence gate; null falls back to raw evidence counts.
  final PreparationLoopKind? preparationLoopKind;

  /// Quiet route row into Reports.
  final VoidCallback? onOpenReports;

  /// Route into Plus from locked depth.
  final VoidCallback? onOpenPlus;

  /// Named next actions forwarded to Gravity's structural previews.
  final VoidCallback? onRecordPeriodStart;
  final VoidCallback? onBackfillPastPeriod;

  /// Route into recording symptoms (Cycle's day editor / Today quick path).
  final VoidCallback? onRecordSymptoms;

  /// Edit routes surfaced from SourcePanel entries.
  final ValueChanged<String>? onEditHealthRecord;
  final void Function(Object record)? onEditPeriodRecord;

  /// Recorded cycles Twin's comparison needs before it carries weight.
  static const int twinCyclesNeeded = 2;

  @override
  State<PatternsExperience> createState() => _PatternsExperienceState();
}

enum _PatternSection { gravity, spectrum, twin }

class _PatternsExperienceState extends State<PatternsExperience> {
  /// Exactly one expanded section per viewport. Gravity leads by default —
  /// free, and first in the order of disclosure.
  _PatternSection _expanded = _PatternSection.gravity;

  bool get _spectrumPremium =>
      widget.entitlement.canUse(LetterCapability.personalPatterns);

  bool get _twinPremium =>
      widget.entitlement.canUse(LetterCapability.longitudinalComparisons);

  void _expand(_PatternSection section) {
    if (_expanded == section) return;
    ExperienceHaptics.pick();
    setState(() => _expanded = section);
  }

  // -------------------------------------------------------------------------
  // Today's plain-language line — serif, numeral-free.
  // -------------------------------------------------------------------------

  String get _todayLine {
    return switch (widget.gravity.stateId) {
      HorizonStateId.noHistory =>
        'Your patterns begin with one recorded period',
      HorizonStateId.insufficientHistory =>
        'Your pattern is beginning to take shape',
      HorizonStateId.predictionAvailable =>
        'Here is what your records are saying',
      HorizonStateId.periodInProgress =>
        'Your period is the headline right now',
      HorizonStateId.pastEstimatedRange =>
        'This cycle is writing its own timing',
    };
  }

  // -------------------------------------------------------------------------
  // Collapsed-section readiness lines — factual, derived, never hard-coded.
  // -------------------------------------------------------------------------

  String get _gravityReadiness {
    return switch (widget.gravity.stateId) {
      HorizonStateId.noHistory => 'Waiting on your first recorded period.',
      HorizonStateId.insufficientHistory =>
        'Forming — each recorded start sharpens it.',
      HorizonStateId.predictionAvailable =>
        'Your estimated horizon, drawn from recorded history.',
      HorizonStateId.periodInProgress =>
        'Resting while your period is being recorded.',
      HorizonStateId.pastEstimatedRange =>
        'Running later than the estimate — your record leads.',
    };
  }

  String get _spectrumReadiness {
    final cycles = widget.spectrum.data.cyclesCoveredFor(SymptomKey.all);
    final needed = SpectrumChart.cyclesNeeded;
    if (!_spectrumPremium) {
      return cycles > 0
          ? 'Plus depth — $cycles recorded '
                '${cycles == 1 ? 'cycle' : 'cycles'} already anchored.'
          : 'Plus depth — typical levels across the two weeks before '
                'your period.';
    }
    if (cycles >= needed) {
      return 'Anchored by $cycles recorded cycles.';
    }
    return '$cycles of $needed cycles anchored — keep recording.';
  }

  String get _twinReadiness {
    final cycles = widget.twin?.cyclesCovered ?? 0;
    const needed = PatternsExperience.twinCyclesNeeded;
    if (!_twinPremium) {
      return cycles > 0
          ? 'Plus depth — $cycles recorded '
                '${cycles == 1 ? 'cycle' : 'cycles'} already mapped.'
          : 'Plus depth — the days before bleeding beside the days after '
                'it begins.';
    }
    if (cycles >= needed) {
      return 'Comparing across $cycles recorded cycles.';
    }
    return '$cycles of $needed cycles mapped — keep recording.';
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.md,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.scrollBottomPadding,
      ),
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            _todayLine,
            style: ExperienceType.title(ExperienceColors.ink),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          'Every claim below traces to a record you saved — '
          'blank means missing, never zero.',
          style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
        ),
        const SizedBox(height: ExperienceSpacing.lg),
        _buildSection(
          section: _PatternSection.gravity,
          name: 'Gravity',
          readiness: _gravityReadiness,
          accent: ExperienceColors.accentGravity,
          semanticsHint:
              'Cycle gravity, the estimated horizon. Free for everyone.',
          child: GravityChart(
            viewModel: widget.gravity,
            expanded: _expanded == _PatternSection.gravity,
            onRecordPeriodStart: widget.onRecordPeriodStart,
            onBackfillPastPeriod: widget.onBackfillPastPeriod,
            onEditRecord: widget.onEditPeriodRecord == null
                ? null
                : (record) => widget.onEditPeriodRecord!(record),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        _buildSection(
          section: _PatternSection.spectrum,
          name: 'Spectrum',
          readiness: _spectrumReadiness,
          accent: ExperienceColors.accentSpectrum,
          semanticsHint:
              'Spectrum, typical levels across the fourteen days '
              'before your recorded periods.',
          child: SpectrumChart(
            viewModel: widget.spectrum,
            premiumAccess: _spectrumPremium,
            emphasized: _expanded == _PatternSection.spectrum,
            onOpenPlus: widget.onOpenPlus,
            onRecordSymptoms: widget.onRecordSymptoms,
            onEditRecord: widget.onEditHealthRecord,
          ),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        _buildSection(
          section: _PatternSection.twin,
          name: 'Twin',
          readiness: _twinReadiness,
          accent: ExperienceColors.accentTwin,
          semanticsHint:
              'Twin, the two-window comparison of the days '
              'before your period and the first days of your cycle.',
          child: TwinChart(
            viewModel: widget.twin,
            isLoading: widget.twinLoading,
            hasPremiumAccess: _twinPremium,
            cyclesNeeded: PatternsExperience.twinCyclesNeeded,
            expanded: _expanded == _PatternSection.twin,
            onOpenPlus: widget.onOpenPlus,
            onEditRecord: widget.onEditHealthRecord,
            onRecordObservation: widget.onRecordSymptoms,
          ),
        ),
        ..._buildNarrativeSection(context),
        const SizedBox(height: ExperienceSpacing.lg),
        _ReportsRow(onOpenReports: widget.onOpenReports),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Section frame — one expanded family at full accent; collapsed families
  // step down one weight so chart accents never compete in one viewport.
  // -------------------------------------------------------------------------

  Widget _buildSection({
    required _PatternSection section,
    required String name,
    required String readiness,
    required Color accent,
    required String semanticsHint,
    required Widget child,
  }) {
    final expanded = _expanded == section;
    final effectiveAccent = expanded ? accent : accent.withValues(alpha: 0.45);

    if (expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            button: true,
            label: '$name, expanded. $semanticsHint Activate to collapse.',
            child: InkWell(
              borderRadius: ExperienceRadius.chipRadius,
              onTap: () => ExperienceHaptics.pick(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: effectiveAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: ExperienceType.headline(ExperienceColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          child,
        ],
      );
    }

    return Semantics(
      button: true,
      label: '$name, collapsed. $readiness Activate to expand.',
      child: InkWell(
        borderRadius: ExperienceRadius.cardRadius,
        onTap: () => _expand(section),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: ExperienceColors.surface,
            borderRadius: ExperienceRadius.cardRadius,
            border: Border.all(color: ExperienceColors.hairline),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: effectiveAccent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(ExperienceRadius.card),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(ExperienceSpacing.sm),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                name,
                                style: ExperienceType.bodyStrong(
                                  ExperienceColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                readiness,
                                style: ExperienceType.caption(
                                  ExperienceColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: ExperienceSpacing.xs + 4),
                        Icon(Icons.expand_more, color: effectiveAccent),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // "From your records" — narratives composed ONLY from
  // PersonalPatternAnalysis. Memory copy passes through the single gate;
  // factualOutcomeSummary wording is preserved verbatim.
  // -------------------------------------------------------------------------

  List<Widget> _buildNarrativeSection(BuildContext context) {
    final support = widget.analysis.supportActions;
    final symptoms = widget.analysis.symptomPatterns;
    final verdict = ExperienceFoundation.gateMemoryEvidence(
      loopKind: widget.preparationLoopKind,
      evidence: support,
    );

    final showSupport =
        verdict == MemoryEvidenceVerdict.remembered ||
        verdict == MemoryEvidenceVerdict.proposal;
    final showAccumulating = verdict == MemoryEvidenceVerdict.accumulating;
    final showSymptoms = _spectrumPremium && symptoms.isNotEmpty;
    final showLockedSymptoms = !_spectrumPremium && symptoms.isNotEmpty;

    // Zero evidence renders silence — no heading, no placeholder, no
    // fabricated confidence. Early evidence renders the honest
    // intermediate line so silence never reads as brokenness.
    if (!showSupport &&
        !showAccumulating &&
        !showSymptoms &&
        !showLockedSymptoms) {
      return const <Widget>[];
    }

    return <Widget>[
      const SizedBox(height: ExperienceSpacing.lg),
      Semantics(
        header: true,
        child: Text(
          'From your records',
          style: ExperienceType.headline(ExperienceColors.ink),
        ),
      ),
      const SizedBox(height: ExperienceSpacing.xs + 4),
      if (showAccumulating)
        Padding(
          padding: const EdgeInsets.only(bottom: ExperienceSpacing.xs + 4),
          child: Text(
            ExperienceMemoryGate.accumulatingLine(support),
            style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
          ),
        ),
      if (showSupport)
        for (final pattern in support.take(3)) ...<Widget>[
          _SupportActionCard(
            pattern: pattern,
            proposal: verdict == MemoryEvidenceVerdict.proposal,
            onInspect: () => _inspectSupportPattern(pattern),
          ),
          const SizedBox(height: ExperienceSpacing.xs + 4),
        ],
      if (showSymptoms)
        for (final pattern in symptoms.take(4)) ...<Widget>[
          _SymptomNarrativeCard(
            pattern: pattern,
            onInspect: () => _inspectSymptomPattern(pattern),
          ),
          const SizedBox(height: ExperienceSpacing.xs + 4),
        ],
      if (showLockedSymptoms) ...<Widget>[
        _LockedNarrativeCard(
          recordCount: symptoms.fold<int>(0, (sum, item) => sum + item.count),
          onOpenPlus: widget.onOpenPlus,
        ),
        const SizedBox(height: ExperienceSpacing.xs + 4),
      ],
    ];
  }

  void _inspectSupportPattern(SupportActionPattern pattern) {
    SourcePanel.show(
      context,
      title: 'Behind "${pattern.actionLabel}"',
      subtitle:
          '${pattern.mode.label} · ${pattern.factualOutcomeSummary}. '
          'Every check-back below is a Care action you deliberately saved.',
      certainty: ExperienceCertainty.observed,
      entries: <SourcePanelEntry>[
        for (final source in pattern.sources)
          SourcePanelEntry.fromPatternSource(source),
      ],
    );
  }

  void _inspectSymptomPattern(ObservedSymptomPattern pattern) {
    SourcePanel.show(
      context,
      title: 'Behind "${pattern.symptom.label}"',
      subtitle:
          'A factual view over your confirmed records — '
          'nothing inferred, nothing smoothed.',
      certainty: ExperienceCertainty.observed,
      entries: <SourcePanelEntry>[
        for (final source in pattern.sources)
          SourcePanelEntry.fromPatternSource(
            source,
            onEdit: widget.onEditHealthRecord == null
                ? null
                : () => widget.onEditHealthRecord!(source.id),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Support action card — memory accent (ember-coral is reserved for memory).
// Copy comes from the pattern itself; factualOutcomeSummary is verbatim.
// ---------------------------------------------------------------------------

class _SupportActionCard extends StatelessWidget {
  const _SupportActionCard({
    required this.pattern,
    required this.proposal,
    this.onInspect,
  });

  final SupportActionPattern pattern;

  /// Proposed loops render as a clearly-labeled suggestion rather than a
  /// settled memory.
  final bool proposal;
  final VoidCallback? onInspect;

  @override
  Widget build(BuildContext context) {
    const accent = ExperienceColors.accentMemory;
    final semanticsLabel =
        '${pattern.actionLabel}, ${pattern.mode.label}. '
        '${pattern.factualOutcomeSummary}'
        '${pattern.pinned ? ', pinned' : ''}'
        '${proposal ? ', suggested from your records' : ''}. '
        'Activate to inspect the records behind this.';

    return Semantics(
      button: onInspect != null,
      label: semanticsLabel,
      child: InkWell(
        onTap: onInspect,
        borderRadius: ExperienceRadius.cardRadius,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: ExperienceColors.surface,
            borderRadius: ExperienceRadius.cardRadius,
            border: Border.all(color: ExperienceColors.hairline),
            boxShadow: ExperienceShadows.card,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(ExperienceRadius.card),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(ExperienceSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                pattern.actionLabel,
                                style: ExperienceType.headline(
                                  ExperienceColors.ink,
                                ),
                              ),
                            ),
                            if (pattern.pinned)
                              const Padding(
                                padding: EdgeInsets.only(left: 8, top: 2),
                                child: Icon(
                                  Icons.push_pin_outlined,
                                  size: 16,
                                  color: ExperienceColors.inkSoft,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: ExperienceSpacing.xs),
                        Text(
                          pattern.mode.label,
                          style: ExperienceType.caption(
                            ExperienceColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: ExperienceSpacing.xs),
                        Text(
                          proposal
                              ? 'Your records suggest: '
                                    '${pattern.factualOutcomeSummary}.'
                              : '${pattern.factualOutcomeSummary}.',
                          style: ExperienceType.bodySmall(ExperienceColors.ink),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Observed symptom narrative — factual, engine-derived, spectrum accent at
// stepped-down weight (narratives never compete with the expanded chart).
// ---------------------------------------------------------------------------

class _SymptomNarrativeCard extends StatelessWidget {
  const _SymptomNarrativeCard({required this.pattern, this.onInspect});

  final ObservedSymptomPattern pattern;
  final VoidCallback? onInspect;

  static T? _topKey<T>(Map<T, int> counts) {
    T? best;
    var bestCount = -1;
    for (final entry in counts.entries) {
      if (entry.value > bestCount) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    return best;
  }

  String _narrative() {
    final buffer = StringBuffer(
      'Recorded ${pattern.count} times, '
      '${summaryDateLabel(pattern.firstDate)} – '
      '${summaryDateLabel(pattern.lastDate)}.',
    );
    final severity = _topKey(pattern.severityCounts);
    if (severity != null) {
      buffer.write(' Most often ${severity.label.toLowerCase()}.');
    }
    final impact = _topKey(pattern.functionalImpactCounts);
    if (impact != null) {
      buffer.write(' Most often affects: ${impact.label.toLowerCase()}.');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ExperienceColors.accentSpectrum.withValues(alpha: 0.45);
    return Semantics(
      button: onInspect != null,
      label:
          '${pattern.symptom.label}. ${_narrative()} '
          'Activate to inspect the records behind this.',
      child: InkWell(
        onTap: onInspect,
        borderRadius: ExperienceRadius.cardRadius,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: ExperienceColors.surface,
            borderRadius: ExperienceRadius.cardRadius,
            border: Border.all(color: ExperienceColors.hairline),
            boxShadow: ExperienceShadows.card,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(ExperienceRadius.card),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(ExperienceSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          pattern.symptom.label,
                          style: ExperienceType.headline(ExperienceColors.ink),
                        ),
                        const SizedBox(height: ExperienceSpacing.xs),
                        Text(
                          _narrative(),
                          style: ExperienceType.bodySmall(ExperienceColors.ink),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Locked narrative card — concrete value and real evidence counts, never a
// blurred fake chart, never a hard sell.
// ---------------------------------------------------------------------------

class _LockedNarrativeCard extends StatelessWidget {
  const _LockedNarrativeCard({required this.recordCount, this.onOpenPlus});

  final int recordCount;
  final VoidCallback? onOpenPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ExperienceColors.surface,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(color: ExperienceColors.hairline),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: ExperienceColors.accentSpectrum.withValues(alpha: 0.45),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(ExperienceRadius.card),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(ExperienceSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Your records hold stories Plus can read aloud.',
                      style: ExperienceType.bodyStrong(ExperienceColors.ink),
                    ),
                    const SizedBox(height: ExperienceSpacing.xs),
                    Semantics(
                      label:
                          'You have $recordCount confirmed symptom records. '
                          'Plus turns repeated observations into plain-'
                          'language narratives. Tracking and your records '
                          'stay free.',
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
                                text: '$recordCount',
                                style: ExperienceType.data(
                                  ExperienceColors.ink,
                                  size: 14,
                                ),
                              ),
                              TextSpan(
                                text:
                                    ' confirmed symptom '
                                    '${recordCount == 1 ? 'record' : 'records'}. '
                                    'Plus turns repeated observations into '
                                    'plain-language narratives — tracking and '
                                    'your records stay free.',
                                style: ExperienceType.bodySmall(
                                  ExperienceColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (onOpenPlus != null) ...<Widget>[
                      const SizedBox(height: ExperienceSpacing.xs + 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: onOpenPlus,
                          child: const Text('See what Plus adds'),
                        ),
                      ),
                    ],
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

// ---------------------------------------------------------------------------
// Reports route row — quiet, never a dead panel.
// ---------------------------------------------------------------------------

class _ReportsRow extends StatelessWidget {
  const _ReportsRow({this.onOpenReports});

  final VoidCallback? onOpenReports;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onOpenReports != null,
      label:
          'Reports. Share a factual summary with your clinician, on '
          'your terms. Activate to open Reports.',
      child: InkWell(
        onTap: onOpenReports,
        borderRadius: ExperienceRadius.cardRadius,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: ExperienceColors.surface,
            borderRadius: ExperienceRadius.cardRadius,
            border: Border.all(color: ExperienceColors.hairline),
          ),
          padding: const EdgeInsets.all(ExperienceSpacing.sm),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.ios_share_outlined,
                size: 18,
                color: ExperienceColors.inkSoft,
              ),
              const SizedBox(width: ExperienceSpacing.xs + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Reports',
                      style: ExperienceType.bodyStrong(ExperienceColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'A factual summary for your clinician — '
                      'non-diagnostic, on your terms.',
                      style: ExperienceType.caption(ExperienceColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: ExperienceColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}
