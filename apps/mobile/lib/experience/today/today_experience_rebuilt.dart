import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/capture/domain/capture_models.dart';
import '../../features/check_in/domain/moment_check_in.dart';
import '../../features/check_in/domain/moment_check_in_repository.dart';
import '../../features/cycle/domain/bleeding_flow.dart';
import '../../features/cycle/domain/cycle_prediction.dart';
import '../../features/cycle/domain/local_date.dart';
import '../../features/cycle/domain/period_record.dart';
import '../../features/cycle/domain/period_repository.dart';
import '../../features/health_records/domain/health_record.dart';
import '../../features/health_records/domain/health_record_repository.dart';
import '../../features/health_records/domain/observation_catalog.dart';
import '../../features/patterns/domain/personal_pattern.dart';
import '../../features/preparation/domain/preparation_loop_state.dart';
import '../../features/today/today_cycle_ring_model.dart';
import '../care/care_safety_route.dart';
import '../degree/degree_graphics.dart';
import '../records/observation_picker.dart';
import '../theme/experience_foundation.dart';

/// The rebuilt Today destination: record what is happening today with the
/// least possible effort — no ring, no full daily form, no page-level Save.
///
/// Contracts honored here (design authority):
///  * The coral context hero is always visible — populated, partial-history,
///    and no-history alike — and renders only contract facts: the current
///    cycle day derived from the latest recorded period start, the phase
///    supplied by [TodayCycleRingModel] (with its observed/estimated
///    certainty), and the predicted menses **range** from
///    [CyclePredictionEngine]. No midpoint, countdown, approximate cycle
///    length, confidence value, or invented date is ever calculated or
///    displayed here.
///  * The primary mood is exactly one [MomentCheckIn] for the date; choosing
///    another replaces it (the newest check-in wins, earlier same-day
///    check-ins are deleted through the repository). A mood-only interaction
///    is a complete valid daily action. Difficult moods reveal a quiet Care
///    doorway; Care never opens automatically.
///  * Bleeding is one compact cluster: `None` plus the four illustrated
///    [BleedingFlow] degrees. `null` (no flow record) reads as
///    None/unanswered because the repository contract stores flow only
///    inside a containing period; deselecting the chosen degree records
///    absence via [PeriodRepository.clearFlow]. Color is conditional on a
///    saved flow and saves through [PeriodRepository.setBleedingColor] — one
///    write per choice, no faked second save. Spotting never starts or
///    extends a period. Period start/end are explicit, separate, compact
///    controls.
///  * Symptoms are usable every day, bleeding or not. The add flow is one
///    symptom at a time: choose symptom → choose one of the five named
///    [SymptomSeverity] degrees → immediate save → return to Today. There is
///    no "Not at all", no 0–10 pain score, and no pain-location field.
///    Selecting a safety-route symptom opens the existing safety route
///    immediately, keeps the in-progress selection, and never auto-saves.
///    Saved entries support edit and explicit remove. When
///    [TodayExperienceRebuilt.healthRecordRepository] is absent the section
///    says so honestly and offers no fake success.
///  * `A note to self` is a separate, low-priority route through
///    [CaptureNoteStore]; no note field lives inside the recording cards.
///  * Every mutation answers near its originating control with the Saved
///    Rhythm (visual change + light haptic + one quiet line); failures keep
///    the visible selection and offer Retry. Fallback copies are exactly
///    `Saved.` and `Letter Within couldn't save that. Try again.`
///  * Remembered-help copy renders only through [ExperienceMemoryGate] —
///    never fabricated counts or sample claims.
final class TodayExperienceRebuilt extends StatefulWidget {
  const TodayExperienceRebuilt({
    super.key,
    required this.periodRepository,
    required this.checkInRepository,
    required this.captureNoteStore,
    required this.today,
    required this.onOpenCare,
    required this.onOpenCycleDayEditor,
    required this.onOpenCycleBackfill,
    required this.onCycleDataChanged,
    this.now,
    this.healthRecordRepository,
    this.onOpenSafetyRoute,
    this.loadSupportActionPatterns,
    this.loadPreparationLoopKind,
  });

  final PeriodRepository periodRepository;
  final MomentCheckInRepository checkInRepository;
  final CaptureNoteStore captureNoteStore;

  /// Local "today" supplier (testable seam, matches the shell wiring).
  final LocalDate Function() today;

  /// Wall-clock seam for check-in timestamps.
  final DateTime Function()? now;

  /// Symptom persistence. When null, the symptoms section renders its honest
  /// unavailable state and nothing fakes a save.
  final HealthRecordRepository? healthRecordRepository;

  /// Opens the existing safety route (shell-provided). When null, the
  /// deterministic [CareSafetyRoute] sheet is used directly.
  final Future<void> Function()? onOpenSafetyRoute;

  /// Memory-evidence seams (shell-derived; never fabricated here).
  final Future<List<SupportActionPattern>> Function()?
  loadSupportActionPatterns;
  final Future<PreparationLoopKind?> Function()? loadPreparationLoopKind;

  /// Quiet Care doorway for difficult check-ins. Never invoked automatically.
  final VoidCallback onOpenCare;

  /// Preserved shell routes. Today no longer surfaces the full daily editor;
  /// these stay part of the public contract for the shell swap.
  final Future<void> Function()? onOpenCycleDayEditor;
  final VoidCallback onOpenCycleBackfill;

  /// Fired after every persisted mutation so the shell refreshes derived
  /// models (ring, charts) from the same facts.
  final VoidCallback onCycleDataChanged;

  @override
  State<TodayExperienceRebuilt> createState() => _TodayExperienceRebuiltState();
}

/// Per-section near-source feedback: saving indicator, quiet saved line, or
/// error + Retry. Errors are visual + textual, never haptic.
final class _SectionFeedback {
  bool saving = false;
  String? ack;
  String? error;
  Future<void> Function()? retry;

  void begin() {
    saving = true;
    error = null;
    retry = null;
  }

  void succeed(String? line) {
    saving = false;
    ack = line;
    error = null;
    retry = null;
  }

  void fail(String message, Future<void> Function() retryAction) {
    saving = false;
    error = message;
    retry = retryAction;
  }
}

class _TodayExperienceRebuiltState extends State<TodayExperienceRebuilt> {
  static const String _fallbackError =
      "Letter Within couldn't save that. Try again.";

  bool _loading = true;
  bool _loadFailed = false;
  int _loadSeq = 0;

  List<PeriodRecord> _periods = const <PeriodRecord>[];
  List<BleedingDayRecord> _flowDays = const <BleedingDayRecord>[];
  List<MomentCheckIn> _checkIns = const <MomentCheckIn>[];
  List<HealthRecord> _healthRecords = const <HealthRecord>[];
  List<SupportActionPattern> _supportActions = const <SupportActionPattern>[];
  PreparationLoopKind? _loopKind;

