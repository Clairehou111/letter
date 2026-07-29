import 'package:flutter/material.dart';

import '../../../design_system/letter_bottom_navigation.dart';
import '../../../design_system/letter_theme.dart';
import '../domain/cycle_prediction.dart';
import '../domain/local_date.dart';
import '../domain/period_record.dart';
import '../domain/period_repository.dart';

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

class _CycleScreenState extends State<CycleScreen> {
  List<PeriodRecord> _records = const [];
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
      final records = await widget.repository.getAll();
      if (!mounted) {
        return;
      }
      setState(() {
        _records = records;
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
          await widget.repository.create(draft, today: _today);
        } else {
          await widget.repository.update(record.id, draft, today: _today);
        }
        final records = await widget.repository.getAll();
        if (!mounted) {
          return;
        }
        setState(() => _records = records);
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
              content: Text('Letter could not save these dates. Try again.'),
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
      final records = await widget.repository.getAll();
      if (!mounted) {
        return;
      }
      setState(() => _records = records);
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
            content: Text('Letter could not save these dates. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: LetterBottomNavigation(
        selectedIndex: 0,
        onSelected: widget.onNavigationSelected,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _loading
                ? const _CycleLoading()
                : _loadFailed
                ? _CycleLoadError(onRetry: _load)
                : _CycleContent(
                    records: _records,
                    today: _today,
                    saving: _saving,
                    onStartToday: _startToday,
                    onEndToday: _endCurrent,
                    onAddPast: () => _openEditor(),
                    onEdit: _openEditor,
                    onDelete: _confirmDelete,
                  ),
          ),
        ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 34, color: LetterColors.teal),
            const SizedBox(height: LetterSpacing.md),
            const Text(
              'Your private cycle history could not be opened.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: LetterSpacing.lg),
            FilledButton.icon(
              key: const Key('retry-cycle-load'),
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

class _CycleContent extends StatelessWidget {
  const _CycleContent({
    required this.records,
    required this.today,
    required this.saving,
    required this.onStartToday,
    required this.onEndToday,
    required this.onAddPast,
    required this.onEdit,
    required this.onDelete,
  });

  final List<PeriodRecord> records;
  final LocalDate today;
  final bool saving;
  final VoidCallback onStartToday;
  final VoidCallback onEndToday;
  final VoidCallback onAddPast;
  final ValueChanged<PeriodRecord> onEdit;
  final ValueChanged<PeriodRecord> onDelete;

  PeriodRecord? get openPeriod {
    for (final record in records) {
      if (record.isOpen) {
        return record;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final closedRecords = records.where((record) => !record.isOpen).toList();
    return CustomScrollView(
      key: const Key('cycle-scroll-view'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          sliver: SliverList.list(
            children: [
              const _CycleHeader(),
              const SizedBox(height: LetterSpacing.xl),
              if (openPeriod case final current?)
                _CurrentPeriodPanel(
                  record: current,
                  today: today,
                  saving: saving,
                  onEndToday: onEndToday,
                  onEdit: () => onEdit(current),
                )
              else
                _NoCurrentPeriodPanel(
                  hasHistory: records.isNotEmpty,
                  saving: saving,
                  onStartToday: onStartToday,
                ),
              const SizedBox(height: LetterSpacing.xl),
              _PredictionSection(records: records, today: today),
              const SizedBox(height: LetterSpacing.xl),
              LetterSectionTitle(
                eyebrow: 'Your record',
                title: 'Past periods',
                action: TextButton.icon(
                  key: const Key('add-past-period'),
                  onPressed: saving ? null : onAddPast,
                  icon: const Icon(Icons.add, size: 19),
                  label: const Text('Add past'),
                ),
              ),
              const SizedBox(height: LetterSpacing.sm),
              if (closedRecords.isEmpty)
                const _HistoryEmpty()
              else
                ...closedRecords.asMap().entries.map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.key == closedRecords.length - 1
                          ? 0
                          : LetterSpacing.sm,
                    ),
                    child: _PeriodHistoryRow(
                      record: entry.value,
                      folioNumber: closedRecords.length - entry.key,
                      onEdit: () => onEdit(entry.value),
                      onDelete: () => onDelete(entry.value),
                    ),
                  ),
                ),
              const SizedBox(height: LetterSpacing.lg),
              const _PrivateNote(),
            ],
          ),
        ),
      ],
    );
  }
}

class _CycleHeader extends StatelessWidget {
  const _CycleHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 58,
          decoration: BoxDecoration(
            color: LetterColors.coral,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: LetterSpacing.md),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LetterEyebrow('Letter / Cycle'),
              SizedBox(height: LetterSpacing.xs),
              Text(
                'Your cycle record',
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

class _NoCurrentPeriodPanel extends StatelessWidget {
  const _NoCurrentPeriodPanel({
    required this.hasHistory,
    required this.saving,
    required this.onStartToday,
  });

  final bool hasHistory;
  final bool saving;
  final VoidCallback onStartToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('no-current-period'),
      padding: const EdgeInsets.all(LetterSpacing.lg),
      decoration: BoxDecoration(
        color: LetterColors.tealSoft,
        border: Border.all(color: const Color(0xFFC6DFDA)),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasHistory ? Icons.check_circle_outline : Icons.water_drop_outlined,
            color: LetterColors.teal,
            size: 26,
          ),
          const SizedBox(height: LetterSpacing.sm),
          Text(
            hasHistory ? 'No period in progress' : 'Begin your cycle record',
            style: const TextStyle(
              fontFamily: 'Newsreader',
              fontSize: 23,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: LetterSpacing.xs),
          const Text(
            'Start when your period begins. Spotting is not counted here.',
            style: TextStyle(color: LetterColors.muted, height: 1.45),
          ),
          const SizedBox(height: LetterSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              key: const Key('start-period-today'),
              onPressed: saving ? null : onStartToday,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.water_drop_outlined),
              label: const Text('Start period today'),
            ),
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
    required this.onEdit,
  });

