import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/letter_bottom_navigation.dart';
import '../../../design_system/letter_theme.dart';
import '../domain/bleeding_flow.dart';
import '../domain/cycle_prediction.dart';
import '../domain/local_date.dart';
import '../domain/period_record.dart';
import '../domain/period_repository.dart';
import 'period_flow_screen.dart';
import 'today_flow_card.dart';

class CycleScreen extends StatefulWidget {
  const CycleScreen({
    required this.repository,
    super.key,
    this.onNavigationSelected,
    this.now,
  });

  final PeriodRepository repository;
  final ValueChanged<int>? onNavigationSelected;
  final DateTime Function()? now;

  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

/// The cycle-recording workspace without a root scaffold or primary navigation.
/// Letters embeds this surface so period operations continue to use the same
/// repository, validation, and prediction paths as the compatibility screen.
class CycleOperationsPane extends StatefulWidget {
  const CycleOperationsPane({
    required this.repository,
    super.key,
    this.now,
    this.embedded = false,
    this.compact = false,
    this.onDataChanged,
    this.onDeleteRequested,
  });

  final PeriodRepository repository;
  final DateTime Function()? now;
  final bool embedded;
  final bool compact;
  final FutureOr<void> Function()? onDataChanged;
  final FutureOr<void> Function(PeriodRecord record)? onDeleteRequested;

  @override
  State<CycleOperationsPane> createState() => _CycleOperationsPaneState();
}

class _CycleScreenState extends State<CycleScreen> {
  @override
  Widget build(BuildContext context) {
    final inheritedTheme = Theme.of(context);
    final lovableTheme = inheritedTheme.copyWith(
      textTheme: inheritedTheme.textTheme.apply(
        bodyColor: LetterColors.ink,
        displayColor: LetterColors.ink,
      ),
    );
    return Theme(
      data: lovableTheme,
      child: Scaffold(
        bottomNavigationBar: LetterBottomNavigation(
          selectedIndex: 2,
          onSelected: widget.onNavigationSelected,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: CycleOperationsPane(
                repository: widget.repository,
                now: widget.now,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CycleOperationsPaneState extends State<CycleOperationsPane> {
  List<PeriodRecord> _records = const [];
  List<BleedingDayRecord> _flowDays = const [];
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;

  LocalDate get _today =>
      LocalDate.fromDateTime((widget.now ?? DateTime.now)());

  PeriodRecord? get _openPeriod {
    for (final record in _records) {
      if (record.isOpen) {
        return record;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final results = await Future.wait<Object>([
        widget.repository.getAll(),
        widget.repository.getAllFlowDays(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _records = results[0] as List<PeriodRecord>;
        _flowDays = results[1] as List<BleedingDayRecord>;
        _loading = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _notifyDataChanged() async {
    await widget.onDataChanged?.call();
  }

  Future<void> _startToday() async {
    await _write(
      () => widget.repository.create(
        PeriodDraft(startDate: _today),
        today: _today,
      ),
      successMessage: 'Period started for today.',
    );
  }

  Future<void> _endCurrent() async {
    final current = _openPeriod;
    if (current == null) {
      return;
    }
    await _write(
      () => widget.repository.update(
        current.id,
        PeriodDraft(startDate: current.startDate, endDate: _today),
        today: _today,
      ),
      successMessage: 'Period ended today.',
    );
  }

  Future<void> _openEditor([PeriodRecord? record]) async {
    PeriodDraft? attemptedDraft;
    while (mounted) {
      if (!context.mounted) return;
      final draft = await showModalBottomSheet<PeriodDraft>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => PeriodEditorSheet(
          record: record,
          initialDraft: attemptedDraft,
          today: _today,
        ),
      );
      if (draft == null || !mounted) {
        return;
      }

      setState(() => _saving = true);
      try {
        if (record == null) {
          final confirmed = await _confirmAdjacentPeriod(draft);
          if (!confirmed) {
            attemptedDraft = draft;
            return;
          }
          await widget.repository.create(draft, today: _today);
        } else {
          await widget.repository.update(record.id, draft, today: _today);
        }
        final records = await _readRecordsAndFlow();
        if (!mounted) {
          return;
        }
        setState(() => _records = records);
        await _notifyDataChanged();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              record == null
                  ? 'Period added to your history.'
                  : 'Period dates updated.',
            ),
          ),
        );
        return;
      } on PeriodWriteException catch (error) {
        attemptedDraft = draft;
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.userMessage)));
        }
      } on Object {
        attemptedDraft = draft;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Letter Within could not save these dates. Try again.',
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _saving = false);
        }
      }
    }
  }

  Future<bool> _confirmAdjacentPeriod(PeriodDraft draft) async {
    final preceding =
        _records
            .where((item) => item.startDate.isBefore(draft.startDate))
            .toList()
          ..sort((left, right) => right.startDate.compareTo(left.startDate));
    final previous = preceding.firstOrNull;
    if (previous == null ||
        draft.startDate.epochDay - previous.startDate.epochDay >= 10) {
      return true;
    }
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Save as a separate period?'),
            content: const Text(
              'This start is less than 10 days after the previous period '
              'start. It may be continuing bleeding or spotting. Letter Within will '
              'only save it as a separate record if you confirm.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Review dates'),
              ),
              FilledButton(
                key: const Key('confirm-adjacent-period'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save record'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _confirmDelete(PeriodRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this period?'),
        content: Text(
          'The period beginning ${_formatDate(context, record.startDate)} '
          'will be permanently removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-delete-period'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: LetterColors.safetyRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _write(
      () => widget.repository.delete(record.id),
      successMessage: 'Period deleted.',
    );
  }

  Future<void> _requestDelete(PeriodRecord record) async {
    final externalDelete = widget.onDeleteRequested;
    if (externalDelete == null) {
      await _confirmDelete(record);
      return;
    }
    await externalDelete(record);
    if (mounted) {
      await _reloadRecords();
    }
  }

  Future<void> _write(
    Future<Object?> Function() operation, {
    required String successMessage,
  }) async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await operation();
      final records = await _readRecordsAndFlow();
      if (!mounted) {
        return;
      }
      setState(() => _records = records);
      await _notifyDataChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } on PeriodWriteException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.userMessage)));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Letter Within could not save these dates. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<List<PeriodRecord>> _reloadRecords() async {
    final records = await _readRecordsAndFlow();
    if (mounted) {
      setState(() => _records = records);
    }
    await _notifyDataChanged();
    return records;
  }

