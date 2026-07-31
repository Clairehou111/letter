import 'package:flutter/material.dart';

import '../../../design_system/letter_bottom_navigation.dart';
import '../../../design_system/letter_theme.dart';

enum CycleLettersStatus { loading, error, ready }

@immutable
class CycleLettersViewModel {
  const CycleLettersViewModel({
    required this.status,
    this.completedLetters = const [],
    this.currentCycle,
    this.unassignedCareRecords = const [],
  });

  const CycleLettersViewModel.loading()
    : status = CycleLettersStatus.loading,
      completedLetters = const [],
      currentCycle = null,
      unassignedCareRecords = const [];

  const CycleLettersViewModel.error()
    : status = CycleLettersStatus.error,
      completedLetters = const [],
      currentCycle = null,
      unassignedCareRecords = const [];

  final CycleLettersStatus status;
  final List<CycleLetterDisplay> completedLetters;
  final CycleLetterDisplay? currentCycle;
  final List<UnassignedCareDisplay> unassignedCareRecords;
}

@immutable
class CycleLetterDisplay {
  const CycleLetterDisplay({
    required this.id,
    required this.dateRange,
    required this.recordedPeriodDates,
    required this.careMoments,
    required this.checkBackCounts,
    required this.notRecorded,
    this.letterNumber,
    this.reflection,
  });

  final String id;
  final int? letterNumber;
  final String dateRange;
  final List<String> recordedPeriodDates;
  final List<CycleLetterCareMomentDisplay> careMoments;
  final CycleLetterCheckBackCounts checkBackCounts;
  final CycleLetterReflectionDisplay? reflection;
  final List<String> notRecorded;

  bool get isComplete => letterNumber != null;
}

@immutable
class CycleLetterCareMomentDisplay {
  const CycleLetterCareMomentDisplay({
    required this.dateLabel,
    required this.actionLabel,
    this.id,
    this.checkBackLabel,
    this.reflectionId,
    this.reflectionPreview,
  });

  final String? id;
  final String dateLabel;
  final String actionLabel;
  final String? checkBackLabel;
  final String? reflectionId;
  final String? reflectionPreview;
}

@immutable
class CycleLetterCheckBackCounts {
  const CycleLetterCheckBackCounts({
    this.better = 0,
    this.same = 0,
    this.worse = 0,
  });

  final int better;
  final int same;
  final int worse;

  int get total => better + same + worse;
}

@immutable
class CycleLetterReflectionDisplay {
  const CycleLetterReflectionDisplay({
    required this.id,
    required this.dateLabel,
  });

  final String id;
  final String dateLabel;
}

@immutable
class UnassignedCareDisplay {
  const UnassignedCareDisplay({
    required this.id,
    required this.dateLabel,
    required this.actionLabel,
    this.checkBackLabel,
  });

  final String id;
  final String dateLabel;
  final String actionLabel;
  final String? checkBackLabel;
}

class CycleLettersScreen extends StatelessWidget {
  const CycleLettersScreen({
    required this.viewModel,
    super.key,
    this.selectedLetterId,
    this.onNavigationSelected,
    this.onRetry,
    this.onLetterOpen,
    this.onLetterClose,
    this.onReflectionOpen,
    this.onCareRecordReflect,
    this.onOpenArchiveViews,
    this.onOpenPersonalPatterns,
  });

  final CycleLettersViewModel viewModel;
  final String? selectedLetterId;
  final ValueChanged<int>? onNavigationSelected;
  final VoidCallback? onRetry;
  final ValueChanged<String>? onLetterOpen;
  final VoidCallback? onLetterClose;
  final ValueChanged<String>? onReflectionOpen;
  final ValueChanged<String>? onCareRecordReflect;
  final VoidCallback? onOpenArchiveViews;
  final VoidCallback? onOpenPersonalPatterns;

