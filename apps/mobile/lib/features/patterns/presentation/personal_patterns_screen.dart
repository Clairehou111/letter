import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../../care/domain/care_mode.dart';
import '../../health_records/domain/health_record.dart';
import '../../insights/presentation/hormonal_spectrum_strip.dart';
import '../../insights/presentation/spectrum_log_view_model.dart';
import '../../preparation/domain/preparation_plan.dart';
import '../../preparation/presentation/next_window_card.dart';
import '../domain/pattern_source.dart';
import '../domain/personal_pattern.dart';

class PersonalPatternsScreen extends StatefulWidget {
  const PersonalPatternsScreen({
    required this.analysis,
    super.key,
    this.source,
    this.onBack,
    this.onCareModeChanged,
    this.onDismissPattern,
    this.onUnpinAction,
    this.onEditSource,
    this.onDeleteSource,
    this.preparationRepository,
  });

  final PersonalPatternAnalysis analysis;
  final PatternSourceSnapshot? source;
  final VoidCallback? onBack;
  final ValueChanged<CareMode?>? onCareModeChanged;
  final ValueChanged<String>? onDismissPattern;
  final ValueChanged<String>? onUnpinAction;
  final ValueChanged<String>? onEditSource;
  final ValueChanged<String>? onDeleteSource;
  final PreparationRepository? preparationRepository;

  @override
  State<PersonalPatternsScreen> createState() => _PersonalPatternsScreenState();

  static SpectrumLogViewModel _spectrumViewModel(
    PersonalPatternAnalysis _,
    PatternSourceSnapshot? source,
  ) {
    // Spectrum requires raw confirmed ratings. Pattern aggregates cannot be
    // expanded back into trustworthy per-record source values.
    return SpectrumLogViewModel.fromSource(
      source ?? const PatternSourceSnapshot(),
    );
  }
}

class _PersonalPatternsScreenState extends State<PersonalPatternsScreen> {
  var _careHistoryExpanded = false;
  List<PreparationDismissal> _dismissals = const [];

  @override
  void initState() {
    super.initState();
    _loadDismissals();
  }

  Future<void> _loadDismissals() async {
    final repository = widget.preparationRepository;
    if (repository == null) return;
    try {
      final dismissals = await repository.getDismissals();
      if (mounted) setState(() => _dismissals = dismissals);
    } on Object {
      // Patterns remains usable if the optional preparation memory cannot load.
    }
  }

