import 'package:flutter/material.dart';

import '../../archive_views/domain/archive_repository.dart';
import '../../archive_views/presentation/archive_views_screen.dart';
import '../../care/domain/care_memory.dart';
import '../../care/domain/care_memory_repository.dart';
import '../../care/presentation/cycle_reflection_flow.dart';
import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_record.dart';
import '../../cycle/domain/period_repository.dart';
import '../../entitlement/data/local_entitlement_repository.dart';
import '../../entitlement/domain/entitlement.dart';
import '../../entitlement/presentation/entitlement_scope.dart';
import '../../health_records/domain/health_record_repository.dart';
import '../../patterns/data/repository_pattern_source.dart';
import '../../patterns/presentation/personal_patterns_route.dart';
import '../domain/cycle_letter.dart';
import '../domain/cycle_letters_aggregator.dart';
import 'cycle_letters_screen.dart';

class LettersHomeScreen extends StatefulWidget {
  const LettersHomeScreen({
    required this.periodRepository,
    required this.careMemoryRepository,
    required this.onNavigationSelected,
    required this.healthRecordRepository,
    super.key,
  });

  final PeriodRepository periodRepository;
  final CareMemoryRepository careMemoryRepository;
  final ValueChanged<int> onNavigationSelected;
  final HealthRecordRepository healthRecordRepository;

  @override
  State<LettersHomeScreen> createState() => _LettersHomeScreenState();
}

