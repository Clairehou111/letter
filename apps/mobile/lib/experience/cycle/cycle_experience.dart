import 'package:flutter/material.dart';

import '../../features/care/domain/care_memory.dart';
import '../../features/care/domain/care_memory_repository.dart';
import '../../features/cycle/domain/bleeding_flow.dart';
import '../../features/cycle/domain/cycle_prediction.dart';
import '../../features/cycle/domain/cycle_read_snapshot.dart';
import '../../features/cycle/domain/local_date.dart';
import '../../features/cycle/domain/period_record.dart';
import '../../features/cycle/domain/period_repository.dart';
import '../../features/health_records/domain/health_record.dart';
import '../../features/health_records/domain/health_record_repository.dart';
import '../../features/health_records/domain/observation_catalog.dart';
import '../../features/summary_export/domain/cycle_care_summary.dart';
import '../../features/today/today_cycle_ring_model.dart';
import '../degree/degree_graphics.dart';
import '../records/observation_picker.dart';
import '../source/source_panel.dart';
import '../theme/experience_foundation.dart';
import 'cycle_action_panel.dart';
import '../today/today_cycle_ring.dart';

/// The Cycle destination: the four-color ring summary, an honest estimated
/// next-period line, the recent-cycles list, the last period's flow history,
/// the day editor, whole-cycle backfill, and per-cycle reflection letters.
///
/// Business behavior preserved (design authority):
///  * Color requires flow first (`flowRequiredForColor`): color controls are
///    inert until a flow exists for that date, and the verbatim repository
///    message is shown as the hint. Spotting is a flow degree — it never
///    starts or extends a period, and the UI says so once, quietly, where
///    spotting is chosen.
///  * Pain is a severity degree on a pain-kind symptom record — the same
///    five named SymptomSeverity degrees as every other observation,
///    never a numeric score or a location list. Cancelling the pain card
///    discards the unfinished degree, and typed failures surface their
///    verbatim userMessage inline with the control left ready for retry.
///  * Whole-cycle backfill edits every date of a past period (flow, color,
///    pain, observations). `overlap`, `anotherPeriodOpen`,
///    `flowDateOutsidePeriod`, and future-date failures surface verbatim.
///    Every mutation — including backfill — fires `onCycleDataChanged` so
///    the ring, Gravity, and charts refresh coherently.
///  * Cycle reflections are validated at 280 characters per field and
///    identified by `startingPeriodId`.
///  * Flow and color are factual records. They render here and in reports
///    and never feed severity, prediction, Gravity, Spectrum, or Twin.
///  * Edit, save, cancel/close, and delete-with-confirmation are uniform.
///    Drafts persist within the destination; destructive exits confirm.
final class CycleExperience extends StatefulWidget {
  const CycleExperience({
    super.key,
    required this.periodRepository,
    required this.healthRecordRepository,
    required this.careMemoryRepository,
    required this.onCycleDataChanged,
    this.ringModel,
    this.revision = 0,
    this.now,
  });

  final PeriodRepository periodRepository;
  final HealthRecordRepository healthRecordRepository;
  final CareMemoryRepository careMemoryRepository;

  /// Fires after any period/flow mutation — including backfill — and after
  /// health-record changes, so every derived surface refreshes.
  final VoidCallback onCycleDataChanged;

  /// The working ring model when history supports one (≥3 period starts).
  /// Null means the destination renders its honest empty / ring-forming
  /// states from the records themselves — never an invented phase.
  final TodayCycleRingModel? ringModel;

  /// A read revision from the persistent shell. Cycle remains mounted across
  /// tab switches, so a changed revision means its in-memory snapshot must be
  /// replaced from the database.
  final int revision;

  final DateTime? now;

  @override
  State<CycleExperience> createState() => _CycleExperienceState();
}

class _CycleExperienceState extends State<CycleExperience> {
  bool _loading = true;
  String? _loadError;

  List<PeriodRecord> _periods = const <PeriodRecord>[];
  List<BleedingDayRecord> _flowDays = const <BleedingDayRecord>[];

  String? _actionError;
  String? _ackLine;
  int _pulseTick = 0;

  LocalDate get _today =>
      LocalDate.fromDateTime((widget.now ?? DateTime.now()).toLocal());