  CycleLetterDisplay? _selectedLetter() {
    final id = selectedLetterId;
    if (id == null) {
      return null;
    }
    if (viewModel.currentCycle?.id == id) {
      return viewModel.currentCycle;
    }
    for (final letter in viewModel.completedLetters) {
      if (letter.id == id) {
        return letter;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedLetter = _selectedLetter();
    return Scaffold(
      bottomNavigationBar: LetterBottomNavigation(
        selectedIndex: 3,
        onSelected: onNavigationSelected,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: switch (viewModel.status) {
              CycleLettersStatus.loading => const _ArchiveLoading(),
              CycleLettersStatus.error => _ArchiveError(onRetry: onRetry),
              CycleLettersStatus.ready =>
                selectedLetterId == null
                    ? _ArchiveList(
                        viewModel: viewModel,
                        onLetterOpen: onLetterOpen,
                        onOpenArchiveViews: onOpenArchiveViews,
                        onOpenPersonalPatterns: onOpenPersonalPatterns,
                      )
                    : selectedLetter == null
                    ? _MissingLetter(onBack: onLetterClose)
                    : _CycleLetterDetail(
                        letter: selectedLetter,
                        onBack: onLetterClose,
                        onReflectionOpen: onReflectionOpen,
                        onCareRecordReflect: onCareRecordReflect,
                      ),
            },
          ),
        ),
      ),
    );
  }
}

class _ArchiveLoading extends StatelessWidget {
  const _ArchiveLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Opening private cycle letters',
        child: const CircularProgressIndicator(color: LetterColors.teal),
      ),
    );
  }
}

class _ArchiveError extends StatelessWidget {
  const _ArchiveError({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(LetterSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 34, color: LetterColors.teal),
            const SizedBox(height: LetterSpacing.md),
            const Text(
              'Your private cycle letters could not be opened.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 25,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: LetterSpacing.sm),
            const Text(
              'Nothing has been changed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: LetterColors.muted),
            ),
            const SizedBox(height: LetterSpacing.lg),
            FilledButton.icon(
              key: const Key('cycle-letters-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveList extends StatelessWidget {
  const _ArchiveList({
    required this.viewModel,
    required this.onLetterOpen,
    required this.onOpenArchiveViews,
    required this.onOpenPersonalPatterns,
  });

  final CycleLettersViewModel viewModel;
  final ValueChanged<String>? onLetterOpen;
  final VoidCallback? onOpenArchiveViews;
  final VoidCallback? onOpenPersonalPatterns;

  @override
  Widget build(BuildContext context) {
    final hasCycleRecord =
        viewModel.currentCycle != null || viewModel.completedLetters.isNotEmpty;
    return CustomScrollView(
      key: const Key('cycle-letters-scroll-view'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          sliver: SliverList.list(
            children: [
              const _ArchiveHeader(),
              const SizedBox(height: LetterSpacing.md),
              _LettersDestinations(
                onOpenPatterns: onOpenPersonalPatterns,
                onOpenReports: onOpenArchiveViews,
              ),
              const SizedBox(height: LetterSpacing.xl),
              if (!hasCycleRecord) const _NoPeriodsRecorded(),
              if (viewModel.currentCycle case final current?) ...[
                const LetterSectionTitle(
                  eyebrow: 'Still being recorded',
                  title: 'Current cycle',
                ),
                const SizedBox(height: LetterSpacing.sm),
                _CycleLetterRow(
                  letter: current,
                  onOpen: onLetterOpen == null
                      ? null
                      : () => onLetterOpen!(current.id),
                ),
              ],
              if (viewModel.currentCycle != null &&
                  viewModel.completedLetters.isNotEmpty)
                const SizedBox(height: LetterSpacing.xl),
              if (viewModel.completedLetters.isNotEmpty) ...[
                const LetterSectionTitle(
                  eyebrow: 'Completed cycles',
                  title: 'Cycle letters',
                ),
                const SizedBox(height: LetterSpacing.sm),
                ...viewModel.completedLetters.map(
                  (letter) => Padding(
                    padding: const EdgeInsets.only(bottom: LetterSpacing.sm),
                    child: _CycleLetterRow(
                      letter: letter,
                      onOpen: onLetterOpen == null
                          ? null
                          : () => onLetterOpen!(letter.id),
                    ),
                  ),
                ),
              ],
              if (viewModel.unassignedCareRecords.isNotEmpty) ...[
                const SizedBox(height: LetterSpacing.xl),
                const LetterSectionTitle(
                  eyebrow: 'Kept, not discarded',
                  title: 'Not assigned to a completed cycle',
                ),
                const SizedBox(height: LetterSpacing.xs),
                const Text(
                  'These Care records fall outside the completed cycles '
                  'available on this device.',
                  style: TextStyle(color: LetterColors.muted, height: 1.45),
                ),
                const SizedBox(height: LetterSpacing.sm),
                ...viewModel.unassignedCareRecords.map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: LetterSpacing.xs),
                    child: _UnassignedCareRow(record: record),
                  ),
                ),
              ],
              const SizedBox(height: LetterSpacing.xl),
              const _ArchivePrivacyNote(),
            ],
          ),
        ),
      ],
    );
  }
}

enum _LettersDestination { cycles, patterns, reports }

class _LettersDestinations extends StatelessWidget {
  const _LettersDestinations({
    required this.onOpenPatterns,
    required this.onOpenReports,
  });