  /// Optimistic selections — the immediate visual change of the Saved
  /// Rhythm, and the preserved selection when a save fails.
  MomentCheckInState? _moodOverride;
  bool _flowOverrideSet = false;
  BleedingFlow? _flowOverride;
  bool _colorOverrideSet = false;
  BleedingColor? _colorOverride;

  final _SectionFeedback _moodFeedback = _SectionFeedback();
  final _SectionFeedback _flowFeedback = _SectionFeedback();
  final _SectionFeedback _colorFeedback = _SectionFeedback();
  final _SectionFeedback _periodFeedback = _SectionFeedback();
  final _SectionFeedback _symptomFeedback = _SectionFeedback();
  final _SectionFeedback _noteFeedback = _SectionFeedback();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  // --- Loading --------------------------------------------------------------

  Future<void> _reload({bool quiet = false}) async {
    final seq = ++_loadSeq;
    if (!quiet) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final healthRepository = widget.healthRecordRepository;
      final results = await Future.wait<Object>(<Future<Object>>[
        widget.periodRepository.getAll(),
        widget.periodRepository.getAllFlowDays(),
        widget.checkInRepository.getAll(),
        if (healthRepository != null)
          healthRepository.getAll()
        else
          Future<Object>.value(const <HealthRecord>[]),
      ]);
      // Memory evidence is subordinate; its failure must never block Today.
      List<SupportActionPattern> actions = const <SupportActionPattern>[];
      PreparationLoopKind? loopKind;
      try {
        actions =
            await widget.loadSupportActionPatterns?.call() ??
            const <SupportActionPattern>[];
      } on Object {
        actions = const <SupportActionPattern>[];
      }
      try {
        loopKind = await widget.loadPreparationLoopKind?.call();
      } on Object {
        loopKind = null;
      }
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _periods = results[0] as List<PeriodRecord>;
        _flowDays = results[1] as List<BleedingDayRecord>;
        _checkIns = results[2] as List<MomentCheckIn>;
        _healthRecords = results[3] as List<HealthRecord>;
        _supportActions = actions;
        _loopKind = loopKind;
        _loading = false;
        _loadFailed = false;
      });
    } on Object {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  // --- Derived facts --------------------------------------------------------

  List<PeriodRecord> get _orderedPeriods {
    final ordered = List<PeriodRecord>.of(_periods)
      ..sort((left, right) => right.startDate.compareTo(left.startDate));
    return ordered;
  }

  PeriodRecord? get _openPeriod =>
      _periods.where((period) => period.isOpen).firstOrNull;

  /// The period that contains today, open or closed — the only context in
  /// which the repository can store a flow record for the date.
  PeriodRecord? get _containingPeriod {
    final today = widget.today();
    for (final period in _periods) {
      final end = period.endDate;
      if (!today.isBefore(period.startDate) &&
          (end == null || !today.isAfter(end))) {
        return period;
      }
    }
    return null;
  }

  BleedingDayRecord? get _todayFlowRecord {
    final period = _containingPeriod;
    if (period == null) return null;
    final today = widget.today();
    return _flowDays
        .where((day) => day.periodId == period.id && day.date == today)
        .firstOrNull;
  }

  BleedingFlow? get _effectiveFlow =>
      _flowOverrideSet ? _flowOverride : _todayFlowRecord?.flow;

  BleedingColor? get _effectiveColor =>
      _colorOverrideSet ? _colorOverride : _todayFlowRecord?.color;

  MomentCheckInState? get _savedMood {
    final today = widget.today();
    // Repositories return newest first; the newest same-day check-in is the
    // primary mood.
    for (final checkIn in _checkIns) {
      if (LocalDate.fromDateTime(checkIn.occurredAt.toLocal()) == today) {
        return checkIn.state;
      }
    }
    return null;
  }

  MomentCheckInState? get _effectiveMood => _moodOverride ?? _savedMood;

  List<HealthRecord> get _todaySymptoms {
    final today = widget.today();
    return _healthRecords
        .where((record) => record.experiencedDate == today)
        .toList(growable: false);
  }

  // --- Mood -----------------------------------------------------------------

  Future<void> _saveMood(MomentCheckInState state) async {
    if (_moodFeedback.saving) return;
    ExperienceHaptics.pick();
    setState(() {
      _moodOverride = state;
      _moodFeedback.begin();
    });
    try {
      final created = await widget.checkInRepository.create(
        state,
        occurredAt: _now(),
      );
      // Replace semantics: exactly one primary mood for the date. The new
      // check-in is persisted first so a failure never loses the selection;
      // earlier same-day check-ins are then withdrawn.
      final today = widget.today();
      for (final entry in List<MomentCheckIn>.of(_checkIns)) {
        if (entry.id == created.id) continue;
        if (LocalDate.fromDateTime(entry.occurredAt.toLocal()) == today) {
          try {
            await widget.checkInRepository.delete(entry.id);
          } on Object {
            // A stale earlier check-in is harmless: the newest one wins.
          }
        }
      }
      final line = await SavedRhythm.acknowledge(SavedRhythmKind.checkIn);
      await _reload(quiet: true);
      if (!mounted) return;
      setState(() {
        _moodOverride = null;
        _moodFeedback.succeed(line);
      });
      widget.onCycleDataChanged();
    } on MomentCheckInException catch (error) {
      if (!mounted) return;
      setState(
        () => _moodFeedback.fail(error.userMessage, () => _saveMood(state)),
      );
    } on Object {
      if (!mounted) return;
      setState(
        () => _moodFeedback.fail(_fallbackError, () => _saveMood(state)),
      );
    }
  }

  Future<void> _openMoodSheet() async {
    ExperienceHaptics.pick();
    final selected = await showExperienceSheet<MomentCheckInState>(
      context,
      child: _MoodMoreSheet(current: _effectiveMood),
    );
    if (selected != null && mounted) {
      await _saveMood(selected);
    }
  }

  // --- Bleeding -------------------------------------------------------------

  Future<void> _selectFlow(BleedingFlow? flow) async {
    final period = _containingPeriod;
    if (period == null || _flowFeedback.saving) return;
    final today = widget.today();
    final current = _todayFlowRecord?.flow;
    if (flow == null && current == null) return;
    ExperienceHaptics.pick();
    setState(() {
      _flowOverride = flow;
      _flowOverrideSet = true;
      _colorOverrideSet = false;
      _flowFeedback.begin();
    });
    try {
      if (flow == null || flow == current) {
        // None, or tapping the chosen degree again: absence. The repository
        // removes the flow record (and its color) in one write.
        await widget.periodRepository.clearFlow(period.id, today);
      } else {
        await widget.periodRepository.setFlow(
          period.id,
          today,
          flow,
          today: today,
        );
      }
      final line = await SavedRhythm.acknowledge(SavedRhythmKind.record);
      await _reload(quiet: true);
      if (!mounted) return;
      setState(() {
        _flowOverrideSet = false;
        _flowFeedback.succeed(line);
      });
      widget.onCycleDataChanged();
    } on PeriodWriteException catch (error) {
      if (!mounted) return;
      setState(
        () => _flowFeedback.fail(error.userMessage, () => _selectFlow(flow)),
      );
    } on Object {
      if (!mounted) return;
      setState(
        () => _flowFeedback.fail(_fallbackError, () => _selectFlow(flow)),
      );
    }
  }

  Future<void> _selectColor(BleedingColor color) async {
    final period = _containingPeriod;
    final record = _todayFlowRecord;
    if (period == null || record == null || _colorFeedback.saving) return;
    ExperienceHaptics.pick();
    setState(() {
      _colorOverride = color;
      _colorOverrideSet = true;
      _colorFeedback.begin();
    });
    try {
      if (record.color == color) {
        await widget.periodRepository.clearBleedingColor(
          period.id,
          record.date,
        );
      } else {
        await widget.periodRepository.setBleedingColor(
          period.id,
          record.date,
          color,
        );
      }
      final line = await SavedRhythm.acknowledge(SavedRhythmKind.record);
      await _reload(quiet: true);
      if (!mounted) return;
      setState(() {
        _colorOverrideSet = false;
        _colorFeedback.succeed(line);
      });
      widget.onCycleDataChanged();
    } on PeriodWriteException catch (error) {
      if (!mounted) return;
      setState(
        () => _colorFeedback.fail(error.userMessage, () => _selectColor(color)),
      );
    } on Object {
      if (!mounted) return;
      setState(
        () => _colorFeedback.fail(_fallbackError, () => _selectColor(color)),
      );
    }
  }

  // --- Period start / end ---------------------------------------------------

  Future<void> _startPeriod() async {
    if (_periodFeedback.saving) return;
    ExperienceHaptics.pick();
    setState(_periodFeedback.begin);
    try {
      await widget.periodRepository.create(
        PeriodDraft(startDate: widget.today()),
        today: widget.today(),
      );
      final line = await SavedRhythm.acknowledge(SavedRhythmKind.record);
      await _reload(quiet: true);
      if (!mounted) return;
      setState(() => _periodFeedback.succeed(line));
      widget.onCycleDataChanged();
    } on PeriodWriteException catch (error) {
      if (!mounted) return;
      setState(() => _periodFeedback.fail(error.userMessage, _startPeriod));
    } on Object {
      if (!mounted) return;
      setState(() => _periodFeedback.fail(_fallbackError, _startPeriod));
    }
  }

  Future<void> _endPeriodToday() async {
    final open = _openPeriod;
    if (open == null || _periodFeedback.saving) return;
    ExperienceHaptics.pick();
    setState(_periodFeedback.begin);
    try {
      await widget.periodRepository.update(
        open.id,
        PeriodDraft(startDate: open.startDate, endDate: widget.today()),
        today: widget.today(),
      );
      final line = await SavedRhythm.acknowledge(SavedRhythmKind.record);
      await _reload(quiet: true);
      if (!mounted) return;
      setState(() => _periodFeedback.succeed(line));
      widget.onCycleDataChanged();
    } on PeriodWriteException catch (error) {
      if (!mounted) return;
      setState(() => _periodFeedback.fail(error.userMessage, _endPeriodToday));
    } on Object {
      if (!mounted) return;
      setState(() => _periodFeedback.fail(_fallbackError, _endPeriodToday));
    }
  }

  // --- Symptoms -------------------------------------------------------------

  Future<void> _writeSymptom(
    SymptomType symptom,
    SymptomSeverity severity,
  ) async {
    final repository = widget.healthRecordRepository;
    if (repository == null) return;
    final existing = _todaySymptoms
        .where((record) => record.symptom == symptom)
        .firstOrNull;
    final draft = validateHealthRecordDraft(
      HealthRecordDraft(
        symptom: symptom,
        severity: severity,
        experiencedDate: widget.today(),
        provenance: HealthRecordProvenance.sameDay,
      ),
    );
    if (existing != null) {
      await repository.update(existing.id, draft);
    } else {
      await repository.create(draft);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    final line = await SavedRhythm.acknowledge(SavedRhythmKind.record);
    await _reload(quiet: true);
    if (!mounted) return;
    setState(() => _symptomFeedback.succeed(line));
    widget.onCycleDataChanged();
  }

  Future<void> _removeSymptom(HealthRecord record) async {
    final repository = widget.healthRecordRepository;
    if (repository == null) return;
    await repository.delete(record.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    await _reload(quiet: true);
    if (!mounted) return;
    setState(() => _symptomFeedback.succeed("Removed from today's record."));
    widget.onCycleDataChanged();
  }

  Future<void> _openSafetyRoute() {
    final callback = widget.onOpenSafetyRoute;
    if (callback != null) return callback();
    return CareSafetyRoute.show(context, careWorld: false);
  }

  Future<void> _openSymptomSheet({SymptomType? editSymptom}) async {
    if (widget.healthRecordRepository == null) return;
    ExperienceHaptics.pick();
    await showExperienceSheet<void>(
      context,
      child: _SymptomEntrySheet(
        todayRecords: _todaySymptoms,
        editSymptom: editSymptom,
        onSave: _writeSymptom,
        onRemove: _removeSymptom,
        onOpenSafetyRoute: _openSafetyRoute,
      ),
    );
  }

  // --- Note to self ---------------------------------------------------------

  Future<void> _saveNote(String text) async {
    final now = _now().toUtc();
    final random = math.Random.secure();
    final suffix = List.generate(
      8,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    final note = CaptureNote(
      id: '${now.microsecondsSinceEpoch.toRadixString(16)}-$suffix',
      text: text,
      source: CaptureSource.typed,
      createdAt: now,
    );
    await widget.captureNoteStore.save(note);
    if (!mounted) return;
    Navigator.of(context).pop();
    final line = await SavedRhythm.acknowledge(SavedRhythmKind.reflection);
    if (!mounted) return;
    setState(() => _noteFeedback.succeed(line ?? 'Saved.'));
  }

  Future<void> _openNoteSheet() async {
    ExperienceHaptics.pick();
    await showExperienceSheet<void>(
      context,
      child: _NoteSheet(onSave: _saveNote),
    );
  }

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: EmberLoadingIndicator(semanticLabel: 'Loading today'),
      );
    }
    if (_loadFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ExperienceSpacing.screenMargin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                "Letter Within couldn't load today.",
                style: ExperienceType.headline(ExperienceColors.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ExperienceSpacing.sm),
              FilledButton(
                onPressed: _reload,
                style: FilledButton.styleFrom(
                  backgroundColor: ExperienceColors.ember,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final today = widget.today();
    final dateTime = today.asLocalDateTime;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.sm,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.scrollBottomPadding,
      ),
      children: <Widget>[
        Text('Today', style: ExperienceType.display(ExperienceColors.ink)),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          '${_weekdayNames[dateTime.weekday - 1]}, '
          '${_monthNames[today.month - 1]} ${today.day}',
          style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
        ),
        const SizedBox(height: ExperienceSpacing.md),
        _buildHero(),
        const SizedBox(height: ExperienceSpacing.md),
        _buildMoodCard(),
        const SizedBox(height: ExperienceSpacing.md),
        _buildBleedingCard(),
        const SizedBox(height: ExperienceSpacing.md),
        _buildSymptomsCard(),
        const SizedBox(height: ExperienceSpacing.md),
        _buildNoteRoute(),
        _buildMemoryLine(),
      ],
    );
  }

  // --- Hero -----------------------------------------------------------------

  Widget _buildHero() {
    final today = widget.today();
    final ordered = _orderedPeriods;
    final open = _openPeriod;

    // Contract facts only.
    final prediction = ordered.isEmpty
        ? null
        : CyclePredictionEngine.calculate(ordered);
    TodayCycleRingModel? ringModel;
    try {
      ringModel = TodayCycleRingModel.fromRecords(
        records: ordered,
        today: today,
      );
    } on TodayCycleRingException {
      ringModel = null;
    }

    final Widget content;
    final String semantics;

    if (ordered.isEmpty) {
      semantics =
          'No periods recorded yet. Your cycle story starts with one '
          'recorded period.';
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'WHERE YOU ARE',
            style: ExperienceType.eyebrow(Colors.white.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: ExperienceSpacing.xs * 2),
          Text(
            'Your cycle story starts with one recorded period.',
            style: ExperienceType.headline(Colors.white),
          ),
          const SizedBox(height: ExperienceSpacing.xs * 2),
          Text(
            'Recording a period start begins the cycle picture — nothing '
            'else is needed today.',
            style: ExperienceType.bodySmall(
              Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          Wrap(
            spacing: ExperienceSpacing.xs * 2,
            runSpacing: ExperienceSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              FilledButton(
                onPressed: _periodFeedback.saving ? null : _startPeriod,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: ExperienceColors.emberDeep,
                  minimumSize: const Size(0, ExperienceSpacing.minTouchTarget),
                  shape: const RoundedRectangleBorder(
                    borderRadius: ExperienceRadius.chipRadius,
                  ),
                ),
                child: const Text('Period started today'),
              ),
              TextButton(
                onPressed: widget.onOpenCycleBackfill,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Add an earlier period'),
              ),
            ],
          ),
          _HeroFeedback(feedback: _periodFeedback),
        ],
      );
    } else if (open != null) {
      final day = today.epochDay - open.startDate.epochDay + 1;
      semantics = 'Period, day $day. Observed from your recorded start.';
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'PERIOD · OBSERVED',
            style: ExperienceType.eyebrow(Colors.white.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: ExperienceSpacing.xs * 2),
          _HeroDayLine(day: day),
          const SizedBox(height: ExperienceSpacing.xs * 2),
          Text(
            'Bleeding, symptoms, and mood can all be recorded below.',
            style: ExperienceType.bodySmall(
              Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      );
    } else if (ringModel != null) {
      final phase = ringModel.currentPhase;
      final segment = phase == null ? null : ringModel.segmentFor(phase);
      final estimated = segment?.certainty == CycleRingCertainty.estimated;
      final eyebrow = phase == null
          ? 'CYCLE CONTEXT'
          : '${phase.label.toUpperCase()} PHASE · '
                '${estimated ? 'ESTIMATED' : 'OBSERVED'}';
      final buffer = StringBuffer('Day ${ringModel.currentDay} of your cycle');
      if (phase != null) {
        buffer.write(
          ', ${phase.label} phase, ${estimated ? 'estimated' : 'observed'}',
        );
      }
      buffer.write('.');
      final windowLine = _predictionWindowLine(prediction, today);
      if (windowLine != null) buffer.write(' $windowLine');
      semantics = buffer.toString();
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            eyebrow,
            style: ExperienceType.eyebrow(Colors.white.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: ExperienceSpacing.xs * 2),
          _HeroDayLine(day: ringModel.currentDay),
          if (windowLine != null) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.xs * 2),
            Text(
              windowLine,
              style: ExperienceType.bodySmall(
                Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
          if (ringModel.hasLimitedEstimate) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.xs),
            Text(
              'Rough estimate — based on limited history.',
              style: ExperienceType.caption(
                Colors.white.withValues(alpha: 0.75),
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ],
      );
    } else {
      // Partial history: factual day plus an honest forming line. The
      // remaining-starts count comes from the prediction contract, never
      // hard-coded.
      final latest = ordered.first;
      final day = today.isBefore(latest.startDate)
          ? null
          : today.epochDay - latest.startDate.epochDay + 1;
      final remaining =
          (CyclePredictionEngine.minimumIntervals -
                  CyclePredictionEngine.observedIntervalCount(ordered))
              .clamp(0, 9);
      final formingLine = remaining >= 1
          ? remaining == 1
                ? 'One more recorded period start begins the estimate.'
                : '$remaining more recorded period starts begin the estimate.'
          : 'Cycle pattern still forming from your recorded dates.';
      semantics = day == null
          ? formingLine
          : 'Day $day of your cycle. $formingLine';
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'CYCLE CONTEXT',
            style: ExperienceType.eyebrow(Colors.white.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: ExperienceSpacing.xs * 2),
          if (day != null) _HeroDayLine(day: day),
          const SizedBox(height: ExperienceSpacing.xs * 2),
          Text(
            formingLine,
            style: ExperienceType.bodySmall(
              Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      );
    }

    return Semantics(
      container: true,
      label: semantics,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: ExperienceColors.heroGradient,
            borderRadius: ExperienceRadius.heroRadius,
            boxShadow: ExperienceShadows.hero,
          ),
          padding: const EdgeInsets.all(ExperienceSpacing.md),
          child: content,
        ),
      ),
    );
  }

  /// The predicted menses **range** as the contract supplies it. No
  /// midpoint, countdown, or single "next period" date is ever shown.
  String? _predictionWindowLine(CyclePrediction? prediction, LocalDate today) {
    if (prediction == null) return null;
    return switch (prediction.timingFor(today)) {
      PredictionTiming.upcoming || PredictionTiming.currentWindow =>
        'Predicted period window: '
            '${_shortRange(prediction.predictedMensesStart, prediction.predictedMensesEnd)}.',
      PredictionTiming.laterThanEstimate =>
        'Later than the predicted window — recording a period start '
            'sharpens the next estimate.',
    };
  }

  // --- Mood card ------------------------------------------------------------

  Widget _buildMoodCard() {
    final quickPicks = ObservationCatalog.momentStates
        .where((definition) => definition.defaultPick)
        .toList(growable: false);
    final selected = _effectiveMood;
    final selectedDefinition = selected == null
        ? null
        : ObservationCatalog.momentStates
              .where((definition) => definition.state == selected)
              .firstOrNull;
    final showCareDoorway = selectedDefinition?.suggestsCare ?? false;

    return _TodayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'How are you, right now?',
            style: ExperienceType.headline(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'One word is a complete check-in. Choosing another replaces it.',
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          Wrap(
            spacing: ExperienceSpacing.xs * 2,
            runSpacing: ExperienceSpacing.xs * 2,
            children: <Widget>[
              for (final definition in quickPicks)
                _MoodChip(
                  definition: definition,
                  selected: selected == definition.state,
                  enabled: !_moodFeedback.saving,
                  onTap: () => _saveMood(definition.state),
                ),
              _MoreChip(
                label: 'More',
                onTap: _moodFeedback.saving ? null : _openMoodSheet,
              ),
            ],
          ),
          _SectionFeedbackLine(feedback: _moodFeedback),
          if (showCareDoorway) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.xs * 2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceSpacing.sm,
                vertical: ExperienceSpacing.xs * 2,
              ),
              decoration: BoxDecoration(
                color: ExperienceColors.surfaceWarm,
                borderRadius: ExperienceRadius.chipRadius,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Hard moments are welcome here. Care can hold a few '
                      'minutes with you.',
                      style: ExperienceType.caption(ExperienceColors.inkSoft),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onOpenCare,
                    child: const Text('Open Care'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Bleeding card --------------------------------------------------------

  Widget _buildBleedingCard() {
    final containing = _containingPeriod;
    final open = _openPeriod;
    final flow = _effectiveFlow;
    final color = _effectiveColor;
    final record = _todayFlowRecord;
    final flowEnabled = containing != null && !_flowFeedback.saving;

    return _TodayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Bleeding',
            style: ExperienceType.headline(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            containing == null
                ? 'Flow is recorded inside a period. Starting one takes one tap.'
                : 'Choose the closest flow. Choosing it again clears it.',
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          Wrap(
            spacing: ExperienceSpacing.xs * 2,
            runSpacing: ExperienceSpacing.xs * 2,
            children: <Widget>[
              _FlowOptionChip(
                label: 'None',
                selected: flow == null,
                // None is the resting state; it acts only when a saved flow
                // exists to clear.
                enabled: record != null && !_flowFeedback.saving,
                semanticsLabel:
                    'Bleeding flow: None${flow == null ? ', selected' : ''}',
                onTap: () => _selectFlow(null),
              ),
              for (final degree in DegreeGraphics.flowDegrees)
                _FlowOptionChip(
                  selected: flow == degree,
                  enabled: flowEnabled,
                  semanticsLabel: DegreeGraphics.flowSemanticsLabel(degree),
                  onTap: () => _selectFlow(degree),
                  child: DegreeGraphics.flow(
                    degree,
                    size: 20,
                    selected: flow == degree,
                  ),
                ),
            ],
          ),
          if (flow == BleedingFlow.spotting) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.xs * 2),
            Text(
              DegreeGraphics.spottingHonestyNote,
              style: ExperienceType.caption(ExperienceColors.inkFaint),
            ),
          ],
          _SectionFeedbackLine(feedback: _flowFeedback),
          if (record != null && flow != null) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.sm),
            Text(
              'Color, if you noticed',
              style: ExperienceType.bodyStrong(ExperienceColors.ink),
            ),
            const SizedBox(height: ExperienceSpacing.xs * 2),
            Wrap(
              spacing: ExperienceSpacing.xs * 2,
              runSpacing: ExperienceSpacing.xs * 2,
              children: <Widget>[
                for (final option in BleedingColor.values)
                  _FlowOptionChip(
                    selected: color == option,
                    enabled: !_colorFeedback.saving,
                    semanticsLabel: DegreeGraphics.bleedingColorSemanticsLabel(
                      option,
                    ),
                    onTap: () => _selectColor(option),
                    child: DegreeGraphics.bleedingColor(
                      option,
                      size: 20,
                      selected: color == option,
                    ),
                  ),
              ],
            ),
            _SectionFeedbackLine(feedback: _colorFeedback),
          ],
          const SizedBox(height: ExperienceSpacing.sm),
          Wrap(
            spacing: ExperienceSpacing.xs * 2,
            runSpacing: ExperienceSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (open != null)
                OutlinedButton(
                  onPressed: _periodFeedback.saving ? null : _endPeriodToday,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ExperienceColors.ink,
                    side: const BorderSide(color: ExperienceColors.hairline),
                    minimumSize: const Size(
                      0,
                      ExperienceSpacing.minTouchTarget,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: ExperienceRadius.chipRadius,
                    ),
                  ),
                  child: const Text('End period today'),
                )
              else
                OutlinedButton(
                  onPressed: _periodFeedback.saving ? null : _startPeriod,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ExperienceColors.ink,
                    side: const BorderSide(color: ExperienceColors.hairline),
                    minimumSize: const Size(
                      0,
                      ExperienceSpacing.minTouchTarget,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: ExperienceRadius.chipRadius,
                    ),
                  ),
                  child: const Text('Period started today'),
                ),
            ],
          ),
          // Period feedback renders near the hero button in the empty state;
          // everywhere else it lives here, next to the period controls.
          if (_periods.isNotEmpty)
            _SectionFeedbackLine(feedback: _periodFeedback),
        ],
      ),
    );
  }

  // --- Symptoms card --------------------------------------------------------

  Widget _buildSymptomsCard() {
    final available = widget.healthRecordRepository != null;
    final records = _todaySymptoms;
    return _TodayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Symptoms today',
            style: ExperienceType.headline(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            available
                ? 'Any day, bleeding or not. Tap one to edit or remove it.'
                : 'Symptom storage is unavailable in this build.',
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
          if (available) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.sm),
            Wrap(
              spacing: ExperienceSpacing.xs * 2,
              runSpacing: ExperienceSpacing.xs * 2,
              children: <Widget>[
                for (final record in records)
                  _SavedSymptomChip(
                    record: record,
                    onTap: () => _openSymptomSheet(editSymptom: record.symptom),
                  ),
                _MoreChip(
                  label: 'Add a symptom',
                  icon: Icons.add,
                  onTap: () => _openSymptomSheet(),
                ),
              ],
            ),
            _SectionFeedbackLine(feedback: _symptomFeedback),
          ],
        ],
      ),
    );
  }

  // --- Note route + memory line ---------------------------------------------

  Widget _buildNoteRoute() {
    return _TodayCard(
      padding: const EdgeInsets.symmetric(
        horizontal: ExperienceSpacing.md,
        vertical: ExperienceSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'A note to self',
                      style: ExperienceType.bodyStrong(ExperienceColors.ink),
                    ),
                    Text(
                      "Private, and separate from today's record.",
                      style: ExperienceType.caption(ExperienceColors.inkFaint),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _openNoteSheet,
                child: const Text('Write a note'),
              ),
            ],
          ),
          _SectionFeedbackLine(feedback: _noteFeedback),
        ],
      ),
    );
  }

  Widget _buildMemoryLine() {
    final verdict = ExperienceMemoryGate.gate(
      loopKind: _loopKind,
      evidence: _supportActions,
    );
    final String? line = switch (verdict) {
      MemoryEvidenceVerdict.remembered => ExperienceMemoryGate.rememberedLine(
        _supportActions,
      ),
      MemoryEvidenceVerdict.accumulating =>
        ExperienceMemoryGate.accumulatingLine(_supportActions),
      _ => null,
    };
    if (line == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(
        top: ExperienceSpacing.md,
        left: ExperienceSpacing.xs,
        right: ExperienceSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: SizedBox(
              width: 8,
              height: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: ExperienceColors.emberGradient,
                ),
              ),
            ),
          ),
          const SizedBox(width: ExperienceSpacing.xs * 2),
          Expanded(
            child: Text(
              line,
              style: ExperienceType.caption(ExperienceColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date formatting helpers (display only; never prediction input).
// ---------------------------------------------------------------------------

const List<String> _weekdayNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _monthShort = <String>[
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

String _shortDate(LocalDate date) =>
    '${_monthShort[date.month - 1]} ${date.day}';

String _shortRange(LocalDate start, LocalDate end) {
  if (start == end) return _shortDate(start);
  if (start.month == end.month && start.year == end.year) {
    return '${_monthShort[start.month - 1]} ${start.day} – ${end.day}';
  }
  return '${_shortDate(start)} – ${_shortDate(end)}';
}

// ---------------------------------------------------------------------------
// Shared small widgets.
// ---------------------------------------------------------------------------

/// The compact soft card shell used by every Today section.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ExperienceColors.surface,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(color: ExperienceColors.hairline),
        boxShadow: ExperienceShadows.card,
      ),
      padding: padding ?? const EdgeInsets.all(ExperienceSpacing.md),
      child: child,
    );
  }
}

