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
  });

  final ArchiveRepository repository;
  final LocalFileShareAdapter fileShareAdapter;
  final HealthRecordRepository? healthRecordRepository;

  @override
  State<ArchiveViewsScreen> createState() => _ArchiveViewsScreenState();
}

class _ArchiveViewsScreenState extends State<ArchiveViewsScreen> {
  ArchiveViewsViewModel _viewModel = const ArchiveViewsViewModel.loading();
  String _query = '';
  String? _selectedCycleId;
  ArchiveViewTab _selectedTab = ArchiveViewTab.story;
  ArchiveInput? _input;

  @override
  void initState() {
    super.initState();
    _load();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Archive views')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: switch (_viewModel.status) {
              ArchiveViewStatus.loading => const Center(
                child: CircularProgressIndicator(color: LetterColors.teal),
              ),
              ArchiveViewStatus.error => _ArchiveError(onRetry: _load),
              ArchiveViewStatus.ready =>
                selected == null
                    ? _ArchiveList(
                        viewModel: _viewModel,
                        query: _query,
                        onQueryChanged: (value) =>
                            setState(() => _query = value),
                        onOpen: (id) => setState(() => _selectedCycleId = id),
                      )
                    : _ArchiveDetail(
                        cycle: selected,
                        selectedTab: _selectedTab,
                        onBack: () => setState(() => _selectedCycleId = null),
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
    required this.query,
    required this.onQueryChanged,
    required this.onOpen,
  });

  final ArchiveViewsViewModel viewModel;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final completed = viewModel.completedCycles
        .where((cycle) => cycle.searchText.contains(normalized))
        .toList();
    final current = viewModel.currentCycle;
    final showCurrent =
        current != null && current.searchText.contains(normalized);
    return ListView(
      key: const Key('archive-cycle-list'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        const LetterSectionTitle(
          eyebrow: 'Letter / Archive',
          title: 'Your cycle archive',
        ),
        const SizedBox(height: LetterSpacing.md),
        TextField(
          key: const Key('archive-search'),
          onChanged: onQueryChanged,
          decoration: const InputDecoration(
            labelText: 'Search saved cycles',
            helperText: 'Symptom, Care action, date, or cycle number',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: LetterSpacing.lg),
        if (showCurrent) ...[
          const LetterSectionTitle(
            eyebrow: 'Still being recorded',
            title: 'Current cycle',
          ),
          const SizedBox(height: LetterSpacing.xs),
          ArchiveCycleSummaryCard(
            cycle: current,
            onOpen: () => onOpen(current.id),
          ),
          const SizedBox(height: LetterSpacing.lg),
        ],
        if (completed.isNotEmpty) ...[
          const LetterSectionTitle(
            eyebrow: 'Completed cycles',
            title: 'Cycle letters',
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
        if (!showCurrent && completed.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: LetterSpacing.lg),
            child: Text(
              'No saved cycle matches this search.',
              key: Key('archive-no-search-results'),
            ),
          ),
        const SizedBox(height: LetterSpacing.lg),
        const Text(
          'This archive shows only saved local records. Drafts, clipboard text, inferred symptoms, medication, contacts, and cloud data are not shown.',
          style: TextStyle(
            color: LetterColors.muted,
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ],
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
    return Semantics(
      button: true,
      label: '${cycle.title}, ${cycle.dateRange}, ${cycle.coverageLabel}',
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
          child: Padding(
            padding: const EdgeInsets.all(LetterSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 84,
                  color: cycle.isComplete
                      ? LetterColors.violet
                      : LetterColors.coral,
                ),
                const SizedBox(width: LetterSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              cycle.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (!cycle.isComplete)
                            const Text(
                              'INCOMPLETE',
                              style: TextStyle(
                                color: LetterColors.amber,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: LetterSpacing.xxs),
                      Text(
                        cycle.dateRange,
                        style: const TextStyle(
                          color: LetterColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.xs),
                      Text(
                        cycle.periodDatesLabel,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        cycle.coverageLabel,
                        style: const TextStyle(
                          color: LetterColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      if (cycle.missingLabel case final missing?)
                        Text(
                          missing,
                          style: const TextStyle(
                            color: LetterColors.amber,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: LetterColors.muted),
              ],
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
    required this.onBack,
    required this.onTabChanged,
    this.onCreateSummary,
    this.onEditHealthRecords,
  });

  final ArchiveCycleSummaryViewModel cycle;
  final ArchiveViewTab selectedTab;
  final VoidCallback onBack;
  final ValueChanged<ArchiveViewTab> onTabChanged;
  final VoidCallback? onCreateSummary;
  final VoidCallback? onEditHealthRecords;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to archive',
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cycle.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      cycle.dateRange,
                      style: const TextStyle(color: LetterColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: SegmentedButton<ArchiveViewTab>(
            key: const Key('archive-view-tabs'),
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
            onSelectionChanged: (selection) => onTabChanged(selection.first),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('The private archive could not be opened.'),
          const SizedBox(height: LetterSpacing.sm),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