  static const List<String> _weekdayNames = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<String> _monthNames = <String>[
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

  String get _todayLabel {
    final d = widget.now ?? DateTime.now();
    return '${_weekdayNames[d.weekday - 1]}, ${_monthNames[d.month - 1]} ${d.day}';
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant CycleExperience oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final periods = await widget.periodRepository.getAll();
      final flowDays = await widget.periodRepository.getAllFlowDays();
      if (!mounted) return;
      periods.sort((a, b) => a.startDate.compareTo(b.startDate));
      setState(() {
        _periods = periods;
        _flowDays = flowDays;
        _loading = false;
      });
    } on PeriodWriteException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.userMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError =
            'Letter Within could not open private cycle storage. Try again.';
      });
    }
  }

  void _dataChanged() {
    widget.onCycleDataChanged();
    _reload();
  }

  // --- Derived views ---------------------------------------------------------

  CycleReadSnapshot get _cycleSnapshot =>
      CycleReadSnapshot.fromRecords(records: _periods, today: _today);

  CurrentCycle? get _currentCycle => _cycleSnapshot.currentCycle;

  /// Completed cycles, most recent first: a period plus the length of the
  /// cycle it began (next start − this start).
  List<_CompletedCycle> get _completedCycles {
    final completed = _cycleSnapshot.completedCyclesNewestFirst;
    return List.unmodifiable(<_CompletedCycle>[
      for (var index = 0; index < completed.length; index += 1)
        _CompletedCycle(
          period: completed[index].period,
          cycleNumber: completed.length - index,
          cycleLengthDays: completed[index].cycleLengthDays,
        ),
    ]);
  }

  PeriodRecord? get _lastClosedPeriod {
    for (final period in _cycleSnapshot.eligiblePeriodsNewestFirst) {
      if (!period.isOpen) return period;
    }
    return null;
  }

  List<BleedingDayRecord> _flowDaysFor(String periodId) {
    final days = _flowDays.where((d) => d.periodId == periodId).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return days;
  }

  // --- Quick actions -----------------------------------------------------------

  Future<void> _recordPeriodStart() async {
    setState(() => _actionError = null);
    try {
      // A same-day retry is not an ambiguous overlap: this date already has
      // a saved period. Take the person straight to its existing edit/delete
      // route instead of making them infer that from a generic error.
      final existing = (await widget.periodRepository.getAll())
          .where(
            (period) =>
                !_today.isBefore(period.startDate) &&
                (period.endDate == null || !_today.isAfter(period.endDate!)),
          )
          .firstOrNull;
      if (existing != null) {
        if (!mounted) return;
        _openPeriodDates(existing: existing);
        return;
      }
      await widget.periodRepository.create(
        PeriodDraft(startDate: _today),
        today: _today,
      );
      final line = await SavedRhythm.acknowledge(SavedRhythmKind.record);
      if (!mounted) return;
      setState(() {
        _ackLine = line;
        _pulseTick += 1;
      });
      _dataChanged();
    } on PeriodWriteException catch (error) {
      if (!mounted) return;
      setState(() => _actionError = error.userMessage);
    }
  }

  Future<void> _endOpenPeriod(PeriodRecord period) async {
    final now = widget.now ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'When did this period end?',
    );
    if (picked == null || !mounted) return;
    final end = LocalDate.fromDateTime(picked);
    setState(() => _actionError = null);
    try {
      await widget.periodRepository.update(
        period.id,
        PeriodDraft(startDate: period.startDate, endDate: end),
        today: _today,
      );
      final line = await SavedRhythm.acknowledge(SavedRhythmKind.record);
      if (!mounted) return;
      setState(() {
        _ackLine = line;
        _pulseTick += 1;
      });
      _dataChanged();
    } on PeriodWriteException catch (error) {
      if (!mounted) return;
      setState(() => _actionError = error.userMessage);
    }
  }

  // --- Sheets ------------------------------------------------------------------

  void _openBackfill({PeriodRecord? existingPeriod}) {
    showExperienceSheet<void>(
      context,
      child: _BackfillSheet(
        periodRepository: widget.periodRepository,
        healthRecordRepository: widget.healthRecordRepository,
        today: _today,
        now: widget.now,
        existingPeriod: existingPeriod,
        onDataChanged: _dataChanged,
      ),
    );
  }

  void _openPeriodDates({PeriodRecord? existing}) {
    showExperienceSheet<void>(
      context,
      child: _PeriodDatesSheet(
        periodRepository: widget.periodRepository,
        today: _today,
        now: widget.now,
        existing: existing,
        onDataChanged: _dataChanged,
      ),
    );
  }

  void _openCycleDetail(_CompletedCycle cycle) {
    showExperienceSheet<void>(
      context,
      child: _CycleDetailSheet(
        cycle: cycle,
        flowDays: _flowDaysFor(cycle.period.id),
        periodRepository: widget.periodRepository,
        healthRecordRepository: widget.healthRecordRepository,
        careMemoryRepository: widget.careMemoryRepository,
        today: _today,
        now: widget.now,
        onDataChanged: _dataChanged,
        onEditDates: () {
          Navigator.of(context).pop();
          _openPeriodDates(existing: cycle.period);
        },
        onFillDays: () {
          Navigator.of(context).pop();
          _openBackfill(existingPeriod: cycle.period);
        },
        onOpenDay: (date) {
          Navigator.of(context).pop();
          _openDayEditor(date);
        },
      ),
    );
  }

  void _openCurrentCycleDetail(CurrentCycle current) {
    final period = current.period;
    showExperienceSheet<void>(
      context,
      child: _CycleDetailSheet(
        cycle: _CompletedCycle(
          period: period,
          cycleNumber: 0,
          cycleLengthDays: current.cycleDay,
        ),
        isCurrentCycle: true,
        currentCycleDay: current.cycleDay,
        bleedingState: current.bleedingState,
        flowDays: _flowDaysFor(period.id),
        periodRepository: widget.periodRepository,
        healthRecordRepository: widget.healthRecordRepository,
        careMemoryRepository: widget.careMemoryRepository,
        today: _today,
        now: widget.now,
        onDataChanged: _dataChanged,
        onEditDates: () {
          Navigator.of(context).pop();
          _openPeriodDates(existing: period);
        },
        onFillDays: () {
          Navigator.of(context).pop();
          _openBackfill(existingPeriod: period);
        },
        onOpenDay: (date) {
          Navigator.of(context).pop();
          _openDayEditor(date);
        },
      ),
    );
  }

  /// The home list stays compact, but every saved period remains reachable.
  /// This must never be a six-period data limit.
  void _openAllPeriods() {
    final newestFirst = _cycleSnapshot.archivePeriodsNewestFirst;
    showExperienceSheet<void>(
      context,
      child: _AllPeriodsSheet(
        periods: newestFirst,
        onOpenPeriod: (period) {
          Navigator.of(context).pop();
          final current = _currentCycle;
          if (current?.period.id == period.id) {
            _openCurrentCycleDetail(current!);
            return;
          }
          final cycle = _cycleForPeriod(period);
          if (cycle != null) {
            _openCycleDetail(cycle);
          } else {
            _openPeriodDates(existing: period);
          }
        },
      ),
    );
  }

  _CompletedCycle? _cycleForPeriod(PeriodRecord period) {
    for (final cycle in _completedCycles) {
      if (cycle.period.id == period.id) return cycle;
    }
    return null;
  }

  void _openDayEditor(LocalDate date) {
    showExperienceSheet<void>(
      context,
      child: _DayEditorSheet(
        date: date,
        periodRepository: widget.periodRepository,
        healthRecordRepository: widget.healthRecordRepository,
        today: _today,
        onDataChanged: _dataChanged,
      ),
    );
  }

  void _inspectRing() {
    final model = widget.ringModel;
    final snapshot = _cycleSnapshot;
    final evidence = snapshot.predictionEvidence;
    final evidenceLabel = switch (evidence.kind) {
      PredictionEstimateKind.early =>
        'Early estimate · ${evidence.candidateStartsNewestFirst.length} starts / 1 interval.',
      PredictionEstimateKind.formal =>
        'Personalized estimate · ${evidence.candidateStartsNewestFirst.length} starts / ${evidence.prediction!.intervalCount} intervals.',
      PredictionEstimateKind.none =>
        'No estimate yet · ${evidence.candidateStartsNewestFirst.length} recorded starts.',
    };
    SourcePanel.show(
      context,
      title: 'What this ring shows',
      subtitle: model == null
          ? 'The ring fills in from your recorded period starts. Nothing here '
                'is estimated yet — there is nothing to estimate from.'
          : 'Period segments are observed from your recorded periods. '
                'Follicular, ovulation, and luteal parts are labeled estimates '
                'from those same records — ovulation is always a range band, '
                'never a detected day. $evidenceLabel',
      certainty: model == null
          ? ExperienceCertainty.unknown
          : model.hasLimitedEstimate
          ? ExperienceCertainty.estimated
          : ExperienceCertainty.observed,
      entries: <SourcePanelEntry>[
        for (final start in evidence.candidateStartsNewestFirst)
          (() {
            final period = snapshot.eligiblePeriodsNewestFirst.firstWhere(
              (record) => record.startDate == start,
            );
            final matching = evidence.intervalsNewestFirst.where(
              (interval) => interval.laterStart == start,
            );
            final interval = matching.isEmpty ? null : matching.first;
            return SourcePanelEntry(
              title: period.isOpen
                  ? 'Period — started ${summaryDateLabel(period.startDate)}'
                  : 'Period — ${summaryDateLabel(period.startDate)} to '
                        '${summaryDateLabel(period.endDate!)}',
              certainty: ExperienceCertainty.observed,
              dateLabel: summaryDateLabel(period.startDate),
              details: <String>[
                if (period.durationDays != null)
                  '${_dayCount(period.durationDays!)} recorded'
                else
                  'Bleeding in progress',
                if (interval != null)
                  '${interval.days}-day interval · ${_intervalEvidenceLabel(interval.status)}',
              ],
              onEdit: () {
                final current = _currentCycle;
                if (current?.period.id == period.id) {
                  _openCurrentCycleDetail(current!);
                  return;
                }
                final cycle = _cycleForPeriod(period);
                if (cycle != null) {
                  _openCycleDetail(cycle);
                } else {
                  _openPeriodDates(existing: period);
                }
              },
            );
          })(),
      ],
    );
  }

  String _intervalEvidenceLabel(PredictionIntervalStatus status) =>
      switch (status) {
        PredictionIntervalStatus.used => 'used for this estimate',
        PredictionIntervalStatus.outsideQualityBounds =>
          'not used · outside review bounds',
        PredictionIntervalStatus.outlier =>
          'not used · differs from recent pattern',
        PredictionIntervalStatus.pending => 'recorded · more history needed',
      };

  // --- Build --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExperienceColors.canvas,
      body: SafeArea(
        child: _loading
            ? const _CycleSkeleton()
            : _loadError != null
            ? _LoadErrorPanel(message: _loadError!, onRetry: _reload)
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final currentCycle = _currentCycle;
    final completed = _completedCycles;
    final lastClosed = _lastClosedPeriod;
    // The current cycle already has its own full card above. Recent cycles
    // are deliberately completed, comparable cycles only — never a second
    // rendering of today's day number.
    final visibleCompleted = completed.take(6);
    final lastClosedFlow = lastClosed == null
        ? const <BleedingDayRecord>[]
        : _flowDaysFor(lastClosed.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.sm,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.scrollBottomPadding,
      ),
      children: <Widget>[
        _buildHeader(),
        const SizedBox(height: ExperienceSpacing.md),
        Center(child: _buildRing()),
        if (widget.ringModel != null) _buildEstimateLine(),
        const SizedBox(height: ExperienceSpacing.md),
        SavedRhythmAckLine(line: _ackLine),
        if (_actionError != null) _InlineErrorLine(message: _actionError!),
        const SizedBox(height: ExperienceSpacing.xs * 2),
        if (currentCycle != null)
          _buildCurrentCycleCard(currentCycle)
        else
          _buildPeriodStartActions(),
        if (_periods.isEmpty) _buildFirstRunExplanation(),
        if (completed.isNotEmpty) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.lg),
          const _SectionHeader(title: 'Recent cycles'),
          const SizedBox(height: ExperienceSpacing.xs * 2),
          for (final cycle in visibleCompleted) _buildCycleRow(cycle),
        ],
        if (_periods.length > 6) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.xs * 2),
          OutlinedButton.icon(
            onPressed: _openAllPeriods,
            icon: const Icon(Icons.history_outlined, size: 18),
            label: Text('View all ${_periods.length} periods'),
          ),
        ],
        if (lastClosed != null) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.lg),
          const _SectionHeader(title: 'Bleeding flow, last period'),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'Observed flow days for '
            '${summaryDateLabel(lastClosed.startDate)} – '
            '${summaryDateLabel(lastClosed.endDate!)}. '
            'Blank days are missing, never zero.',
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          if (lastClosedFlow.isEmpty)
            _QuietActionCard(
              message: 'No flow recorded for this period yet.',
              actionLabel: 'Fill in days',
              onAction: () => _openBackfill(existingPeriod: lastClosed),
            )
          else
            _FlowBarChart(
              period: lastClosed,
              flowDays: lastClosedFlow,
              onDayTapped: _openDayEditor,
            ),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              'Cycle',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ExperienceType.title(ExperienceColors.ink),
            ),
          ),
        ),
        const SizedBox(width: ExperienceSpacing.xs * 2),
        Text(
          _todayLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ExperienceType.caption(ExperienceColors.inkSoft),
        ),
      ],
    );
  }

  Widget _buildRing() {
    final model = widget.ringModel;
    final eligible = _cycleSnapshot.eligiblePeriodsNewestFirst;
    if (eligible.isEmpty) {
      return TodayCycleRing.empty(onInspect: _inspectRing);
    }
    if (model != null) {
      return Stack(
        alignment: Alignment.center,
        children: <Widget>[
          TodayCycleRing(model: model, onInspect: _inspectRing),
          if (_pulseTick > 0)
            EmberPulse(key: ValueKey<int>(_pulseTick), diameter: 220),
        ],
      );
    }
    if (eligible.length < 3) {
      // Ring forming: the remaining count is derived from the records and
      // the ring contract (three starts), never hard-coded.
      final latest = eligible.first;
      final observedDays = (_today.epochDay - latest.startDate.epochDay + 1)
          .clamp(1, 9999);
      return TodayCycleRing.forming(
        observedDays: observedDays,
        remainingPeriodStarts: 3 - eligible.length,
        onInspect: _inspectRing,
      );
    }
    // A raw start count does not guarantee usable start-to-start intervals.
    // For example, an adjacent accidental start may be rejected by the
    // prediction engine. This is an honest steady fallback, never a spinner
    // that implies a model is still computing.
    final latest = eligible.first;
    final observedDays = (_today.epochDay - latest.startDate.epochDay + 1)
        .clamp(1, 9999);
    return TodayCycleRing.learning(
      observedDays: observedDays,
      onInspect: _inspectRing,
    );
  }

  Widget _buildEstimateLine() {
    final model = widget.ringModel!;
    final estimatedStart = model.predictedPeriodStart;
    final estimatedEnd = model.predictedPeriodEnd;
    final estimatedLabel = estimatedStart == estimatedEnd
        ? summaryDateLabel(estimatedStart)
        : '${summaryDateLabel(estimatedStart)} – ${summaryDateLabel(estimatedEnd)}';
    return Padding(
      padding: const EdgeInsets.only(top: ExperienceSpacing.sm),
      child: Semantics(
        label:
            'Estimated next period '
            '$estimatedLabel'
            '${model.hasLimitedEstimate ? ', based on limited history' : ''}',
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            const CertaintySwatch(
              certainty: ExperienceCertainty.estimated,
              size: 14,
              color: ExperienceColors.accentGravity,
            ),
            const SizedBox(width: ExperienceSpacing.xs * 2),
            Text(
              'Estimated next period · ',
              style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
            ),
            Text(
              estimatedLabel,
              style: ExperienceType.data(ExperienceColors.ink, size: 14),
            ),
            Text(
              model.hasLimitedEstimate ? ' · limited history' : '',
              style: ExperienceType.caption(ExperienceColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodStartActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          onPressed: _recordPeriodStart,
          icon: const Icon(Icons.water_drop_outlined, size: 18),
          style: FilledButton.styleFrom(
            backgroundColor: ExperienceColors.ember,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, ExperienceSpacing.degreeTarget),
            shape: const RoundedRectangleBorder(
              borderRadius: ExperienceRadius.chipRadius,
            ),
          ),
          label: Text(
            'Record a period start',
            style: ExperienceType.label(Colors.white),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.xs * 2),
        OutlinedButton.icon(
          onPressed: () => _openBackfill(),
          icon: const Icon(Icons.history, size: 18),
          style: OutlinedButton.styleFrom(
            foregroundColor: ExperienceColors.ink,
            side: const BorderSide(color: ExperienceColors.hairline),
            minimumSize: const Size(0, ExperienceSpacing.degreeTarget),
            shape: const RoundedRectangleBorder(
              borderRadius: ExperienceRadius.chipRadius,
            ),
          ),
          label: const Text('Backfill a past period'),
        ),
      ],
    );
  }

  Widget _buildCurrentCycleCard(CurrentCycle current) {
    final period = current.period;
    final bleedingLine = switch (current.bleedingState) {
      BleedingState.open => 'Bleeding in progress',
      BleedingState.endedToday => 'Bleeding ended today',
      BleedingState.ended => 'Bleeding recorded',
    };
    return CycleActionPanel(
      bleedingLine: 'Current cycle',
      startedLabel:
          '$bleedingLine · started ${summaryDateLabel(period.startDate)}.',
      primaryLabel: current.bleedingOpen ? 'End period' : 'Fill in days',
      onOpenDetails: () => _openCurrentCycleDetail(current),
      onPrimary: current.bleedingOpen
          ? () => _endOpenPeriod(period)
          : () => _openBackfill(existingPeriod: period),
      onEditDates: () => _openPeriodDates(existing: period),
      onRecordNewPeriodStart: _recordPeriodStart,
      onBackfillPastPeriod: _openBackfill,
    );
  }

  Widget _buildFirstRunExplanation() {
    return Padding(
      padding: const EdgeInsets.only(top: ExperienceSpacing.lg),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: ExperienceColors.surface,
          borderRadius: ExperienceRadius.cardRadius,
          border: Border.all(color: ExperienceColors.hairline),
        ),
        padding: const EdgeInsets.all(ExperienceSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'What will live here',
              style: ExperienceType.headline(ExperienceColors.ink),
            ),
            const SizedBox(height: ExperienceSpacing.xs * 2),
            Text(
              'As you record periods, this screen fills with your recent '
              'cycles, each period’s flow history, and a letter you can '
              'write to future you at the end of each cycle. Recording one '
              'period start — or backfilling a past one — is the fastest '
              'way to begin.',
              style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCycleRow(_CompletedCycle cycle) {
    final period = cycle.period;
    final range = period.endDate == null
        ? summaryDateLabel(period.startDate)
        : '${summaryDateLabel(period.startDate)} – '
              '${summaryDateLabel(period.endDate!)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: ExperienceSpacing.xs * 2),
      child: Semantics(
        button: true,
        label:
            'Cycle ${cycle.cycleNumber}: $range, '
            '${cycle.cycleLengthDays}-day cycle. Activate for details, '
            'letter, and editing.',
        child: Material(
          color: ExperienceColors.surface,
          borderRadius: ExperienceRadius.chipRadius,
          child: InkWell(
            borderRadius: ExperienceRadius.chipRadius,
            onTap: () => _openCycleDetail(cycle),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: ExperienceSpacing.minTouchTarget,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceSpacing.sm,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                borderRadius: ExperienceRadius.chipRadius,
                border: Border.all(color: ExperienceColors.hairline),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: ExperienceColors.phasePeriod,
                    ),
                  ),
                  const SizedBox(width: ExperienceSpacing.sm),
                  Expanded(
                    child: Text(
                      range,
                      style: ExperienceType.body(ExperienceColors.ink),
                    ),
                  ),
                  Text(
                    '${cycle.cycleLengthDays}-day cycle',
                    style: ExperienceType.bodyStrong(ExperienceColors.ink),
                  ),
                  const SizedBox(width: ExperienceSpacing.xs),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: ExperienceColors.inkFaint,
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

// ---------------------------------------------------------------------------
// Supporting value type
// ---------------------------------------------------------------------------

final class _CompletedCycle {
  const _CompletedCycle({
    required this.period,
    required this.cycleNumber,
    required this.cycleLengthDays,
  });

  final PeriodRecord period;
  final int cycleNumber;
  final int cycleLengthDays;
}

class _AllPeriodsSheet extends StatelessWidget {
  const _AllPeriodsSheet({required this.periods, required this.onOpenPeriod});

  final List<PeriodRecord> periods;
  final ValueChanged<PeriodRecord> onOpenPeriod;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 560,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ExperienceSpacing.screenMargin,
            ExperienceSpacing.sm,
            ExperienceSpacing.screenMargin,
            ExperienceSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _SectionHeader(title: 'All periods'),
              const SizedBox(height: ExperienceSpacing.xs * 2),
              Text(
                'Every period saved on this device. Open one to review or edit it.',
                style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
              ),
              const SizedBox(height: ExperienceSpacing.sm),
              Expanded(
                child: ListView.separated(
                  itemCount: periods.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: ExperienceSpacing.xs * 2),
                  itemBuilder: (context, index) {
                    final period = periods[index];
                    final range = period.endDate == null
                        ? 'Started ${summaryDateLabel(period.startDate)}'
                        : '${summaryDateLabel(period.startDate)} – '
                              '${summaryDateLabel(period.endDate!)}';
                    final detail = period.isOpen
                        ? 'Period in progress'
                        : '${_dayCount(period.durationDays!)} recorded';
                    return Material(
                      color: ExperienceColors.surface,
                      borderRadius: ExperienceRadius.chipRadius,
                      child: InkWell(
                        borderRadius: ExperienceRadius.chipRadius,
                        onTap: () => onOpenPeriod(period),
                        child: Container(
                          constraints: const BoxConstraints(
                            minHeight: ExperienceSpacing.minTouchTarget,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: ExperienceSpacing.sm,
                            vertical: ExperienceSpacing.xs * 2,
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.water_drop_outlined,
                                size: 18,
                                color: ExperienceColors.phasePeriod,
                              ),
                              const SizedBox(width: ExperienceSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      range,
                                      style: ExperienceType.bodyStrong(
                                        ExperienceColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      detail,
                                      style: ExperienceType.caption(
                                        ExperienceColors.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: ExperienceColors.inkFaint,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(title, style: ExperienceType.headline(ExperienceColors.ink)),
    );
  }
}

class _InlineErrorLine extends StatelessWidget {
  const _InlineErrorLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: ExperienceSpacing.xs * 2),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: ExperienceType.caption(ExperienceColors.error),
        ),
      ),
    );
  }
}

class _QuietActionCard extends StatelessWidget {
  const _QuietActionCard({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ExperienceColors.surface,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(color: ExperienceColors.hairline),
      ),
      padding: const EdgeInsets.all(ExperienceSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(message, style: ExperienceType.body(ExperienceColors.inkSoft)),
          const SizedBox(height: ExperienceSpacing.xs * 2),
          OutlinedButton(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              foregroundColor: ExperienceColors.ember,
              side: const BorderSide(color: ExperienceColors.ember),
              minimumSize: const Size(0, ExperienceSpacing.minTouchTarget),
              shape: const RoundedRectangleBorder(
                borderRadius: ExperienceRadius.chipRadius,
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _LoadErrorPanel extends StatelessWidget {
  const _LoadErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ExperienceSpacing.screenMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              style: ExperienceType.body(ExperienceColors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ExperienceSpacing.sm),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: ExperienceColors.ember,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, ExperienceSpacing.degreeTarget),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CycleSkeleton extends StatelessWidget {
  const _CycleSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget shimmer(double height, double width) => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: ExperienceColors.surfaceWarm,
        borderRadius: ExperienceRadius.chipRadius,
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(ExperienceSpacing.screenMargin),
      children: <Widget>[
        shimmer(28, 180),
        const SizedBox(height: ExperienceSpacing.lg),
        Center(
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ExperienceColors.hairline, width: 12),
            ),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.lg),
        shimmer(52, double.infinity),
        const SizedBox(height: ExperienceSpacing.sm),
        shimmer(52, double.infinity),
        const SizedBox(height: ExperienceSpacing.sm),
        shimmer(52, double.infinity),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Flow chart — observed flow days of one period. Every day occupies the same
// fixed mark area above a shared baseline, so recorded and missing days read
// as one aligned sequence with equal footprints. Recorded days render the
// shared fixed-terracotta fill-level droplet (the same language as the
// Today/Cycle flow selector); amount is encoded only by the droplet's own
// internal fill level, never by hue, opacity, size, or bar height. Missing
// days render a compact dotted slot at the same footprint — visibly "not
// recorded," never zero, and never mistakable for a Spotting droplet. Flow
// is factual: it never feeds severity, prediction, Gravity, Spectrum, or
// Twin.
// ---------------------------------------------------------------------------

class _FlowBarChart extends StatelessWidget {
  const _FlowBarChart({
    required this.period,
    required this.flowDays,
    required this.onDayTapped,
  });

  final PeriodRecord period;
  final List<BleedingDayRecord> flowDays;
  final ValueChanged<LocalDate> onDayTapped;

  /// One fixed mark area per day. Every day's mark — droplet or dotted
  /// slot — rests on the same baseline inside this height.
  static const double _markAreaHeight = 56;
  static const double _dropletSize = 40;
  static const double _missingSlotSize = 40;

  @override
  Widget build(BuildContext context) {
    final duration = period.durationDays;
    if (duration == null || duration <= 0) return const SizedBox.shrink();
    final reduced = ExperienceMotion.reducedMotion(context);
    final byEpochDay = <int, BleedingDayRecord>{
      for (final day in flowDays) day.date.epochDay: day,
    };

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: reduced ? Duration.zero : ExperienceMotion.chartDrawOn,
      curve: Curves.easeOut,
      builder: (context, t, _) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: ExperienceColors.surface,
            borderRadius: ExperienceRadius.cardRadius,
            border: Border.all(color: ExperienceColors.hairline),
          ),
          padding: const EdgeInsets.all(ExperienceSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (var i = 0; i < duration; i++)
                Expanded(
                  child: _buildDayColumn(
                    context,
                    dayIndex: i,
                    record: byEpochDay[period.startDate.epochDay + i],
                    drawFraction: t,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayColumn(
    BuildContext context, {
    required int dayIndex,
    required BleedingDayRecord? record,
    required double drawFraction,
  }) {
    final date = period.startDate.addDays(dayIndex);
    final semanticsLabel = record == null
        ? 'Day ${dayIndex + 1}: no flow recorded'
        : 'Day ${dayIndex + 1}: ${record.flow.label}'
              '${record.color != null ? ', ${record.color!.label}' : ''}';

    return Semantics(
      button: true,
      label: '$semanticsLabel. Activate to edit this day.',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onDayTapped(date),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // The shared mark area: fixed height, bottom-anchored, one
              // footprint for every day in the sequence.
              SizedBox(
                height: _markAreaHeight,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: record == null
                      ? _buildMissingSlot()
                      // The shared droplet: one stable terracotta outline
                      // for every degree, with the amount read only from
                      // its bottom-anchored internal fill level.
                      : Opacity(
                          opacity: drawFraction,
                          child: Transform.scale(
                            scale: 0.6 + (0.4 * drawFraction),
                            child: DegreeGraphics.flow(
                              record.flow,
                              size: _dropletSize,
                              showWord: false,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: ExperienceSpacing.xs),
              Text(
                'D${dayIndex + 1}',
                style: ExperienceType.data(
                  ExperienceColors.inkFaint,
                  size: 11,
                  weight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A missing day: a compact dotted slot at the droplet's footprint.
  /// Clearly "not recorded," and never confused with a Spotting droplet.
  Widget _buildMissingSlot() {
    return Container(
      width: _missingSlotSize,
      height: _missingSlotSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ExperienceColors.hairline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: const CustomPaint(
          painter: DotGridPainter(spacing: 7),
          size: Size.infinite,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day editor — flow, patterned color, the pain degree card, observations via
// the catalog picker, and functional impact on the day's records.
// ---------------------------------------------------------------------------

class _DayEditorSheet extends StatefulWidget {
  const _DayEditorSheet({
    required this.date,
    required this.periodRepository,
    required this.healthRecordRepository,
    required this.today,
    required this.onDataChanged,
  });

  final LocalDate date;
  final PeriodRepository periodRepository;
  final HealthRecordRepository healthRecordRepository;
  final LocalDate today;
  final VoidCallback onDataChanged;

  @override
  State<_DayEditorSheet> createState() => _DayEditorSheetState();
}

class _DayEditorSheetState extends State<_DayEditorSheet> {
  bool _loading = true;
  String? _loadError;

  List<PeriodRecord> _periods = const <PeriodRecord>[];
  BleedingDayRecord? _flowRecord;
  List<HealthRecord> _dayRecords = const <HealthRecord>[];

  String? _flowError;
  String? _colorError;
  String? _ackLine;
  bool _spottingNoteShown = false;

  // Pain quick-edit working state — cancellation discards this degree.
  HealthRecord? _painRecord;
  SymptomSeverity? _painSeverity;
  String? _painError;
  bool _painSaving = false;

  bool get _isToday => widget.date.epochDay == widget.today.epochDay;

  HealthRecordProvenance get _provenance => _isToday
      ? HealthRecordProvenance.sameDay
      : HealthRecordProvenance.laterRecall;

  PeriodRecord? get _containingPeriod {
    for (final period in _periods) {
      final afterStart = !widget.date.isBefore(period.startDate);
      final beforeEnd =
          period.endDate == null || !widget.date.isAfter(period.endDate!);
      if (afterStart && beforeEnd) return period;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final periods = await widget.periodRepository.getAll();
      final flowDays = await widget.periodRepository.getAllFlowDays();
      final records = await widget.healthRecordRepository.getAll();
      if (!mounted) return;
      periods.sort((a, b) => a.startDate.compareTo(b.startDate));
      BleedingDayRecord? flowRecord;
      for (final day in flowDays) {
        if (day.date.epochDay == widget.date.epochDay) {
          flowRecord = day;
          break;
        }
      }
      final dayRecords = records
          .where((r) => r.experiencedDate.epochDay == widget.date.epochDay)
          .toList();
      HealthRecord? painRecord;
      for (final record in dayRecords) {
        final definition = ObservationCatalog.definitionFor(record.symptom);
        if (definition.recordingKind == ObservationRecordingKind.pain) {
          painRecord = record;
          break;
        }
      }
      setState(() {
        _periods = periods;
        _flowRecord = flowRecord;
        _dayRecords = dayRecords;
        _painRecord = painRecord;
        _painSeverity = painRecord?.severity;
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError =
            'Letter Within could not open private cycle storage. Try again.';
      });
    }
  }

  HealthRecord? _recordForSymptom(SymptomType symptom) {
    for (final record in _dayRecords) {
      if (record.symptom == symptom) return record;
    }
    return null;
  }

  Future<void> _setFlow(BleedingFlow flow) async {
    final period = _containingPeriod;
    if (period == null) return;
    ExperienceHaptics.pick();
    setState(() => _flowError = null);
    try {
      if (_flowRecord?.flow == flow) {
        // Deselection is absence.
        await widget.periodRepository.clearFlow(period.id, widget.date);
      } else {
        await widget.periodRepository.setFlow(
          period.id,
          widget.date,
          flow,
          today: widget.today,
        );
        if (flow == BleedingFlow.spotting && !_spottingNoteShown) {
          _spottingNoteShown = true;
        }
      }
      final line = await SavedRhythm.acknowledge(SavedRhythmKind.record);
      if (!mounted) return;
      setState(() => _ackLine = line);
      await _reload();
      widget.onDataChanged();
    } on PeriodWriteException catch (error) {
      if (!mounted) return;
      setState(() => _flowError = error.userMessage);
    }
  }

  Future<void> _setColor(BleedingColor color) async {
    final period = _containingPeriod;
    if (period == null) return;
    ExperienceHaptics.pick();
    setState(() => _colorError = null);
    try {
      await widget.periodRepository.setBleedingColor(
        period.id,
        widget.date,
        color,
      );
      final line = await SavedRhythm.acknowledge(SavedRhythmKind.record);
      if (!mounted) return;
      setState(() => _ackLine = line);
      await _reload();
      widget.onDataChanged();
    } on PeriodWriteException catch (error) {
      if (!mounted) return;
      setState(() => _colorError = error.userMessage);
    }
  }

  Future<void> _saveObservation(HealthRecordDraft draft) async {
    final existing = _recordForSymptom(draft.symptom);
    if (existing != null) {
      await widget.healthRecordRepository.update(existing.id, draft);
    } else {
      await widget.healthRecordRepository.create(draft);
    }
    await _reload();
    widget.onDataChanged();
  }

  Future<void> _deleteObservation(HealthRecord record) async {
    await widget.healthRecordRepository.delete(record.id);
    await _reload();
    widget.onDataChanged();
  }

  Future<void> _withdrawObservation(SymptomType symptom) async {
    final record = _recordForSymptom(symptom);
    if (record != null) {
      await widget.healthRecordRepository.delete(record.id);
      await _reload();
      widget.onDataChanged();
    }
  }

  Future<void> _savePainEntry() async {
    final record = _painRecord;
    if (record == null || _painSaving) return;
    setState(() {
      _painError = null;
      _painSaving = true;
    });
    try {
      final severity = _painSeverity;
      if (severity == null) {
        // A cleared degree removes the pain record — absence, never a
        // "not at all" value.
        await widget.healthRecordRepository.delete(record.id);
      } else {
        final draft = validateHealthRecordDraft(
          HealthRecordDraft(
            symptom: record.symptom,
            severity: severity,
            experiencedDate: record.experiencedDate,
            provenance: record.provenance,
            functionalImpacts: record.functionalImpacts,
          ),
        );
        await widget.healthRecordRepository.update(record.id, draft);
      }
      final line = await SavedRhythm.acknowledge(SavedRhythmKind.record);
      if (!mounted) return;
      setState(() {
        _painSaving = false;
        _ackLine = line;
      });
      await _reload();
      widget.onDataChanged();
    } on HealthRecordException catch (error) {
      if (!mounted) return;
      setState(() {
        _painSaving = false;
        _painError = error.userMessage;
      });
    }
  }

  void _cancelPainEntry() {
    ExperienceHaptics.pick();
    // Cancellation discards the unfinished degree — invalid data never
    // persists.
    setState(() {
      _painSeverity = _painRecord?.severity;
      _painError = null;
    });
  }

  bool get _painDirty {
    final record = _painRecord;
    if (record == null) return false;
    return _painSeverity != record.severity;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(ExperienceSpacing.xl),
        child: Center(
          child: EmberLoadingIndicator(semanticLabel: 'Loading this day'),
        ),
      );
    }
    if (_loadError != null) {
      return _LoadErrorPanel(message: _loadError!, onRetry: _reload);
    }

    final period = _containingPeriod;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        0,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    summaryDateLabel(widget.date),
                    style: ExperienceType.headline(ExperienceColors.ink),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close day editor',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: ExperienceColors.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            '${_provenance.label} · '
            '${period == null ? 'outside a recorded period' : 'inside a recorded period'}',
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.xs * 2),
          SavedRhythmAckLine(line: _ackLine),
          if (period != null) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.sm),
            _buildFlowSection(),
            _buildColorSection(),
          ],
          const SizedBox(height: ExperienceSpacing.sm),
          _buildPainSection(),
          const SizedBox(height: ExperienceSpacing.sm),
          Text(
            'Observations',
            style: ExperienceType.headline(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs * 2),
          ObservationPicker(
            experiencedDate: widget.date,
            provenance: _provenance,
            existingRecords: _dayRecords,
            onSave: _saveObservation,
            onDelete: _deleteObservation,
            onWithdraw: _withdrawObservation,
            onEditImpacts: _openImpactsEditor,
          ),
        ],
      ),
    );
  }

  Widget _buildFlowSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Bleeding flow',
          style: ExperienceType.headline(ExperienceColors.ink),
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          'Choose the closest degree. Choosing it again removes it.',
          style: ExperienceType.caption(ExperienceColors.inkSoft),
        ),
        const SizedBox(height: ExperienceSpacing.xs * 2),
        // The shared Today/Cycle selector cells — one silhouette, one
        // selection treatment, one semantics contract everywhere.
        Row(
          children: <Widget>[
            for (final flow in DegreeGraphics.flowDegrees)
              Expanded(
                child: DegreeGraphics.flowChoice(
                  flow,
                  selected: _flowRecord?.flow == flow,
                  onTap: () => _setFlow(flow),
                ),
              ),
          ],
        ),
        if (_flowRecord?.flow == BleedingFlow.spotting && _spottingNoteShown)
          Padding(
            padding: const EdgeInsets.only(top: ExperienceSpacing.xs * 2),
            child: Text(
              DegreeGraphics.spottingHonestyNote,
              style: ExperienceType.caption(ExperienceColors.inkFaint),
            ),
          ),
        if (_flowError != null) _InlineErrorLine(message: _flowError!),
      ],
    );
  }

  Widget _buildColorSection() {
    final hasFlow = _flowRecord != null;
    return Padding(
      padding: const EdgeInsets.only(top: ExperienceSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Bleeding color',
            style: ExperienceType.headline(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            hasFlow
                ? 'A visual observation only — color never feeds prediction '
                      'or symptom patterns.'
                : // Verbatim flowRequiredForColor wording as the quiet hint.
                  const PeriodWriteException(
                    PeriodWriteFailure.flowRequiredForColor,
                  ).userMessage,
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
          if (hasFlow) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.xs * 2),
            // Color stays inert until a flow exists: the choices appear only
            // once flow is recorded, exactly as in the backfill editor.
            Row(
              children: <Widget>[
                for (final color in BleedingColor.values)
                  Expanded(
                    child: DegreeGraphics.bleedingColorChoice(
                      color,
                      selected: _flowRecord?.color == color,
                      onTap: () => _setColor(color),
                    ),
                  ),
              ],
            ),
          ],
          if (_colorError != null) _InlineErrorLine(message: _colorError!),
        ],
      ),
    );
  }

  Widget _buildPainSection() {
    final record = _painRecord;
    if (record == null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: ExperienceColors.surface,
          borderRadius: ExperienceRadius.cardRadius,
          border: Border.all(color: ExperienceColors.hairline),
        ),
        padding: const EdgeInsets.all(ExperienceSpacing.md),
        child: Text(
          'Pain is saved together with a symptom — add it under '
          'Observations, where its degree saves as one.',
          style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DegreeGraphics.painEntry(
          severity: _painSeverity,
          enabled: !_painSaving,
          onSeverityChanged: _painSaving
              ? null
              : (degree) => setState(() {
                  // Choosing the same degree again removes it — absence,
                  // never "not at all".
                  _painSeverity = _painSeverity == degree ? null : degree;
                }),
          onCleared: _painSaving
              ? null
              : () => setState(() => _painSeverity = null),
        ),
        if (_painError != null) _InlineErrorLine(message: _painError!),
        if (_painDirty)
          Padding(
            padding: const EdgeInsets.only(top: ExperienceSpacing.xs * 2),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: _painSaving ? null : _savePainEntry,
                    style: FilledButton.styleFrom(
                      backgroundColor: ExperienceColors.ember,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(
                        0,
                        ExperienceSpacing.degreeTarget,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: ExperienceRadius.chipRadius,
                      ),
                    ),
                    child: Text(
                      _painSaving ? 'Saving…' : 'Save pain entry',
                      style: ExperienceType.label(Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: ExperienceSpacing.xs * 2),
                TextButton(
                  onPressed: _painSaving ? null : _cancelPainEntry,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _openImpactsEditor(HealthRecord record) {
    showExperienceSheet<void>(
      context,
      child: _ImpactsEditorSheet(
        record: record,
        healthRecordRepository: widget.healthRecordRepository,
        onSaved: () async {
          await _reload();
          widget.onDataChanged();
        },
      ),
    );
  }
}

class _DegreeOptionTile extends StatelessWidget {
  const _DegreeOptionTile({
    required this.selected,
    required this.semanticsLabel,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final String semanticsLabel;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: ExperienceRadius.chipRadius,
        child: AnimatedContainer(
          duration: ExperienceMotion.chipSelect,
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.degreeTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? ExperienceColors.surfaceWarm
                : ExperienceColors.surface,
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(
              color: selected
                  ? ExperienceColors.ember
                  : ExperienceColors.hairline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Functional impact editor — multi-select over the day's record.
// ---------------------------------------------------------------------------

class _ImpactsEditorSheet extends StatefulWidget {
  const _ImpactsEditorSheet({
    required this.record,
    required this.healthRecordRepository,
    required this.onSaved,
  });

  final HealthRecord record;
  final HealthRecordRepository healthRecordRepository;
  final Future<void> Function() onSaved;

  @override
  State<_ImpactsEditorSheet> createState() => _ImpactsEditorSheetState();
}

class _ImpactsEditorSheetState extends State<_ImpactsEditorSheet> {
  late Set<FunctionalImpact> _selected = <FunctionalImpact>{
    ...widget.record.functionalImpacts,
  };
  bool _saving = false;
  String? _errorLine;

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorLine = null;
    });
    try {
      final draft = validateHealthRecordDraft(
        HealthRecordDraft(
          symptom: widget.record.symptom,
          severity: widget.record.severity,
          experiencedDate: widget.record.experiencedDate,
          provenance: widget.record.provenance,
          functionalImpacts: _selected,
        ),
      );
      await widget.healthRecordRepository.update(widget.record.id, draft);
      await SavedRhythm.acknowledge(SavedRhythmKind.record);
      await widget.onSaved();
      if (!mounted) return;
      Navigator.of(context).pop();
    } on HealthRecordException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorLine = error.userMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        0,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              'What ${widget.record.symptom.label.toLowerCase()} affected',
              style: ExperienceType.headline(ExperienceColors.ink),
            ),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'Choose everything this day touched, or nothing at all.',
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          Wrap(
            spacing: ExperienceSpacing.xs * 2,
            runSpacing: ExperienceSpacing.xs * 2,
            children: <Widget>[
              for (final impact in FunctionalImpact.values)
                _DegreeOptionTile(
                  selected: _selected.contains(impact),
                  semanticsLabel: 'Functional impact: ${impact.label}',
                  onTap: _saving
                      ? () {}
                      : () {
                          ExperienceHaptics.pick();
                          setState(() {
                            final next = <FunctionalImpact>{..._selected};
                            if (!next.add(impact)) next.remove(impact);
                            _selected = next;
                          });
                        },
                  child: Text(
                    impact.label,
                    style: ExperienceType.label(ExperienceColors.ink),
                  ),
                ),
            ],
          ),
          if (_errorLine != null) _InlineErrorLine(message: _errorLine!),
          const SizedBox(height: ExperienceSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: ExperienceColors.ember,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, ExperienceSpacing.degreeTarget),
                    shape: const RoundedRectangleBorder(
                      borderRadius: ExperienceRadius.chipRadius,
                    ),
                  ),
                  child: Text(
                    _saving ? 'Saving…' : 'Save',
                    style: ExperienceType.label(Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: ExperienceSpacing.xs * 2),
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Whole-cycle backfill — pick a past period's dates, then edit every date:
// flow, color (after flow), pain, and observations. Repository failures
// (overlap, anotherPeriodOpen, flowDateOutsidePeriod, future dates) surface
// verbatim inline; every successful mutation fires onCycleDataChanged.
// ---------------------------------------------------------------------------

class _BackfillSheet extends StatefulWidget {
  const _BackfillSheet({
    required this.periodRepository,
    required this.healthRecordRepository,
    required this.today,
    required this.onDataChanged,
    this.existingPeriod,
    this.now,
  });

  final PeriodRepository periodRepository;
  final HealthRecordRepository healthRecordRepository;
  final LocalDate today;
  final VoidCallback onDataChanged;
  final PeriodRecord? existingPeriod;
  final DateTime? now;

  @override
  State<_BackfillSheet> createState() => _BackfillSheetState();
}

class _BackfillSheetState extends State<_BackfillSheet> {
  PeriodRecord? _period;
  LocalDate? _pickedStart;
  LocalDate? _pickedEnd;

  bool _busy = false;
  String? _createError;
  final Map<int, String> _rowErrors = <int, String>{};
  Map<int, BleedingDayRecord> _flowByDay = <int, BleedingDayRecord>{};
  List<HealthRecord> _healthRecords = const <HealthRecord>[];
  int? _expandedDay;
  bool _spottingNoteShown = false;
  bool _created = false;

  @override
  void initState() {
    super.initState();
    _period = widget.existingPeriod;
    if (_period != null) {
      _reloadDays();
    }
  }

  Future<void> _reloadDays() async {
    final period = _period;
    if (period == null) return;
    try {
      final flowDays = await widget.periodRepository.getAllFlowDays();
      final records = await widget.healthRecordRepository.getAll();
      if (!mounted) return;
      setState(() {
        _flowByDay = <int, BleedingDayRecord>{
          for (final day in flowDays)
            if (day.periodId == period.id) day.date.epochDay: day,
        };
        _healthRecords = records;
      });
    } catch (_) {
      // Day rows keep working; per-row writes surface their own errors.
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final now = widget.now ?? DateTime.now();
    final initial = start
        ? (_pickedStart != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  0,
                  isUtc: true,
                ).add(Duration(days: _pickedStart!.epochDay))
              : now)
        : (_pickedEnd != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  0,
                  isUtc: true,
                ).add(Duration(days: _pickedEnd!.epochDay))
              : (_pickedStart != null
                    ? DateTime.fromMillisecondsSinceEpoch(
                        0,
                        isUtc: true,
                      ).add(Duration(days: _pickedStart!.epochDay))
                    : now));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: start ? 'Period start' : 'Period end',
    );
    if (picked == null || !mounted) return;
    setState(() {
      final date = LocalDate.fromDateTime(picked);
      if (start) {
        _pickedStart = date;
      } else {
        _pickedEnd = date;
      }
      _createError = null;
    });
  }

  Future<void> _createPeriod() async {
    final start = _pickedStart;
    final end = _pickedEnd;
    if (start == null || end == null || _busy) return;
    setState(() {
      _busy = true;
      _createError = null;
    });
    try {
      final period = await widget.periodRepository.create(
        PeriodDraft(startDate: start, endDate: end),
        today: widget.today,
      );
      if (!mounted) return;
      setState(() {
        _period = period;
        _busy = false;
        _created = true;
      });
      // A period mutation — charts refresh immediately.
      widget.onDataChanged();
      await _reloadDays();
    } on PeriodWriteException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _createError = error.userMessage;
      });
    }
  }

  Future<void> _setFlow(LocalDate date, BleedingFlow flow) async {
    final period = _period;
    if (period == null) return;
    ExperienceHaptics.pick();
    setState(() => _rowErrors.remove(date.epochDay));
    try {
      if (_flowByDay[date.epochDay]?.flow == flow) {
        await widget.periodRepository.clearFlow(period.id, date);
      } else {
        await widget.periodRepository.setFlow(
          period.id,
          date,
          flow,
          today: widget.today,
        );
        if (flow == BleedingFlow.spotting && !_spottingNoteShown) {
          _spottingNoteShown = true;
        }
      }
      await _reloadDays();
      widget.onDataChanged();
    } on PeriodWriteException catch (error) {
      if (!mounted) return;
      setState(() => _rowErrors[date.epochDay] = error.userMessage);
    }
  }

  Future<void> _setColor(LocalDate date, BleedingColor color) async {
    final period = _period;
    if (period == null) return;
    ExperienceHaptics.pick();
    setState(() => _rowErrors.remove(date.epochDay));
    try {
      await widget.periodRepository.setBleedingColor(period.id, date, color);
      await _reloadDays();
      widget.onDataChanged();
    } on PeriodWriteException catch (error) {
      if (!mounted) return;
      setState(() => _rowErrors[date.epochDay] = error.userMessage);
    }
  }

  Future<void> _saveObservation(HealthRecordDraft draft) async {
    HealthRecord? existing;
    for (final record in _healthRecords) {
      if (record.symptom == draft.symptom &&
          record.experiencedDate.epochDay == draft.experiencedDate.epochDay) {
        existing = record;
        break;
      }
    }
    if (existing != null) {
      await widget.healthRecordRepository.update(existing.id, draft);
    } else {
      await widget.healthRecordRepository.create(draft);
    }
    await _reloadDays();
    widget.onDataChanged();
  }

  Future<void> _deleteObservation(HealthRecord record) async {
    await widget.healthRecordRepository.delete(record.id);
    await _reloadDays();
    widget.onDataChanged();
  }

  void _openImpactsEditor(HealthRecord record) {
    showExperienceSheet<void>(
      context,
      child: _ImpactsEditorSheet(
        record: record,
        healthRecordRepository: widget.healthRecordRepository,
        onSaved: () async {
          await _reloadDays();
          widget.onDataChanged();
        },
      ),
    );
  }

  Future<void> _withdrawObservation(SymptomType symptom, LocalDate date) async {
    for (final record in _healthRecords) {
      if (record.symptom == symptom &&
          record.experiencedDate.epochDay == date.epochDay) {
        await widget.healthRecordRepository.delete(record.id);
        break;
      }
    }
    await _reloadDays();
    widget.onDataChanged();
  }

  List<HealthRecord> _recordsFor(LocalDate date) {
    return _healthRecords
        .where((r) => r.experiencedDate.epochDay == date.epochDay)
        .toList(growable: false);
  }

  Future<bool> _confirmClose() async {
    // Drafts (picked but uncreated dates) are the only unsaved state; every
    // other change persisted at the moment of choice.
    if (_period != null || (_pickedStart == null && _pickedEnd == null)) {
      return true;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this backfill?'),
        content: const Text(
          'The dates you picked have not been saved as a period.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ExperienceColors.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.75;
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ExperienceSpacing.screenMargin,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      _period == null
                          ? 'Backfill a past period'
                          : 'Fill in '
                                '${summaryDateLabel(_period!.startDate)} – '
                                '${_period!.endDate == null ? 'ongoing' : summaryDateLabel(_period!.endDate!)}',
                      style: ExperienceType.headline(ExperienceColors.ink),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    if (await _confirmClose() && context.mounted) {
                      Navigator.of(context).pop();
                      if (_created) widget.onDataChanged();
                    }
                  },
                  child: Text(_period == null ? 'Close' : 'Done'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _period == null
                ? _buildDatePickStep()
                : _buildFillStep(_period!),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickStep() {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: ExperienceSpacing.screenMargin,
      ),
      children: <Widget>[
        Text(
          'Choose the start and end of a period that already happened. '
          'Then you can fill in flow, color, pain, and observations for '
          'every date. Later-recall entries stay labeled as later recall.',
          style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
        ),
        const SizedBox(height: ExperienceSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _pickDate(start: true),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, ExperienceSpacing.degreeTarget),
                  side: const BorderSide(color: ExperienceColors.hairline),
                  shape: const RoundedRectangleBorder(
                    borderRadius: ExperienceRadius.chipRadius,
                  ),
                ),
                child: Text(
                  _pickedStart == null
                      ? 'Choose start'
                      : summaryDateLabel(_pickedStart!),
                  style: ExperienceType.label(ExperienceColors.ink),
                ),
              ),
            ),
            const SizedBox(width: ExperienceSpacing.xs * 2),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _pickDate(start: false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, ExperienceSpacing.degreeTarget),
                  side: const BorderSide(color: ExperienceColors.hairline),
                  shape: const RoundedRectangleBorder(
                    borderRadius: ExperienceRadius.chipRadius,
                  ),
                ),
                child: Text(
                  _pickedEnd == null
                      ? 'Choose end'
                      : summaryDateLabel(_pickedEnd!),
                  style: ExperienceType.label(ExperienceColors.ink),
                ),
              ),
            ),
          ],
        ),
        if (_createError != null) _InlineErrorLine(message: _createError!),
        const SizedBox(height: ExperienceSpacing.md),
        FilledButton(
          onPressed: _pickedStart != null && _pickedEnd != null && !_busy
              ? _createPeriod
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: ExperienceColors.ember,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, ExperienceSpacing.degreeTarget),
            shape: const RoundedRectangleBorder(
              borderRadius: ExperienceRadius.chipRadius,
            ),
          ),
          child: Text(
            _busy ? 'Saving…' : 'Save this period',
            style: ExperienceType.label(Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildFillStep(PeriodRecord period) {
    final end = period.endDate ?? widget.today;
    final dayCount = end.epochDay - period.startDate.epochDay + 1;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: ExperienceSpacing.screenMargin,
      ),
      itemCount: dayCount + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: ExperienceSpacing.sm),
            child: Text(
              'Tap a day to record flow, color, pain, and observations. '
              'Blank days stay blank — missing is never zero.',
              style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
            ),
          );
        }
        final date = period.startDate.addDays(index - 1);
        return _buildDayRow(date);
      },
    );
  }

  Widget _buildDayRow(LocalDate date) {
    final record = _flowByDay[date.epochDay];
    final expanded = _expandedDay == date.epochDay;
    final error = _rowErrors[date.epochDay];
    final dayRecords = _recordsFor(date);

    return Padding(
      padding: const EdgeInsets.only(bottom: ExperienceSpacing.xs * 2),
      child: Container(
        decoration: BoxDecoration(
          color: ExperienceColors.surface,
          borderRadius: ExperienceRadius.chipRadius,
          border: Border.all(color: ExperienceColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              button: true,
              expanded: expanded,
              label:
                  '${summaryDateLabel(date)}: '
                  '${record == null ? 'no flow recorded' : record.flow.label}'
                  '${dayRecords.isEmpty ? '' : ', ${dayRecords.length} observations'}',
              child: InkWell(
                borderRadius: ExperienceRadius.chipRadius,
                onTap: () {
                  ExperienceHaptics.pick();
                  setState(() {
                    _expandedDay = expanded ? null : date.epochDay;
                  });
                },
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: ExperienceSpacing.minTouchTarget,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: ExperienceSpacing.sm,
                    vertical: 10,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          summaryDateLabel(date),
                          style: ExperienceType.bodyStrong(
                            ExperienceColors.ink,
                          ),
                        ),
                      ),
                      if (record != null)
                        DegreeGraphics.flow(
                          record.flow,
                          showWord: true,
                          size: 20,
                        )
                      else
                        Text(
                          'Blank',
                          style: ExperienceType.caption(
                            ExperienceColors.inkFaint,
                          ),
                        ),
                      const SizedBox(width: ExperienceSpacing.xs),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: ExperienceColors.inkFaint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (expanded) ...<Widget>[
              const Divider(height: 1, color: ExperienceColors.hairline),
              Padding(
                padding: const EdgeInsets.all(ExperienceSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        for (final flow in DegreeGraphics.flowDegrees)
                          Expanded(
                            child: DegreeGraphics.flowChoice(
                              flow,
                              selected: record?.flow == flow,
                              onTap: () => _setFlow(date, flow),
                            ),
                          ),
                      ],
                    ),
                    if (record?.flow == BleedingFlow.spotting &&
                        _spottingNoteShown)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: ExperienceSpacing.xs * 2,
                        ),
                        child: Text(
                          DegreeGraphics.spottingHonestyNote,
                          style: ExperienceType.caption(
                            ExperienceColors.inkFaint,
                          ),
                        ),
                      ),
                    const SizedBox(height: ExperienceSpacing.xs * 2),
                    if (record != null)
                      Row(
                        children: <Widget>[
                          for (final color in BleedingColor.values)
                            Expanded(
                              child: DegreeGraphics.bleedingColorChoice(
                                color,
                                selected: record.color == color,
                                onTap: () => _setColor(date, color),
                              ),
                            ),
                        ],
                      )
                    else
                      Text(
                        const PeriodWriteException(
                          PeriodWriteFailure.flowRequiredForColor,
                        ).userMessage,
                        style: ExperienceType.caption(ExperienceColors.inkSoft),
                      ),
                    if (error != null) _InlineErrorLine(message: error),
                    const SizedBox(height: ExperienceSpacing.xs * 2),
                    OutlinedButton.icon(
                      onPressed: () {
                        ObservationPicker.show(
                          context,
                          experiencedDate: date,
                          provenance: date.epochDay == widget.today.epochDay
                              ? HealthRecordProvenance.sameDay
                              : HealthRecordProvenance.laterRecall,
                          existingRecords: dayRecords,
                          onSave: _saveObservation,
                          onDelete: _deleteObservation,
                          onWithdraw: (symptom) =>
                              _withdrawObservation(symptom, date),
                          onEditImpacts: _openImpactsEditor,
                        );
                      },
                      icon: const Icon(Icons.playlist_add, size: 18),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ExperienceColors.ink,
                        side: const BorderSide(
                          color: ExperienceColors.hairline,
                        ),
                        minimumSize: const Size(
                          0,
                          ExperienceSpacing.minTouchTarget,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: ExperienceRadius.chipRadius,
                        ),
                      ),
                      label: Text(
                        dayRecords.isEmpty
                            ? 'Pain & observations'
                            : 'Pain & observations (${dayRecords.length})',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Period dates editor — create or correct a period's start/end. Typed
// failures (overlap, anotherPeriodOpen, future dates, end before start)
// surface verbatim.
// ---------------------------------------------------------------------------

class _PeriodDatesSheet extends StatefulWidget {
  const _PeriodDatesSheet({
    required this.periodRepository,
    required this.today,
    required this.onDataChanged,
    this.existing,
    this.now,
  });

  final PeriodRepository periodRepository;
  final LocalDate today;
  final VoidCallback onDataChanged;
  final PeriodRecord? existing;
  final DateTime? now;

  @override
  State<_PeriodDatesSheet> createState() => _PeriodDatesSheetState();
}

class _PeriodDatesSheetState extends State<_PeriodDatesSheet> {
  LocalDate? _start;
  LocalDate? _end;
  bool _stillBleeding = false;
  bool _busy = false;
  String? _errorLine;

  @override
  void initState() {
    super.initState();
    _start = widget.existing?.startDate;
    _end = widget.existing?.endDate;
    _stillBleeding = widget.existing?.endDate == null;
  }

  Future<void> _pick({required bool start}) async {
    final now = widget.now ?? DateTime.now();
    final current = start ? _start : _end;
    final initial = current == null
        ? now
        : DateTime.fromMillisecondsSinceEpoch(
            0,
            isUtc: true,
          ).add(Duration(days: current.epochDay));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: start ? 'Period start' : 'Period end',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = LocalDate.fromDateTime(picked);
      } else {
        _end = LocalDate.fromDateTime(picked);
        _stillBleeding = false;
      }
      _errorLine = null;
    });
  }

  Future<void> _save() async {
    final start = _start;
    if (start == null || _busy) return;
    setState(() {
      _busy = true;
      _errorLine = null;
    });
    try {
      final draft = PeriodDraft(
        startDate: start,
        endDate: _stillBleeding ? null : _end,
      );
      final existing = widget.existing;
      if (existing == null) {
        await widget.periodRepository.create(draft, today: widget.today);
      } else {
        await widget.periodRepository.update(
          existing.id,
          draft,
          today: widget.today,
        );
      }
      await SavedRhythm.acknowledge(SavedRhythmKind.record);
      widget.onDataChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
    } on PeriodWriteException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorLine = error.userMessage;
      });
    }
  }

  Future<void> _deletePeriod() async {
    final existing = widget.existing;
    if (existing == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this period?'),
        content: const Text(
          'The period and its flow days will be removed from your record. '
          'This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ExperienceColors.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.periodRepository.delete(existing.id);
      widget.onDataChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
    } on PeriodWriteException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorLine = error.userMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        0,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              widget.existing == null ? 'Record a period' : 'Edit period dates',
              style: ExperienceType.headline(ExperienceColors.ink),
            ),
          ),
          const SizedBox(height: ExperienceSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _pick(start: true),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, ExperienceSpacing.degreeTarget),
                    side: const BorderSide(color: ExperienceColors.hairline),
                    shape: const RoundedRectangleBorder(
                      borderRadius: ExperienceRadius.chipRadius,
                    ),
                  ),
                  child: Text(
                    _start == null ? 'Start' : summaryDateLabel(_start!),
                    style: ExperienceType.label(ExperienceColors.ink),
                  ),
                ),
              ),
              const SizedBox(width: ExperienceSpacing.xs * 2),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy || _stillBleeding
                      ? null
                      : () => _pick(start: false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, ExperienceSpacing.degreeTarget),
                    side: const BorderSide(color: ExperienceColors.hairline),
                    shape: const RoundedRectangleBorder(
                      borderRadius: ExperienceRadius.chipRadius,
                    ),
                  ),
                  child: Text(
                    _stillBleeding
                        ? 'Still bleeding'
                        : _end == null
                        ? 'End'
                        : summaryDateLabel(_end!),
                    style: ExperienceType.label(ExperienceColors.ink),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ExperienceSpacing.xs * 2),
          Semantics(
            toggled: _stillBleeding,
            label: 'This period is still bleeding, no end date yet',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Still bleeding',
                style: ExperienceType.body(ExperienceColors.ink),
              ),
              value: _stillBleeding,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _stillBleeding = value),
            ),
          ),
          if (_errorLine != null) _InlineErrorLine(message: _errorLine!),
          const SizedBox(height: ExperienceSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: _start != null && !_busy ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: ExperienceColors.ember,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, ExperienceSpacing.degreeTarget),
                    shape: const RoundedRectangleBorder(
                      borderRadius: ExperienceRadius.chipRadius,
                    ),
                  ),
                  child: Text(
                    _busy ? 'Saving…' : 'Save',
                    style: ExperienceType.label(Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: ExperienceSpacing.xs * 2),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              if (widget.existing != null) ...<Widget>[
                const SizedBox(width: ExperienceSpacing.xs * 2),
                TextButton(
                  onPressed: _busy ? null : _deletePeriod,
                  child: const Text(
                    'Delete period',
                    style: TextStyle(color: ExperienceColors.error),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cycle detail — dates, flow days, letter, edit, fill-in, delete.
// Cycle reflections are validated at 280 characters per field and identified
// by startingPeriodId.
// ---------------------------------------------------------------------------

class _CycleDetailSheet extends StatefulWidget {
  const _CycleDetailSheet({
    required this.cycle,
    required this.flowDays,
    required this.periodRepository,
    required this.healthRecordRepository,
    required this.careMemoryRepository,
    required this.today,
    required this.onDataChanged,
    required this.onEditDates,
    required this.onFillDays,
    required this.onOpenDay,
    this.isCurrentCycle = false,
    this.currentCycleDay,
    this.bleedingState,
    this.now,
  });

  final _CompletedCycle cycle;
  final List<BleedingDayRecord> flowDays;
  final PeriodRepository periodRepository;
  final HealthRecordRepository healthRecordRepository;
  final CareMemoryRepository careMemoryRepository;
  final LocalDate today;
  final VoidCallback onDataChanged;
  final VoidCallback onEditDates;
  final VoidCallback onFillDays;
  final ValueChanged<LocalDate> onOpenDay;
  final bool isCurrentCycle;
  final int? currentCycleDay;
  final BleedingState? bleedingState;
  final DateTime? now;

  @override
  State<_CycleDetailSheet> createState() => _CycleDetailSheetState();
}

class _CycleDetailSheetState extends State<_CycleDetailSheet> {
  final TextEditingController _hardController = TextEditingController();
  final TextEditingController _helpedController = TextEditingController();
  final TextEditingController _futureController = TextEditingController();

  CycleReflection? _existingReflection;
  bool _reflectionLoaded = false;
  bool _savingReflection = false;
  String? _reflectionError;
  String? _reflectionAck;

  @override
  void initState() {
    super.initState();
    if (widget.isCurrentCycle) {
      _reflectionLoaded = true;
    } else {
      _loadReflection();
    }
  }

  @override
  void dispose() {
    _hardController.dispose();
    _helpedController.dispose();
    _futureController.dispose();
    super.dispose();
  }

  Future<void> _loadReflection() async {
    try {
      final reflection = await widget.careMemoryRepository.getCycleReflection(
        widget.cycle.period.startDate.epochDay,
        startingPeriodId: widget.cycle.period.id,
      );
      if (!mounted) return;
      setState(() {
        _existingReflection = reflection;
        _reflectionLoaded = true;
        if (reflection != null) {
          _hardController.text = reflection.observation ?? '';
          _helpedController.text = reflection.whatHelped ?? '';
          _futureController.text = reflection.futureSelfNote ?? '';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _reflectionLoaded = true);
    }
  }

  String? _normalized(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _saveReflection() async {
    if (_savingReflection) return;
    setState(() {
      _savingReflection = true;
      _reflectionError = null;
    });
    try {
      final draft = validateCycleReflection(
        CycleReflectionDraft(
          observation: _normalized(_hardController.text),
          whatHelped: _normalized(_helpedController.text),
          futureSelfNote: _normalized(_futureController.text),
        ),
      );
      final saved = await widget.careMemoryRepository.saveCycleReflection(
        widget.cycle.period.startDate.epochDay,
        draft,
        startingPeriodId: widget.cycle.period.id,
      );
      final line = await SavedRhythm.acknowledge(SavedRhythmKind.reflection);
      if (!mounted) return;
      setState(() {
        _savingReflection = false;
        _existingReflection = saved;
        _reflectionAck = line;
      });
      widget.onDataChanged();
    } on CareMemoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _savingReflection = false;
        _reflectionError = error.userMessage;
      });
    }
  }

  Future<void> _deleteReflection() async {
    final existing = _existingReflection;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this letter?'),
        content: const Text(
          'Your reflection for this cycle will be removed. '
          'This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ExperienceColors.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.careMemoryRepository.deleteCycleReflection(existing.id);
      if (!mounted) return;
      setState(() {
        _existingReflection = null;
        _hardController.clear();
        _helpedController.clear();
        _futureController.clear();
      });
      widget.onDataChanged();
    } on CareMemoryException catch (error) {
      if (!mounted) return;
      setState(() => _reflectionError = error.userMessage);
    }
  }

  Future<void> _deletePeriod() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this period?'),
        content: const Text(
          'The period and its flow days will be removed from your record. '
          'This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ExperienceColors.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.periodRepository.delete(widget.cycle.period.id);
      widget.onDataChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
    } on PeriodWriteException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = widget.cycle.period;
    final range = period.endDate == null
        ? summaryDateLabel(period.startDate)
        : '${summaryDateLabel(period.startDate)} – '
              '${summaryDateLabel(period.endDate!)}';

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          ExperienceSpacing.screenMargin,
          0,
          ExperienceSpacing.screenMargin,
          ExperienceSpacing.lg,
        ),
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              widget.isCurrentCycle
                  ? 'Current cycle'
                  : 'Cycle ${widget.cycle.cycleNumber}',
              style: ExperienceType.headline(ExperienceColors.ink),
            ),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            widget.isCurrentCycle
                ? '$range · day ${widget.currentCycleDay} of your current cycle'
                      '${period.durationDays != null ? ' · ${_periodDayCount(period.durationDays!)}' : ' · bleeding in progress'}'
                : '$range · ${widget.cycle.cycleLengthDays}-day cycle'
                      '${period.durationDays != null ? ' · ${_periodDayCount(period.durationDays!)}' : ''}',
            style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          Wrap(
            spacing: ExperienceSpacing.xs * 2,
            runSpacing: ExperienceSpacing.xs * 2,
            children: <Widget>[
              OutlinedButton(
                onPressed: widget.onEditDates,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ExperienceColors.ink,
                  side: const BorderSide(color: ExperienceColors.hairline),
                  minimumSize: const Size(0, ExperienceSpacing.minTouchTarget),
                  shape: const RoundedRectangleBorder(
                    borderRadius: ExperienceRadius.chipRadius,
                  ),
                ),
                child: const Text('Edit dates'),
              ),
              OutlinedButton(
                onPressed: widget.onFillDays,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ExperienceColors.ink,
                  side: const BorderSide(color: ExperienceColors.hairline),
                  minimumSize: const Size(0, ExperienceSpacing.minTouchTarget),
                  shape: const RoundedRectangleBorder(
                    borderRadius: ExperienceRadius.chipRadius,
                  ),
                ),
                child: const Text('Fill in days'),
              ),
              TextButton(
                onPressed: _deletePeriod,
                child: const Text(
                  'Delete period',
                  style: TextStyle(color: ExperienceColors.error),
                ),
              ),
            ],
          ),
          if (widget.flowDays.isNotEmpty) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.md),
            Text(
              'Flow days',
              style: ExperienceType.headline(ExperienceColors.ink),
            ),
            const SizedBox(height: ExperienceSpacing.xs * 2),
            for (final day in widget.flowDays)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: ExperienceSpacing.xs * 2,
                ),
                child: Semantics(
                  button: true,
                  label:
                      '${summaryDateLabel(day.date)}: ${day.flow.label}'
                      '${day.color != null ? ', ${day.color!.label}' : ''}. '
                      'Activate to edit this day.',
                  child: InkWell(
                    borderRadius: ExperienceRadius.chipRadius,
                    onTap: () => widget.onOpenDay(day.date),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: ExperienceSpacing.minTouchTarget,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: ExperienceSpacing.sm,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: ExperienceColors.surface,
                        borderRadius: ExperienceRadius.chipRadius,
                        border: Border.all(color: ExperienceColors.hairline),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              summaryDateLabel(day.date),
                              style: ExperienceType.body(ExperienceColors.ink),
                            ),
                          ),
                          DegreeGraphics.flow(day.flow, size: 20),
                          if (day.color != null) ...<Widget>[
                            const SizedBox(width: ExperienceSpacing.xs * 2),
                            DegreeGraphics.bleedingColor(
                              day.color!,
                              showWord: false,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
          if (!widget.isCurrentCycle) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.md),
            Text(
              'Letter to future you',
              style: ExperienceType.headline(ExperienceColors.ink),
            ),
            const SizedBox(height: ExperienceSpacing.xs),
            Text(
              'A short reflection for this cycle. Each answer stays within '
              '$careMemoryTextMaximumCharacters characters.',
              style: ExperienceType.caption(ExperienceColors.inkSoft),
            ),
            const SizedBox(height: ExperienceSpacing.sm),
            if (!_reflectionLoaded)
              const Padding(
                padding: EdgeInsets.all(ExperienceSpacing.md),
                child: Center(
                  child: EmberLoadingIndicator(
                    semanticLabel: 'Loading this cycle’s letter',
                  ),
                ),
              )
            else ...<Widget>[
              _ReflectionField(
                controller: _hardController,
                label: 'What was hard',
              ),
              const SizedBox(height: ExperienceSpacing.xs * 2),
              _ReflectionField(
                controller: _helpedController,
                label: 'What helped',
              ),
              const SizedBox(height: ExperienceSpacing.xs * 2),
              _ReflectionField(
                controller: _futureController,
                label: 'A note to future you',
              ),
              SavedRhythmAckLine(line: _reflectionAck),
              if (_reflectionError != null)
                _InlineErrorLine(message: _reflectionError!),
              const SizedBox(height: ExperienceSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      onPressed: _savingReflection ? null : _saveReflection,
                      style: FilledButton.styleFrom(
                        backgroundColor: ExperienceColors.ember,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(
                          0,
                          ExperienceSpacing.degreeTarget,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: ExperienceRadius.chipRadius,
                        ),
                      ),
                      child: Text(
                        _savingReflection ? 'Saving…' : 'Save letter',
                        style: ExperienceType.label(Colors.white),
                      ),
                    ),
                  ),
                  if (_existingReflection != null) ...<Widget>[
                    const SizedBox(width: ExperienceSpacing.xs * 2),
                    TextButton(
                      onPressed: _savingReflection ? null : _deleteReflection,
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: ExperienceColors.error),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
          const SizedBox(height: ExperienceSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}

String _dayCount(int count) => '$count ${count == 1 ? 'day' : 'days'}';

String _periodDayCount(int count) =>
    '$count period ${count == 1 ? 'day' : 'days'}';

class _ReflectionField extends StatelessWidget {
  const _ReflectionField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: '$label, at most $careMemoryTextMaximumCharacters characters',
      child: TextField(
        controller: controller,
        maxLength: careMemoryTextMaximumCharacters,
        maxLines: 3,
        minLines: 2,
        style: ExperienceType.body(ExperienceColors.ink),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: ExperienceType.bodySmall(ExperienceColors.inkSoft),
          counterStyle: ExperienceType.caption(ExperienceColors.inkFaint),
          filled: true,
          fillColor: ExperienceColors.surface,
          border: const OutlineInputBorder(
            borderRadius: ExperienceRadius.chipRadius,
            borderSide: BorderSide(color: ExperienceColors.hairline),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: ExperienceRadius.chipRadius,
            borderSide: BorderSide(color: ExperienceColors.hairline),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: ExperienceRadius.chipRadius,
            borderSide: BorderSide(color: ExperienceColors.ember, width: 1.5),
          ),
        ),
      ),
    );
  }
}