/// The hero "Day N" line: numerals are always sans tabular figures, never
/// inside the serif headline.
class _HeroDayLine extends StatelessWidget {
  const _HeroDayLine({required this.day});

  final int day;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Day',
          style: ExperienceType.headline(Colors.white.withValues(alpha: 0.85)),
        ),
        const SizedBox(width: ExperienceSpacing.xs * 2),
        Text(
          '$day',
          style: ExperienceType.data(
            Colors.white,
            size: 34,
            weight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Near-source feedback: a saving indicator, a quiet saved line, or an error
/// with Retry. Errors are visual + textual, never haptic.
class _SectionFeedbackLine extends StatelessWidget {
  const _SectionFeedbackLine({required this.feedback});

  final _SectionFeedback feedback;

  @override
  Widget build(BuildContext context) {
    if (feedback.saving) {
      return const Padding(
        padding: EdgeInsets.only(top: ExperienceSpacing.xs * 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ExperienceColors.ember,
              ),
            ),
            SizedBox(width: ExperienceSpacing.xs * 2),
          ],
        ),
      );
    }
    final error = feedback.error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: ExperienceSpacing.xs * 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: ExperienceType.caption(ExperienceColors.error),
                ),
              ),
            ),
            if (feedback.retry != null)
              TextButton(onPressed: feedback.retry, child: const Text('Retry')),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: ExperienceSpacing.xs),
      child: SavedRhythmAckLine(line: feedback.ack, textAlign: TextAlign.left),
    );
  }
}

