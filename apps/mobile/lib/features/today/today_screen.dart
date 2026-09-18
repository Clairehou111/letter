import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/letter_brand_mark.dart';
import '../../design_system/letter_bottom_navigation.dart';
import '../../design_system/letter_theme.dart';
import '../../design_system/lovable/letter_kit.dart' as lovable_kit;
import '../../design_system/lovable/letter_theme.dart' as lovable;
import '../care/domain/care_memory.dart';
import '../care/domain/care_memory_repository.dart';
import '../care/domain/care_mode.dart';
import '../check_in/domain/moment_check_in.dart';
import '../check_in/domain/moment_check_in_repository.dart';
import '../cycle/domain/cycle_prediction.dart';
import '../cycle/domain/local_date.dart';
import '../cycle/domain/period_record.dart';
import '../cycle/domain/period_repository.dart';
import '../capture/domain/capture_models.dart';
import '../entitlement/domain/entitlement.dart';
import '../entitlement/presentation/entitlement_scope.dart';
import '../entitlement/presentation/plans_sheet.dart';
import '../health_records/domain/health_record_repository.dart';
import '../health_records/domain/health_record.dart';
import '../health_records/presentation/health_records_screen.dart';
import '../insights/presentation/gravity_horizon.dart';
import '../insights/presentation/gravity_horizon_view_model.dart';
import '../patterns/domain/pattern_source.dart';
import '../patterns/domain/personal_pattern_engine.dart';
import '../preparation/domain/preparation_snapshot.dart';
import '../preparation/domain/preparation_snapshot_composer.dart';
import '../preparation/domain/preparation_loop_state.dart';
import '../preparation/domain/preparation_plan.dart';
import '../preparation/presentation/next_window_card.dart';
import 'today_cycle_context.dart';

const _healthCompactWindow = Duration(minutes: 5);

final class _LoadedPreparation {
  const _LoadedPreparation({
    required this.composition,
    this.loop,
    this.loopLoadFailed = false,
  });

  final PreparationComposition composition;
  final PreparationLoopState? loop;
  final bool loopLoadFailed;
}

final class _PastSelfMemory {
  const _PastSelfMemory({required this.actionLabel, required this.betterCount});

  final String actionLabel;
  final int betterCount;
}

enum TodayState {
  good(
    'Good',
    Icons.wb_sunny_outlined,
    LetterColors.teal,
    LetterColors.tealSoft,
  ),
  steady(
    'Steady',
    Icons.favorite_border,
    LetterColors.blue,
    LetterColors.blueSoft,
  ),
  energized(
    'Energized',
    Icons.auto_awesome_outlined,
    LetterColors.amber,
    LetterColors.amberSoft,
  ),
  low('Low', Icons.bedtime_outlined, LetterColors.blue, LetterColors.blueSoft),
  irritable(
    'Irritable',
    Icons.local_fire_department_outlined,
    LetterColors.safetyRed,
    LetterColors.coralSoft,
  ),
  physical(
    'Physical',
    Icons.waves_outlined,
    LetterColors.violet,
    LetterColors.violetSoft,
  );

  const TodayState(this.label, this.icon, this.foreground, this.background);

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;

  bool get isNegative => switch (this) {
    TodayState.low || TodayState.irritable || TodayState.physical => true,
    _ => false,
  };