class _LettersHomeScreenState extends State<LettersHomeScreen> {
  CycleLettersViewModel _viewModel = const CycleLettersViewModel.loading();
  List<CycleReflection> _cycleReflections = const [];
  String? _selectedLetterId;
  int? _reflectionCycleStartDay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() => _viewModel = const CycleLettersViewModel.loading());
    }
    try {
      final periods = await widget.periodRepository.getAll();
      final records = await widget.careMemoryRepository.getRecords();
      final reflections = await widget.careMemoryRepository.getReflections();
      final cycleReflections = await widget.careMemoryRepository
          .getCycleReflections();
      final archive = CycleLettersAggregator.build(
        periods: periods,
        careRecords: records,
        reflections: reflections,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _cycleReflections = cycleReflections;
        _viewModel = _toViewModel(
          archive,
          periods,
          reflections,
          cycleReflections,
        );
      });
    } on Object {
      if (mounted) {
        setState(() => _viewModel = const CycleLettersViewModel.error());
      }
    }
  }

  CycleReflection? _cycleReflectionFor(int cycleStartDay) {
    return _cycleReflections
        .where((reflection) => reflection.cycleStartDay == cycleStartDay)
        .firstOrNull;
  }

  Future<void> _saveCycleReflection(
    int cycleStartDay,
    CycleReflectionDraft draft,
  ) async {
    await widget.careMemoryRepository.saveCycleReflection(cycleStartDay, draft);
    await _reloadSourcesWithoutClosingReflection();
  }

  Future<void> _deleteCycleReflection(CycleReflection reflection) async {
    await widget.careMemoryRepository.deleteCycleReflection(reflection.id);
    await _reloadSourcesWithoutClosingReflection();
  }

  Future<void> _openArchiveViews() async {
    try {
      final periods = await widget.periodRepository.getAll();
      final records = await widget.careMemoryRepository.getRecords();
      final reflections = await widget.careMemoryRepository.getReflections();
      final cycleReflections = await widget.careMemoryRepository
          .getCycleReflections();
      final healthRecords = await widget.healthRecordRepository.getAll();
      final sorted = [...periods]
        ..sort((left, right) => left.startDate.compareTo(right.startDate));
      final cycles = [
        for (var index = 0; index < sorted.length; index += 1)
          ArchiveCycleInput(
            id: sorted[index].id,
            number: index + 1,
            startDate: sorted[index].startDate,
            endDate: index + 1 < sorted.length
                ? sorted[index + 1].startDate.addDays(-1)
                : null,
            periodDates: [
              for (
                var day = 0;
                day < (sorted[index].durationDays ?? 1);
                day += 1
              )
                sorted[index].startDate.addDays(day),
            ],
            isComplete: index + 1 < sorted.length,
          ),
      ];
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => ArchiveViewsScreen(
            healthRecordRepository: widget.healthRecordRepository,
            repository: InMemoryArchiveRepository(
              ArchiveInput(
                cycles: cycles,
                healthRecords: healthRecords,
                careRecords: records,
                reflections: reflections,
                cycleReflections: cycleReflections,
              ),
            ),
          ),
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archive views could not be opened.')),
        );
      }
    }
  }

  Future<void> _openPersonalPatterns() async {
    final existingRepo = EntitlementScope.repositoryOf(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => EntitlementScope(
          repository:
              existingRepo ??
              LocalEntitlementRepository(
                initial: const EntitlementState(
                  status: EntitlementStatus.freeOrUnknown,
                ),
              ),
          child: PersonalPatternsRoute(
            source: RepositoryPatternSource(
              healthRecords: widget.healthRecordRepository,
              careMemory: widget.careMemoryRepository,
              periods: widget.periodRepository,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _reloadSourcesWithoutClosingReflection() async {
    final periods = await widget.periodRepository.getAll();
    final records = await widget.careMemoryRepository.getRecords();
    final reflections = await widget.careMemoryRepository.getReflections();
    final cycleReflections = await widget.careMemoryRepository
        .getCycleReflections();
    final archive = CycleLettersAggregator.build(
      periods: periods,
      careRecords: records,
      reflections: reflections,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _cycleReflections = cycleReflections;
      _viewModel = _toViewModel(
        archive,
        periods,
        reflections,
        cycleReflections,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cycleStartDay = _reflectionCycleStartDay;
    if (cycleStartDay != null) {
      final existing = _cycleReflectionFor(cycleStartDay);
      final letter = [
        ..._viewModel.completedLetters,
        ?_viewModel.currentCycle,
      ].where((item) => item.cycleStartDay == cycleStartDay).firstOrNull;
      return CycleReflectionFlow(
        cycleLabel: letter?.dateRange ?? 'Saved cycle',
        existingReflection: existing,
        onSave: (draft) => _saveCycleReflection(cycleStartDay, draft),
        onDelete: existing == null
            ? null
            : () => _deleteCycleReflection(existing),
        onClose: () => setState(() => _reflectionCycleStartDay = null),
      );
    }
    return CycleLettersScreen(
      viewModel: _viewModel,
      selectedLetterId: _selectedLetterId,
      onNavigationSelected: widget.onNavigationSelected,
      onRetry: _load,
      onLetterOpen: (id) => setState(() => _selectedLetterId = id),
      onLetterClose: () => setState(() => _selectedLetterId = null),
      onCycleReflectionOpen: (cycleStartDay) {
        setState(() => _reflectionCycleStartDay = cycleStartDay);
      },
      onOpenArchiveViews: _openArchiveViews,
      onOpenPersonalPatterns: _openPersonalPatterns,
    );
  }

  static CycleLettersViewModel _toViewModel(
    CycleLettersArchive archive,
    List<PeriodRecord> periods,
    List<CareReflection> reflections,
    List<CycleReflection> cycleReflections,
  ) {
    final periodsByStart = {
      for (final period in periods) period.startDate: period,
    };
    final reflectionsByRecord = {
      for (final reflection in reflections) reflection.careRecordId: reflection,
    };

    CycleLetterDisplay letter(CycleLetter source) {
      final period = periodsByStart[source.startDate];
      final cycleReflection = cycleReflections
          .where(
            (reflection) =>
                reflection.cycleStartDay == source.startDate.epochDay,
          )
          .firstOrNull;
      return CycleLetterDisplay(
        id: 'cycle-${source.startDate.epochDay}',
        cycleStartDay: source.startDate.epochDay,
        letterNumber: source.number,
        dateRange: source.endDate == null
            ? '${_formatDate(source.startDate)} - In progress'
            : '${_formatDate(source.startDate)} - '
                  '${_formatDate(source.endDate!)}',
        recordedPeriodDates: _periodDateLabels(period),
        careMoments: [
          for (final record in source.careRecords)
            CycleLetterCareMomentDisplay(
              id: record.id,
              dateLabel: _formatDateTime(record.occurredAt),
              actionLabel: record.actionLabel,
              checkBackLabel: _outcomeLabel(record.outcome),
              reflectionId: reflectionsByRecord[record.id]?.id,
              reflectionPreview: _reflectionPreview(
                reflectionsByRecord[record.id],
              ),
            ),
        ],
        checkBackCounts: CycleLetterCheckBackCounts(
          better: source.careRecords
              .where((record) => record.outcome == CareOutcome.better)
              .length,
          same: source.careRecords
              .where((record) => record.outcome == CareOutcome.same)
              .length,
          worse: source.careRecords
              .where((record) => record.outcome == CareOutcome.worse)
              .length,
        ),
        reflection: cycleReflection == null
            ? null
            : CycleLetterReflectionDisplay(
                id: cycleReflection.id,
                dateLabel: _formatDateTime(cycleReflection.updatedAt),
                observation: cycleReflection.observation,
                needLabel: cycleReflection.need == null
                    ? null
                    : _needLabel(cycleReflection.need!),
                whatHelped: cycleReflection.whatHelped,
                futureSelfNote: cycleReflection.futureSelfNote,
              ),
        notRecorded: const [
          'Symptoms and severity',
          'Medication history',
          'Clinical interpretation',
        ],
      );
    }

    return CycleLettersViewModel(
      status: CycleLettersStatus.ready,
      completedLetters: archive.completed.map(letter).toList(),
      currentCycle: archive.current == null ? null : letter(archive.current!),
      unassignedCareRecords: [
        for (final record in archive.unassignedCareRecords)
          UnassignedCareDisplay(
            id: record.id,
            dateLabel: _formatDateTime(record.occurredAt),
            actionLabel: record.actionLabel,
            checkBackLabel: _outcomeLabel(record.outcome),
          ),
      ],
    );
  }

  static List<String> _periodDateLabels(PeriodRecord? period) {
    if (period == null) {
      return const [];
    }
    final duration = period.durationDays;
    if (duration == null) {
      return [_formatDate(period.startDate)];
    }
    return [
      for (var day = 0; day < duration; day += 1)
        _formatDate(period.startDate.addDays(day)),
    ];
  }

  static String _formatDate(LocalDate date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static String _formatDateTime(DateTime value) {
    return _formatDate(LocalDate.fromDateTime(value.toLocal()));
  }

  static String _outcomeLabel(CareOutcome outcome) => switch (outcome) {
    CareOutcome.better => 'Better',
    CareOutcome.same => 'Same',
    CareOutcome.worse => 'Worse',
  };

  static String? _reflectionPreview(CareReflection? reflection) {
    if (reflection == null) return null;
    final parts = [
      reflection.observation,
      reflection.whatHelped,
      reflection.futureSelfNote,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();
    if (parts.isEmpty) {
      return reflection.need == null
          ? null
          : 'Need remembered: ${reflection.need!.name}';
    }
    return parts.join(' ');
  }

  static String _needLabel(ReflectionNeed need) => switch (need) {
    ReflectionNeed.boundaries => 'Boundaries',
    ReflectionNeed.connection => 'Connection',
    ReflectionNeed.autonomy => 'Autonomy',
    ReflectionNeed.restOrPhysicalCapacity => 'Rest or physical capacity',
    ReflectionNeed.somethingElse => 'Something else',
    ReflectionNeed.notSure => 'Not sure',
  };
}
