import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/letter_bottom_navigation.dart';
import '../../../design_system/letter_brand_mark.dart';
import '../../../design_system/letter_theme.dart';
import '../../cycle/domain/bleeding_flow.dart';
import '../../cycle/domain/cycle_prediction.dart';
import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_repository.dart';
import '../../cycle/presentation/cycle_screen.dart';
import '../../health_records/domain/health_record_repository.dart';

typedef PeriodDeleteCallback = FutureOr<void> Function(String periodId);

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
    this.cycleStartDay,
    this.reflection,
    this.year,
    this.cycleLengthDays,
    this.bleedingDays,
    this.periodId,
    this.cycleEndDay,
    this.bleedingRangeLabel,
    this.flowDays = const [],
    this.symptomRecordCount = 0,
    this.symptomTypeCount = 0,
    this.symptomMissingDays = 0,
  });

  final String id;
  final int? cycleStartDay;
  final String dateRange;
  final List<String> recordedPeriodDates;
  final List<CycleLetterCareMomentDisplay> careMoments;
  final CycleLetterCheckBackCounts checkBackCounts;
  final CycleLetterReflectionDisplay? reflection;
  final List<String> notRecorded;
  final int? year;
  final int? cycleLengthDays;
  final int? bleedingDays;
  final String? periodId;
  final int? cycleEndDay;
  final String? bleedingRangeLabel;
  final List<CycleFlowDayDisplay> flowDays;
  final int symptomRecordCount;
  final int symptomTypeCount;
  final int symptomMissingDays;

  int get recordedFlowDays => flowDays.where((day) => day.flow != null).length;

  bool get flowComplete =>
      flowDays.isNotEmpty && recordedFlowDays == flowDays.length;

  String get flowActionLabel => flowComplete ? 'Edit flow' : 'Record flow';

  bool get isComplete => cycleLengthDays != null;

  int? get displayYear {
    if (year != null) {
      return year;
    }
    final match = RegExp(r'\b(\d{4})\b').firstMatch(dateRange);
    return match == null ? null : int.tryParse(match.group(1)!);
  }
}

@immutable
class CycleFlowDayDisplay {
  const CycleFlowDayDisplay({
    required this.date,
    required this.dateLabel,
    this.flow,
  });

  final LocalDate date;
  final String dateLabel;
  final BleedingFlow? flow;
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
    this.observation,
    this.needLabel,
    this.whatHelped,
    this.futureSelfNote,
  });

  final String id;
  final String dateLabel;
  final String? observation;
  final String? needLabel;
  final String? whatHelped;
  final String? futureSelfNote;
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

class CycleLettersScreen extends StatefulWidget {
  const CycleLettersScreen({
    required this.viewModel,
    super.key,
    this.selectedLetterId,
    this.onNavigationSelected,
    this.onRetry,
    this.onLetterOpen,
    this.onLetterClose,
    this.onCycleReflectionOpen,
    this.onOpenArchiveViews,
    this.onOpenPersonalPatterns,
    this.periodRepository,
    this.healthRecordRepository,
    this.onOptionalCare,
    this.onCycleDataChanged,
    this.now,
    this.onPeriodFlowOpen,
    this.onPeriodDatesEdit,
    this.onPeriodDelete,
    this.onCycleSymptomsOpen,
  });

  final CycleLettersViewModel viewModel;
  final String? selectedLetterId;
  final ValueChanged<int>? onNavigationSelected;
  final VoidCallback? onRetry;
  final ValueChanged<String>? onLetterOpen;
  final VoidCallback? onLetterClose;
  final ValueChanged<String>? onCycleReflectionOpen;
  final VoidCallback? onOpenArchiveViews;
  final VoidCallback? onOpenPersonalPatterns;
  final PeriodRepository? periodRepository;
  final HealthRecordRepository? healthRecordRepository;
  final VoidCallback? onOptionalCare;
  final Future<void> Function()? onCycleDataChanged;
  final DateTime Function()? now;
  final ValueChanged<String>? onPeriodFlowOpen;
  final ValueChanged<String>? onPeriodDatesEdit;
  final PeriodDeleteCallback? onPeriodDelete;
  final void Function(int fromDay, int throughDay)? onCycleSymptomsOpen;

  @override
  State<CycleLettersScreen> createState() => _CycleLettersScreenState();
}

class _CycleLettersScreenState extends State<CycleLettersScreen> {
  bool _showArchive = false;
  bool _unassignedCareExpanded = false;
  final Set<int> _expandedArchiveYears = {};