  final VoidCallback? onOpenPatterns;
  final VoidCallback? onOpenReports;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_LettersDestination>(
      key: const Key('letters-destinations'),
      segments: const [
        ButtonSegment(
          value: _LettersDestination.cycles,
          label: Text('Cycles'),
          icon: Icon(Icons.mail_outline),
        ),
        ButtonSegment(
          value: _LettersDestination.patterns,
          label: Text('Patterns'),
          icon: Icon(Icons.insights_outlined),
        ),
        ButtonSegment(
          value: _LettersDestination.reports,
          label: Text('Reports'),
          icon: Icon(Icons.description_outlined),
        ),
      ],
      selected: const {_LettersDestination.cycles},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        switch (selection.single) {
          case _LettersDestination.cycles:
            return;
          case _LettersDestination.patterns:
            onOpenPatterns?.call();
          case _LettersDestination.reports:
            onOpenReports?.call();
        }
      },
    );
  }
}

class _ArchiveHeader extends StatelessWidget {
  const _ArchiveHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 58,
          decoration: BoxDecoration(
            color: LetterColors.violet,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: LetterSpacing.md),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LetterEyebrow('Letter / Archive'),
              SizedBox(height: LetterSpacing.xs),
              Text(
                'Your cycle letters',
                style: TextStyle(
                  fontFamily: 'Newsreader',
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Tooltip(
          message: 'Stored privately on this device',
          child: Icon(Icons.lock_outline, color: LetterColors.teal, size: 22),
        ),
      ],
    );
  }
}

