import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../../summary_export/domain/local_file_share_adapter.dart';
import '../../summary_export/domain/summary_export_repository.dart';
import '../../summary_export/presentation/summary_export_screen.dart';
import '../../health_records/domain/health_record_repository.dart';
import '../../health_records/presentation/health_records_screen.dart';
import '../domain/archive_repository.dart';
import '../domain/archive_summary_export_input.dart';
import '../domain/archive_view_models.dart';
import 'clinical_view.dart';
import 'story_view.dart';

class ArchiveViewsScreen extends StatefulWidget {
  const ArchiveViewsScreen({
    required this.repository,
    super.key,
    this.fileShareAdapter = const SystemLocalFileShareAdapter(),
    this.healthRecordRepository,
    this.onBack,
  });

  final ArchiveRepository repository;
  final LocalFileShareAdapter fileShareAdapter;
  final HealthRecordRepository? healthRecordRepository;
  final VoidCallback? onBack;

  @override
  State<ArchiveViewsScreen> createState() => _ArchiveViewsScreenState();
}

class _ArchiveViewsScreenState extends State<ArchiveViewsScreen> {
  final TextEditingController _searchController = TextEditingController();
  ArchiveViewsViewModel _viewModel = const ArchiveViewsViewModel.loading();
  String _query = '';
  String? _selectedCycleId;
  ArchiveViewTab _selectedTab = ArchiveViewTab.story;
  ArchiveInput? _input;
  bool _showAllReports = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _viewModel = const ArchiveViewsViewModel.loading());
    try {
      final input = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _input = input;
        _viewModel = buildArchiveViewsViewModel(input);
      });
    } on Object {
      if (!mounted) return;
      setState(() => _viewModel = const ArchiveViewsViewModel.error());
    }
  }

  ArchiveCycleSummaryViewModel? _selectedCycle() {
    final id = _selectedCycleId;
    if (id == null) return null;
    if (_viewModel.currentCycle?.id == id) return _viewModel.currentCycle;
    return _viewModel.completedCycles
        .where((cycle) => cycle.id == id)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedCycle();
    final showingArchive = _showAllReports && selected == null;
    return Scaffold(
      key: const Key('reports-root'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: Key(
            selected != null
                ? 'report-detail-back'
                : showingArchive
                ? 'reports-archive-back'
                : 'reports-root-back',
          ),
          onPressed: selected != null || showingArchive
              ? () => setState(() {
                  _selectedCycleId = null;
                  _showAllReports = false;
                })
              : _backToLetters,
          tooltip: selected != null
              ? 'Back to reports'
              : showingArchive
              ? 'Back to reports'
              : 'Back to Letters',
          icon: const Icon(Icons.arrow_back),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selected?.title ?? (showingArchive ? 'All reports' : 'Reports'),
              style: const TextStyle(
                fontFamily: 'Newsreader',
                fontWeight: FontWeight.w700,
              ),
            ),
            if (selected != null)
              Text(
                selected.dateRange,
                style: const TextStyle(
                  color: LetterColors.muted,
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: switch (_viewModel.status) {
              ArchiveViewStatus.loading => const Center(
                key: Key('reports-loading'),
                child: CircularProgressIndicator(color: LetterColors.teal),
              ),
              ArchiveViewStatus.error => _ArchiveError(onRetry: _load),
              ArchiveViewStatus.ready =>
                selected == null
                    ? showingArchive
                          ? _AllReportsView(
                              cycles: _viewModel.completedCycles,
                              onOpen: (id) => setState(() {
                                _showAllReports = false;
                                _selectedCycleId = id;
                              }),
                            )
                          : _ArchiveList(
                              viewModel: _viewModel,
                              searchController: _searchController,
                              query: _query,
                              onQueryChanged: (value) =>
                                  setState(() => _query = value),
                              onClearQuery: () => setState(() {
                                _query = '';
                                _searchController.clear();
                              }),
                              onOpen: (id) =>
                                  setState(() => _selectedCycleId = id),
                              onOpenAll: () =>
                                  setState(() => _showAllReports = true),
                            )
                    : _ArchiveDetail(
                        cycle: selected,
                        selectedTab: _selectedTab,
                        onTabChanged: (tab) =>
                            setState(() => _selectedTab = tab),
                        onCreateSummary: _input == null
                            ? null
                            : () => _openSummary(_input!),
                        onEditHealthRecords:
                            widget.healthRecordRepository == null
                            ? null
                            : _openHealthRecords,
                      ),
            },
          ),
        ),
      ),
    );
  }

  void _backToLetters() {
    final onBack = widget.onBack;
    if (onBack != null) {
      onBack();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _openSummary(ArchiveInput input) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SummaryExportScreen(
          repository: InMemorySummaryExportRepository(
            summaryExportInputFromArchive(input),
          ),
          fileShareAdapter: widget.fileShareAdapter,
        ),
      ),
    );
  }

  Future<void> _openHealthRecords() async {
    final repository = widget.healthRecordRepository;
    final input = _input;
    if (repository == null || input == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => HealthRecordsScreen(repository: repository),
      ),
    );
    if (!mounted) return;
    final refreshed = await repository.getAll();
    final updated = ArchiveInput(
      cycles: input.cycles,
      healthRecords: refreshed,
      careRecords: input.careRecords,
      reflections: input.reflections,
      cycleReflections: input.cycleReflections,
    );
    setState(() {
      _input = updated;
      _viewModel = buildArchiveViewsViewModel(updated);
    });
  }
}