  CycleLetterDisplay? _selectedLetter() {
    final id = widget.selectedLetterId;
    if (id == null) {
      return null;
    }
    if (widget.viewModel.currentCycle?.id == id) {
      return widget.viewModel.currentCycle;
    }
    for (final letter in widget.viewModel.completedLetters) {
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
        selectedIndex: 2,
        onSelected: widget.onNavigationSelected,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: switch (widget.viewModel.status) {
              CycleLettersStatus.loading => const _ArchiveLoading(),
              CycleLettersStatus.error => _ArchiveError(
                onRetry: widget.onRetry,
              ),
              CycleLettersStatus.ready =>
                widget.selectedLetterId == null
                    ? _showArchive
                          ? _CycleLettersArchive(
                              viewModel: widget.viewModel,
                              expandedYears: _expandedArchiveYears,
                              unassignedCareExpanded: _unassignedCareExpanded,
                              onBack: _closeArchive,
                              onToggleYear: _toggleArchiveYear,
                              onUnassignedCareChanged: (expanded) => setState(
                                () => _unassignedCareExpanded = expanded,
                              ),
                              onLetterOpen: _openFromArchive,
                              onPeriodFlowOpen: widget.onPeriodFlowOpen,
                              onPeriodDatesEdit: widget.onPeriodDatesEdit,
                              onPeriodDelete: widget.onPeriodDelete,
                            )
                          : _RecentCycleLetters(
                              viewModel: widget.viewModel,
                              unassignedCareExpanded: _unassignedCareExpanded,
                              onViewAll: _openArchive,
                              onUnassignedCareChanged: (expanded) => setState(
                                () => _unassignedCareExpanded = expanded,
                              ),
                              onLetterOpen: _openFromRecent,
                              onOpenArchiveViews: widget.onOpenArchiveViews,
                              onOpenPersonalPatterns:
                                  widget.onOpenPersonalPatterns,
                              periodRepository: widget.periodRepository,
                              healthRecordRepository:
                                  widget.healthRecordRepository,
                              onOptionalCare: widget.onOptionalCare,
                              onCycleDataChanged: widget.onCycleDataChanged,
                              now: widget.now,
                              onPeriodFlowOpen: widget.onPeriodFlowOpen,
                              onPeriodDatesEdit: widget.onPeriodDatesEdit,
                              onPeriodDelete: widget.onPeriodDelete,
                            )
                    : selectedLetter == null
                    ? _MissingLetter(onBack: widget.onLetterClose)
                    : _CycleLetterDetail(
                        letter: selectedLetter,
                        onBack: widget.onLetterClose,
                        onCycleReflectionOpen: widget.onCycleReflectionOpen,
                        onPeriodFlowOpen: widget.onPeriodFlowOpen,
                        onPeriodDatesEdit: widget.onPeriodDatesEdit,
                        onPeriodDelete: widget.onPeriodDelete,
                        onCycleSymptomsOpen: widget.onCycleSymptomsOpen,
                      ),
            },
          ),
        ),
      ),
    );
  }

  void _openArchive() {
    final years = _archiveYears(widget.viewModel);
    if (years.isNotEmpty) {
      final currentYear = DateTime.now().year;
      _expandedArchiveYears
        ..clear()
        ..add(years.contains(currentYear) ? currentYear : years.first);
    }
    setState(() => _showArchive = true);
  }

  void _closeArchive() => setState(() => _showArchive = false);

  void _openFromRecent(String id) {
    setState(() => _showArchive = false);
    widget.onLetterOpen?.call(id);
  }

  void _openFromArchive(String id) {
    setState(() => _showArchive = true);
    widget.onLetterOpen?.call(id);
  }

  void _toggleArchiveYear(int year, bool expanded) {
    setState(() {
      if (expanded) {
        _expandedArchiveYears.add(year);
      } else {
        _expandedArchiveYears.remove(year);
      }
    });
  }

  static List<int> _archiveYears(CycleLettersViewModel viewModel) {
    final years = <int>{
      for (final letter in viewModel.completedLetters) ?letter.displayYear,
    }.toList()..sort((left, right) => right.compareTo(left));
    return years;
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

class _RecentCycleLetters extends StatelessWidget {
  const _RecentCycleLetters({
    required this.viewModel,
    required this.unassignedCareExpanded,
    required this.onViewAll,
    required this.onUnassignedCareChanged,
    required this.onLetterOpen,
    required this.onPeriodFlowOpen,
    required this.onPeriodDatesEdit,
    required this.onPeriodDelete,
    required this.onOpenArchiveViews,
    required this.onOpenPersonalPatterns,
    this.periodRepository,
    this.healthRecordRepository,
    this.onOptionalCare,
    this.onCycleDataChanged,
    this.now,
  });

  final CycleLettersViewModel viewModel;
  final bool unassignedCareExpanded;
  final VoidCallback onViewAll;
  final ValueChanged<bool> onUnassignedCareChanged;
  final ValueChanged<String>? onLetterOpen;
  final ValueChanged<String>? onPeriodFlowOpen;
  final ValueChanged<String>? onPeriodDatesEdit;
  final PeriodDeleteCallback? onPeriodDelete;
  final VoidCallback? onOpenArchiveViews;
  final VoidCallback? onOpenPersonalPatterns;
  final PeriodRepository? periodRepository;
  final HealthRecordRepository? healthRecordRepository;
  final VoidCallback? onOptionalCare;
  final Future<void> Function()? onCycleDataChanged;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final recentLetters = viewModel.completedLetters.take(3).toList();
    final canonicalLetters = [?viewModel.currentCycle, ...recentLetters];
    final hasCycleRecord =
        viewModel.currentCycle != null || viewModel.completedLetters.isNotEmpty;
    return CustomScrollView(
      key: const Key('cycle-letters-recent-scroll-view'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          sliver: SliverList.list(
            children: [
              const LetterBrandLockup(),
              const SizedBox(height: LetterSpacing.md),
              const _ArchiveHeader(),
              const SizedBox(height: LetterSpacing.md),
              _LettersDestinations(
                onOpenPatterns: onOpenPersonalPatterns,
                onOpenReports: onOpenArchiveViews,
              ),
              const SizedBox(height: LetterSpacing.xl),
              if (periodRepository case final repository?) ...[
                const LetterSectionTitle(
                  eyebrow: 'Record once, revisit here',
                  title: 'Cycle workspace',
                ),
                const SizedBox(height: LetterSpacing.sm),
                CycleOperationsPane(
                  key: const Key('letters-cycle-operations'),
                  repository: repository,
                  now: now,
                  embedded: true,
                  compact: true,
                  onDataChanged: onCycleDataChanged,
                  onDeleteRequested: onPeriodDelete == null
                      ? null
                      : (record) => onPeriodDelete!(record.id),
                ),
                const SizedBox(height: LetterSpacing.xl),
              ],
              if (!hasCycleRecord) const _NoPeriodsRecorded(),
              if (canonicalLetters.isNotEmpty) ...[
                const LetterSectionTitle(
                  eyebrow: 'Most recent',
                  title: 'Cycles',
                ),
                const SizedBox(height: LetterSpacing.sm),
                ...canonicalLetters.map(
                  (letter) => Padding(
                    padding: const EdgeInsets.only(bottom: LetterSpacing.sm),
                    child: _CycleLetterRow(
                      letter: letter,
                      onOpen: onLetterOpen == null
                          ? null
                          : () => onLetterOpen!(letter.id),
                      onFlow:
                          letter.periodId == null || onPeriodFlowOpen == null
                          ? null
                          : () => onPeriodFlowOpen!(letter.periodId!),
                      onEditDates:
                          letter.periodId == null || onPeriodDatesEdit == null
                          ? null
                          : () => onPeriodDatesEdit!(letter.periodId!),
                      onDelete:
                          letter.periodId == null || onPeriodDelete == null
                          ? null
                          : () => onPeriodDelete!(letter.periodId!),
                    ),
                  ),
                ),
                const SizedBox(height: LetterSpacing.xs),
                if (viewModel.completedLetters.length > 3)
                  _ViewAllCycleLettersButton(onPressed: onViewAll),
              ],
              if (viewModel.unassignedCareRecords.isNotEmpty) ...[
                const SizedBox(height: LetterSpacing.xl),
                _UnassignedCareSection(
                  records: viewModel.unassignedCareRecords,
                  expanded: unassignedCareExpanded,
                  onExpansionChanged: onUnassignedCareChanged,
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

class _CycleLettersArchive extends StatelessWidget {
  const _CycleLettersArchive({
    required this.viewModel,
    required this.expandedYears,
    required this.unassignedCareExpanded,
    required this.onBack,
    required this.onToggleYear,
    required this.onUnassignedCareChanged,
    required this.onLetterOpen,
    required this.onPeriodFlowOpen,
    required this.onPeriodDatesEdit,
    required this.onPeriodDelete,
  });

  final CycleLettersViewModel viewModel;
  final Set<int> expandedYears;
  final bool unassignedCareExpanded;
  final VoidCallback onBack;
  final void Function(int year, bool expanded) onToggleYear;
  final ValueChanged<bool> onUnassignedCareChanged;
  final ValueChanged<String>? onLetterOpen;
  final ValueChanged<String>? onPeriodFlowOpen;
  final ValueChanged<String>? onPeriodDatesEdit;
  final PeriodDeleteCallback? onPeriodDelete;

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<CycleLetterDisplay>>{};
    for (final letter in viewModel.completedLetters) {
      final year = letter.displayYear;
      if (year != null) {
        grouped.putIfAbsent(year, () => []).add(letter);
      }
    }
    final years = grouped.keys.toList()
      ..sort((left, right) => right.compareTo(left));

    return CustomScrollView(
      key: const Key('cycle-letters-archive-scroll-view'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 8, 20, 36),
          sliver: SliverList.list(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  key: const Key('cycle-letters-archive-back'),
                  onPressed: onBack,
                  tooltip: 'Back to recent cycle letters',
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: LetterBrandLockup(),
              ),
              const SizedBox(height: LetterSpacing.md),
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: _ArchiveTitle(
                  eyebrow: 'Archive',
                  title: 'All Cycle Letters',
                  subtitle: 'A private record of completed cycles.',
                ),
              ),
              const SizedBox(height: LetterSpacing.xl),
              if (years.isEmpty)
                const _NoCompletedLetters()
              else
                for (final year in years)
                  _YearSection(
                    year: year,
                    letters: grouped[year]!,
                    expanded: expandedYears.contains(year),
                    onExpansionChanged: (expanded) =>
                        onToggleYear(year, expanded),
                    onLetterOpen: onLetterOpen,
                    onPeriodFlowOpen: onPeriodFlowOpen,
                    onPeriodDatesEdit: onPeriodDatesEdit,
                    onPeriodDelete: onPeriodDelete,
                  ),
              if (viewModel.unassignedCareRecords.isNotEmpty) ...[
                const SizedBox(height: LetterSpacing.xl),
                _UnassignedCareSection(
                  records: viewModel.unassignedCareRecords,
                  expanded: unassignedCareExpanded,
                  onExpansionChanged: onUnassignedCareChanged,
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

class _ArchiveTitle extends StatelessWidget {
  const _ArchiveTitle({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 82,
          decoration: BoxDecoration(
            color: LetterColors.violet,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: LetterSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LetterEyebrow(eyebrow),
              const SizedBox(height: LetterSpacing.xs),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Newsreader',
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: LetterSpacing.xs),
              Text(
                subtitle,
                style: const TextStyle(color: LetterColors.muted, height: 1.4),
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

class _YearSection extends StatelessWidget {
  const _YearSection({
    required this.year,
    required this.letters,
    required this.expanded,
    required this.onExpansionChanged,
    required this.onLetterOpen,
    required this.onPeriodFlowOpen,
    required this.onPeriodDatesEdit,
    required this.onPeriodDelete,
  });

  final int year;
  final List<CycleLetterDisplay> letters;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<String>? onLetterOpen;
  final ValueChanged<String>? onPeriodFlowOpen;
  final ValueChanged<String>? onPeriodDatesEdit;
  final PeriodDeleteCallback? onPeriodDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('cycle-letters-year-$year'),
      margin: const EdgeInsets.only(bottom: LetterSpacing.sm),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          key: PageStorageKey<String>('cycle-letters-year-$year-tile'),
          initiallyExpanded: expanded,
          onExpansionChanged: onExpansionChanged,
          tilePadding: const EdgeInsets.symmetric(horizontal: LetterSpacing.md),
          childrenPadding: const EdgeInsets.fromLTRB(
            LetterSpacing.sm,
            0,
            LetterSpacing.sm,
            LetterSpacing.sm,
          ),
          title: Text(
            '$year',
            style: const TextStyle(
              fontFamily: 'Newsreader',
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '${letters.length} ${letters.length == 1 ? 'letter' : 'letters'}',
            style: const TextStyle(color: LetterColors.muted),
          ),
          children: [
            for (final letter in letters)
              Padding(
                padding: const EdgeInsets.only(bottom: LetterSpacing.sm),
                child: _CycleLetterRow(
                  letter: letter,
                  onOpen: onLetterOpen == null
                      ? null
                      : () => onLetterOpen!(letter.id),
                  onFlow: letter.periodId == null || onPeriodFlowOpen == null
                      ? null
                      : () => onPeriodFlowOpen!(letter.periodId!),
                  onEditDates:
                      letter.periodId == null || onPeriodDatesEdit == null
                      ? null
                      : () => onPeriodDatesEdit!(letter.periodId!),
                  onDelete: letter.periodId == null || onPeriodDelete == null
                      ? null
                      : () => onPeriodDelete!(letter.periodId!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewAllCycleLettersButton extends StatelessWidget {
  const _ViewAllCycleLettersButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('cycle-letters-view-all'),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(minimumSize: const Size(44, 48)),
        icon: const Icon(Icons.archive_outlined),
        label: const Text('View all Cycle Letters'),
      ),
    );
  }
}

class _UnassignedCareSection extends StatelessWidget {
  const _UnassignedCareSection({
    required this.records,
    required this.expanded,
    required this.onExpansionChanged,
  });

  final List<UnassignedCareDisplay> records;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('unassigned-care-section'),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          key: const PageStorageKey<String>('unassigned-care-tile'),
          initiallyExpanded: expanded,
          onExpansionChanged: onExpansionChanged,
          tilePadding: const EdgeInsets.symmetric(horizontal: LetterSpacing.md),
          title: const Text(
            'Not assigned to a completed cycle',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${records.length} ${records.length == 1 ? 'record' : 'records'}',
            style: const TextStyle(color: LetterColors.muted),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            LetterSpacing.md,
            0,
            LetterSpacing.md,
            LetterSpacing.md,
          ),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'These Care records fall outside the completed cycles available '
                'on this device.',
                style: TextStyle(color: LetterColors.muted, height: 1.45),
              ),
            ),
            const SizedBox(height: LetterSpacing.sm),
            for (final record in records) ...[
              _UnassignedCareRow(record: record),
              const SizedBox(height: LetterSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoCompletedLetters extends StatelessWidget {
  const _NoCompletedLetters();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'No completed cycle letters yet.',
      style: TextStyle(color: LetterColors.muted, height: 1.4),
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
              LetterEyebrow('Archive'),
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
            'Letter Within will not create sample history.',
            style: TextStyle(color: LetterColors.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _CycleLetterRow extends StatelessWidget {
  const _CycleLetterRow({
    required this.letter,
    required this.onOpen,
    this.onFlow,
    this.onEditDates,
    this.onDelete,
  });

  final CycleLetterDisplay letter;
  final VoidCallback? onOpen;
  final VoidCallback? onFlow;
  final VoidCallback? onEditDates;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final periodCount =
        letter.bleedingDays ?? letter.recordedPeriodDates.length;
    final stacked = context.isLetterNarrow || context.isLetterLargeText;
    final bleedingRange =
        letter.bleedingRangeLabel ??
        '${letter.recordedPeriodDates.join('–')} · '
            '$periodCount ${periodCount == 1 ? 'day' : 'days'}';
    final currentCycleDay = switch ((
      letter.cycleStartDay,
      letter.cycleEndDay,
    )) {
      (final start?, final end?) => end - start + 1,
      _ => null,
    };
    final cycleLength = letter.cycleLengthDays;
    final exceptionalInterval =
        cycleLength != null &&
        (cycleLength < CyclePredictionEngine.minimumTypicalCycleDays ||
            cycleLength > CyclePredictionEngine.maximumTypicalCycleDays);
    final timingLabel = letter.isComplete
        ? cycleLength == null
              ? 'Completed cycle'
              : exceptionalInterval
              ? '$cycleLength-day interval'
              : '$cycleLength-day cycle'
        : currentCycleDay == null
        ? 'In progress'
        : 'Cycle day $currentCycleDay';

    return Material(
      color: LetterColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: '${letter.dateRange}, $timingLabel, bleeding $bleedingRange',
            child: InkWell(
              key: Key('cycle-letter-${letter.id}'),
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LetterEyebrow(
                            letter.isComplete
                                ? 'COMPLETED CYCLE'
                                : 'CURRENT CYCLE · STILL OPEN',
                          ),
                          const SizedBox(height: LetterSpacing.xs),
                          Wrap(
                            spacing: LetterSpacing.xs,
                            runSpacing: LetterSpacing.xxs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                letter.dateRange,
                                style: const TextStyle(
                                  fontFamily: 'Newsreader',
                                  fontSize: 20,
                                  height: 1.1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                timingLabel,
                                style: const TextStyle(
                                  color: LetterColors.muted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: LetterSpacing.xs),
                          Text(
                            'Bleeding $bleedingRange',
                            style: const TextStyle(
                              color: LetterColors.muted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: LetterSpacing.sm),
                    const Padding(
                      padding: EdgeInsets.only(top: LetterSpacing.xs),
                      child: Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: LetterColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: LetterColors.line),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CycleFlowButton(letter: letter, onPressed: onFlow),
                      const SizedBox(height: LetterSpacing.xs),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _CycleManageMenu(
                          letter: letter,
                          onEditDates: onEditDates,
                          onDelete: onDelete,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      _CycleFlowButton(letter: letter, onPressed: onFlow),
                      const Spacer(),
                      _CycleManageMenu(
                        letter: letter,
                        onEditDates: onEditDates,
                        onDelete: onDelete,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CycleFlowButton extends StatelessWidget {
  const _CycleFlowButton({required this.letter, this.onPressed});

  final CycleLetterDisplay letter;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: Key('cycle-letter-flow-${letter.id}'),
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44)),
    icon: const Icon(Icons.water_drop_outlined, size: 18),
    label: Text(letter.flowActionLabel),
  );
}

enum _CycleManageAction { editDates, delete }

class _CycleManageMenu extends StatelessWidget {
  const _CycleManageMenu({
    required this.letter,
    this.onEditDates,
    this.onDelete,
  });

  final CycleLetterDisplay letter;
  final VoidCallback? onEditDates;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_CycleManageAction>(
    key: Key('cycle-letter-manage-${letter.id}'),
    tooltip: 'More cycle actions',
    onSelected: (action) => switch (action) {
      _CycleManageAction.editDates => onEditDates?.call(),
      _CycleManageAction.delete => onDelete?.call(),
    },
    itemBuilder: (context) => const [
      PopupMenuItem(
        value: _CycleManageAction.editDates,
        child: Text('Edit period dates'),
      ),
      PopupMenuItem(
        value: _CycleManageAction.delete,
        child: Text(
          'Delete period',
          style: TextStyle(color: LetterColors.safetyRed),
        ),
      ),
    ],
    child: Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.control),
      ),
      child: const Icon(Icons.more_horiz, size: 20),
    ),
  );
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
    required this.onCycleReflectionOpen,
    required this.onPeriodFlowOpen,
    required this.onPeriodDatesEdit,
    required this.onPeriodDelete,
    required this.onCycleSymptomsOpen,
  });

  final CycleLetterDisplay letter;
  final VoidCallback? onBack;
  final ValueChanged<String>? onCycleReflectionOpen;
  final ValueChanged<String>? onPeriodFlowOpen;
  final ValueChanged<String>? onPeriodDatesEdit;
  final PeriodDeleteCallback? onPeriodDelete;
  final void Function(int fromDay, int throughDay)? onCycleSymptomsOpen;

  @override
  Widget build(BuildContext context) {
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
                      letter.dateRange,
                      style: const TextStyle(
                        fontFamily: 'Newsreader',
                        fontSize: 31,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (letter.periodId case final periodId?) ...[
                      const SizedBox(height: LetterSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _CycleManageMenu(
                          letter: letter,
                          onEditDates: onPeriodDatesEdit == null
                              ? null
                              : () => onPeriodDatesEdit!(periodId),
                          onDelete: onPeriodDelete == null
                              ? null
                              : () => onPeriodDelete!(periodId),
                        ),
                      ),
                    ],
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
                      key: const Key('cycle-letter-section-flow'),
                      icon: Icons.water_drop_outlined,
                      title: 'Bleeding and flow',
                      child: _CycleFlowDetails(
                        letter: letter,
                        onEdit:
                            letter.periodId == null || onPeriodFlowOpen == null
                            ? null
                            : () => onPeriodFlowOpen!(letter.periodId!),
                      ),
                    ),
                    _DetailSection(
                      key: const Key('cycle-letter-section-symptoms'),
                      icon: Icons.health_and_safety_outlined,
                      title: 'Confirmed symptoms',
                      child: _CycleSymptoms(
                        letter: letter,
                        onOpen:
                            letter.cycleStartDay == null ||
                                onCycleSymptomsOpen == null
                            ? null
                            : () => onCycleSymptomsOpen!(
                                letter.cycleStartDay!,
                                letter.cycleEndDay ?? letter.cycleStartDay!,
                              ),
                      ),
                    ),
                    _DetailSection(
                      key: const Key('cycle-letter-section-care'),
                      icon: Icons.volunteer_activism_outlined,
                      title: 'Care',
                      child: _CareMoments(letter: letter),
                    ),
                    _DetailSection(
                      key: const Key('cycle-letter-section-reflection'),
                      icon: Icons.edit_note_outlined,
                      title: 'Cycle reflection',
                      child: _CycleReflectionSection(
                        letter: letter,
                        onOpen: onCycleReflectionOpen,
                      ),
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
    final bleedingDays =
        letter.bleedingDays ?? letter.recordedPeriodDates.length;
    final cycleLength = letter.cycleLengthDays;
    final shortInterval =
        cycleLength != null &&
        cycleLength < CyclePredictionEngine.minimumTypicalCycleDays;
    final longInterval =
        cycleLength != null &&
        cycleLength > CyclePredictionEngine.maximumTypicalCycleDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EvidenceLine(
          label: shortInterval || longInterval
              ? 'Start-to-start interval'
              : 'Complete cycle length',
          value: cycleLength == null
              ? 'Available after the next period starts'
              : longInterval
              ? '$cycleLength days · may contain missing records'
              : shortInterval
              ? '$cycleLength days · not used in estimates'
              : '$cycleLength days',
        ),
        const SizedBox(height: LetterSpacing.sm),
        _EvidenceLine(
          label: 'Bleeding dates',
          value:
              letter.bleedingRangeLabel ??
              '$bleedingDays ${bleedingDays == 1 ? 'day' : 'days'}',
        ),
      ],
    );
  }
}

class _CycleFlowDetails extends StatelessWidget {
  const _CycleFlowDetails({required this.letter, this.onEdit});

  final CycleLetterDisplay letter;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    if (letter.flowDays.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No daily flow recorded. The days stay blank rather than being estimated.',
            style: TextStyle(color: LetterColors.muted, height: 1.45),
          ),
          const SizedBox(height: LetterSpacing.sm),
          OutlinedButton.icon(
            key: const Key('cycle-detail-edit-flow'),
            onPressed: onEdit,
            icon: const Icon(Icons.water_drop_outlined),
            label: Text(letter.flowActionLabel),
          ),
        ],
      );
    }
    final missing = letter.flowDays.length - letter.recordedFlowDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 620
                ? 4
                : constraints.maxWidth >= 360
                ? 3
                : 2;
            const gap = LetterSpacing.xs;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final day in letter.flowDays)
                  SizedBox(
                    width: width,
                    child: _CycleFlowDayCard(day: day),
                  ),
              ],
            );
          },
        ),
        if (missing > 0)
          Text(
            '$missing of these ${missing == 1 ? 'days has' : 'days have'} no '
            'flow recorded and remain blank.',
            style: const TextStyle(
              color: LetterColors.muted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        const SizedBox(height: LetterSpacing.sm),
        OutlinedButton.icon(
          key: const Key('cycle-detail-edit-flow'),
          onPressed: onEdit,
          icon: const Icon(Icons.water_drop_outlined),
          label: Text(letter.flowActionLabel),
        ),
      ],
    );
  }
}

class _CycleFlowDayCard extends StatelessWidget {
  const _CycleFlowDayCard({required this.day});

  final CycleFlowDayDisplay day;

  Color get _accent => switch (day.flow) {
    BleedingFlow.spotting => LetterColors.coral,
    BleedingFlow.light => LetterColors.violet,
    BleedingFlow.medium => LetterColors.teal,
    BleedingFlow.heavy => LetterColors.tealDark,
    null => LetterColors.muted,
  };

  Color get _background => switch (day.flow) {
    BleedingFlow.spotting => LetterColors.coralSoft,
    BleedingFlow.light => LetterColors.violetSoft,
    BleedingFlow.medium || BleedingFlow.heavy => LetterColors.tealSoft,
    null => LetterColors.canvas,
  };

  @override
  Widget build(BuildContext context) {
    final label = day.flow?.label ?? 'Not recorded';
    return Semantics(
      label: '${day.dateLabel}, $label',
      child: Container(
        constraints: const BoxConstraints(minHeight: 78),
        padding: const EdgeInsets.all(LetterSpacing.sm),
        decoration: BoxDecoration(
          color: _background,
          border: Border.all(color: LetterColors.line),
          borderRadius: BorderRadius.circular(LetterRadius.panel),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  day.flow == null
                      ? Icons.water_drop_outlined
                      : Icons.water_drop,
                  size: 16,
                  color: _accent,
                ),
                const SizedBox(width: LetterSpacing.xxs),
                Expanded(
                  child: Text(
                    day.dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LetterColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: LetterSpacing.xs),
            Text(
              label,
              style: TextStyle(
                color: day.flow == null ? LetterColors.muted : LetterColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CycleSymptoms extends StatelessWidget {
  const _CycleSymptoms({required this.letter, this.onOpen});

  final CycleLetterDisplay letter;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final count = letter.symptomRecordCount;
    final types = letter.symptomTypeCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count == 0
              ? 'No confirmed symptom records'
              : '$count confirmed ${count == 1 ? 'record' : 'records'} · '
                    '$types symptom ${types == 1 ? 'type' : 'types'}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: LetterSpacing.xs),
        Text(
          count == 0
              ? 'Days without a record stay blank. Nothing is filled in for you.'
              : 'No confirmed symptom record on ${letter.symptomMissingDays} '
                    '${letter.symptomMissingDays == 1 ? 'day' : 'days'} in this cycle.',
          style: const TextStyle(
            color: LetterColors.muted,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: LetterSpacing.sm),
        OutlinedButton.icon(
          key: const Key('cycle-detail-view-symptoms'),
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('View symptoms from this cycle'),
        ),
      ],
    );
  }
}

class _CareMoments extends StatelessWidget {
  const _CareMoments({required this.letter});

  final CycleLetterDisplay letter;

  @override
  Widget build(BuildContext context) {
    final counts = letter.checkBackCounts;
    final grouped = <String, List<CycleLetterCareMomentDisplay>>{};
    for (final moment in letter.careMoments) {
      grouped.putIfAbsent(moment.actionLabel, () => []).add(moment);
    }
    final activityCount = letter.careMoments.length;
    return Material(
      color: LetterColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const Key('cycle-detail-care'),
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: LetterSpacing.md),
        childrenPadding: const EdgeInsets.fromLTRB(
          LetterSpacing.md,
          0,
          LetterSpacing.md,
          LetterSpacing.md,
        ),
        title: Text(
          activityCount == 0
              ? 'Care in this cycle · none recorded'
              : 'Care in this cycle · $activityCount '
                    '${activityCount == 1 ? 'activity' : 'activities'}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          counts.total == 0
              ? 'Nothing is added for you.'
              : 'Better ${counts.better} · Same ${counts.same} · '
                    'Worse ${counts.worse}, as recorded',
          style: const TextStyle(color: LetterColors.muted, fontSize: 12),
        ),
        children: [
          if (grouped.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Care activities completed during this cycle appear here.',
                style: TextStyle(color: LetterColors.muted, height: 1.4),
              ),
            )
          else ...[
            for (final entry in grouped.entries)
              _CareMomentGroup(actionLabel: entry.key, moments: entry.value),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Better, Same, and Worse are counted exactly as recorded. '
                'Nothing here says what worked.',
                style: TextStyle(
                  color: LetterColors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CycleReflectionSection extends StatelessWidget {
  const _CycleReflectionSection({required this.letter, required this.onOpen});

  final CycleLetterDisplay letter;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final reflection = letter.reflection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reflection == null)
          const Text(
            'Nothing written yet. A reflection is separate from Care and is '
            'never counted as a symptom.',
            style: TextStyle(color: LetterColors.muted, height: 1.45),
          )
        else
          _CycleReflectionCard(reflection: reflection),
        if (letter.periodId case final periodId?) ...[
          const SizedBox(height: LetterSpacing.sm),
          OutlinedButton.icon(
            key: const Key('cycle-letter-cycle-reflection'),
            onPressed: onOpen == null ? null : () => onOpen!(periodId),
            icon: Icon(
              reflection == null
                  ? Icons.edit_note_outlined
                  : Icons.edit_outlined,
            ),
            label: Text(
              reflection == null ? 'Add a reflection' : 'Edit reflection',
            ),
          ),
        ],
      ],
    );
  }
}

class _CareMomentGroup extends StatelessWidget {
  const _CareMomentGroup({required this.actionLabel, required this.moments});

  final String actionLabel;
  final List<CycleLetterCareMomentDisplay> moments;

  @override
  Widget build(BuildContext context) {
    final better = moments
        .where((item) => item.checkBackLabel == 'Better')
        .length;
    final same = moments.where((item) => item.checkBackLabel == 'Same').length;
    final worse = moments
        .where((item) => item.checkBackLabel == 'Worse')
        .length;
    final outcomeParts = [
      if (better > 0) '$better better',
      if (same > 0) '$same same',
      if (worse > 0) '$worse worse',
    ];
    final noteCount = moments
        .where((item) => item.reflectionPreview != null)
        .length;
    return Container(
      key: Key('cycle-letter-care-group-${actionLabel.hashCode}'),
      margin: const EdgeInsets.only(bottom: LetterSpacing.sm),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: LetterSpacing.md),
          childrenPadding: const EdgeInsets.fromLTRB(
            LetterSpacing.md,
            0,
            LetterSpacing.md,
            LetterSpacing.md,
          ),
          title: Text(
            actionLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            [
              'Used ${moments.length} ${moments.length == 1 ? 'time' : 'times'}',
              if (outcomeParts.isNotEmpty) outcomeParts.join(' · '),
              if (noteCount > 0)
                '$noteCount saved ${noteCount == 1 ? 'Care note' : 'Care notes'}',
            ].join('  •  '),
            style: const TextStyle(color: LetterColors.muted, fontSize: 12),
          ),
          children: [
            for (final moment in moments) ...[
              _EvidenceLine(
                label: moment.dateLabel,
                value: moment.checkBackLabel ?? 'No check-back recorded',
              ),
              if (moment.reflectionPreview case final preview?)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(
                    top: LetterSpacing.xs,
                    bottom: LetterSpacing.sm,
                  ),
                  padding: const EdgeInsets.all(LetterSpacing.sm),
                  decoration: const BoxDecoration(
                    color: LetterColors.tealSoft,
                    border: Border(
                      left: BorderSide(color: LetterColors.teal, width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saved Care note',
                        style: TextStyle(
                          color: LetterColors.tealDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.xxs),
                      Text(preview, style: const TextStyle(height: 1.4)),
                    ],
                  ),
                )
              else
                const SizedBox(height: LetterSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _CycleReflectionCard extends StatelessWidget {
  const _CycleReflectionCard({required this.reflection});

  final CycleLetterReflectionDisplay reflection;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (reflection.observation case final value?) ('What stood out', value),
      if (reflection.needLabel case final value?) ('What you needed', value),
      if (reflection.whatHelped case final value?) ('What helped', value),
      if (reflection.futureSelfNote case final value?) ('For next time', value),
    ];
    return Container(
      key: const Key('cycle-letter-cycle-reflection-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: const BoxDecoration(
        color: LetterColors.violetSoft,
        border: Border(left: BorderSide(color: LetterColors.violet, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your cycle reflection',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: LetterSpacing.xxs),
          Text(
            'Updated ${reflection.dateLabel}',
            style: const TextStyle(color: LetterColors.muted, fontSize: 12),
          ),
          for (final row in rows) ...[
            const SizedBox(height: LetterSpacing.sm),
            Text(
              row.$1,
              style: const TextStyle(
                color: LetterColors.violet,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: LetterSpacing.xxs),
            Text(row.$2, style: const TextStyle(height: 1.4)),
          ],
        ],
      ),
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