  Future<List<PeriodRecord>> _readRecordsAndFlow() async {
    final results = await Future.wait<Object>([
      widget.repository.getAll(),
      widget.repository.getAllFlowDays(),
    ]);
    final records = results[0] as List<PeriodRecord>;
    final flowDays = results[1] as List<BleedingDayRecord>;
    if (mounted) {
      _flowDays = flowDays;
    }
    return records;
  }

  Future<void> _openFlowEditor(PeriodRecord record) async {
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => PeriodFlowScreen(
          repository: widget.repository,
          record: record,
          today: _today,
          initialDate: record.isOpen ? _today : null,
          initialFlowDays: _flowDays
              .where((flowDay) => flowDay.periodId == record.id)
              .toList(growable: false),
        ),
      ),
    );
    if (mounted) {
      await _reloadRecords();
    }
  }

  Future<void> _openAllPeriods() async {
    if (!mounted) {
      return;
    }
    final closedRecords = _records.where((record) => !record.isOpen).toList();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => AllPeriodsScreen(
          repository: widget.repository,
          records: closedRecords,
          cycleLengthByPeriodId: _completedCycleLengths(_records),
          flowDays: _flowDays,
          today: _today,
          onDeleteRequested: widget.onDeleteRequested,
          onDataChanged: widget.onDataChanged,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _reloadRecords();
  }

  @override
  Widget build(BuildContext context) {
    final content = _loading
        ? const _CycleLoading()
        : _loadFailed
        ? _CycleLoadError(onRetry: _load)
        : _CycleContent(
            records: _records,
            flowDays: _flowDays,
            today: _today,
            saving: _saving,
            onStartToday: _startToday,
            onEndToday: _endCurrent,
            onAddPast: () => _openEditor(),
            onEdit: _openEditor,
            onDelete: _requestDelete,
            onOpenFlow: _openFlowEditor,
            onOpenAllPeriods: _openAllPeriods,
            embedded: widget.embedded,
            compact: widget.compact,
          );
    return widget.embedded
        ? content
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: content,
            ),
          );
  }
}

class _CycleLoading extends StatelessWidget {
  const _CycleLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Opening private cycle history',
        child: const CircularProgressIndicator(color: LetterColors.teal),
      ),
    );
  }
}