/// The hero variant of the feedback line, readable on the coral gradient.
class _HeroFeedback extends StatelessWidget {
  const _HeroFeedback({required this.feedback});

  final _SectionFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final error = feedback.error;
    final ack = feedback.ack;
    if (feedback.saving) {
      return const Padding(
        padding: EdgeInsets.only(top: ExperienceSpacing.xs),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }
    if (error == null && ack == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: ExperienceSpacing.xs * 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                error ?? ack!,
                style: ExperienceType.caption(Colors.white),
              ),
            ),
          ),
          if (error != null && feedback.retry != null)
            TextButton(
              onPressed: feedback.retry,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

/// One compact mood choice. Selecting saves immediately; exactly one primary
/// mood exists for the date.
class _MoodChip extends StatelessWidget {
  const _MoodChip({
    required this.definition,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final MomentStateDefinition definition;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label:
          'Mood: ${definition.label}'
          '${selected ? ', selected' : ', not selected'}',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: ExperienceRadius.chipRadius,
        child: AnimatedContainer(
          duration: ExperienceMotion.chipSelect,
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (selected) ...<Widget>[
                const Icon(
                  Icons.check,
                  size: 16,
                  color: ExperienceColors.ember,
                ),
                const SizedBox(width: ExperienceSpacing.xs),
              ],
              Text(
                definition.label,
                style: selected
                    ? ExperienceType.label(ExperienceColors.ink)
                    : ExperienceType.bodySmall(ExperienceColors.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small outline action chip ("More", "Add a symptom").
class _MoreChip extends StatelessWidget {
  const _MoreChip({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: ExperienceRadius.chipRadius,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(color: ExperienceColors.inkFaint),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 16, color: ExperienceColors.inkSoft),
                const SizedBox(width: ExperienceSpacing.xs),
              ],
              Text(
                label,
                style: ExperienceType.label(ExperienceColors.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One flow, color, or degree choice inside a compact cluster — words plus
/// the shared illustrated glyph, never a full-width row.
class _FlowOptionChip extends StatelessWidget {
  const _FlowOptionChip({
    required this.selected,
    required this.enabled,
    required this.semanticsLabel,
    required this.onTap,
    this.label,
    this.child,
  });

  final bool selected;
  final bool enabled;
  final String semanticsLabel;
  final VoidCallback onTap;
  final String? label;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: semanticsLabel,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: ExperienceRadius.chipRadius,
        child: AnimatedContainer(
          duration: ExperienceMotion.chipSelect,
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.minTouchTarget,
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
          child: Opacity(
            opacity: enabled ? 1 : 0.55,
            child:
                child ??
                Text(
                  label!,
                  style: selected
                      ? ExperienceType.label(ExperienceColors.ink)
                      : ExperienceType.bodySmall(ExperienceColors.inkSoft),
                ),
          ),
        ),
      ),
    );
  }
}

/// A saved symptom as a concise editable chip: name plus its named degree.
class _SavedSymptomChip extends StatelessWidget {
  const _SavedSymptomChip({required this.record, required this.onTap});

  final HealthRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final definition = ObservationCatalog.definitionFor(record.symptom);
    return Semantics(
      button: true,
      label:
          'Recorded symptom: ${definition.label}, ${record.severity.label}. '
          'Activate to edit.',
      child: InkWell(
        onTap: onTap,
        borderRadius: ExperienceRadius.chipRadius,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: ExperienceColors.surfaceWarm,
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(color: ExperienceColors.ember, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.check, size: 16, color: ExperienceColors.ember),
              const SizedBox(width: ExperienceSpacing.xs),
              Text(
                '${definition.label} · ${record.severity.label}',
                style: ExperienceType.label(ExperienceColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mood "More" sheet — the remaining catalog, one tap saves immediately.
// ---------------------------------------------------------------------------

class _MoodMoreSheet extends StatelessWidget {
  const _MoodMoreSheet({required this.current});

  final MomentCheckInState? current;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Every word for right now',
            style: ExperienceType.headline(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            "Choosing one saves it as today's primary mood.",
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          Wrap(
            spacing: ExperienceSpacing.xs * 2,
            runSpacing: ExperienceSpacing.xs * 2,
            children: <Widget>[
              for (final definition in ObservationCatalog.momentStates)
                _MoodChip(
                  definition: definition,
                  selected: current == definition.state,
                  enabled: true,
                  onTap: () => Navigator.of(context).pop(definition.state),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Symptom entry sheet — choose one symptom → choose its degree → immediate
// save → return to Today. Safety-route symptoms open the safety surface
// immediately, keep the in-progress selection, and never auto-save.
// ---------------------------------------------------------------------------

class _SymptomEntrySheet extends StatefulWidget {
  const _SymptomEntrySheet({
    required this.todayRecords,
    required this.onSave,
    required this.onRemove,
    required this.onOpenSafetyRoute,
    this.editSymptom,
  });

  final List<HealthRecord> todayRecords;
  final SymptomType? editSymptom;
  final Future<void> Function(SymptomType symptom, SymptomSeverity severity)
  onSave;
  final Future<void> Function(HealthRecord record) onRemove;
  final Future<void> Function() onOpenSafetyRoute;

  @override
  State<_SymptomEntrySheet> createState() => _SymptomEntrySheetState();
}

class _SymptomEntrySheetState extends State<_SymptomEntrySheet> {
  final TextEditingController _searchController = TextEditingController();

  ObservationDefinition? _selected;
  SymptomSeverity? _severity;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final edit = widget.editSymptom;
    if (edit != null) {
      _selected = ObservationCatalog.definitionFor(edit);
      _severity = _recordFor(edit)?.severity;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  HealthRecord? _recordFor(SymptomType symptom) {
    for (final record in widget.todayRecords) {
      if (record.symptom == symptom) return record;
    }
    return null;
  }

  bool _available(ObservationDefinition definition) =>
      definition.symptom.availableForNewRecords;

  List<ObservationDefinition> get _quickPicks => ObservationCatalog.symptoms
      .where(
        (definition) =>
            _available(definition) &&
            definition.quickPickPriority ==
                ObservationQuickPickPriority.defaultPick,
      )
      .toList(growable: false);

  List<ObservationDefinition> _browseFor(ObservationCategory category) =>
      ObservationCatalog.symptoms
          .where(
            (definition) =>
                _available(definition) &&
                definition.category == category &&
                definition.quickPickPriority !=
                    ObservationQuickPickPriority.searchOnly,
          )
          .toList(growable: false);

  List<ObservationDefinition> get _searchResults => ObservationCatalog.search(
    _searchController.text,
  ).where(_available).toList(growable: false);

  bool get _searching => _searchController.text.trim().isNotEmpty;

  bool get _isMedical =>
      _selected?.safetyRoute == ObservationSafetyRoute.medicalAttention;

  void _choose(ObservationDefinition definition) {
    if (_saving) return;
    ExperienceHaptics.pick();
    setState(() {
      _selected = definition;
      _severity = _recordFor(definition.symptom)?.severity;
      _error = null;
    });
    // Safety-route symptoms open the existing safety route immediately; the
    // selection above is preserved behind it and nothing is auto-saved.
    if (definition.safetyRoute == ObservationSafetyRoute.medicalAttention) {
      widget.onOpenSafetyRoute();
    }
  }

  Future<void> _save(SymptomSeverity severity) async {
    final selected = _selected;
    if (selected == null || _saving) return;
    setState(() {
      _severity = severity;
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(selected.symptom, severity);
      // The parent pops the sheet on success.
      if (!mounted) return;
      setState(() => _saving = false);
    } on HealthRecordException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.userMessage;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Letter Within couldn't save that. Try again.";
      });
    }
  }

  Future<void> _remove() async {
    final selected = _selected;
    if (selected == null || _saving) return;
    final record = _recordFor(selected.symptom);
    if (record == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onRemove(record);
      if (!mounted) return;
      setState(() => _saving = false);
    } on HealthRecordException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.userMessage;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Letter Within couldn't save that. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        0,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.lg,
      ),
      child: selected == null ? _buildChooseStep() : _buildDegreeStep(selected),
    );
  }

  Widget _buildChooseStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Add a symptom',
          style: ExperienceType.headline(ExperienceColors.ink),
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          'One at a time — choose the symptom, then its degree.',
          style: ExperienceType.caption(ExperienceColors.inkSoft),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: ExperienceType.body(ExperienceColors.ink),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: "Search — try 'swelling' or 'worry'",
            hintStyle: ExperienceType.body(ExperienceColors.inkFaint),
            prefixIcon: const Icon(
              Icons.search,
              color: ExperienceColors.inkSoft,
            ),
            suffixIcon: _searching
                ? IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(
                      Icons.close,
                      color: ExperienceColors.inkSoft,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            filled: true,
            fillColor: ExperienceColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: ExperienceSpacing.sm,
              vertical: 14,
            ),
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
        const SizedBox(height: ExperienceSpacing.sm),
        if (_searching)
          _buildSearchResults()
        else ...<Widget>[
          _buildChooseSection('Quick picks', _quickPicks),
          for (final category in ObservationCategory.values)
            if (_browseFor(category).isNotEmpty)
              _buildChooseSection(category.label, _browseFor(category)),
        ],
      ],
    );
  }

  Widget _buildSearchResults() {
    final results = _searchResults;
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.lg),
        child: Text(
          'No matches in the vocabulary. Try another word you would use.',
          style: ExperienceType.body(ExperienceColors.inkSoft),
          textAlign: TextAlign.center,
        ),
      );
    }
    return _buildChooseSection('Matches', results);
  }

  Widget _buildChooseSection(String title, List<ObservationDefinition> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            top: ExperienceSpacing.sm,
            bottom: ExperienceSpacing.xs * 2,
          ),
          child: Text(
            title,
            style: ExperienceType.bodyStrong(ExperienceColors.ink),
          ),
        ),
        Wrap(
          spacing: ExperienceSpacing.xs * 2,
          runSpacing: ExperienceSpacing.xs * 2,
          children: <Widget>[
            for (final definition in items)
              _SymptomChoiceChip(
                definition: definition,
                record: _recordFor(definition.symptom),
                enabled: !_saving,
                onTap: () => _choose(definition),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDegreeStep(ObservationDefinition definition) {
    final record = _recordFor(definition.symptom);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (widget.editSymptom == null)
              IconButton(
                tooltip: 'Back to all symptoms',
                icon: const Icon(
                  Icons.arrow_back,
                  color: ExperienceColors.inkSoft,
                ),
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        _selected = null;
                        _error = null;
                      }),
              ),
            Expanded(
              child: Text(
                definition.label,
                style: ExperienceType.headline(ExperienceColors.ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          _isMedical
              ? 'Choose the closest degree, then save it explicitly.'
              : 'Choose the closest degree — it saves right away.',
          style: ExperienceType.caption(ExperienceColors.inkSoft),
        ),
        if (_isMedical) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.sm),
          const _MedicalBoundaryBox(),
          const SizedBox(height: ExperienceSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: widget.onOpenSafetyRoute,
              child: const Text('Open medical guidance'),
            ),
          ),
        ],
        const SizedBox(height: ExperienceSpacing.sm),
        Text(
          'How strong is it',
          style: ExperienceType.bodyStrong(ExperienceColors.ink),
        ),
        const SizedBox(height: ExperienceSpacing.xs * 2),
        Wrap(
          spacing: ExperienceSpacing.xs * 2,
          runSpacing: ExperienceSpacing.xs * 2,
          children: <Widget>[
            // Exactly the five present degrees — no "Not at all", no 0–10
            // score, no pain location.
            for (final degree in DegreeGraphics.severityDegrees)
              _FlowOptionChip(
                selected: _severity == degree,
                enabled: !_saving,
                semanticsLabel:
                    '${definition.label}, '
                    '${DegreeGraphics.severitySemanticsLabel(degree)}',
                onTap: () => _isMedical
                    ? setState(() => _severity = degree)
                    : _save(degree),
                child: DegreeGraphics.severity(
                  degree,
                  selected: _severity == degree,
                ),
              ),
          ],
        ),
        if (_saving) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.sm),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ExperienceColors.ember,
            ),
          ),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: ExperienceSpacing.xs * 2),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: ExperienceType.caption(ExperienceColors.error),
            ),
          ),
        ],
        const SizedBox(height: ExperienceSpacing.sm),
        Row(
          children: <Widget>[
            if (_isMedical)
              Expanded(
                child: FilledButton(
                  onPressed: _severity != null && !_saving
                      ? () => _save(_severity!)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: ExperienceColors.ember,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, ExperienceSpacing.degreeTarget),
                    shape: const RoundedRectangleBorder(
                      borderRadius: ExperienceRadius.chipRadius,
                    ),
                  ),
                  child: Text(_saving ? 'Saving…' : 'Save to record'),
                ),
              )
            else
              const Spacer(),
            if (record != null) ...<Widget>[
              const SizedBox(width: ExperienceSpacing.xs * 2),
              TextButton(
                onPressed: _saving ? null : _remove,
                style: TextButton.styleFrom(
                  foregroundColor: ExperienceColors.error,
                ),
                child: const Text('Remove from today'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// One symptom choice in the chooser: already-recorded entries carry their
/// check + degree, and choosing one edits that record instead of duplicating.
class _SymptomChoiceChip extends StatelessWidget {
  const _SymptomChoiceChip({
    required this.definition,
    required this.record,
    required this.enabled,
    required this.onTap,
  });

  final ObservationDefinition definition;
  final HealthRecord? record;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final recorded = record != null;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: recorded,
      label: recorded
          ? 'Symptom: ${definition.label}, recorded, ${record!.severity.label}'
          : 'Symptom: ${definition.label}, not recorded',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: ExperienceRadius.chipRadius,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: recorded
                ? ExperienceColors.surfaceWarm
                : ExperienceColors.surface,
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(
              color: recorded
                  ? ExperienceColors.ember
                  : ExperienceColors.hairline,
              width: recorded ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (recorded) ...<Widget>[
                const Icon(
                  Icons.check,
                  size: 16,
                  color: ExperienceColors.ember,
                ),
                const SizedBox(width: ExperienceSpacing.xs),
              ],
              Flexible(
                child: Text(
                  definition.label,
                  style: recorded
                      ? ExperienceType.label(ExperienceColors.ink)
                      : ExperienceType.bodySmall(ExperienceColors.inkSoft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The fixed medical-boundary list shown at record time for safety-route
/// symptoms. Copy comes from the shared [ObservationPicker] contract —
/// deterministic, no invented numbers.
class _MedicalBoundaryBox extends StatelessWidget {
  const _MedicalBoundaryBox();

  @override
  Widget build(BuildContext context) {
    const accent = ExperienceColors.accentSafety;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ExperienceSpacing.sm),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: ExperienceRadius.chipRadius,
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'When to seek medical care',
            style: ExperienceType.bodyStrong(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs * 2),
          for (final line in ObservationPicker.medicalBoundaryList)
            Padding(
              padding: const EdgeInsets.only(bottom: ExperienceSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: ExperienceSpacing.xs * 2),
                  Expanded(
                    child: Text(
                      line,
                      style: ExperienceType.caption(ExperienceColors.inkSoft),
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

// ---------------------------------------------------------------------------
// Note-to-self sheet — a separate, low-priority route through the capture
// store. Never implied as an expected daily action.
// ---------------------------------------------------------------------------

class _NoteSheet extends StatefulWidget {
  const _NoteSheet({required this.onSave});

  final Future<void> Function(String text) onSave;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(text);
      if (!mounted) return;
      setState(() => _saving = false);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Letter Within couldn't save that. Try again.";
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'A note to self',
            style: ExperienceType.headline(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            "Kept privately, alongside — never inside — today's record.",
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          TextField(
            controller: _controller,
            maxLength: captureTextLimit,
            maxLines: 5,
            minLines: 3,
            style: ExperienceType.body(ExperienceColors.ink),
            decoration: InputDecoration(
              hintText: 'Whatever future you should know.',
              hintStyle: ExperienceType.body(ExperienceColors.inkFaint),
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
                borderSide: BorderSide(
                  color: ExperienceColors.ember,
                  width: 1.5,
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: ExperienceSpacing.xs),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: ExperienceType.caption(ExperienceColors.error),
                ),
              ),
            ),
          const SizedBox(height: ExperienceSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: ExperienceColors.ember,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, ExperienceSpacing.minTouchTarget),
                shape: const RoundedRectangleBorder(
                  borderRadius: ExperienceRadius.chipRadius,
                ),
              ),
              child: Text(_saving ? 'Saving…' : 'Save note'),
            ),
          ),
        ],
      ),
    );
  }
}