class _NoPeriodsRecorded extends StatelessWidget {
  const _NoPeriodsRecorded();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('cycle-letters-no-periods'),
      padding: const EdgeInsets.all(LetterSpacing.lg),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mail_outline, color: LetterColors.violet, size: 28),
          SizedBox(height: LetterSpacing.sm),
          Text(
            'No cycle letters yet',
            style: TextStyle(
              fontFamily: 'Newsreader',
              fontSize: 23,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: LetterSpacing.xs),
          Text(
            'A completed letter appears after two period starts are recorded. '
            'Letter will not create sample history.',
            style: TextStyle(color: LetterColors.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _CycleLetterRow extends StatelessWidget {
  const _CycleLetterRow({required this.letter, required this.onOpen});

  final CycleLetterDisplay letter;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final title = letter.isComplete
        ? 'Letter No. ${letter.letterNumber}'
        : 'Current cycle';
    final periodCount = letter.recordedPeriodDates.length;
    final careCount = letter.careMoments.length;
    final evidence =
        '$periodCount recorded period ${periodCount == 1 ? 'day' : 'days'}'
        '  •  $careCount Care ${careCount == 1 ? 'moment' : 'moments'}';

    return Semantics(
      button: true,
      label: '$title, ${letter.dateRange}, $evidence',
      child: ExcludeSemantics(
        child: Material(
          color: LetterColors.surface,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: LetterColors.line),
            borderRadius: BorderRadius.circular(LetterRadius.panel),
          ),
          child: InkWell(
            key: Key('cycle-letter-${letter.id}'),
            onTap: onOpen,
            borderRadius: BorderRadius.circular(LetterRadius.panel),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 92),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 7,
                    height: 68,
                    decoration: BoxDecoration(
                      color: letter.isComplete
                          ? LetterColors.violet
                          : LetterColors.coral,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(LetterSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontFamily: 'Newsreader',
                                    fontSize: 20,
                                    height: 1.1,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (!letter.isComplete)
                                const Text(
                                  'INCOMPLETE',
                                  style: TextStyle(
                                    color: LetterColors.safetyRed,
                                    fontSize: 9,
                                    height: 1.2,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: LetterSpacing.xxs),
                          Text(
                            letter.dateRange,
                            style: const TextStyle(
                              color: LetterColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: LetterSpacing.xs),
                          Text(
                            evidence,
                            style: const TextStyle(
                              color: LetterColors.muted,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 44,
                    child: Icon(Icons.chevron_right, color: LetterColors.muted),
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

class _UnassignedCareRow extends StatelessWidget {
  const _UnassignedCareRow({required this.record});

  final UnassignedCareDisplay record;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('unassigned-care-${record.id}'),
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: const BoxDecoration(
        color: LetterColors.surface,
        border: Border(left: BorderSide(color: LetterColors.amber, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.volunteer_activism_outlined,
            size: 20,
            color: LetterColors.amber,
          ),
          const SizedBox(width: LetterSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.actionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: LetterSpacing.xxs),
                Text(
                  [record.dateLabel, ?record.checkBackLabel].join('  •  '),
                  style: const TextStyle(
                    color: LetterColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivePrivacyNote extends StatelessWidget {
  const _ArchivePrivacyNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline, color: LetterColors.teal, size: 18),
        SizedBox(width: LetterSpacing.xs),
        Expanded(
          child: Text(
            'This archive uses records stored on this device. It shows only '
            'saved cycle, Care, and reflection evidence.',
            style: TextStyle(
              color: LetterColors.muted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _CycleLetterDetail extends StatelessWidget {
  const _CycleLetterDetail({
    required this.letter,
    required this.onBack,
    required this.onReflectionOpen,
    required this.onCareRecordReflect,
  });

  final CycleLetterDisplay letter;
  final VoidCallback? onBack;
  final ValueChanged<String>? onReflectionOpen;
  final ValueChanged<String>? onCareRecordReflect;

  @override
  Widget build(BuildContext context) {
    final title = letter.isComplete
        ? 'Letter No. ${letter.letterNumber}'
        : 'Current cycle';
    return CustomScrollView(
      key: const Key('cycle-letter-detail-scroll-view'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 8, 20, 36),
          sliver: SliverList.list(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  key: const Key('cycle-letter-detail-back'),
                  onPressed: onBack,
                  tooltip: 'Back to cycle letters',
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LetterEyebrow(
                      letter.isComplete ? 'Completed cycle' : 'In progress',
                      color: letter.isComplete
                          ? LetterColors.violet
                          : LetterColors.safetyRed,
                    ),
                    const SizedBox(height: LetterSpacing.xs),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Newsreader',
                        fontSize: 31,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: LetterSpacing.xs),
                    Text(
                      letter.dateRange,
                      style: const TextStyle(
                        color: LetterColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!letter.isComplete) ...[
                      const SizedBox(height: LetterSpacing.sm),
                      const Text(
                        'This cycle is incomplete and is shown separately.',
                        style: TextStyle(
                          color: LetterColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: LetterSpacing.xl),
                    _DetailSection(
                      key: const Key('cycle-letter-section-timing'),
                      icon: Icons.calendar_today_outlined,
                      title: 'Cycle timing',
                      child: _CycleTiming(letter: letter),
                    ),
                    _DetailSection(
                      key: const Key('cycle-letter-section-care'),
                      icon: Icons.volunteer_activism_outlined,
                      title: 'Care moments',
                      child: _CareMoments(
                        letter: letter,
                        onReflect: onCareRecordReflect,
                      ),
                    ),
                    _DetailSection(
                      key: const Key('cycle-letter-section-missing'),
                      icon: Icons.remove_circle_outline,
                      title: 'What is not recorded',
                      child: _NotRecorded(items: letter.notRecorded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.child,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: LetterSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LetterColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: LetterColors.teal),
              const SizedBox(width: LetterSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Newsreader',
                    fontSize: 21,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LetterSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _CycleTiming extends StatelessWidget {
  const _CycleTiming({required this.letter});

  final CycleLetterDisplay letter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EvidenceLine(label: 'Cycle range', value: letter.dateRange),
        const SizedBox(height: LetterSpacing.sm),
        if (letter.recordedPeriodDates.isEmpty)
          const Text(
            'No period days are recorded for this cycle.',
            style: TextStyle(color: LetterColors.muted, height: 1.4),
          )
        else ...[
          Text(
            'Recorded period days (${letter.recordedPeriodDates.length})',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: LetterSpacing.xs),
          Text(
            letter.recordedPeriodDates.join(', '),
            style: const TextStyle(color: LetterColors.muted, height: 1.4),
          ),
        ],
      ],
    );
  }
}

class _CareMoments extends StatelessWidget {
  const _CareMoments({required this.letter, required this.onReflect});

  final CycleLetterDisplay letter;
  final ValueChanged<String>? onReflect;

  @override
  Widget build(BuildContext context) {
    if (letter.careMoments.isEmpty) {
      return const Text(
        'No Care moments are recorded for this cycle.',
        style: TextStyle(color: LetterColors.muted, height: 1.4),
      );
    }

    final counts = letter.checkBackCounts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final moment in letter.careMoments)
          Padding(
            padding: const EdgeInsets.only(bottom: LetterSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EvidenceLine(
                  label: moment.dateLabel,
                  value: [
                    moment.actionLabel,
                    ?moment.checkBackLabel,
                  ].join('  •  '),
                ),
                if (moment.reflectionPreview case final preview?) ...[
                  const SizedBox(height: LetterSpacing.xs),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(LetterSpacing.sm),
                    decoration: const BoxDecoration(
                      color: LetterColors.tealSoft,
                      border: Border(
                        left: BorderSide(color: LetterColors.teal, width: 3),
                      ),
                    ),
                    child: Text(
                      preview,
                      key: Key('cycle-letter-reflection-preview-${moment.id}'),
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                ],
                if (moment.id case final id?) ...[
                  const SizedBox(height: LetterSpacing.xs),
                  OutlinedButton.icon(
                    key: Key('cycle-letter-reflect-$id'),
                    onPressed: onReflect == null ? null : () => onReflect!(id),
                    icon: Icon(
                      moment.reflectionId == null
                          ? Icons.edit_note_outlined
                          : Icons.edit_outlined,
                      size: 19,
                    ),
                    label: Text(
                      moment.reflectionId == null
                          ? 'Reflect'
                          : 'Edit reflection',
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (counts.total > 0) ...[
          const SizedBox(height: LetterSpacing.xs),
          Wrap(
            spacing: LetterSpacing.xs,
            runSpacing: LetterSpacing.xs,
            children: [
              _CountLabel(label: 'Better', count: counts.better),
              _CountLabel(label: 'Same', count: counts.same),
              _CountLabel(label: 'Worse', count: counts.worse),
            ],
          ),
        ] else
          const Text(
            'No Better, Same, or Worse check-backs are recorded.',
            style: TextStyle(color: LetterColors.muted, height: 1.4),
          ),
      ],
    );
  }
}

class _CountLabel extends StatelessWidget {
  const _CountLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LetterSpacing.sm,
        vertical: LetterSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: LetterColors.tealSoft,
        borderRadius: BorderRadius.circular(LetterRadius.control),
      ),
      child: Text(
        '$label $count',
        style: const TextStyle(
          color: LetterColors.tealDark,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NotRecorded extends StatelessWidget {
  const _NotRecorded({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'Nothing else is marked missing in this archive view.',
        style: TextStyle(color: LetterColors.muted, height: 1.4),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: LetterSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: SizedBox.square(
                    dimension: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: LetterColors.muted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: LetterSpacing.sm),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: LetterColors.muted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EvidenceLine extends StatelessWidget {
  const _EvidenceLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: LetterColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: LetterSpacing.xxs),
        Text(value, style: const TextStyle(height: 1.4)),
      ],
    );
  }
}

class _MissingLetter extends StatelessWidget {
  const _MissingLetter({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(LetterSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              size: 34,
              color: LetterColors.violet,
            ),
            const SizedBox(height: LetterSpacing.md),
            const Text(
              'This cycle letter is no longer available.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 25,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: LetterSpacing.sm),
            const Text(
              'Its source records may have been changed or deleted.',
              textAlign: TextAlign.center,
              style: TextStyle(color: LetterColors.muted, height: 1.4),
            ),
            const SizedBox(height: LetterSpacing.lg),
            OutlinedButton.icon(
              key: const Key('cycle-letter-missing-back'),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to cycle letters'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44)),
            ),
          ],
        ),
      ),
    );
  }
}