class _ArchiveList extends StatelessWidget {
  const _ArchiveList({
    required this.viewModel,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onOpen,
    required this.onOpenAll,
  });

  final ArchiveViewsViewModel viewModel;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<String> onOpen;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final searching = normalized.isNotEmpty;
    final matchingCompleted = viewModel.completedCycles
        .where((cycle) => cycle.searchText.contains(normalized))
        .toList();
    final completed = searching
        ? matchingCompleted
        : matchingCompleted.take(3).toList();
    final current = viewModel.currentCycle;
    final showCurrent =
        current != null && current.searchText.contains(normalized);
    final noHistory = current == null && viewModel.completedCycles.isEmpty;
    final noResults = searching && !showCurrent && matchingCompleted.isEmpty;
    return ListView(
      key: const Key('archive-cycle-list'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        const LetterSectionTitle(
          eyebrow: 'Reports',
          title: 'The saved evidence for one cycle',
        ),
        const SizedBox(height: LetterSpacing.xs),
        const Text(
          'Open a cycle to inspect exactly what you recorded, or create a factual summary to share.',
          style: TextStyle(color: LetterColors.muted, height: 1.45),
        ),
        const SizedBox(height: LetterSpacing.md),
        if (!noHistory) ...[
          TextField(
            key: const Key('archive-search'),
            controller: searchController,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              labelText: 'Search saved evidence',
              helperText: searching
                  ? '${matchingCompleted.length + (showCurrent ? 1 : 0)} matching reports'
                  : 'Symptom, Care action, date, or reflection',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searching
                  ? IconButton(
                      key: const Key('reports-clear-search'),
                      onPressed: onClearQuery,
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: LetterSpacing.lg),
        if (noHistory)
          const _ReportsEmpty()
        else if (noResults)
          const _ReportsNoResults()
        else ...[
          if (showCurrent) ...[
            const LetterSectionTitle(
              eyebrow: 'Current cycle',
              title: 'Still open, so still incomplete',
            ),
            const SizedBox(height: LetterSpacing.xs),
            ArchiveCycleSummaryCard(
              cycle: current,
              onOpen: () => onOpen(current.id),
            ),
            const SizedBox(height: LetterSpacing.lg),
          ],
          if (completed.isNotEmpty) ...[
            LetterSectionTitle(
              eyebrow: searching ? 'Matching reports' : 'Recent reports',
              title: searching
                  ? 'Completed cycles that match'
                  : 'Your three newest completed cycles',
            ),
            const SizedBox(height: LetterSpacing.xs),
            ...completed.map(
              (cycle) => Padding(
                padding: const EdgeInsets.only(bottom: LetterSpacing.sm),
                child: ArchiveCycleSummaryCard(
                  cycle: cycle,
                  onOpen: () => onOpen(cycle.id),
                ),
              ),
            ),
          ],
          if (!searching && viewModel.completedCycles.isNotEmpty) ...[
            const SizedBox(height: LetterSpacing.xs),
            _ReportsArchiveLink(
              total: viewModel.completedCycles.length,
              hidden: (viewModel.completedCycles.length - completed.length)
                  .clamp(0, viewModel.completedCycles.length),
              onOpen: onOpenAll,
            ),
          ],
        ],
      ],
    );
  }
}

class _ReportsEmpty extends StatelessWidget {
  const _ReportsEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('reports-empty'),
      padding: const EdgeInsets.all(LetterSpacing.lg),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.description_outlined, color: LetterColors.teal, size: 28),
          SizedBox(height: LetterSpacing.sm),
          Text(
            'Nothing to report yet',
            style: TextStyle(
              fontFamily: 'Newsreader',
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: LetterSpacing.xs),
          Text(
            'Record a period start and the cycle it opens will appear here with whatever you save inside it.',
            style: TextStyle(color: LetterColors.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ReportsNoResults extends StatelessWidget {
  const _ReportsNoResults();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('archive-no-search-results'),
      padding: EdgeInsets.symmetric(vertical: LetterSpacing.lg),
      child: Column(
        children: [
          Icon(Icons.search_off, color: LetterColors.muted, size: 30),
          SizedBox(height: LetterSpacing.sm),
          Text(
            'No saved evidence matches that',
            key: Key('reports-no-results'),
            style: TextStyle(
              fontFamily: 'Newsreader',
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: LetterSpacing.xs),
          Text(
            'Search only checks the records, Care actions, dates, and reflections you saved.',
            textAlign: TextAlign.center,
            style: TextStyle(color: LetterColors.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ReportsArchiveLink extends StatelessWidget {
  const _ReportsArchiveLink({
    required this.total,
    required this.hidden,
    required this.onOpen,
  });

  final int total;
  final int hidden;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LetterColors.tealSoft,
      borderRadius: BorderRadius.circular(LetterRadius.panel),
      child: InkWell(
        key: const Key('reports-archive-link'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(LetterRadius.panel),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.all(LetterSpacing.md),
            child: Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  color: LetterColors.teal,
                ),
                const SizedBox(width: LetterSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'All reports',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: LetterSpacing.xxs),
                      Text(
                        hidden > 0
                            ? '$total completed reports · $hidden not shown here'
                            : '$total completed ${total == 1 ? 'report' : 'reports'} · grouped by year',
                        style: const TextStyle(
                          color: LetterColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: LetterColors.teal),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AllReportsView extends StatefulWidget {
  const _AllReportsView({required this.cycles, required this.onOpen});

  final List<ArchiveCycleSummaryViewModel> cycles;
  final ValueChanged<String> onOpen;

  @override
  State<_AllReportsView> createState() => _AllReportsViewState();
}

class _AllReportsViewState extends State<_AllReportsView> {
  static const _pageSize = 6;

  late final List<int> _years;
  late final Set<int> _expandedYears;
  final Map<int, int> _visibleByYear = {};

  @override
  void initState() {
    super.initState();
    _years = widget.cycles.map((cycle) => cycle.startDate.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    _expandedYears = {if (_years.isNotEmpty) _years.first};
  }

  List<ArchiveCycleSummaryViewModel> _cyclesIn(int year) =>
      widget.cycles.where((cycle) => cycle.startDate.year == year).toList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('reports-archive'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Text(
          '${widget.cycles.length} completed ${widget.cycles.length == 1 ? 'report' : 'reports'} on this device · grouped by year',
          style: const TextStyle(color: LetterColors.muted, height: 1.4),
        ),
        const SizedBox(height: LetterSpacing.lg),
        if (widget.cycles.isEmpty)
          const _ReportsEmpty()
        else
          for (final year in _years) _yearSection(year),
      ],
    );
  }

  Widget _yearSection(int year) {
    final cycles = _cyclesIn(year);
    final expanded = _expandedYears.contains(year);
    final visibleCount = _visibleByYear[year] ?? _pageSize;
    final shown = expanded ? cycles.take(visibleCount).toList() : const [];
    final remaining = cycles.length - shown.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: LetterSpacing.sm),
      child: Material(
        color: LetterColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: LetterColors.line),
          borderRadius: BorderRadius.circular(LetterRadius.panel),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: Key('reports-year-$year'),
          initiallyExpanded: expanded,
          maintainState: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: LetterSpacing.md),
          childrenPadding: const EdgeInsets.fromLTRB(
            LetterSpacing.md,
            0,
            LetterSpacing.md,
            LetterSpacing.md,
          ),
          onExpansionChanged: (value) => setState(() {
            if (value) {
              _expandedYears.add(year);
            } else {
              _expandedYears.remove(year);
            }
          }),
          title: Text(
            '$year',
            style: const TextStyle(
              fontFamily: 'Newsreader',
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '${cycles.length} completed ${cycles.length == 1 ? 'report' : 'reports'}',
            style: const TextStyle(color: LetterColors.muted, fontSize: 12),
          ),
          children: [
            KeyedSubtree(
              key: Key('reports-year-$year-content'),
              child: Column(
                children: [
                  for (final cycle in shown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: LetterSpacing.sm),
                      child: ArchiveCycleSummaryCard(
                        cycle: cycle,
                        onOpen: () => widget.onOpen(cycle.id),
                      ),
                    ),
                  if (remaining > 0)
                    OutlinedButton(
                      key: Key('reports-year-$year-more'),
                      onPressed: () => setState(
                        () => _visibleByYear[year] = visibleCount + _pageSize,
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: Text('Show more ($remaining)'),
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

class ArchiveCycleSummaryCard extends StatelessWidget {
  const ArchiveCycleSummaryCard({
    required this.cycle,
    required this.onOpen,
    super.key,
  });

  final ArchiveCycleSummaryViewModel cycle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final stacked =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.45;
    final status = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LetterSpacing.xs,
        vertical: LetterSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cycle.isComplete ? LetterColors.tealSoft : LetterColors.surface,
        border: Border.all(
          color: cycle.isComplete ? LetterColors.teal : LetterColors.line,
        ),
        borderRadius: BorderRadius.circular(LetterRadius.control),
      ),
      child: Text(
        cycle.isComplete ? 'Complete' : 'Incomplete',
        style: TextStyle(
          color: cycle.isComplete ? LetterColors.tealDark : LetterColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cycle.title,
          style: const TextStyle(
            fontFamily: 'Newsreader',
            fontSize: 22,
            height: 1.05,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (cycle.title != cycle.dateRange) ...[
          const SizedBox(height: LetterSpacing.xxs),
          Text(
            cycle.dateRange,
            style: const TextStyle(
              color: LetterColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
    return Semantics(
      button: true,
      label:
          '${cycle.title}${cycle.title == cycle.dateRange ? '' : ', ${cycle.dateRange}'}, ${cycle.isComplete ? 'complete' : 'incomplete'}, ${cycle.coverageLabel}',
      child: ExcludeSemantics(
        child: Material(
          color: LetterColors.surface,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: LetterColors.line),
            borderRadius: BorderRadius.circular(LetterRadius.panel),
          ),
          child: InkWell(
            key: Key('archive-cycle-${cycle.id}'),
            onTap: onOpen,
            borderRadius: BorderRadius.circular(LetterRadius.panel),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 108),
              child: Padding(
                padding: const EdgeInsets.all(LetterSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (stacked) ...[
                      title,
                      const SizedBox(height: LetterSpacing.xs),
                      status,
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: title),
                          const SizedBox(width: LetterSpacing.xs),
                          status,
                        ],
                      ),
                    const SizedBox(height: LetterSpacing.sm),
                    Text(
                      [cycle.coverageLabel, cycle.periodDatesLabel].join(' · '),
                      style: const TextStyle(
                        color: LetterColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    if (cycle.missingLabel case final missing?) ...[
                      const SizedBox(height: LetterSpacing.xxs),
                      Text(
                        missing,
                        style: const TextStyle(
                          color: LetterColors.amber,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: LetterSpacing.sm),
                    const Row(
                      children: [
                        Text(
                          'Open report',
                          style: TextStyle(
                            color: LetterColors.tealDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: LetterSpacing.xxs),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: LetterColors.teal,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchiveDetail extends StatelessWidget {
  const _ArchiveDetail({
    required this.cycle,
    required this.selectedTab,
    required this.onTabChanged,
    this.onCreateSummary,
    this.onEditHealthRecords,
  });

  final ArchiveCycleSummaryViewModel cycle;
  final ArchiveViewTab selectedTab;
  final ValueChanged<ArchiveViewTab> onTabChanged;
  final VoidCallback? onCreateSummary;
  final VoidCallback? onEditHealthRecords;

  @override
  Widget build(BuildContext context) {
    final stacked =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.45;
    final tabs = SegmentedButton<ArchiveViewTab>(
      segments: const [
        ButtonSegment(
          value: ArchiveViewTab.story,
          label: Text('Story'),
          icon: Icon(Icons.auto_stories_outlined),
        ),
        ButtonSegment(
          value: ArchiveViewTab.clinical,
          label: Text('Clinical'),
          icon: Icon(Icons.table_chart_outlined),
        ),
      ],
      selected: {selectedTab},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onTabChanged(selection.first),
    );
    return Column(
      children: [
        if (!cycle.isComplete)
          Container(
            key: const Key('report-incomplete-note'),
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.all(LetterSpacing.sm),
            decoration: BoxDecoration(
              color: LetterColors.mist,
              border: Border.all(color: LetterColors.line),
              borderRadius: BorderRadius.circular(LetterRadius.control),
            ),
            child: const Text(
              'This cycle is still open, so this report is incomplete. It will keep changing until the next period start is recorded.',
              style: TextStyle(color: LetterColors.muted, height: 1.4),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: KeyedSubtree(
            key: const Key('archive-view-tabs'),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final tab in ArchiveViewTab.values)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: LetterSpacing.xs,
                          ),
                          child: OutlinedButton.icon(
                            onPressed: () => onTabChanged(tab),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              backgroundColor: selectedTab == tab
                                  ? LetterColors.tealSoft
                                  : null,
                            ),
                            icon: Icon(
                              tab == ArchiveViewTab.story
                                  ? Icons.auto_stories_outlined
                                  : Icons.table_chart_outlined,
                            ),
                            label: Text(
                              tab == ArchiveViewTab.story
                                  ? 'Story'
                                  : 'Clinical',
                            ),
                          ),
                        ),
                    ],
                  )
                : tabs,
          ),
        ),
        Expanded(
          child: switch (selectedTab) {
            ArchiveViewTab.story => ArchiveStoryView(viewModel: cycle.story),
            ArchiveViewTab.clinical => ArchiveClinicalView(
              viewModel: cycle.clinical,
              onCreateSummary: onCreateSummary,
              onEditHealthRecords: onEditHealthRecords,
            ),
          },
        ),
      ],
    );
  }
}

class _ArchiveError extends StatelessWidget {
  const _ArchiveError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('reports-error'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('The private archive could not be opened.'),
          const SizedBox(height: LetterSpacing.sm),
          FilledButton.icon(
            key: const Key('reports-retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