class _CycleLoadError extends StatelessWidget {
  const _CycleLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LetterSpacing.xl),
        child: LetterSurface(
          color: LetterColors.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 34,
                color: LetterColors.teal,
              ),
              const SizedBox(height: LetterSpacing.md),
              const Text(
                'Your private cycle history could not be opened.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Newsreader',
                  fontSize: 25,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: LetterSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('retry-cycle-load'),
                  onPressed: onRetry,
                  style: LetterButtonStyles.filled,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CycleContent extends StatelessWidget {
  const _CycleContent({
    required this.records,
    required this.flowDays,
    required this.today,
    required this.saving,
    required this.onStartToday,
    required this.onEndToday,
    required this.onAddPast,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenFlow,
    required this.onOpenAllPeriods,
    this.embedded = false,
    this.compact = false,
  });

  final List<PeriodRecord> records;
  final List<BleedingDayRecord> flowDays;
  final LocalDate today;
  final bool saving;
  final VoidCallback onStartToday;
  final VoidCallback onEndToday;
  final VoidCallback onAddPast;
  final Future<void> Function(PeriodRecord) onEdit;
  final Future<void> Function(PeriodRecord) onDelete;
  final Future<void> Function(PeriodRecord) onOpenFlow;
  final VoidCallback onOpenAllPeriods;
  final bool embedded;
  final bool compact;

  PeriodRecord? get openPeriod =>
      records.where((record) => record.isOpen).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final closedRecords = records.where((record) => !record.isOpen).toList()
      ..sort((left, right) => right.startDate.compareTo(left.startDate));
    final recentRecords = closedRecords.take(3).toList();
    final cycleLengths = _completedCycleLengths(records);
    final children = <Widget>[
      if (!compact) const _CycleHeader(),
      if (!compact) const SizedBox(height: LetterSpacing.lg),
      if (openPeriod case final current?)
        _CurrentPeriodPanel(
          record: current,
          today: today,
          saving: saving,
          onEndToday: onEndToday,
          onAddPast: onAddPast,
          onEdit: () => onEdit(current),
        )
      else
        _NoCurrentPeriodPanel(
          hasHistory: records.isNotEmpty,
          lastPeriodStart: closedRecords.firstOrNull?.startDate,
          saving: saving,
          onStartToday: onStartToday,
          onAddPast: onAddPast,
        ),
      if (openPeriod case final current?) ...[
        const SizedBox(height: LetterSpacing.md),
        TodayFlowCard(
          record: current,
          today: today,
          flow: _flowForDate(flowDays, current.id, today)?.flow,
          recordedDays: _flowCount(flowDays, current.id),
          onOpenFlow: () => onOpenFlow(current),
        ),
      ],
      const SizedBox(height: LetterSpacing.md),
      _PredictionSection(records: records, today: today, compact: compact),
      if (!compact) ...[
        const SizedBox(height: LetterSpacing.lg),
        _CycleHistorySection(
          records: recentRecords,
          flowDays: flowDays,
          cycleLengthByPeriodId: cycleLengths,
          totalRecords: closedRecords.length,
          saving: saving,
          onAddPast: onAddPast,
          onEdit: onEdit,
          onDelete: onDelete,
          onOpenFlow: onOpenFlow,
          onOpenAllPeriods: onOpenAllPeriods,
        ),
        const SizedBox(height: LetterSpacing.lg),
        _ExplanationCard(records: records, today: today),
      ],
    ];
    final column = Padding(
      padding: EdgeInsets.fromLTRB(
        embedded ? 0 : 20,
        embedded ? 0 : 18,
        embedded ? 0 : 20,
        embedded ? 0 : 36,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    return embedded
        ? column
        : SingleChildScrollView(
            key: const Key('cycle-scroll-view'),
            child: column,
          );
  }
}

class _CycleHeader extends StatelessWidget {
  const _CycleHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, LetterSpacing.xs, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LetterEyebrow('CYCLE'),
          const SizedBox(height: LetterSpacing.xxs),
          Semantics(
            header: true,
            child: Text(
              'Recorded dates',
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: context.isLetterNarrow ? 26 : 30,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: LetterSpacing.sm),
          const Text(
            'Every period below is a date you entered. Estimates are calculated from these dates and are never stored as recorded days.',
            style: TextStyle(
              color: LetterColors.muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoCurrentPeriodPanel extends StatelessWidget {
  const _NoCurrentPeriodPanel({
    required this.hasHistory,
    required this.lastPeriodStart,
    required this.saving,
    required this.onStartToday,
    required this.onAddPast,
  });

  final bool hasHistory;
  final LocalDate? lastPeriodStart;
  final bool saving;
  final VoidCallback onStartToday;
  final VoidCallback onAddPast;

  @override
  Widget build(BuildContext context) {
    final stacked = context.isLetterNarrow || context.isLetterLargeText;
    final title = hasHistory
        ? 'No period in progress'
        : 'No period recorded yet';
    final actions = <Widget>[
      _CycleButton(
        key: const Key('start-period-today'),
        label: 'Start period today',
        primary: true,
        expand: stacked,
        onPressed: saving ? null : onStartToday,
        semanticHint: 'Records today as the first day of bleeding',
      ),
      if (stacked) const SizedBox(height: LetterSpacing.xs),
      _CycleButton(
        key: const Key('add-past-period'),
        label: 'Add past period',
        expand: stacked,
        onPressed: saving ? null : onAddPast,
        semanticHint:
            'Enter the dates of a period you did not record at the time',
      ),
    ];
    return LetterSurface(
      key: const Key('no-current-period'),
      color: LetterColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LetterEyebrow('STATUS'),
          const SizedBox(height: LetterSpacing.xxs),
          Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: stacked ? 20 : 22,
                height: 1.15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: LetterSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ProvenanceTag(observed: true),
              const SizedBox(width: LetterSpacing.xs),
              Expanded(
                child: Text(
                  hasHistory
                      ? 'Recorded by you on this device.'
                      : 'Nothing recorded yet. Start when your period begins.',
                  style: const TextStyle(
                    color: LetterColors.muted,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          if (lastPeriodStart != null) ...[
            const SizedBox(height: LetterSpacing.xs),
            Text(
              'Last period started ${_formatDate(context, lastPeriodStart!)}',
              style: const TextStyle(
                color: LetterColors.muted,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: LetterSpacing.md),
          stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: actions,
                )
              : Wrap(
                  spacing: LetterSpacing.sm,
                  runSpacing: LetterSpacing.xs,
                  children: actions,
                ),
        ],
      ),
    );
  }
}

class _CurrentPeriodPanel extends StatelessWidget {
  const _CurrentPeriodPanel({
    required this.record,
    required this.today,
    required this.saving,
    required this.onEndToday,
    required this.onAddPast,
    required this.onEdit,
  });

  final PeriodRecord record;
  final LocalDate today;
  final bool saving;
  final VoidCallback onEndToday;
  final VoidCallback onAddPast;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final day = today.epochDay - record.startDate.epochDay + 1;
    final stacked = context.isLetterNarrow || context.isLetterLargeText;
    final actions = <Widget>[
      _CycleButton(
        key: const Key('end-period-today'),
        label: 'End period today',
        primary: true,
        expand: stacked,
        onPressed: saving ? null : onEndToday,
        semanticHint: 'Records today as the last day of bleeding',
      ),
      if (stacked) const SizedBox(height: LetterSpacing.xs),
      _CycleButton(
        key: const Key('add-past-period'),
        label: 'Add past period',
        expand: stacked,
        onPressed: saving ? null : onAddPast,
        semanticHint:
            'Enter the dates of a period you did not record at the time',
      ),
    ];
    return LetterSurface(
      key: const Key('current-period'),
      color: LetterColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LetterEyebrow('STATUS'),
          const SizedBox(height: LetterSpacing.xxs),
          Semantics(
            header: true,
            child: Text(
              'Period in progress since ${_formatDate(context, record.startDate)}',
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: stacked ? 20 : 22,
                height: 1.15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: LetterSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ProvenanceTag(observed: true),
              const SizedBox(width: LetterSpacing.xs),
              Expanded(
                child: Text(
                  'Recorded period day $day. No end date recorded yet.',
                  style: const TextStyle(
                    color: LetterColors.muted,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LetterSpacing.xs),
          if (day > 7) const _ProlongedBleedingPrompt(),
          Text(
            'Period day $day',
            style: const TextStyle(
              color: LetterColors.muted,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: LetterSpacing.md),
          stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: actions,
                )
              : Wrap(
                  spacing: LetterSpacing.sm,
                  runSpacing: LetterSpacing.xs,
                  children: actions,
                ),
          const SizedBox(height: LetterSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              key: const Key('edit-current-period'),
              onPressed: saving ? null : onEdit,
              tooltip: 'Edit period dates',
              icon: const Icon(Icons.edit_outlined),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProlongedBleedingPrompt extends StatefulWidget {
  const _ProlongedBleedingPrompt();

  @override
  State<_ProlongedBleedingPrompt> createState() =>
      _ProlongedBleedingPromptState();
}

class _ProlongedBleedingPromptState extends State<_ProlongedBleedingPrompt> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Still bleeding?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: LetterSpacing.xxs),
        const Text(
          'Keep it open, or record today as the last day. Letter Within will not '
          'choose an end date for you.',
          style: TextStyle(
            color: LetterColors.muted,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
        TextButton(
          key: const Key('keep-period-open'),
          onPressed: () => setState(() => _visible = false),
          child: const Text('Keep open'),
        ),
        const SizedBox(height: LetterSpacing.xs),
      ],
    );
  }
}

class _PredictionSection extends StatelessWidget {
  const _PredictionSection({
    required this.records,
    required this.today,
    this.compact = false,
  });

  final List<PeriodRecord> records;
  final LocalDate today;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final prediction = CyclePredictionEngine.calculate(records);
    if (compact) {
      return _PredictionCollapsed(prediction: prediction, today: today);
    }
    if (prediction == null) {
      return _PredictionLearning(
        intervalCount: CyclePredictionEngine.observedIntervalCount(records),
        hasHistory: records.isNotEmpty,
      );
    }
    return _PredictionAvailable(prediction: prediction, today: today);
  }
}

class _PredictionCollapsed extends StatelessWidget {
  const _PredictionCollapsed({required this.prediction, required this.today});

  final CyclePrediction? prediction;
  final LocalDate today;

  @override
  Widget build(BuildContext context) {
    if (prediction == null) {
      return LetterSurface(
        key: const Key('prediction-collapsed'),
        color: LetterColors.tealSoft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ProvenanceTag(observed: false),
            const SizedBox(width: LetterSpacing.sm),
            const Expanded(
              child: Text(
                'Estimate appears after three recorded period starts.',
                style: TextStyle(color: LetterColors.muted, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }
    return LetterSurface(
      key: const Key('prediction-collapsed'),
      color: LetterColors.surface,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(LetterRadius.panel),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: LetterSpacing.md),
          title: Text(
            '${_formatDate(context, prediction!.rangeStart)} - '
            '${_formatDate(context, prediction!.rangeEnd)}',
            key: const Key('prediction-collapsed-date-range'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Row(
            children: [
              _ProvenanceTag(observed: false),
              SizedBox(width: LetterSpacing.xs),
              Expanded(
                child: Text(
                  'Estimated next period · tap for provenance',
                  style: TextStyle(color: LetterColors.muted, fontSize: 12),
                ),
              ),
            ],
          ),
          children: [
            _PredictionAvailable(
              prediction: prediction!,
              today: today,
              showDateHeading: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _PredictionLearning extends StatelessWidget {
  const _PredictionLearning({
    required this.intervalCount,
    required this.hasHistory,
  });

  final int intervalCount;
  final bool hasHistory;

  @override
  Widget build(BuildContext context) {
    return LetterSurface(
      key: const Key('prediction-learning'),
      color: LetterColors.tealSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LetterEyebrow('ESTIMATED NEXT PERIOD'),
          const SizedBox(height: LetterSpacing.xs),
          Text(
            hasHistory
                ? 'Not enough recorded periods yet'
                : 'No estimate without recorded dates',
            style: const TextStyle(
              fontFamily: 'Newsreader',
              fontSize: 20,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: LetterSpacing.xs),
          Text(
            hasHistory
                ? 'An estimate needs at least two intervals between recorded starts, which means three recorded periods. Until then, nothing is shown rather than something uncertain.'
                : 'Record a period start and end to begin. Nothing is estimated from anything other than the dates you enter.',
            style: const TextStyle(
              color: LetterColors.muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: LetterSpacing.sm),
          Semantics(
            label: 'Cycle prediction history progress',
            value:
                '$intervalCount of ${CyclePredictionEngine.minimumIntervals} intervals',
            child: Text(
              '$intervalCount of ${CyclePredictionEngine.minimumIntervals} cycle intervals',
              style: const TextStyle(
                color: LetterColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionAvailable extends StatelessWidget {
  const _PredictionAvailable({
    required this.prediction,
    required this.today,
    this.showDateHeading = true,
  });

  final CyclePrediction prediction;
  final LocalDate today;
  final bool showDateHeading;

  @override
  Widget build(BuildContext context) {
    final timing = prediction.timingFor(today);
    final cycleRange =
        prediction.minimumCycleDays == prediction.maximumCycleDays
        ? '${prediction.minimumCycleDays} days'
        : '${prediction.minimumCycleDays}-${prediction.maximumCycleDays} days';
    return LetterSurface(
      key: const Key('prediction-available'),
      padding: EdgeInsets.zero,
      color: LetterColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(LetterSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (timing == PredictionTiming.laterThanEstimate)
                  const LetterEyebrow('LATER THAN THE ESTIMATED RANGE'),
                if (timing == PredictionTiming.laterThanEstimate)
                  const SizedBox(height: LetterSpacing.xs),
                if (showDateHeading) ...[
                  const LetterEyebrow('ESTIMATED NEXT PERIOD'),
                  const SizedBox(height: LetterSpacing.xs),
                  Text(
                    '${_formatDate(context, prediction.rangeStart)} - '
                    '${_formatDate(context, prediction.rangeEnd)}',
                    key: const Key('prediction-date-range'),
                    style: TextStyle(
                      fontFamily: 'Newsreader',
                      fontSize: context.isLetterNarrow ? 22 : 26,
                      height: 1.15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: LetterSpacing.sm),
                ],
                Row(
                  children: [
                    const _ProvenanceTag(observed: false),
                    const SizedBox(width: LetterSpacing.xs),
                    Expanded(
                      child: Text(
                        'Calculated from your recorded start dates.',
                        style: const TextStyle(
                          color: LetterColors.muted,
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: LetterSpacing.sm),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Confidence: ${prediction.confidence.label}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' — based on ${prediction.intervalCount} recorded ${prediction.intervalCount == 1 ? 'interval' : 'intervals'}.',
                        style: const TextStyle(
                          color: LetterColors.muted,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LetterSpacing.xxs),
                Text(
                  '${prediction.confidence.label} confidence',
                  style: const TextStyle(
                    color: LetterColors.muted,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: LetterSpacing.xxs),
                Text(
                  '${prediction.intervalCount} recent intervals',
                  style: const TextStyle(
                    color: LetterColors.muted,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: LetterSpacing.xxs),
                Text(
                  'Recorded cycles: $cycleRange',
                  style: const TextStyle(
                    color: LetterColors.muted,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: LetterSpacing.xs),
            child: Column(
              children: [
                _PredictionDataRow(
                  label: 'Midpoint',
                  value: _formatDate(context, prediction.midpoint),
                  estimated: true,
                ),
                _PredictionDataRow(
                  label: 'Median recorded cycle',
                  value: '${prediction.medianCycleDays} days',
                  estimated: false,
                ),
                _PredictionDataRow(
                  label: 'Shortest to longest',
                  value:
                      '${prediction.minimumCycleDays}–${prediction.maximumCycleDays} days',
                  estimated: false,
                ),
                _PredictionDataRow(
                  label: 'Range width',
                  value: '${prediction.observedSpreadDays} days',
                  estimated: true,
                  last: true,
                ),
              ],
            ),
          ),
          if (prediction.hasWideVariation ||
              timing == PredictionTiming.laterThanEstimate)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LetterSpacing.md,
                LetterSpacing.xs,
                LetterSpacing.md,
                LetterSpacing.md,
              ),
              child: Text(
                prediction.hasWideVariation
                    ? 'Your recorded cycles vary, so this estimate is wider.'
                    : 'Today is ${today.epochDay - prediction.predictedMensesEnd.epochDay} days beyond the estimated range.',
                style: const TextStyle(
                  color: LetterColors.muted,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          if (timing == PredictionTiming.laterThanEstimate)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                LetterSpacing.md,
                0,
                LetterSpacing.md,
                LetterSpacing.md,
              ),
              child: Text(
                'No new period start is recorded yet. This is a date comparison, not a health conclusion.',
                style: TextStyle(
                  color: LetterColors.muted,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PredictionDataRow extends StatelessWidget {
  const _PredictionDataRow({
    required this.label,
    required this.value,
    required this.estimated,
    this.last = false,
  });

  final String label;
  final String value;
  final bool estimated;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final stacked = context.isLetterNarrow || context.isLetterLargeText;
    final valueText = Text(
      value,
      textAlign: stacked ? TextAlign.start : TextAlign.end,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
    );
    return Container(
      constraints: const BoxConstraints(minHeight: LetterDimensions.tapTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: LetterSpacing.md,
        vertical: LetterSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: LetterColors.line)),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: LetterColors.muted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: LetterSpacing.xs),
                _ProvenanceTag(observed: !estimated),
                const SizedBox(height: LetterSpacing.xxs),
                valueText,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: LetterColors.muted,
                      fontSize: 14,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: LetterSpacing.xs),
                  child: _ProvenanceTag(observed: !estimated),
                ),
                Expanded(flex: 5, child: valueText),
              ],
            ),
    );
  }
}

class _CycleHistorySection extends StatelessWidget {
  const _CycleHistorySection({
    required this.records,
    required this.flowDays,
    required this.cycleLengthByPeriodId,
    required this.totalRecords,
    required this.saving,
    required this.onAddPast,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenFlow,
    required this.onOpenAllPeriods,
  });

  final List<PeriodRecord> records;
  final List<BleedingDayRecord> flowDays;
  final Map<String, int> cycleLengthByPeriodId;
  final int totalRecords;
  final bool saving;
  final VoidCallback onAddPast;
  final Future<void> Function(PeriodRecord) onEdit;
  final Future<void> Function(PeriodRecord) onDelete;
  final Future<void> Function(PeriodRecord) onOpenFlow;
  final VoidCallback onOpenAllPeriods;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return LetterSurface(
        key: const Key('period-history-empty'),
        color: LetterColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LetterEyebrow('RECENT PERIODS'),
            const SizedBox(height: LetterSpacing.xs),
            const Text(
              'No recent periods yet',
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: LetterSpacing.xs),
            const Text(
              'When you record a period it appears here, newest first, with the dates exactly as you entered them.',
              style: TextStyle(color: LetterColors.muted, height: 1.5),
            ),
            const SizedBox(height: LetterSpacing.md),
            _CycleButton(
              label: 'Add past period',
              primary: true,
              expand: context.isLetterNarrow || context.isLetterLargeText,
              onPressed: saving ? null : onAddPast,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LetterEyebrow('RECENT PERIODS'),
        const SizedBox(height: LetterSpacing.xs),
        Container(
          decoration: const BoxDecoration(
            color: LetterColors.surface,
            border: Border(
              top: BorderSide(color: LetterColors.line),
              bottom: BorderSide(color: LetterColors.line),
            ),
          ),
          child: Column(
            children: [
              for (var i = 0; i < records.length; i++)
                _PeriodHistoryRow(
                  record: records[i],
                  flowDayCount: _flowCount(flowDays, records[i].id),
                  cycleLengthDays: cycleLengthByPeriodId[records[i].id],
                  onEdit: () => onEdit(records[i]),
                  onDelete: () => onDelete(records[i]),
                  onOpenFlow: () => onOpenFlow(records[i]),
                  last: i == records.length - 1,
                ),
            ],
          ),
        ),
        const SizedBox(height: LetterSpacing.xs),
        Text(
          totalRecords > records.length
              ? 'Newest first. Showing the three most recent completed periods.'
              : 'Newest first. These are the three most recent completed periods.',
          style: TextStyle(
            color: LetterColors.muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: LetterSpacing.sm),
        _CycleButton(
          key: const Key('view-all-periods'),
          label: 'View all periods',
          expand: context.isLetterNarrow || context.isLetterLargeText,
          onPressed: saving ? null : onOpenAllPeriods,
          semanticHint: 'Opens your complete period archive grouped by year',
        ),
      ],
    );
  }
}

class _PeriodHistoryRow extends StatelessWidget {
  const _PeriodHistoryRow({
    required this.record,
    required this.flowDayCount,
    required this.cycleLengthDays,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenFlow,
    required this.last,
  });

  final PeriodRecord record;
  final int flowDayCount;
  final int? cycleLengthDays;
  final Future<void> Function() onEdit;
  final Future<void> Function() onDelete;
  final Future<void> Function() onOpenFlow;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final duration = record.durationDays;
    final exceptionalInterval =
        cycleLengthDays != null &&
        (cycleLengthDays! < CyclePredictionEngine.minimumTypicalCycleDays ||
            cycleLengthDays! > CyclePredictionEngine.maximumTypicalCycleDays);
    final cycleText = cycleLengthDays == null
        ? 'Awaiting next start'
        : exceptionalInterval
        ? '$cycleLengthDays-day interval'
        : '$cycleLengthDays-day cycle';
    final intervalNote = switch (cycleLengthDays) {
      final days? when days < CyclePredictionEngine.minimumTypicalCycleDays =>
        'Short interval · review the recorded starts',
      final days? when days > CyclePredictionEngine.maximumTypicalCycleDays =>
        'Long interval · may contain missing records',
      _ => null,
    };
    final bleedingText = duration == 1
        ? 'Bleeding: 1 day'
        : 'Bleeding: ${duration ?? 0} days';
    final flowText = flowDayCount == 0
        ? 'Flow: not recorded'
        : flowDayCount == duration
        ? 'Flow: all $flowDayCount ${flowDayCount == 1 ? 'day' : 'days'} recorded'
        : 'Flow: $flowDayCount of ${duration ?? 0} days recorded';
    return Container(
      key: Key('period-record-${record.id}'),
      width: double.infinity,
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: LetterColors.line)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: LetterSpacing.md,
        vertical: LetterSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: LetterSpacing.sm,
            runSpacing: LetterSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _formatRange(context, record),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                cycleText,
                style: const TextStyle(
                  color: LetterColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: LetterSpacing.xs),
          Text(
            bleedingText,
            style: const TextStyle(color: LetterColors.muted, fontSize: 12),
          ),
          if (intervalNote != null) ...[
            const SizedBox(height: 2),
            Text(
              intervalNote,
              style: const TextStyle(
                color: LetterColors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            flowText,
            style: const TextStyle(color: LetterColors.muted, fontSize: 12),
          ),
          const SizedBox(height: LetterSpacing.sm),
          Wrap(
            spacing: LetterSpacing.xxs,
            runSpacing: LetterSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: Key('period-flow-${record.id}'),
                onPressed: onOpenFlow,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const Icon(Icons.water_drop_outlined, size: 17),
                label: Text(flowDayCount == 0 ? 'Flow' : 'Edit flow'),
              ),
              IconButton(
                key: Key('period-edit-dates-${record.id}'),
                onPressed: onEdit,
                tooltip: 'Edit period dates',
                icon: const Icon(Icons.edit_outlined, size: 19),
              ),
              IconButton(
                key: Key('period-delete-${record.id}'),
                onPressed: onDelete,
                tooltip: 'Delete period',
                color: LetterColors.safetyRed,
                icon: const Icon(Icons.delete_outline, size: 19),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AllPeriodsScreen extends StatefulWidget {
  const AllPeriodsScreen({
    required this.repository,
    required this.records,
    required this.flowDays,
    required this.cycleLengthByPeriodId,
    required this.today,
    super.key,
    this.onDeleteRequested,
    this.onDataChanged,
  });

  final PeriodRepository repository;
  final List<PeriodRecord> records;
  final List<BleedingDayRecord> flowDays;
  final Map<String, int> cycleLengthByPeriodId;
  final LocalDate today;
  final FutureOr<void> Function(PeriodRecord record)? onDeleteRequested;
  final FutureOr<void> Function()? onDataChanged;

  @override
  State<AllPeriodsScreen> createState() => _AllPeriodsScreenState();
}

class _AllPeriodsScreenState extends State<AllPeriodsScreen> {
  late List<PeriodRecord> _records;
  late List<BleedingDayRecord> _flowDays;
  late Map<String, int> _cycleLengthByPeriodId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _records = _sortedClosed(widget.records);
    _flowDays = widget.flowDays;
    _cycleLengthByPeriodId = widget.cycleLengthByPeriodId;
  }

  Future<void> _reload({bool notifyDataChanged = false}) async {
    final results = await Future.wait<Object>([
      widget.repository.getAll(),
      widget.repository.getAllFlowDays(),
    ]);
    final records = results[0] as List<PeriodRecord>;
    final flowDays = results[1] as List<BleedingDayRecord>;
    if (!mounted) return;
    setState(() {
      _records = _sortedClosed(records);
      _flowDays = flowDays;
      _cycleLengthByPeriodId = _completedCycleLengths(records);
    });
    if (notifyDataChanged) {
      await widget.onDataChanged?.call();
    }
  }

  Future<void> _openFlowEditor(PeriodRecord record) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final flowDays = await widget.repository.getAllFlowDays();
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => PeriodFlowScreen(
            repository: widget.repository,
            record: record,
            today: widget.today,
            initialFlowDays: flowDays
                .where((flowDay) => flowDay.periodId == record.id)
                .toList(growable: false),
          ),
        ),
      );
      if (mounted) await _reload(notifyDataChanged: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openEditor([PeriodRecord? record]) async {
    if (_saving) return;
    PeriodDraft? attemptedDraft;
    while (mounted) {
      final draft = await showModalBottomSheet<PeriodDraft>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => PeriodEditorSheet(
          record: record,
          initialDraft: attemptedDraft,
          today: widget.today,
        ),
      );
      if (draft == null || !mounted) return;

      setState(() => _saving = true);
      try {
        if (record == null) {
          final confirmed = await _confirmAdjacentPeriod(draft);
          if (!confirmed) {
            attemptedDraft = draft;
            return;
          }
          await widget.repository.create(draft, today: widget.today);
        } else {
          await widget.repository.update(record.id, draft, today: widget.today);
        }
        await _reload(notifyDataChanged: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              record == null
                  ? 'Period added to your history.'
                  : 'Period dates updated.',
            ),
          ),
        );
        return;
      } on PeriodWriteException catch (error) {
        attemptedDraft = draft;
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.userMessage)));
        }
      } on Object {
        attemptedDraft = draft;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Letter Within could not save these dates. Try again.',
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  Future<bool> _confirmAdjacentPeriod(PeriodDraft draft) async {
    final preceding =
        _records
            .where((item) => item.startDate.isBefore(draft.startDate))
            .toList()
          ..sort((left, right) => right.startDate.compareTo(left.startDate));
    final previous = preceding.firstOrNull;
    if (previous == null ||
        draft.startDate.epochDay - previous.startDate.epochDay >= 10) {
      return true;
    }
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Save as a separate period?'),
            content: const Text(
              'This start is less than 10 days after the previous period '
              'start. It may be continuing bleeding or spotting. Letter Within will '
              'only save it as a separate record if you confirm.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Review dates'),
              ),
              FilledButton(
                key: const Key('confirm-adjacent-period'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save record'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteRecord(PeriodRecord record) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final externalDelete = widget.onDeleteRequested;
      if (externalDelete != null) {
        await externalDelete(record);
      } else {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete this period?'),
            content: Text(
              'The period beginning '
              '${_formatDate(context, record.startDate)} will be permanently '
              'removed from this device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('confirm-delete-period'),
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: LetterColors.safetyRed,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await widget.repository.delete(record.id);
          await widget.onDataChanged?.call();
        }
      }
      if (mounted) await _reload();
    } on PeriodWriteException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.userMessage)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<PeriodRecord>>{};
    for (final record in _records) {
      grouped.putIfAbsent(record.startDate.year, () => []).add(record);
    }
    final years = grouped.keys.toList()..sort((left, right) => right - left);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 76,
        leading: TextButton(
          key: const Key('all-periods-back'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back'),
        ),
        title: const Text('All periods'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              key: const Key('all-periods-scroll-view'),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                const LetterEyebrow('PERIOD ARCHIVE'),
                const SizedBox(height: LetterSpacing.xs),
                Text(
                  'Every completed period',
                  style: TextStyle(
                    fontFamily: 'Newsreader',
                    fontSize: context.isLetterNarrow ? 26 : 30,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: LetterSpacing.xs),
                const Text(
                  'All recorded periods are kept here, grouped by the year they began.',
                  style: TextStyle(color: LetterColors.muted, height: 1.5),
                ),
                const SizedBox(height: LetterSpacing.md),
                _CycleButton(
                  key: const Key('archive-add-past-period'),
                  label: 'Add past period',
                  primary: true,
                  expand: context.isLetterNarrow || context.isLetterLargeText,
                  onPressed: _saving ? null : () => _openEditor(),
                ),
                const SizedBox(height: LetterSpacing.lg),
                if (years.isEmpty)
                  const LetterSurface(
                    key: Key('all-periods-empty'),
                    child: Text('No completed periods yet.'),
                  )
                else
                  for (final year in years) ...[
                    ExpansionTile(
                      key: PageStorageKey<String>('period-year-$year'),
                      initiallyExpanded: year == widget.today.year,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: LetterSpacing.md,
                      ),
                      childrenPadding: EdgeInsets.zero,
                      backgroundColor: LetterColors.surface,
                      collapsedBackgroundColor: LetterColors.surface,
                      shape: const Border(
                        top: BorderSide(color: LetterColors.line),
                        bottom: BorderSide(color: LetterColors.line),
                      ),
                      collapsedShape: const Border(
                        top: BorderSide(color: LetterColors.line),
                        bottom: BorderSide(color: LetterColors.line),
                      ),
                      title: Text(
                        '$year',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        _periodCountLabel(grouped[year]!.length),
                        style: const TextStyle(color: LetterColors.muted),
                      ),
                      children: [
                        for (var i = 0; i < grouped[year]!.length; i++)
                          _PeriodHistoryRow(
                            record: grouped[year]![i],
                            flowDayCount: _flowCount(
                              _flowDays,
                              grouped[year]![i].id,
                            ),
                            cycleLengthDays:
                                _cycleLengthByPeriodId[grouped[year]![i].id],
                            onEdit: () => _openEditor(grouped[year]![i]),
                            onDelete: () => _deleteRecord(grouped[year]![i]),
                            onOpenFlow: () =>
                                _openFlowEditor(grouped[year]![i]),
                            last: i == grouped[year]!.length - 1,
                          ),
                      ],
                    ),
                    if (year != years.last)
                      const SizedBox(height: LetterSpacing.xs),
                  ],
                const SizedBox(height: LetterSpacing.md),
                const Text(
                  'These are recorded dates from this device. Predictions use the complete record list, including periods outside Recent periods.',
                  style: TextStyle(
                    color: LetterColors.muted,
                    fontSize: 12,
                    height: 1.5,
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

List<PeriodRecord> _sortedClosed(Iterable<PeriodRecord> records) {
  return records.where((record) => !record.isOpen).toList()
    ..sort((left, right) => right.startDate.compareTo(left.startDate));
}

Map<String, int> _completedCycleLengths(Iterable<PeriodRecord> records) {
  final chronological = records.toList()
    ..sort((left, right) => left.startDate.compareTo(right.startDate));
  return {
    for (var index = 0; index + 1 < chronological.length; index++)
      chronological[index].id:
          chronological[index + 1].startDate.epochDay -
          chronological[index].startDate.epochDay,
  };
}

BleedingDayRecord? _flowForDate(
  Iterable<BleedingDayRecord> flowDays,
  String periodId,
  LocalDate date,
) {
  for (final flowDay in flowDays) {
    if (flowDay.periodId == periodId && flowDay.date == date) {
      return flowDay;
    }
  }
  return null;
}

int _flowCount(Iterable<BleedingDayRecord> flowDays, String periodId) =>
    flowDays.where((flowDay) => flowDay.periodId == periodId).length;

String _periodCountLabel(int count) =>
    count == 1 ? '1 period' : '$count periods';

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.records, required this.today});

  final List<PeriodRecord> records;
  final LocalDate today;

  @override
  Widget build(BuildContext context) {
    final prediction = CyclePredictionEngine.calculate(records);
    final starts = records.map((record) => record.startDate).toList()..sort();
    final lastPeriodStart = starts.isEmpty ? null : starts.last;
    return LetterSurface(
      color: LetterColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How the estimate is made',
            style: TextStyle(
              fontFamily: 'Newsreader',
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: LetterSpacing.sm),
          const Text(
            'The gaps between your recorded start dates are measured in days. The median gap is added to your latest recorded start to give a midpoint, and the range around that midpoint reflects how much your recorded gaps vary.',
            style: TextStyle(color: LetterColors.muted, height: 1.5),
          ),
          if (prediction != null && lastPeriodStart != null) ...[
            const SizedBox(height: LetterSpacing.sm),
            Text(
              'Right now: median ${prediction.medianCycleDays} days added to ${_formatDate(context, lastPeriodStart)} gives ${_formatDate(context, prediction.midpoint)}, widened to ${_formatDate(context, prediction.predictedMensesStart)} - ${_formatDate(context, prediction.predictedMensesEnd)}.',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
          const SizedBox(height: LetterSpacing.md),
          Wrap(
            spacing: LetterSpacing.xs,
            runSpacing: LetterSpacing.xs,
            children: const [
              _ProvenanceTag(observed: true),
              _ProvenanceTag(observed: false),
            ],
          ),
          const SizedBox(height: LetterSpacing.xs),
          const Text(
            'Observed means a date you recorded. Estimated means a date calculated from those recordings.',
            style: TextStyle(
              color: LetterColors.muted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProvenanceTag extends StatelessWidget {
  const _ProvenanceTag({required this.observed});

  final bool observed;

  @override
  Widget build(BuildContext context) {
    final color = observed ? LetterColors.teal : LetterColors.blue;
    return Semantics(
      label: observed
          ? 'Observed, recorded by you'
          : 'Estimated, calculated from dates',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: observed
              ? color.withValues(alpha: 0.10)
              : LetterColors.surface,
          borderRadius: BorderRadius.circular(LetterRadius.control),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: observed ? 8 : 10,
              height: observed ? 8 : 2,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              observed ? 'OBSERVED' : 'ESTIMATED',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CycleButton extends StatelessWidget {
  const _CycleButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.expand = false,
    this.semanticHint,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool expand;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final foreground = disabled
        ? LetterColors.muted
        : primary
        ? LetterColors.surface
        : LetterColors.ink;
    final background = disabled
        ? LetterColors.canvas
        : primary
        ? LetterColors.teal
        : LetterColors.surface;
    final border = disabled
        ? LetterColors.line
        : primary
        ? LetterColors.tealDark
        : LetterColors.line;
    final child = Container(
      constraints: const BoxConstraints(
        minHeight: LetterDimensions.tapTarget,
        minWidth: LetterDimensions.tapTarget,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(LetterRadius.control),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: foreground,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: !disabled,
      hint: semanticHint,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(LetterRadius.control),
        child: expand ? SizedBox(width: double.infinity, child: child) : child,
      ),
    );
  }
}

class PeriodEditorSheet extends StatefulWidget {
  const PeriodEditorSheet({
    required this.today,
    super.key,
    this.record,
    this.initialDraft,
  });

  final LocalDate today;
  final PeriodRecord? record;
  final PeriodDraft? initialDraft;

  @override
  State<PeriodEditorSheet> createState() => _PeriodEditorSheetState();
}

class _PeriodEditorSheetState extends State<PeriodEditorSheet> {
  late LocalDate _startDate;
  late LocalDate _endDate;
  late bool _ongoing;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    final draft = widget.initialDraft;
    _startDate =
        draft?.startDate ?? record?.startDate ?? widget.today.addDays(-4);
    _endDate = draft?.endDate ?? record?.endDate ?? widget.today;
    _ongoing = draft != null ? draft.endDate == null : record?.isOpen ?? false;
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.asLocalDateTime,
      firstDate: DateTime(1900),
      lastDate: widget.today.asLocalDateTime,
      helpText: 'Period start date',
    );
    if (picked == null) {
      return;
    }
    final date = LocalDate.fromDateTime(picked);
    setState(() {
      _startDate = date;
      if (_endDate.isBefore(date)) {
        _endDate = date;
      }
    });
  }

  Future<void> _pickEnd() async {
    final initial = _endDate.isBefore(_startDate) ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.asLocalDateTime,
      firstDate: _startDate.asLocalDateTime,
      lastDate: widget.today.asLocalDateTime,
      helpText: 'Period end date',
    );
    if (picked == null) {
      return;
    }
    setState(() => _endDate = LocalDate.fromDateTime(picked));
  }

  void _save() {
    Navigator.pop(
      context,
      PeriodDraft(startDate: _startDate, endDate: _ongoing ? null : _endDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Material(
      color: LetterColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: LetterColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: LetterSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LetterEyebrow('YOUR RECORD'),
                      const SizedBox(height: LetterSpacing.xs),
                      Text(
                        widget.record == null
                            ? 'Add a past period'
                            : 'Edit period',
                        style: const TextStyle(
                          fontFamily: 'Newsreader',
                          fontSize: 26,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                  constraints: const BoxConstraints(
                    minWidth: LetterDimensions.tapTarget,
                    minHeight: LetterDimensions.tapTarget,
                  ),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: LetterSpacing.xs),
            const Text(
              'Only the dates you enter here are stored as a period. Estimates are calculated separately and are never saved as recorded dates.',
              style: TextStyle(color: LetterColors.muted, height: 1.45),
            ),
            const SizedBox(height: LetterSpacing.lg),
            _DateField(
              key: const Key('period-start-date'),
              label: 'First day of bleeding',
              value: _formatDate(context, _startDate),
              onTap: _pickStart,
            ),
            const SizedBox(height: LetterSpacing.sm),
            _CycleToggle(
              key: const Key('period-ongoing-toggle'),
              label: 'Still ongoing',
              description:
                  'Leave the end date empty while the period is in progress.',
              value: _ongoing,
              onChanged: (value) => setState(() => _ongoing = value),
            ),
            if (!_ongoing) ...[
              const SizedBox(height: LetterSpacing.sm),
              _DateField(
                key: const Key('period-end-date'),
                label: 'Last day of bleeding',
                value: _formatDate(context, _endDate),
                onTap: _pickEnd,
              ),
            ],
            const SizedBox(height: LetterSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('save-period-dates'),
                onPressed: _save,
                style: LetterButtonStyles.filled,
                icon: const Icon(Icons.check),
                label: Text(
                  widget.record == null ? 'Save period' : 'Save changes',
                ),
              ),
            ),
            const SizedBox(height: LetterSpacing.xs),
            const Center(
              child: Text(
                'You can edit these dates later.',
                style: TextStyle(color: LetterColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LetterRadius.control),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(
            horizontal: LetterSpacing.md,
            vertical: LetterSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: LetterColors.surface,
            border: Border.all(color: LetterColors.line),
            borderRadius: BorderRadius.circular(LetterRadius.control),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: LetterColors.teal,
              ),
              const SizedBox(width: LetterSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: LetterColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: LetterColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CycleToggle extends StatelessWidget {
  const _CycleToggle({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: LetterDimensions.tapTarget,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: LetterSpacing.xxs),
                  Text(
                    description,
                    style: const TextStyle(
                      color: LetterColors.muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: LetterSpacing.sm),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: LetterColors.surface,
              activeTrackColor: LetterColors.teal,
              inactiveTrackColor: LetterColors.canvas,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(BuildContext context, LocalDate date) {
  return MaterialLocalizations.of(
    context,
  ).formatMediumDate(date.asLocalDateTime);
}

String _formatRange(BuildContext context, PeriodRecord record) {
  final end = record.endDate;
  if (end == null) {
    return '${_formatDate(context, record.startDate)} - now';
  }
  return '${_formatDate(context, record.startDate)} - '
      '${_formatDate(context, end)}';
}