  SymptomCategory? get defaultCategory => switch (this) {
    TodayState.low => SymptomCategory.energy,
    TodayState.irritable => SymptomCategory.mood,
    TodayState.physical => SymptomCategory.physical,
    _ => null,
  };
}

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    required this.repository,
    super.key,
    this.onNavigationSelected,
    this.now,
    this.healthRecordRepository,
    this.captureNoteStore,
    this.momentCheckInRepository,
    this.careMemoryRepository,
    this.preparationRepository,
    this.onOpenCareMode,
    this.onOpenQuickCareMode,
    this.onOpenCareToolkit,
  });

  final PeriodRepository repository;
  final ValueChanged<int>? onNavigationSelected;
  final DateTime Function()? now;
  final HealthRecordRepository? healthRecordRepository;
  final CaptureNoteStore? captureNoteStore;
  final MomentCheckInRepository? momentCheckInRepository;
  final CareMemoryRepository? careMemoryRepository;
  final PreparationRepository? preparationRepository;
  final ValueChanged<CareMode>? onOpenCareMode;
  final ValueChanged<CareMode>? onOpenQuickCareMode;
  final VoidCallback? onOpenCareToolkit;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  TodayState? selectedState;
  List<PeriodRecord> _records = const [];
  List<MomentCheckIn> _checkIns = const [];
  bool _loading = true;
  bool _loadFailed = false;
  PreparationComposition? _preparation;
  PreparationLoopState? _preparationLoop;
  bool _returnHiddenForVisit = false;
  bool _preparationLoopLoadFailed = false;
  _PastSelfMemory? _pastSelfMemory;

  LocalDate get _today =>
      LocalDate.fromDateTime((widget.now ?? DateTime.now)());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showProgress = true}) async {
    if (showProgress) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final results = await Future.wait<Object>([
        widget.repository.getAll(),
        widget.momentCheckInRepository?.getAll() ??
            Future.value(const <MomentCheckIn>[]),
        _loadCareRecords(),
      ]);
      final records = results[0] as List<PeriodRecord>;
      final checkIns = results[1] as List<MomentCheckIn>;
      final careRecords = results[2] as List<CareRecord>;
      final preparation = await _loadPreparation(records, careRecords);
      if (!mounted) {
        return;
      }
      setState(() {
        _records = records;
        _checkIns = checkIns;
        _preparation = preparation?.composition;
        _preparationLoop = preparation?.loop;
        _preparationLoopLoadFailed = preparation?.loopLoadFailed ?? false;
        _pastSelfMemory = _buildPastSelfMemory(careRecords);
        selectedState = _latestTodayState(checkIns, _today);
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

  Future<List<CareRecord>> _loadCareRecords() async {
    try {
      return await widget.careMemoryRepository?.getRecords() ?? const [];
    } on Object {
      // Care memory enriches Today but must never prevent Today from opening.
      return const [];
    }
  }

  Future<_LoadedPreparation?> _loadPreparation(
    List<PeriodRecord> periods,
    List<CareRecord> careRecords,
  ) async {
    final healthRepository = widget.healthRecordRepository;
    final careRepository = widget.careMemoryRepository;
    if (healthRepository == null || careRepository == null) return null;
    try {
      final results = await Future.wait<Object>([
        healthRepository.getAll(),
        careRepository.getReflections(),
      ]);
      final source = PatternSourceSnapshot(
        healthRecords: results[0] as List<HealthRecord>,
        careRecords: careRecords,
        careReflections: results[1] as List<CareReflection>,
        periods: periods,
      );
      final composition = const PreparationSnapshotComposer().compose(
        source: source,
        patterns: const PersonalPatternEngine().analyze(source),
        prediction: CyclePredictionEngine.calculate(periods),
        today: _today,
      );
      final snapshot = composition.snapshot;
      final preparationRepository = widget.preparationRepository;
      if (snapshot == null || preparationRepository == null) {
        return _LoadedPreparation(composition: composition);
      }
      try {
        final loop = await PreparationLoopState.load(
          snapshot: snapshot,
          repository: preparationRepository,
          currentSourceIds: {
            for (final record in source.healthRecords) record.id,
            for (final record in source.careRecords) record.id,
          },
        );
        return _LoadedPreparation(composition: composition, loop: loop);
      } on Object {
        return _LoadedPreparation(
          composition: composition,
          loopLoadFailed: true,
        );
      }
    } on Object {
      // Preparation is optional; a memory failure must not hide Today.
      return null;
    }
  }

  void _openCare() {
    widget.onNavigationSelected?.call(1);
  }

  void _openCareMode(CareMode mode) {
    final callback = widget.onOpenCareMode;
    if (callback != null) {
      callback(mode);
      return;
    }
    _openCare();
  }

  Future<void> _openPreparationDetails(PreparationSnapshot snapshot) {
    return Navigator.of(context)
        .push<void>(
          MaterialPageRoute(
            builder: (detailsContext) => YourNextWindowScreen(
              snapshot: snapshot,
              loopState: _preparationLoop,
              loopLoadFailed: _preparationLoopLoadFailed,
              repository: widget.preparationRepository,
              onReviewRecords: _openHealthRecords,
              onOpenCare: (mode) {
                Navigator.of(detailsContext).pop();
                _openCareMode(mode);
              },
            ),
          ),
        )
        .then((_) async {
          if (mounted) await _load(showProgress: false);
        });
  }

  Future<void> _openHealthRecords() async {
    final repository = widget.healthRecordRepository;
    if (repository == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => HealthRecordsScreen(
          repository: repository,
          periodRepository: widget.repository,
          now: widget.now,
        ),
      ),
    );
    if (mounted) {
      await _load(showProgress: false);
    }
  }

  Future<void> _openQuickStateSheet() async {
    final state = await showModalBottomSheet<TodayState>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: LetterColors.ink.withValues(alpha: 0.35),
      builder: (context) => QuickStateSheet(selectedState: selectedState),
    );
    if (state != null && mounted) {
      await _saveCheckIn(state);
    }
  }

  Future<void> _saveCheckIn(TodayState state) async {
    final repository = widget.momentCheckInRepository;
    if (repository == null) {
      _showActivityError('Check-in storage is unavailable.');
      return;
    }
    try {
      final checkIn = await repository.create(
        _momentState(state),
        occurredAt: (widget.now ?? DateTime.now)(),
      );
      if (!mounted) return;
      setState(() {
        selectedState = state;
        _checkIns = [checkIn, ..._checkIns];
      });
      if (state.isNegative) {
        HapticFeedback.lightImpact();
        final next = await showModalBottomSheet<_DifficultMomentAction>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          barrierColor: LetterColors.ink.withValues(alpha: 0.35),
          builder: (context) => DifficultMomentSavedSheet(state: state),
        );
        if (!mounted) return;
        switch (next) {
          case _DifficultMomentAction.reset:
            final mode = switch (state) {
              TodayState.irritable => CareMode.explode,
              TodayState.low => CareMode.heavy,
              TodayState.physical => CareMode.physical,
              _ => CareMode.racing,
            };
            final callback = widget.onOpenQuickCareMode;
            if (callback != null) {
              callback(mode);
            } else {
              _openCareMode(mode);
            }
          case _DifficultMomentAction.bodyCare:
            final callback = widget.onOpenCareToolkit;
            if (callback != null) {
              callback();
            } else {
              _openCareMode(CareMode.physical);
            }
          case _DifficultMomentAction.details:
            await _openHealthRecordEditor(
              initialCategory: state.defaultCategory,
            );
          case _DifficultMomentAction.notNow || null:
            break;
        }
        return;
      }
      final next = await showModalBottomSheet<_CheckInNextAction>(
        context: context,
        useSafeArea: true,
        barrierColor: LetterColors.ink.withValues(alpha: 0.35),
        builder: (context) => CheckInSavedSheet(checkIn: checkIn),
      );
      if (!mounted) return;
      if (next == _CheckInNextAction.undo) {
        await repository.delete(checkIn.id);
        await _load(showProgress: false);
      } else if (next == _CheckInNextAction.addDetails) {
        await _openHealthRecordEditor();
      }
    } on MomentCheckInException catch (error) {
      if (mounted) _showActivityError(error.userMessage);
    }
  }

  Future<void> _openHealthRecordEditor({
    HealthRecord? record,
    SymptomCategory? initialCategory,
  }) async {
    final repository = widget.healthRecordRepository;
    if (repository == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => HealthRecordFormScreen(
          repository: repository,
          initialRecord: record,
          initialCategory: initialCategory,
          now: widget.now,
        ),
      ),
    );
    if (mounted) {
      await _load(showProgress: false);
    }
  }

  void _showActivityError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final horizon = GravityHorizonViewModel.fromRecords(
      records: _records,
      today: _today,
    );
    return Scaffold(
      bottomNavigationBar: LetterBottomNavigation(
        onSelected: widget.onNavigationSelected,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: LetterColors.teal),
                  )
                : _loadFailed
                ? _TodayLoadError(onRetry: _load)
                : CustomScrollView(
                    key: const Key('today-scroll'),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
                        sliver: SliverList.list(
                          children: [
                            AppHeader(onCheckIn: _openQuickStateSheet),
                            const SizedBox(height: LetterSpacing.md),
                            _TodayDateHeader(viewModel: horizon),
                            const SizedBox(height: LetterSpacing.lg),
                            GravityHorizonView(
                              viewModel: horizon,
                              onOpenCycle: () =>
                                  widget.onNavigationSelected?.call(2),
                            ),
                            const SizedBox(height: LetterSpacing.xl),
                            _LovableTodayGroup(
                              label: 'Your check-in',
                              footnote:
                                  'Your own words are the record of how you feel. '
                                  'Nothing on this screen speaks for you.',
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedState == null
                                            ? 'No check-in recorded today.'
                                            : '${selectedState!.label} recorded today.',
                                        style: lovable.letterBody(size: 14),
                                      ),
                                      const SizedBox(height: 12),
                                      lovable_kit.PrimaryButton(
                                        key: const Key('today-start-check-in'),
                                        label: selectedState == null
                                            ? 'Start check-in'
                                            : 'Add another check-in',
                                        onPressed: _openQuickStateSheet,
                                        expand:
                                            context.isLetterNarrow ||
                                            context.isLetterLargeText,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_pastSelfMemory case final memory?)
                              _PastSelfLetterCard(memory: memory),
                            if (_contextualPreparationPlan case final plan?)
                              Padding(
                                padding: const EdgeInsets.only(top: 28),
                                child: PreparationReturnCard(
                                  plan: plan,
                                  onOpenCare: _openCareMode,
                                  onNotNow: () => setState(
                                    () => _returnHiddenForVisit = true,
                                  ),
                                ),
                              ),
                            if (_preparation?.snapshot case final snapshot?
                                when snapshot.hasContinuityEvidence)
                              EntitlementScope.canUse(
                                    context,
                                    LetterCapability.prepareSurface,
                                  )
                                  ? NextWindowCard(
                                      snapshot: snapshot,
                                      onOpenDetails: () =>
                                          _openPreparationDetails(snapshot),
                                    )
                                  : const _PlusPreparationCard(),
                            _TodayQuickActions(
                              showRecordSymptoms:
                                  widget.healthRecordRepository != null,
                              onRecordSymptoms: _openHealthRecords,
                              onOpenCare: _openCare,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  PreparationPlan? get _contextualPreparationPlan {
    if (_returnHiddenForVisit) return null;
    final loop = _preparationLoop;
    final plan = loop?.plan;
    if (loop == null ||
        loop.kind != PreparationLoopKind.saved ||
        plan == null) {
      return null;
    }
    final timing = loop.snapshot.timing;
    if (_today.isBefore(timing.rangeStart) || _today.isAfter(timing.rangeEnd)) {
      return null;
    }
    return plan;
  }
}

class _PlusPreparationCard extends StatelessWidget {
  const _PlusPreparationCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR NEXT WINDOW · PLUS',
                style: TextStyle(
                  color: LetterColors.tealDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Let what helped return when you need it.',
                style: TextStyle(
                  fontFamily: 'Newsreader',
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Plus can prepare a future window from patterns and support you explicitly chose to remember.',
                style: TextStyle(color: LetterColors.muted, height: 1.45),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                key: const Key('today-plus-preparation-plans'),
                onPressed: () {
                  final repository = EntitlementScope.repositoryOf(context);
                  if (repository != null) PlansSheet.show(context, repository);
                },
                child: const Text('See Letter Within Plus'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PastSelfLetterCard extends StatelessWidget {
  const _PastSelfLetterCard({required this.memory});

  final _PastSelfMemory memory;

  @override
  Widget build(BuildContext context) {
    final countText = memory.betterCount == 1
        ? 'once before'
        : '${memory.betterCount} times before';
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        key: const Key('today-past-self-letter'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE9D8), Color(0xFFF2E7F6)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5C7D4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFFFF7F0),
              foregroundColor: Color(0xFF9A627A),
              child: Icon(Icons.mail_outline_rounded),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'A letter from your past self',
                    style: TextStyle(
                      color: Color(0xFF7E5267),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${memory.actionLabel} helped you $countText. Keep it nearby for a harder day.',
                    style: const TextStyle(
                      fontFamily: 'Newsreader',
                      fontSize: 18,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
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

/// Copied from Lovable's generated `TodayGroup`; production data is supplied
/// by [TodayScreen] rather than its design-lab fixtures.
class _LovableTodayGroup extends StatelessWidget {
  const _LovableTodayGroup({
    required this.label,
    required this.children,
    this.footnote,
  });

  final String label;
  final List<Widget> children;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Semantics(
              header: true,
              child: Text(label.toUpperCase(), style: lovable.letterEyebrow()),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: const BoxDecoration(
              color: lovable.LetterTokens.surface,
              border: Border(
                top: lovable.LetterTokens.hairline,
                bottom: lovable.LetterTokens.hairline,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
          if (footnote != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(footnote!, style: lovable.letterHelper(size: 12)),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayQuickActions extends StatelessWidget {
  const _TodayQuickActions({
    required this.showRecordSymptoms,
    required this.onRecordSymptoms,
    required this.onOpenCare,
  });

  final bool showRecordSymptoms;
  final VoidCallback onRecordSymptoms;
  final VoidCallback onOpenCare;

  @override
  Widget build(BuildContext context) {
    final stack = context.isLetterNarrow || context.isLetterLargeText;
    final recordButton = lovable_kit.PrimaryButton(
      key: const Key('open-health-records'),
      label: 'Record symptoms',
      onPressed: onRecordSymptoms,
      expand: true,
    );
    final careButton = OutlinedButton(
      key: const Key('open-care-button'),
      onPressed: onOpenCare,
      style: OutlinedButton.styleFrom(
        foregroundColor: lovable.LetterTokens.teal,
        minimumSize: const Size.fromHeight(lovable.LetterTokens.tapTarget),
        side: const BorderSide(color: lovable.LetterTokens.teal),
        shape: RoundedRectangleBorder(
          borderRadius: lovable.LetterTokens.brControl,
        ),
        textStyle: lovable.letterBody(size: 14, weight: FontWeight.w500),
      ),
      child: const Text('Open Care'),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Semantics(
        container: true,
        label: 'Quick actions',
        child: lovable_kit.LetterCard(
          padding: const EdgeInsets.all(16),
          child: stack
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showRecordSymptoms) recordButton,
                    if (showRecordSymptoms) const SizedBox(height: 10),
                    careButton,
                  ],
                )
              : Row(
                  children: [
                    if (showRecordSymptoms) ...[
                      Expanded(child: recordButton),
                      const SizedBox(width: 10),
                    ],
                    Expanded(child: careButton),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TodayLoadError extends StatelessWidget {
  const _TodayLoadError({required this.onRetry});

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
              'Today could not open your private cycle context.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: LetterSpacing.lg),
            FilledButton.icon(
              key: const Key('retry-today-load'),
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

class QuickStateSheet extends StatelessWidget {
  const QuickStateSheet({required this.selectedState, super.key});

  final TodayState? selectedState;

  @override
  Widget build(BuildContext context) {
    return LetterSheetFrame(
      title: 'How are you right now?',
      subtitle:
          'Choose one moment. It will be saved privately with the current time.',
      child: StateGrid(
        selectedState: selectedState,
        onSelected: (state) => Navigator.pop(context, state),
      ),
    );
  }
}

enum _CheckInNextAction { addDetails, undo }

enum _DifficultMomentAction { reset, bodyCare, details, notNow }

class DifficultMomentSavedSheet extends StatelessWidget {
  const DifficultMomentSavedSheet({required this.state, super.key});

  final TodayState state;

  @override
  Widget build(BuildContext context) {
    Widget action({
      required Key key,
      required String title,
      required String detail,
      required IconData icon,
      required Color color,
      required _DifficultMomentAction result,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color.withValues(alpha: .1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: .28)),
        ),
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pop(context, result),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: const TextStyle(
                          color: LetterColors.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: color, size: 19),
              ],
            ),
          ),
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(state.icon, color: state.foreground, size: 38),
              const SizedBox(height: 10),
              Text(
                '${state.label} is saved.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Newsreader',
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'What would feel useful right now?',
                textAlign: TextAlign.center,
                style: TextStyle(color: LetterColors.muted),
              ),
              const SizedBox(height: 18),
              action(
                key: const Key('difficult-moment-reset'),
                title: '30-second reset',
                detail: 'A small visual pause. Nothing to explain.',
                icon: Icons.hourglass_bottom_rounded,
                color: LetterColors.violet,
                result: _DifficultMomentAction.reset,
              ),
              action(
                key: const Key('difficult-moment-body-care'),
                title: 'Find something for my body',
                detail: 'Warmth, gentle movement, rest, and comfort.',
                icon: Icons.spa_outlined,
                color: LetterColors.amber,
                result: _DifficultMomentAction.bodyCare,
              ),
              action(
                key: const Key('difficult-moment-details'),
                title: 'Record more detail',
                detail: 'Add symptoms and their intensity.',
                icon: Icons.edit_note_rounded,
                color: LetterColors.teal,
                result: _DifficultMomentAction.details,
              ),
              TextButton(
                key: const Key('difficult-moment-not-now'),
                onPressed: () =>
                    Navigator.pop(context, _DifficultMomentAction.notNow),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CheckInSavedSheet extends StatelessWidget {
  const CheckInSavedSheet({required this.checkIn, super.key});

  final MomentCheckIn checkIn;

  @override
  Widget build(BuildContext context) {
    final local = checkIn.occurredAt.toLocal();
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return Container(
      key: const Key('check-in-saved-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: const BoxDecoration(
        color: LetterColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Spacer(),
              const Icon(
                Icons.check_circle_outline,
                color: LetterColors.teal,
                size: 34,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    key: const Key('check-in-saved-close'),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LetterSpacing.sm),
          Text(
            '${checkIn.state.label} saved at $time',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Newsreader',
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: LetterSpacing.xs),
          const Text(
            'This moment appears in Today and your cycle Story. It is not a clinical rating.',
            textAlign: TextAlign.center,
            style: TextStyle(color: LetterColors.muted, height: 1.4),
          ),
          const SizedBox(height: LetterSpacing.lg),
          FilledButton.icon(
            key: const Key('check-in-add-details'),
            onPressed: () =>
                Navigator.pop(context, _CheckInNextAction.addDetails),
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('Add symptom details'),
          ),
          TextButton.icon(
            key: const Key('check-in-undo'),
            onPressed: () => Navigator.pop(context, _CheckInNextAction.undo),
            icon: const Icon(Icons.undo),
            label: const Text('Undo check-in'),
          ),
        ],
      ),
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({required this.onCheckIn, super.key});

  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.textScalerOf(context).scale(1) > 1.45 &&
        MediaQuery.sizeOf(context).width < 360;

    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: compact
                  ? const LetterBrandMark(size: 27)
                  : const LetterBrandLockup(),
            ),
          ),
          if (compact)
            IconButton.outlined(
              key: const Key('header-log-button'),
              tooltip: 'Check in',
              onPressed: onCheckIn,
              icon: const Icon(Icons.add),
            )
          else
            OutlinedButton.icon(
              key: const Key('header-log-button'),
              onPressed: onCheckIn,
              style: OutlinedButton.styleFrom(
                foregroundColor: LetterColors.ink,
                side: const BorderSide(color: LetterColors.line),
                minimumSize: const Size(70, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LetterRadius.control),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Check in',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

class _TodayDateHeader extends StatelessWidget {
  const _TodayDateHeader({required this.viewModel});

  final GravityHorizonViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(
      context,
    ).formatFullDate(viewModel.today.asLocalDateTime);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LetterEyebrow('Today'),
        const SizedBox(height: LetterSpacing.xxs),
        Semantics(
          header: true,
          child: Text(
            date,
            style: TextStyle(
              fontFamily: 'Newsreader',
              fontSize: context.isLetterNarrow ? 26 : 30,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class CycleHero extends StatelessWidget {
  const CycleHero({
    required this.cycleContext,
    required this.onOpenCycle,
    super.key,
  });

  final TodayCycleContext cycleContext;
  final VoidCallback onOpenCycle;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final prediction = cycleContext.prediction;
    final timing = prediction?.timingFor(cycleContext.today);
    final rangeText = _buildRangeText(context, prediction);
    final title = switch (cycleContext.kind) {
      TodayCycleKind.noHistory => 'Start with a real cycle record.',
      TodayCycleKind.periodInProgress => 'Your period is in progress.',
      TodayCycleKind.betweenPeriods when prediction == null =>
        'Your cycle record is taking shape.',
      TodayCycleKind.betweenPeriods
          when timing == PredictionTiming.currentWindow =>
        'Your estimate window is here.',
      TodayCycleKind.betweenPeriods
          when timing == PredictionTiming.laterThanEstimate =>
        'Later than the current estimate.',
      TodayCycleKind.betweenPeriods => 'Your next estimate is ahead.',
    };
    final body = switch (cycleContext.kind) {
      TodayCycleKind.noHistory =>
        'No period history yet. Add a start date in Cycle when you are ready.',
      TodayCycleKind.periodInProgress =>
        'Period day ${cycleContext.dayNumber}. Started '
            '${_formatContextDate(context, cycleContext.latestStart!)}.',
      TodayCycleKind.betweenPeriods when prediction == null =>
        'Cycle day ${cycleContext.dayNumber}. Letter Within needs two complete '
            'cycle intervals before estimating a range.',
      TodayCycleKind.betweenPeriods
          when timing == PredictionTiming.currentWindow =>
        'Cycle day ${cycleContext.dayNumber}. Today falls within $rangeText.',
      TodayCycleKind.betweenPeriods
          when timing == PredictionTiming.laterThanEstimate =>
        'Cycle day ${cycleContext.dayNumber}. The recorded estimate was $rangeText.',
      TodayCycleKind.betweenPeriods =>
        'Cycle day ${cycleContext.dayNumber}. Next estimated period: $rangeText.',
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackContent = constraints.maxWidth < 340 || textScale > 1.45;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LetterEyebrow(
              MaterialLocalizations.of(
                context,
              ).formatFullDate(cycleContext.today.asLocalDateTime),
              color: const Color(0xFFA7D4D1),
            ),
            const SizedBox(height: LetterSpacing.sm),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Newsreader',
                fontSize: 27,
                height: 1.05,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: LetterSpacing.sm),
            Text(
              body,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: LetterSpacing.sm),
            TextButton.icon(
              key: const Key('today-open-cycle'),
              onPressed: onOpenCycle,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                alignment: Alignment.centerLeft,
              ),
              icon: const Icon(Icons.calendar_today_outlined, size: 17),
              label: const Text(
                'Open Cycles',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
        final ring = CycleRing(cycleContext: cycleContext, size: 114);

        return Container(
          key: const Key('today-cycle-context'),
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF176D67), Color(0xFF124B50)],
            ),
            borderRadius: BorderRadius.circular(LetterRadius.panel),
            boxShadow: LetterShadows.soft,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 8,
                left: 10,
                child: Transform.rotate(
                  angle: -0.18,
                  child: Container(
                    width: 56,
                    height: 16,
                    decoration: BoxDecoration(
                      color: LetterColors.moonMetal.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -8,
                left: 0,
                child: Container(
                  width: 76,
                  height: 22,
                  decoration: BoxDecoration(
                    color: LetterColors.teal,
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: LetterColors.moonMetal.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                right: -10,
                child: Transform.rotate(
                  angle: 0.3,
                  child: Container(
                    width: 36,
                    height: 8,
                    decoration: BoxDecoration(
                      color: LetterColors.canvas.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 21, 16, 18),
                child: stackContent
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          copy,
                          Align(alignment: Alignment.centerRight, child: ring),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: copy),
                          const SizedBox(width: LetterSpacing.sm),
                          ring,
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CycleRing extends StatelessWidget {
  const CycleRing({required this.cycleContext, required this.size, super.key});

  final TodayCycleContext cycleContext;
  final double size;

  @override
  Widget build(BuildContext context) {
    final day = cycleContext.dayNumber;
    final progress = day == null || cycleContext.prediction == null
        ? null
        : ((day - 1) / cycleContext.prediction!.medianCycleDays)
              .clamp(0.0, 1.0)
              .toDouble();
    final label = switch (cycleContext.kind) {
      TodayCycleKind.noHistory => 'Start',
      TodayCycleKind.periodInProgress => 'Period',
      TodayCycleKind.betweenPeriods => 'Cycle',
    };

    return Semantics(
      label: day == null ? 'No cycle history' : '$label day $day',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: CycleRingPainter(progress: progress),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.2,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      day == null ? 'NO DAY' : 'DAY',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      day?.toString() ?? '--',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Newsreader',
                        fontSize: 34,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontSize: 9),
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

class CycleRingPainter extends CustomPainter {
  const CycleRingPainter({required this.progress});

  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 7;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = const Color(0xFF4C8D88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius, track);
    if (progress case final value?) {
      final progressPaint = Paint()
        ..color = LetterColors.coral
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = 10;
      const start = -math.pi / 2;
      final sweep = math.pi * 2 * value;
      canvas.drawArc(rect, start, sweep, false, progressPaint);

      final markerAngle = start + sweep;
      final marker = Offset(
        center.dx + radius * math.cos(markerAngle),
        center.dy + radius * math.sin(markerAngle),
      );
      canvas.drawCircle(marker, 4.2, Paint()..color = Colors.white);
      canvas.drawCircle(marker, 2.2, Paint()..color = LetterColors.tealDark);
    }
  }

  @override
  bool shouldRepaint(CycleRingPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}

class TodayCareEntry extends StatelessWidget {
  const TodayCareEntry({required this.onOpenCare, super.key});

  final VoidCallback onOpenCare;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: LetterColors.tealSoft,
                borderRadius: BorderRadius.circular(LetterRadius.panel),
              ),
              child: const Icon(
                Icons.volunteer_activism_outlined,
                color: LetterColors.teal,
                size: 21,
              ),
            ),
            const SizedBox(width: LetterSpacing.sm),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LetterEyebrow('Care'),
                  SizedBox(height: LetterSpacing.xxs),
                  Text(
                    'Need support right now?',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: LetterSpacing.md),
        const Text(
          'Choose what feels most urgent. You can leave at any time.',
          style: TextStyle(
            color: LetterColors.muted,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: LetterSpacing.md),
        FilledButton.icon(
          key: const Key('open-care-button'),
          onPressed: onOpenCare,
          style: FilledButton.styleFrom(
            backgroundColor: LetterColors.teal,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LetterRadius.control),
            ),
          ),
          icon: const Icon(Icons.volunteer_activism_outlined, size: 19),
          label: const Text('Open Care'),
        ),
      ],
    );
  }
}

class TodayHealthRecordEntry extends StatelessWidget {
  const TodayHealthRecordEntry({required this.onOpenRecords, super.key});

  final VoidCallback onOpenRecords;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('today-health-record-entry'),
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: BoxDecoration(
        color: LetterColors.violetSoft,
        border: Border.all(color: LetterColors.violet.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note_outlined, color: LetterColors.violet),
              SizedBox(width: LetterSpacing.sm),
              Expanded(
                child: Text(
                  'Log your symptoms',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: LetterSpacing.xs),
          const Text(
            'Track what you experienced. Everything stays private on this device.',
            style: TextStyle(color: LetterColors.muted, fontSize: 12),
          ),
          const SizedBox(height: LetterSpacing.sm),
          OutlinedButton.icon(
            key: const Key('open-health-records'),
            onPressed: onOpenRecords,
            icon: const Icon(Icons.add),
            label: const Text('Add symptom details'),
            style: OutlinedButton.styleFrom(
              foregroundColor: LetterColors.violet,
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: LetterColors.violet),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LetterRadius.control),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TodayCaptureEntry extends StatelessWidget {
  const TodayCaptureEntry({required this.onOpenCapture, super.key});

  final VoidCallback onOpenCapture;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('today-capture-entry'),
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: BoxDecoration(
        color: LetterColors.tealSoft,
        border: Border.all(color: LetterColors.teal.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_outlined, color: LetterColors.teal),
              SizedBox(width: LetterSpacing.sm),
              Expanded(
                child: Text(
                  'Put today into words',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: LetterSpacing.xs),
          const Text(
            'A private note stays on this device. It is not added to reports or insights.',
            style: TextStyle(color: LetterColors.muted, fontSize: 12),
          ),
          const SizedBox(height: LetterSpacing.sm),
          OutlinedButton.icon(
            key: const Key('open-text-voice-capture'),
            onPressed: onOpenCapture,
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('Write a private note'),
            style: OutlinedButton.styleFrom(
              foregroundColor: LetterColors.teal,
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: LetterColors.teal),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LetterRadius.control),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TodayActivity extends StatelessWidget {
  const TodayActivity({
    required this.today,
    required this.checkIns,
    required this.healthRecords,
    required this.notes,
    required this.careRecords,
    required this.onDeleteHealthRecord,
    required this.onDeleteNote,
    required this.onDeleteCheckIn,
    super.key,
  });

  final LocalDate today;
  final List<MomentCheckIn> checkIns;
  final List<HealthRecord> healthRecords;
  final List<CaptureNote> notes;
  final List<CareRecord> careRecords;
  final ValueChanged<HealthRecord> onDeleteHealthRecord;
  final ValueChanged<CaptureNote> onDeleteNote;
  final ValueChanged<MomentCheckIn> onDeleteCheckIn;

  @override
  Widget build(BuildContext context) {
    final healthGroups = _compactHealthRecordsStatic(healthRecords, today);
    final entries = <_TodayActivityEntry>[
      for (final checkIn in checkIns)
        if (_isToday(checkIn.occurredAt, today))
          _TodayActivityEntry(
            key: Key('today-activity-check-in-${checkIn.id}'),
            occurredAt: checkIn.occurredAt,
            icon: Icons.brightness_1_outlined,
            iconColor: LetterColors.teal,
            title: checkIn.state.label,
            detail: 'Moment check-in · not a clinical rating',
            onDelete: () => onDeleteCheckIn(checkIn),
          ),
      for (final group in healthGroups)
        if (group.isToday)
          _TodayActivityEntry(
            key: Key('today-activity-health-grp-${group.key}'),
            occurredAt: group.occurredAt,
            icon: Icons.edit_note_outlined,
            iconColor: LetterColors.violet,
            title: group.title,
            detail: group.detail,
            onDelete: () {
              for (final record in group._records) {
                onDeleteHealthRecord(record);
              }
            },
          ),
      for (final note in notes)
        if (_isToday(note.createdAt, today))
          _TodayActivityEntry(
            key: Key('today-activity-note-${note.id}'),
            occurredAt: note.createdAt,
            icon: Icons.notes_outlined,
            iconColor: LetterColors.blue,
            title: note.text,
            detail: 'Private note · excluded from reports by default',
            onDelete: () => onDeleteNote(note),
          ),
      for (final record in careRecords)
        if (_isToday(record.occurredAt, today))
          _TodayActivityEntry(
            key: Key('today-activity-care-${record.id}'),
            occurredAt: record.occurredAt,
            icon: Icons.volunteer_activism_outlined,
            iconColor: LetterColors.coral,
            title: record.actionLabel,
            detail: 'Care · ${_careOutcomeLabel(record.outcome)}',
          ),
    ]..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));

    return Column(
      key: const Key('today-activity'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LetterSectionTitle(
          eyebrow: 'Saved on this device',
          title: "Today's activity",
        ),
        const SizedBox(height: LetterSpacing.sm),
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(LetterSpacing.md),
            decoration: BoxDecoration(
              color: LetterColors.surface,
              border: Border.all(color: LetterColors.line),
              borderRadius: BorderRadius.circular(LetterRadius.panel),
            ),
            child: const Text(
              'Nothing recorded today yet.',
              key: Key('today-activity-empty'),
              style: TextStyle(color: LetterColors.muted),
            ),
          )
        else
          for (var index = 0; index < entries.length; index++) ...[
            entries[index],
            if (index != entries.length - 1)
              const SizedBox(height: LetterSpacing.xs),
          ],
      ],
    );
  }

  static bool _isToday(DateTime value, LocalDate today) {
    return LocalDate.fromDateTime(value.toLocal()) == today;
  }

  static List<_HealthRecordGroup> _compactHealthRecordsStatic(
    List<HealthRecord> records,
    LocalDate today,
  ) {
    final todayRecords =
        records
            .where(
              (r) =>
                  TodayActivity._isToday(r.recordedAt, today) ||
                  TodayActivity._isToday(r.updatedAt, today),
            )
            .toList()
          ..sort(
            (a, b) => _healthActivityTime(a).compareTo(_healthActivityTime(b)),
          );
    if (todayRecords.isEmpty) return [];
    final groups = <_HealthRecordGroup>[];
    var current = <HealthRecord>[todayRecords.first];
    for (var i = 1; i < todayRecords.length; i++) {
      final prev = current.last;
      final next = todayRecords[i];
      if (_healthActivityTime(
            next,
          ).difference(_healthActivityTime(prev)).abs() <=
          _healthCompactWindow) {
        current.add(next);
      } else {
        groups.add(_HealthRecordGroup._fromRecords(current));
        current = [next];
      }
    }
    groups.add(_HealthRecordGroup._fromRecords(current));
    return groups;
  }
}

class _HealthRecordGroup {
  _HealthRecordGroup._fromRecords(this._records);
  final List<HealthRecord> _records;

  String get key => _records.first.id;

  DateTime get occurredAt =>
      _records.map(_healthActivityTime).reduce((a, b) => a.isAfter(b) ? a : b);

  bool get isToday => _records.isNotEmpty;

  String get title {
    final sorted = [..._records]
      ..sort((a, b) => a.symptom.index.compareTo(b.symptom.index));
    return sorted.map((r) => r.symptom.label).join(', ');
  }

  String get detail {
    final count = _records.length;
    final provenance = _records.first.provenance.label;
    if (count == 1) {
      final r = _records.first;
      final experienced =
          LocalDate.fromDateTime(r.recordedAt.toLocal()) == r.experiencedDate;
      final when = experienced
          ? ''
          : ' · experienced ${r.experiencedDate.month}/${r.experiencedDate.day}';
      final changed = r.updatedAt.isAfter(r.recordedAt)
          ? 'Edited today'
          : provenance;
      return '${r.severity.label} · ${r.severity.score}/5 · $changed$when';
    }
    final recalled = _records.any(
      (record) => record.provenance == HealthRecordProvenance.laterRecall,
    );
    final edited = _records.any(
      (record) => record.updatedAt.isAfter(record.recordedAt),
    );
    return '$count symptoms · ${edited ? 'edited today' : 'logged $provenance'}${recalled ? ' · includes earlier date' : ''}';
  }
}

DateTime _healthActivityTime(HealthRecord record) {
  return record.updatedAt.isAfter(record.recordedAt)
      ? record.updatedAt
      : record.recordedAt;
}

class _TodayActivityEntry extends StatelessWidget {
  const _TodayActivityEntry({
    required this.occurredAt,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.detail,
    super.key,
    this.onDelete,
  });

  final DateTime occurredAt;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String detail;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(occurredAt.toLocal()));
    return Material(
      color: LetterColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(LetterRadius.panel),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 36,
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: LetterSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$time · $detail',
                      style: const TextStyle(
                        color: LetterColors.muted,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class StateGrid extends StatelessWidget {
  const StateGrid({
    required this.selectedState,
    required this.onSelected,
    super.key,
  });

  final TodayState? selectedState;
  final ValueChanged<TodayState> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;
        final columns = constraints.maxWidth < 340 ? 2 : 3;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          childAspectRatio: largeText
              ? 1.6
              : columns == 2
              ? 2.05
              : 1.85,
          mainAxisSpacing: LetterSpacing.xs,
          crossAxisSpacing: LetterSpacing.xs,
          children: TodayState.values
              .map(
                (state) => StateButton(
                  state: state,
                  selected: selectedState == state,
                  onPressed: () => onSelected(state),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class StateButton extends StatelessWidget {
  const StateButton({
    required this.state,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final TodayState state;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${state.label} state',
      child: Material(
        color: LetterColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.panel),
          side: BorderSide(
            color: selected
                ? state.foreground.withValues(alpha: 0.5)
                : LetterColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('state-${state.label.toLowerCase()}'),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(state.icon, size: 20, color: state.foreground),
                const SizedBox(height: LetterSpacing.xxs),
                Text(
                  state.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: state.foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
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

class LetterSheetFrame extends StatelessWidget {
  const LetterSheetFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.78,
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: const BoxDecoration(
          color: LetterColors.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: LetterColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: LetterSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Newsreader',
                      fontSize: 25,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: LetterSpacing.xs),
            Text(
              subtitle,
              style: const TextStyle(
                color: LetterColors.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: LetterSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}

String _formatContextDate(BuildContext context, LocalDate date) {
  return MaterialLocalizations.of(
    context,
  ).formatMediumDate(date.asLocalDateTime);
}

String? _buildRangeText(BuildContext context, CyclePrediction? prediction) {
  if (prediction == null) return null;
  final start = _formatContextDate(context, prediction.rangeStart);
  // For low-confidence predictions, only show the start date to avoid
  // confusion from wide uncertainty windows (e.g. "8.1–8.11" looks like
  // an 11-day period, when it's actually a 10-day prediction window).
  if (prediction.confidence == PredictionConfidence.low) {
    return 'around $start';
  }
  final end = _formatContextDate(context, prediction.rangeEnd);
  return '$start – $end';
}

MomentCheckInState _momentState(TodayState state) => switch (state) {
  TodayState.good => MomentCheckInState.good,
  TodayState.steady => MomentCheckInState.steady,
  TodayState.energized => MomentCheckInState.energized,
  TodayState.low => MomentCheckInState.low,
  TodayState.irritable => MomentCheckInState.irritable,
  TodayState.physical => MomentCheckInState.physical,
};

TodayState _todayState(MomentCheckInState state) => switch (state) {
  MomentCheckInState.good => TodayState.good,
  MomentCheckInState.steady ||
  MomentCheckInState.calm ||
  MomentCheckInState.hopeful ||
  MomentCheckInState.tender => TodayState.steady,
  MomentCheckInState.energized => TodayState.energized,
  MomentCheckInState.low => TodayState.low,
  MomentCheckInState.irritable => TodayState.irritable,
  MomentCheckInState.anxious ||
  MomentCheckInState.overwhelmed => TodayState.low,
  MomentCheckInState.exhausted => TodayState.low,
  MomentCheckInState.physical => TodayState.physical,
};

TodayState? _latestTodayState(List<MomentCheckIn> checkIns, LocalDate today) {
  for (final checkIn in checkIns) {
    if (LocalDate.fromDateTime(checkIn.occurredAt.toLocal()) == today) {
      return _todayState(checkIn.state);
    }
  }
  return null;
}

String _careOutcomeLabel(CareOutcome outcome) => switch (outcome) {
  CareOutcome.better => 'Better',
  CareOutcome.same => 'Same',
  CareOutcome.worse => 'Worse',
};

_PastSelfMemory? _buildPastSelfMemory(List<CareRecord> records) {
  final counts = <String, ({String label, int count, DateTime last})>{};
  for (final record in records) {
    if (record.outcome != CareOutcome.better) continue;
    final current = counts[record.actionId];
    counts[record.actionId] = (
      label: record.actionLabel,
      count: (current?.count ?? 0) + 1,
      last: current == null || record.occurredAt.isAfter(current.last)
          ? record.occurredAt
          : current.last,
    );
  }
  if (counts.isEmpty) return null;
  final best = counts.values.reduce((left, right) {
    if (right.count != left.count) {
      return right.count > left.count ? right : left;
    }
    return right.last.isAfter(left.last) ? right : left;
  });
  return _PastSelfMemory(actionLabel: best.label, betterCount: best.count);
}
