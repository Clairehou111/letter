import 'package:flutter/material.dart';

import '../../care/domain/care_memory.dart';
import '../../care/domain/care_memory_repository.dart';
import '../../care/presentation/clearer_day_reflection_flow.dart';
import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_record.dart';
import '../../cycle/domain/period_repository.dart';
import '../domain/cycle_letter.dart';
import '../domain/cycle_letters_aggregator.dart';
import 'cycle_letters_screen.dart';

class LettersHomeScreen extends StatefulWidget {
  const LettersHomeScreen({
    required this.periodRepository,
    required this.careMemoryRepository,
    required this.onNavigationSelected,
    super.key,
  });

  final PeriodRepository periodRepository;
  final CareMemoryRepository careMemoryRepository;
  final ValueChanged<int> onNavigationSelected;

  @override
  State<LettersHomeScreen> createState() => _LettersHomeScreenState();
}

class _LettersHomeScreenState extends State<LettersHomeScreen> {
  CycleLettersViewModel _viewModel = const CycleLettersViewModel.loading();
  List<CareRecord> _records = const [];
  List<CareReflection> _reflections = const [];
  String? _selectedLetterId;
  String? _reflectionRecordId;

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
      final archive = CycleLettersAggregator.build(
        periods: periods,
        careRecords: records,
        reflections: reflections,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _records = records;
        _reflections = reflections;
        _viewModel = _toViewModel(archive, periods, reflections);
      });
    } on Object {
      if (mounted) {
        setState(() => _viewModel = const CycleLettersViewModel.error());
      }
    }
  }

  CareRecord? get _selectedRecord {
    final id = _reflectionRecordId;
    if (id == null) {
      return null;
    }
    return _records.where((record) => record.id == id).firstOrNull;
  }

  CareReflection? _reflectionFor(String recordId) {
    return _reflections
        .where((reflection) => reflection.careRecordId == recordId)
        .firstOrNull;
  }

  Future<void> _saveReflection(
    CareRecord record,
    ClearerDayReflectionDraft draft,
  ) async {
    await widget.careMemoryRepository.saveReflection(
      record.id,
      CareReflectionDraft(
        observation: draft.stillFeelsTrue,
        need: _toDomainNeed(draft.need),
        whatHelped: draft.whatHelped,
        futureSelfNote: draft.futureSelfNote,
      ),
    );
    await _reloadSourcesWithoutClosingReflection();
  }

  Future<void> _deleteReflection(CareReflection reflection) async {
    await widget.careMemoryRepository.deleteReflection(reflection.id);
    await _reloadSourcesWithoutClosingReflection();
  }

  Future<void> _reloadSourcesWithoutClosingReflection() async {
    final periods = await widget.periodRepository.getAll();
    final records = await widget.careMemoryRepository.getRecords();
    final reflections = await widget.careMemoryRepository.getReflections();
    final archive = CycleLettersAggregator.build(
      periods: periods,
      careRecords: records,
      reflections: reflections,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _records = records;
      _reflections = reflections;
      _viewModel = _toViewModel(archive, periods, reflections);
    });
  }

  @override
  Widget build(BuildContext context) {
    final record = _selectedRecord;
    if (record != null) {
      final existing = _reflectionFor(record.id);
      return ClearerDayReflectionFlow(
        careRecord: ClearerDayCareRecordContext(
          recordId: record.id,
          modeLabel: record.mode.label,
          actionLabel: record.actionLabel,
          outcomeLabel: _outcomeLabel(record.outcome),
          occurredLabel: _formatDateTime(record.occurredAt),
        ),
        existingReflection: existing == null
            ? null
            : ClearerDayReflectionViewModel(
                reflectionId: existing.id,
                stillFeelsTrue: existing.observation,
                need: _toViewNeed(existing.need),
                whatHelped: existing.whatHelped,
                futureSelfNote: existing.futureSelfNote,
              ),
        onSave: (draft) => _saveReflection(record, draft),
        onDelete: existing == null ? null : () => _deleteReflection(existing),
        onDiscard: () => setState(() => _reflectionRecordId = null),
        onDone: () => setState(() => _reflectionRecordId = null),
      );
    }
    return CycleLettersScreen(
      viewModel: _viewModel,
      selectedLetterId: _selectedLetterId,
      onNavigationSelected: widget.onNavigationSelected,
      onRetry: _load,
      onLetterOpen: (id) => setState(() => _selectedLetterId = id),
      onLetterClose: () => setState(() => _selectedLetterId = null),
      onReflectionOpen: (reflectionId) {
        final reflection = _reflections
            .where((item) => item.id == reflectionId)
            .firstOrNull;
        if (reflection != null) {
          setState(() => _reflectionRecordId = reflection.careRecordId);
        }
      },
      onCareRecordReflect: (recordId) {
        setState(() => _reflectionRecordId = recordId);
      },
    );
  }

  static CycleLettersViewModel _toViewModel(
    CycleLettersArchive archive,
    List<PeriodRecord> periods,
    List<CareReflection> reflections,
  ) {
    final periodsByStart = {
      for (final period in periods) period.startDate: period,
    };
    final reflectionsByRecord = {
      for (final reflection in reflections) reflection.careRecordId: reflection,
    };

    CycleLetterDisplay letter(CycleLetter source) {
      final period = periodsByStart[source.startDate];
      final reflection = source.reflections.firstOrNull;
      return CycleLetterDisplay(
        id: 'cycle-${source.startDate.epochDay}',
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
        reflection: reflection == null
            ? null
            : CycleLetterReflectionDisplay(
                id: reflection.id,
                dateLabel: _formatDateTime(reflection.updatedAt),
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

  static ReflectionNeed? _toDomainNeed(ClearerDayNeed? need) {
    return switch (need) {
      ClearerDayNeed.boundaries => ReflectionNeed.boundaries,
      ClearerDayNeed.connection => ReflectionNeed.connection,
      ClearerDayNeed.autonomy => ReflectionNeed.autonomy,
      ClearerDayNeed.restOrPhysicalCapacity =>
        ReflectionNeed.restOrPhysicalCapacity,
      ClearerDayNeed.somethingElse => ReflectionNeed.somethingElse,
      ClearerDayNeed.notSure => ReflectionNeed.notSure,
      null => null,
    };
  }

  static ClearerDayNeed? _toViewNeed(ReflectionNeed? need) {
    return switch (need) {
      ReflectionNeed.boundaries => ClearerDayNeed.boundaries,
      ReflectionNeed.connection => ClearerDayNeed.connection,
      ReflectionNeed.autonomy => ClearerDayNeed.autonomy,
      ReflectionNeed.restOrPhysicalCapacity =>
        ClearerDayNeed.restOrPhysicalCapacity,
      ReflectionNeed.somethingElse => ClearerDayNeed.somethingElse,
      ReflectionNeed.notSure => ClearerDayNeed.notSure,
      null => null,
    };
  }
}
