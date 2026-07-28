import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../../care/domain/care_mode.dart';
import '../../health_records/domain/health_record.dart';
import '../domain/personal_pattern.dart';

class PersonalPatternsScreen extends StatelessWidget {
  const PersonalPatternsScreen({
    required this.analysis,
    super.key,
    this.onBack,
    this.onCareModeChanged,
    this.onDismissPattern,
    this.onUnpinAction,
    this.onEditSource,
    this.onDeleteSource,
  });

  final PersonalPatternAnalysis analysis;
  final VoidCallback? onBack;
  final ValueChanged<CareMode?>? onCareModeChanged;
  final ValueChanged<String>? onDismissPattern;
  final ValueChanged<String>? onUnpinAction;
  final ValueChanged<String>? onEditSource;
  final ValueChanged<String>? onDeleteSource;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;
    return Scaffold(
      key: const Key('personal-patterns-screen'),
      backgroundColor: LetterColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: CustomScrollView(
              key: const Key('personal-patterns-scroll'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
                  sliver: SliverList.list(
                    children: [
                      if (onBack != null) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            key: const Key('personal-patterns-back'),
                            tooltip: 'Back',
                            onPressed: onBack,
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
                        'Your observed history',
                        color: LetterColors.teal,
                      ),
                      const SizedBox(height: LetterSpacing.md),
                      Text(
                        'What has repeated',
                        style: TextStyle(
                          color: LetterColors.ink,
                          fontFamily: 'Newsreader',
                          fontSize: largeText ? 26 : 32,
                          height: 1.08,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.xs),
                      const Text(
                        'A factual view of confirmed records and the Care actions '
                        'you have already tried. Nothing here fills in missing days.',
                        style: TextStyle(
                          color: LetterColors.muted,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.xl),
                      const LetterSectionTitle(
                        eyebrow: 'Repeated records',
                        title: 'What your body has said more than once',
                      ),
                      const SizedBox(height: LetterSpacing.md),
                      if (analysis.symptomPatterns.isEmpty)
                        const _InsufficientHistory()
                      else
                        for (final pattern in analysis.symptomPatterns) ...[
                          _SymptomPatternCard(
                            pattern: pattern,
                            onDismiss: onDismissPattern,
                            onEditSource: onEditSource,
                            onDeleteSource: onDeleteSource,
                          ),
                          const SizedBox(height: LetterSpacing.sm),
                        ],
                      const SizedBox(height: LetterSpacing.xl),
                      LetterSectionTitle(
                        eyebrow: 'Your Care history',
                        title: 'Actions you have already chosen',
                        action: _CareModeMenu(
                          selectedMode: analysis.selectedCareMode,
                          onChanged: onCareModeChanged,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.md),
                      if (analysis.supportActions.isEmpty)
                        const _NoPriorActions()
                      else
                        for (final action in analysis.supportActions) ...[
                          _SupportActionCard(
                            action: action,
                            onDismiss: onDismissPattern,
                            onUnpin: onUnpinAction,
                            onDeleteSource: onDeleteSource,
                          ),
                          const SizedBox(height: LetterSpacing.sm),
                        ],
                      const SizedBox(height: LetterSpacing.xl),
                      const _GeneralComfortSection(),
                    ],
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
    return _PatternPanel(
      key: Key('symptom-pattern-${pattern.id}'),
      icon: Icons.edit_note,
      iconColor: LetterColors.coral,
      title: pattern.symptom.label,
      subtitle: '${pattern.count} confirmed records',
      menu: _PatternMenu(
        patternId: pattern.id,
        sourceId: pattern.sources.first.id,
        onDismiss: onDismiss,
        onEditSource: onEditSource,
        onDeleteSource: onDeleteSource,
      ),
      children: [
        Text(
          'Recorded ${pattern.count} times from ${pattern.firstDate} to '
          '${pattern.lastDate}.',
          key: Key('symptom-pattern-dates-${pattern.id}'),
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: LetterSpacing.sm),
        Text(
          'Observed dates: ${pattern.coveredDates.join(', ')}',
          style: const TextStyle(
            color: LetterColors.muted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: LetterSpacing.sm),
        Text(
          _severitySummary(pattern),
          key: Key('symptom-pattern-severity-${pattern.id}'),
          style: const TextStyle(
            color: LetterColors.muted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        if (pattern.painLocationCounts.isNotEmpty) ...[
          const SizedBox(height: LetterSpacing.xs),
          Text(
            _countSummary('Pain locations', pattern.painLocationCounts),
            style: const TextStyle(
              color: LetterColors.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
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
      if (value is PainLocation) {
        return value.label;
      }
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
          'Letter will leave missing days blank.',
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

class _GeneralComfortSection extends StatelessWidget {
  const _GeneralComfortSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LetterSectionTitle(
          eyebrow: 'Separate from your history',
          title: 'General comfort ideas',
        ),
        const SizedBox(height: LetterSpacing.sm),
        const Text(
          'These are general options, not personal findings or promises.',
          style: TextStyle(
            color: LetterColors.muted,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: LetterSpacing.sm),
        Wrap(
          spacing: LetterSpacing.xs,
          runSpacing: LetterSpacing.xs,
          children: const [
            Chip(label: Text('Lower the input around you')),
            Chip(label: Text('Try a familiar comfort')),
            Chip(label: Text('Give the next minute less to hold')),
          ],
        ),
      ],
    );
  }
}