  Future<void> _openDismissals() async {
    final repository = widget.preparationRepository;
    if (repository == null) return;
    await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (context) => RestoreDismissedPreparationScreen(
          repository: repository,
          dismissals: _dismissals,
        ),
      ),
    );
    if (mounted) await _loadDismissals();
  }

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;
    final analysis = widget.analysis;
    final spectrumViewModel = PersonalPatternsScreen._spectrumViewModel(
      analysis,
      widget.source,
    );
    final spectrumCount = spectrumViewModel.confirmedRatingCount;
    final confirmedCount = spectrumCount > 0
        ? spectrumCount
        : analysis.symptomPatterns.fold<int>(
            0,
            (total, pattern) => total + pattern.count,
          );
    final cyclesCovered = spectrumViewModel.data.cyclesCovered;
    return Scaffold(
      key: const Key('personal-patterns-screen'),
      backgroundColor: LetterColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth >= 840 ? 720 : 600,
              ),
              child: CustomScrollView(
                key: const Key('personal-patterns-scroll'),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    sliver: SliverList.list(
                      children: [
                        if (widget.onBack != null) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              key: const Key('personal-patterns-back'),
                              tooltip: 'Back',
                              onPressed: widget.onBack,
                              icon: const Icon(Icons.arrow_back),
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                            ),
                          ),
                          const SizedBox(height: LetterSpacing.xs),
                        ],
                        const LetterEyebrow(
                          'Patterns',
                          color: LetterColors.teal,
                        ),
                        const SizedBox(height: LetterSpacing.md),
                        Text(
                          confirmedCount == 0
                              ? 'Nothing has been confirmed yet'
                              : 'Two views of the same records',
                          style: TextStyle(
                            color: LetterColors.ink,
                            fontFamily: 'Newsreader',
                            fontSize: largeText ? 26 : 32,
                            height: 1.08,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: LetterSpacing.xs),
                        Text(
                          confirmedCount == 0
                              ? 'Patterns is built only from symptom records you '
                                    'confirmed before a recorded period. Until then '
                                    'there is nothing to read here.'
                              : 'Timing before periods arranges your $confirmedCount '
                                    'confirmed ${confirmedCount == 1 ? 'record' : 'records'} '
                                    'by day. Symptoms that recur groups those same '
                                    'records by symptom. Neither adds anything you '
                                    'did not record.',
                          style: const TextStyle(
                            color: LetterColors.muted,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        if (cyclesCovered > 0) ...[
                          const SizedBox(height: LetterSpacing.sm),
                          Text(
                            '$confirmedCount confirmed '
                            '${confirmedCount == 1 ? 'record' : 'records'} across '
                            '$cyclesCovered completed '
                            '${cyclesCovered == 1 ? 'cycle' : 'cycles'}.',
                            style: const TextStyle(
                              color: LetterColors.muted,
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                        const SizedBox(height: LetterSpacing.xl),
                        const LetterSectionTitle(
                          eyebrow: 'View one',
                          title: 'Timing before periods',
                        ),
                        const SizedBox(height: LetterSpacing.sm),
                        HormonalSpectrumStrip(viewModel: spectrumViewModel),
                        const SizedBox(height: LetterSpacing.xl),
                        const LetterSectionTitle(
                          eyebrow: 'View two',
                          title: 'Symptoms that recur',
                        ),
                        const SizedBox(height: LetterSpacing.md),
                        if (analysis.symptomPatterns.isEmpty)
                          const _InsufficientHistory()
                        else
                          for (final pattern in analysis.symptomPatterns) ...[
                            _SymptomPatternCard(
                              pattern: pattern,
                              onDismiss: widget.onDismissPattern,
                              onEditSource: widget.onEditSource,
                              onDeleteSource: widget.onDeleteSource,
                            ),
                            const SizedBox(height: LetterSpacing.sm),
                          ],
                        if (_dismissals.isNotEmpty) ...[
                          const SizedBox(height: LetterSpacing.xs),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              key: const Key('prep_restore_entry'),
                              onPressed: _openDismissals,
                              child: const Text(
                                'Restore a dismissed suggestion',
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: LetterSpacing.xl),
                        _CareHistorySection(
                          expanded: _careHistoryExpanded,
                          actions: analysis.supportActions,
                          selectedMode: analysis.selectedCareMode,
                          onToggle: () => setState(
                            () => _careHistoryExpanded = !_careHistoryExpanded,
                          ),
                          onModeChanged: widget.onCareModeChanged,
                          onDismiss: widget.onDismissPattern,
                          onUnpin: widget.onUnpinAction,
                          onDeleteSource: widget.onDeleteSource,
                        ),
                      ],
                    ),
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

class _CareHistorySection extends StatelessWidget {
  const _CareHistorySection({
    required this.expanded,
    required this.actions,
    required this.selectedMode,
    required this.onToggle,
    this.onModeChanged,
    this.onDismiss,
    this.onUnpin,
    this.onDeleteSource,
  });

  final bool expanded;
  final List<SupportActionPattern> actions;
  final CareMode? selectedMode;
  final VoidCallback onToggle;
  final ValueChanged<CareMode?>? onModeChanged;
  final ValueChanged<String>? onDismiss;
  final ValueChanged<String>? onUnpin;
  final ValueChanged<String>? onDeleteSource;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            child: InkWell(
              key: const Key('personal-patterns-care-toggle'),
              onTap: onToggle,
              borderRadius: BorderRadius.circular(LetterRadius.panel),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.all(LetterSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: LetterColors.teal.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(
                            LetterRadius.control,
                          ),
                        ),
                        child: const Icon(
                          Icons.self_improvement_outlined,
                          color: LetterColors.teal,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: LetterSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const LetterEyebrow(
                              'Your Care history',
                              color: LetterColors.teal,
                            ),
                            const SizedBox(height: LetterSpacing.xxs),
                            Text(
                              actions.isEmpty
                                  ? 'No completed check-backs in this view'
                                  : '${actions.length} ${actions.length == 1 ? 'action' : 'actions'} you have tried',
                              style: const TextStyle(
                                color: LetterColors.ink,
                                fontSize: 15,
                                height: 1.35,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        color: LetterColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: LetterColors.line),
            Padding(
              padding: const EdgeInsets.all(LetterSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: _CareModeMenu(
                      selectedMode: selectedMode,
                      onChanged: onModeChanged,
                    ),
                  ),
                  const SizedBox(height: LetterSpacing.md),
                  if (actions.isEmpty)
                    const _NoPriorActions()
                  else
                    for (final action in actions) ...[
                      _SupportActionCard(
                        action: action,
                        onDismiss: onDismiss,
                        onUnpin: action.pinned ? onUnpin : null,
                        onDeleteSource: onDeleteSource,
                      ),
                      const SizedBox(height: LetterSpacing.sm),
                    ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpandableEvidencePanel extends StatefulWidget {
  const _ExpandableEvidencePanel({
    required this.toggleKey,
    required this.title,
    required this.countLabel,
    required this.rangeLabel,
    required this.summaryLabel,
    required this.evidence,
    super.key,
    this.menu,
  });

  final String title;
  final Key toggleKey;
  final String countLabel;
  final String rangeLabel;
  final String summaryLabel;
  final List<Widget> evidence;
  final Widget? menu;

  @override
  State<_ExpandableEvidencePanel> createState() =>
      _ExpandableEvidencePanelState();
}

class _ExpandableEvidencePanelState extends State<_ExpandableEvidencePanel> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LetterSpacing.md,
              LetterSpacing.md,
              LetterSpacing.xs,
              LetterSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: LetterColors.coral.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(LetterRadius.control),
                  ),
                  child: const Icon(
                    Icons.monitor_heart_outlined,
                    color: LetterColors.coral,
                    size: 20,
                  ),
                ),
                const SizedBox(width: LetterSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.xxs),
                      Text(
                        widget.countLabel,
                        style: const TextStyle(
                          color: LetterColors.muted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.xxs),
                      Text(
                        widget.rangeLabel,
                        style: const TextStyle(
                          color: LetterColors.muted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.xxs),
                      Text(
                        widget.summaryLabel,
                        style: const TextStyle(
                          color: LetterColors.tealDark,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                ?widget.menu,
              ],
            ),
          ),
          Semantics(
            button: true,
            expanded: _expanded,
            child: InkWell(
              key: widget.toggleKey,
              onTap: () => setState(() => _expanded = !_expanded),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LetterSpacing.md,
                    vertical: LetterSpacing.xs,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _expanded ? 'Hide evidence' : 'View evidence',
                        style: const TextStyle(
                          color: LetterColors.teal,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: LetterColors.teal,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: LetterColors.line),
            Padding(
              padding: const EdgeInsets.all(LetterSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.evidence,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceDateChip extends StatelessWidget {
  const _EvidenceDateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(
        horizontal: LetterSpacing.sm,
        vertical: LetterSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: LetterColors.canvas,
        borderRadius: BorderRadius.circular(LetterRadius.control),
        border: Border.all(color: LetterColors.line),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

class _SymptomPatternCard extends StatelessWidget {
  const _SymptomPatternCard({
    required this.pattern,
    this.onDismiss,
    this.onEditSource,
    this.onDeleteSource,
  });

  final ObservedSymptomPattern pattern;
  final ValueChanged<String>? onDismiss;
  final ValueChanged<String>? onEditSource;
  final ValueChanged<String>? onDeleteSource;

  @override
  Widget build(BuildContext context) {
    return _ExpandableEvidencePanel(
      key: Key('symptom-pattern-${pattern.id}'),
      toggleKey: Key('symptom-evidence-toggle-${pattern.id}'),
      title: pattern.symptom.label,
      countLabel: '${pattern.count} confirmed records',
      rangeLabel: '${pattern.firstDate} – ${pattern.lastDate}',
      summaryLabel: 'Most often ${_mostCommonSeverity(pattern).label}',
      menu: _PatternMenu(
        patternId: pattern.id,
        sourceId: pattern.sources.first.id,
        onDismiss: onDismiss,
        onEditSource: onEditSource,
        onDeleteSource: onDeleteSource,
      ),
      evidence: [
        Text(
          'DATES YOU RECORDED IT',
          key: Key('symptom-pattern-dates-${pattern.id}'),
          style: const TextStyle(
            color: LetterColors.muted,
            fontSize: 11,
            letterSpacing: .8,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: LetterSpacing.xs),
        Wrap(
          spacing: LetterSpacing.xs,
          runSpacing: LetterSpacing.xs,
          children: [
            for (final date in pattern.coveredDates)
              _EvidenceDateChip(label: '$date'),
          ],
        ),
        const SizedBox(height: LetterSpacing.md),
        const Text(
          'HOW SEVERE YOU SAID IT WAS',
          style: TextStyle(
            color: LetterColors.muted,
            fontSize: 11,
            letterSpacing: .8,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: LetterSpacing.xs),
        Text(
          _severitySummary(pattern),
          key: Key('symptom-pattern-severity-${pattern.id}'),
          style: const TextStyle(
            color: LetterColors.muted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        if (pattern.functionalImpactCounts.isNotEmpty) ...[
          const SizedBox(height: LetterSpacing.xs),
          Text(
            _countSummary('Impact recorded', pattern.functionalImpactCounts),
            style: const TextStyle(
              color: LetterColors.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
        if (pattern.comparisonBasis == PatternComparisonBasis.observedCycleDays)
          Padding(
            padding: const EdgeInsets.only(top: LetterSpacing.xs),
            child: Text(
              'Also observed on the same cycle day in '
              '${pattern.cycleDayObservations.length} records.',
              style: const TextStyle(
                color: LetterColors.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }

  SymptomSeverity _mostCommonSeverity(ObservedSymptomPattern pattern) {
    final entries = pattern.severityCounts.entries.toList()
      ..sort((left, right) {
        final byCount = right.value.compareTo(left.value);
        if (byCount != 0) return byCount;
        return left.key.score.compareTo(right.key.score);
      });
    return entries.first.key;
  }

  String _severitySummary(ObservedSymptomPattern pattern) {
    final entries = pattern.severityCounts.entries.toList()
      ..sort((left, right) => left.key.score.compareTo(right.key.score));
    return 'Recorded severity: ${entries.map((item) => '${item.key.label} ${item.value}').join(' · ')}';
  }

  String _countSummary<T>(String heading, Map<T, int> values) {
    final entries = values.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    String label(T value) {
      if (value is FunctionalImpact) {
        return value.label;
      }
      return value.toString();
    }

    return '$heading: ${entries.map((item) => '${label(item.key)} ${item.value}').join(' · ')}';
  }
}

class _SupportActionCard extends StatelessWidget {
  const _SupportActionCard({
    required this.action,
    this.onDismiss,
    this.onUnpin,
    this.onDeleteSource,
  });

  final SupportActionPattern action;
  final ValueChanged<String>? onDismiss;
  final ValueChanged<String>? onUnpin;
  final ValueChanged<String>? onDeleteSource;

  @override
  Widget build(BuildContext context) {
    return _PatternPanel(
      key: Key('support-action-${action.id}'),
      icon: Icons.bookmark_outline,
      iconColor: LetterColors.teal,
      title: action.actionLabel,
      subtitle: action.mode.label,
      menu: _PatternMenu(
        patternId: action.id,
        sourceId: action.sources.first.id,
        onDismiss: onDismiss,
        onUnpin: action.pinned ? onUnpin : null,
        onDeleteSource: onDeleteSource,
      ),
      children: [
        Text(
          'Recorded ${action.count} ${action.count == 1 ? 'time' : 'times'} '
          'from ${action.firstDate} to ${action.lastDate}.',
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: LetterSpacing.sm),
        Text(
          action.factualOutcomeSummary,
          key: Key('support-action-summary-${action.id}'),
          style: const TextStyle(
            color: LetterColors.tealDark,
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: LetterSpacing.xs),
        Text(
          'Same ${action.sameCount} · Worse ${action.worseCount}',
          key: Key('support-action-outcomes-${action.id}'),
          style: const TextStyle(
            color: LetterColors.muted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        if (action.pinned) ...[
          const SizedBox(height: LetterSpacing.sm),
          const _HistoryLabel('Kept by you'),
        ],
        for (final reflection in action.reflections) ...[
          const SizedBox(height: LetterSpacing.sm),
          _ReflectionQuote(text: reflection.text),
        ],
      ],
    );
  }
}

class _PatternPanel extends StatelessWidget {
  const _PatternPanel({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.children,
    super.key,
    this.menu,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LetterSpacing.lg),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(LetterRadius.control),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: LetterSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: LetterSpacing.xxs),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: LetterColors.muted,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              ?menu,
            ],
          ),
          const SizedBox(height: LetterSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

class _PatternMenu extends StatelessWidget {
  const _PatternMenu({
    required this.patternId,
    required this.sourceId,
    this.onDismiss,
    this.onUnpin,
    this.onEditSource,
    this.onDeleteSource,
  });

  final String patternId;
  final String sourceId;
  final ValueChanged<String>? onDismiss;
  final ValueChanged<String>? onUnpin;
  final ValueChanged<String>? onEditSource;
  final ValueChanged<String>? onDeleteSource;

  @override
  Widget build(BuildContext context) {
    final hasActions =
        onDismiss != null ||
        onUnpin != null ||
        onEditSource != null ||
        onDeleteSource != null;
    if (!hasActions) {
      return const SizedBox(width: 8);
    }
    return PopupMenuButton<String>(
      key: Key('pattern-menu-$patternId'),
      tooltip: 'Manage this history',
      onSelected: (value) {
        switch (value) {
          case 'dismiss':
            onDismiss?.call(patternId);
          case 'unpin':
            onUnpin?.call(sourceId);
          case 'edit':
            onEditSource?.call(sourceId);
          case 'delete':
            onDeleteSource?.call(sourceId);
        }
      },
      itemBuilder: (context) => [
        if (onDismiss != null)
          const PopupMenuItem(value: 'dismiss', child: Text('Hide this view')),
        if (onUnpin != null)
          const PopupMenuItem(value: 'unpin', child: Text('Unpin this action')),
        if (onEditSource != null)
          const PopupMenuItem(value: 'edit', child: Text('Edit source record')),
        if (onDeleteSource != null)
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete source record'),
          ),
      ],
    );
  }
}

class _CareModeMenu extends StatelessWidget {
  const _CareModeMenu({required this.selectedMode, this.onChanged});

  final CareMode? selectedMode;
  final ValueChanged<CareMode?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<CareMode>(
      key: const Key('personal-patterns-care-mode'),
      value: selectedMode,
      hint: const Text('All modes'),
      underline: const SizedBox.shrink(),
      isDense: true,
      isExpanded: true,
      onChanged: onChanged == null ? null : (mode) => onChanged!(mode),
      items: [
        for (final mode in CareMode.values)
          DropdownMenuItem(value: mode, child: Text(mode.label)),
      ],
    );
  }
}

class _InsufficientHistory extends StatelessWidget {
  const _InsufficientHistory();

  @override
  Widget build(BuildContext context) {
    return const _QuietPanel(
      key: Key('personal-patterns-insufficient-history'),
      title: 'Not enough repeated records yet',
      body:
          'A pattern appears after two comparable confirmed records. '
          'Letter Within will leave missing days blank.',
    );
  }
}

class _NoPriorActions extends StatelessWidget {
  const _NoPriorActions();

  @override
  Widget build(BuildContext context) {
    return const _QuietPanel(
      key: Key('personal-patterns-no-actions'),
      title: 'No prior Care actions in this view',
      body:
          'Actions appear here only after you choose one and record a '
          'check-back. General comfort stays separate below.',
    );
  }
}

class _QuietPanel extends StatelessWidget {
  const _QuietPanel({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LetterSpacing.lg),
      decoration: BoxDecoration(
        color: LetterColors.blueSoft,
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: LetterSpacing.xs),
          Text(
            body,
            style: const TextStyle(
              color: LetterColors.muted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryLabel extends StatelessWidget {
  const _HistoryLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: LetterColors.tealDark,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ReflectionQuote extends StatelessWidget {
  const _ReflectionQuote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: BoxDecoration(
        color: LetterColors.amberSoft,
        borderRadius: BorderRadius.circular(LetterRadius.control),
      ),
      child: Text(
        'Your words: “$text”',
        style: const TextStyle(fontSize: 13, height: 1.45),
      ),
    );
  }
}