  final PeriodRecord record;
  final LocalDate today;
  final bool saving;
  final VoidCallback onEndToday;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final day = today.epochDay - record.startDate.epochDay + 1;
    return Container(
      key: const Key('current-period'),
      padding: const EdgeInsets.all(LetterSpacing.lg),
      decoration: BoxDecoration(
        color: LetterColors.coralSoft,
        border: Border.all(color: const Color(0xFFEBC7C2)),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LetterEyebrow(
                      'In progress',
                      color: LetterColors.safetyRed,
                    ),
                    const SizedBox(height: LetterSpacing.xs),
                    Text(
                      'Period day $day',
                      style: const TextStyle(
                        fontFamily: 'Newsreader',
                        fontSize: 28,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: LetterSpacing.xs),
                    Text(
                      'Started ${_formatDate(context, record.startDate)}',
                      style: const TextStyle(color: LetterColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('edit-current-period'),
                onPressed: saving ? null : onEdit,
                tooltip: 'Edit period dates',
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: LetterSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              key: const Key('end-period-today'),
              onPressed: saving ? null : onEndToday,
              style: FilledButton.styleFrom(
                backgroundColor: LetterColors.safetyRed,
              ),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('End period today'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionSection extends StatelessWidget {
  const _PredictionSection({required this.records, required this.today});

  final List<PeriodRecord> records;
  final LocalDate today;

  @override
  Widget build(BuildContext context) {
    final prediction = CyclePredictionEngine.calculate(records);
    if (prediction == null) {
      return _PredictionLearning(
        intervalCount: CyclePredictionEngine.observedIntervalCount(records),
      );
    }
    return _PredictionAvailable(prediction: prediction, today: today);
  }
}

class _PredictionLearning extends StatelessWidget {
  const _PredictionLearning({required this.intervalCount});

  final int intervalCount;

  @override
  Widget build(BuildContext context) {
    final progress = intervalCount / CyclePredictionEngine.minimumIntervals;
    return Container(
      key: const Key('prediction-learning'),
      padding: const EdgeInsets.symmetric(vertical: LetterSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: LetterColors.line),
          bottom: BorderSide(color: LetterColors.line),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.event_repeat_outlined,
                size: 21,
                color: LetterColors.teal,
              ),
              SizedBox(width: LetterSpacing.sm),
              Expanded(
                child: Text(
                  'Learning your rhythm',
                  style: TextStyle(
                    fontFamily: 'Newsreader',
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LetterSpacing.sm),
          Text(
            intervalCount == 1
                ? 'One more period start will complete the minimum history.'
                : 'Letter needs two complete start-to-start cycle intervals.',
            style: const TextStyle(color: LetterColors.muted, height: 1.45),
          ),
          const SizedBox(height: LetterSpacing.md),
          Semantics(
            label: 'Cycle prediction history progress',
            value:
                '$intervalCount of '
                '${CyclePredictionEngine.minimumIntervals} intervals',
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              borderRadius: BorderRadius.circular(3),
              color: LetterColors.teal,
              backgroundColor: LetterColors.tealSoft,
            ),
          ),
          const SizedBox(height: LetterSpacing.xs),
          Text(
            '$intervalCount of '
            '${CyclePredictionEngine.minimumIntervals} cycle intervals',
            style: const TextStyle(
              color: LetterColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionAvailable extends StatelessWidget {
  const _PredictionAvailable({required this.prediction, required this.today});

  final CyclePrediction prediction;
  final LocalDate today;

  @override
  Widget build(BuildContext context) {
    final timing = prediction.timingFor(today);
    final status = switch (timing) {
      PredictionTiming.upcoming => 'Next period estimate',
      PredictionTiming.currentWindow => 'Estimate window is now',
      PredictionTiming.laterThanEstimate => 'Later than this estimate',
    };
    final explanation = switch (timing) {
      PredictionTiming.upcoming =>
        'A range based only on your recorded period starts.',
      PredictionTiming.currentWindow =>
        'Today falls within this estimate. It may still shift.',
      PredictionTiming.laterThanEstimate =>
        'No new start is recorded. Letter will not invent another cycle.',
    };
    final cycleRange =
        prediction.minimumCycleDays == prediction.maximumCycleDays
        ? '${prediction.minimumCycleDays} days'
        : '${prediction.minimumCycleDays}-'
              '${prediction.maximumCycleDays} days';

    return Container(
      key: const Key('prediction-available'),
      padding: const EdgeInsets.symmetric(vertical: LetterSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: LetterColors.line),
          bottom: BorderSide(color: LetterColors.line),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LetterEyebrow(status),
          const SizedBox(height: LetterSpacing.xs),
          Text(
            '${_formatDate(context, prediction.rangeStart)} - '
            '${_formatDate(context, prediction.rangeEnd)}',
            key: const Key('prediction-date-range'),
            style: const TextStyle(
              fontFamily: 'Newsreader',
              fontSize: 24,
              height: 1.12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: LetterSpacing.sm),
          Text(
            explanation,
            style: const TextStyle(color: LetterColors.muted, height: 1.4),
          ),
          const SizedBox(height: LetterSpacing.md),
          _PredictionEvidence(
            icon: Icons.insights_outlined,
            label: '${prediction.confidence.label} confidence',
          ),
          const SizedBox(height: LetterSpacing.xs),
          _PredictionEvidence(
            icon: Icons.history,
            label: '${prediction.intervalCount} recent intervals',
          ),
          const SizedBox(height: LetterSpacing.xs),
          _PredictionEvidence(
            icon: Icons.date_range_outlined,
            label: 'Recorded cycles: $cycleRange',
          ),
          if (prediction.hasWideVariation) ...[
            const SizedBox(height: LetterSpacing.md),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.open_in_full, size: 17, color: LetterColors.amber),
                SizedBox(width: LetterSpacing.xs),
                Expanded(
                  child: Text(
                    'Your recorded cycles vary, so this estimate is wider.',
                    style: TextStyle(
                      color: LetterColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PredictionEvidence extends StatelessWidget {
  const _PredictionEvidence({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: LetterColors.teal),
        const SizedBox(width: LetterSpacing.xxs),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: LetterColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodHistoryRow extends StatelessWidget {
  const _PeriodHistoryRow({
    required this.record,
    required this.folioNumber,
    required this.onEdit,
    required this.onDelete,
  });

  final PeriodRecord record;
  final int folioNumber;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('period-record-${record.id}'),
      constraints: const BoxConstraints(minHeight: 76),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            constraints: const BoxConstraints(minHeight: 76),
            decoration: const BoxDecoration(
              color: LetterColors.coralSoft,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(LetterRadius.panel - 1),
              ),
            ),
            alignment: Alignment.center,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.4,
              child: Text(
                folioNumber.toString().padLeft(2, '0'),
                style: const TextStyle(
                  color: LetterColors.safetyRed,
                  fontFamily: 'Newsreader',
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: LetterSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: LetterSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatRange(context, record),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: LetterSpacing.xxs),
                  Text(
                    record.durationDays == 1
                        ? '1 day'
                        : '${record.durationDays} days',
                    style: const TextStyle(
                      color: LetterColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<_PeriodMenuAction>(
            key: Key('period-menu-${record.id}'),
            tooltip: 'Period actions',
            onSelected: (action) {
              switch (action) {
                case _PeriodMenuAction.edit:
                  onEdit();
                case _PeriodMenuAction.delete:
                  onDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _PeriodMenuAction.edit,
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit dates'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _PeriodMenuAction.delete,
                child: ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: LetterColors.safetyRed,
                  ),
                  title: Text('Delete'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _PeriodMenuAction { edit, delete }

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('period-history-empty'),
      padding: const EdgeInsets.symmetric(
        horizontal: LetterSpacing.lg,
        vertical: LetterSpacing.xl,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: LetterColors.line),
          bottom: BorderSide(color: LetterColors.line),
        ),
      ),
      child: const Text(
        'Completed periods will appear here in date order.',
        style: TextStyle(color: LetterColors.muted),
      ),
    );
  }
}

class _PrivateNote extends StatelessWidget {
  const _PrivateNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline, size: 17, color: LetterColors.teal),
        SizedBox(width: LetterSpacing.xs),
        Expanded(
          child: Text(
            "Cycle dates stay in Letter's private storage on this device.",
            style: TextStyle(
              color: LetterColors.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
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
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.record == null ? 'Add a past period' : 'Edit period',
                    style: const TextStyle(
                      fontFamily: 'Newsreader',
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: LetterSpacing.lg),
            _DateField(
              key: const Key('period-start-date'),
              label: 'Started',
              value: _formatDate(context, _startDate),
              onTap: _pickStart,
            ),
            const SizedBox(height: LetterSpacing.sm),
            SwitchListTile.adaptive(
              key: const Key('period-ongoing-toggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Period is still happening',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              value: _ongoing,
              onChanged: (value) => setState(() => _ongoing = value),
            ),
            if (!_ongoing) ...[
              const SizedBox(height: LetterSpacing.sm),
              _DateField(
                key: const Key('period-end-date'),
                label: 'Ended',
                value: _formatDate(context, _endDate),
                onTap: _pickEnd,
              ),
            ],
            const SizedBox(height: LetterSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                key: const Key('save-period-dates'),
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(
                  widget.record == null ? 'Add period' : 'Save dates',
                ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LetterRadius.control),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(
          horizontal: LetterSpacing.md,
          vertical: LetterSpacing.sm,
        ),
        decoration: BoxDecoration(
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
            const Icon(Icons.chevron_right),
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
