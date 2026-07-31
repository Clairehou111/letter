import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design_system/letter_bottom_navigation.dart';
import '../../design_system/letter_theme.dart';
import '../cycle/domain/cycle_prediction.dart';
import '../cycle/domain/local_date.dart';
import '../cycle/domain/period_record.dart';
import '../cycle/domain/period_repository.dart';
import '../capture/application/text_voice_capture_controller.dart';
import '../capture/domain/capture_models.dart';
import '../capture/domain/speech_to_text_adapter.dart';
import '../capture/presentation/text_voice_capture_flow.dart';
import '../health_records/domain/health_record_repository.dart';
import '../health_records/presentation/health_records_screen.dart';
import '../insights/presentation/gravity_horizon.dart';
import '../insights/presentation/gravity_horizon_view_model.dart';
import 'today_cycle_context.dart';

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
}

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    required this.repository,
    super.key,
    this.onNavigationSelected,
    this.now,
    this.healthRecordRepository,
    this.captureNoteStore,
  });

  final PeriodRepository repository;
  final ValueChanged<int>? onNavigationSelected;
  final DateTime Function()? now;
  final HealthRecordRepository? healthRecordRepository;
  final CaptureNoteStore? captureNoteStore;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  TodayState? selectedState;
  List<PeriodRecord> _records = const [];
  bool _loading = true;
  bool _loadFailed = false;

  LocalDate get _today =>
      LocalDate.fromDateTime((widget.now ?? DateTime.now)());

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

  Future<void> _openStateSheet(TodayState state) async {
    setState(() => selectedState = state);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: LetterColors.ink.withValues(alpha: 0.35),
      builder: (context) => StateDetailSheet(state: state),
    );
  }

  void _openCare() {
    widget.onNavigationSelected?.call(3);
  }

  Future<void> _openHealthRecords() async {
    final repository = widget.healthRecordRepository;
    if (repository == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            HealthRecordsScreen(repository: repository, now: widget.now),
      ),
    );
  }

  Future<void> _openCapture() async {
    final noteStore = widget.captureNoteStore;
    if (noteStore == null) {
      return;
    }
    final controller = TextVoiceCaptureController(
      speechAdapter: const UnsupportedSpeechToTextAdapter(),
      noteStore: noteStore,
      clock: widget.now,
    );
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => TextVoiceCaptureFlow(controller: controller),
        ),
      );
    } finally {
      controller.dispose();
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
      await _openStateSheet(state);
    }
  }

  CyclePrediction? get _prediction =>
      CyclePredictionEngine.calculate(_records);

  Widget _buildGravityHorizon(BuildContext context, CyclePrediction? prediction) {
    if (prediction == null) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    final cycleContext = TodayCycleContext.fromRecords(
      records: _records,
      today: _today,
    );
    return SizedBox(
      height: 280,
      child: GravityHorizonView(
        viewModel: GravityHorizonViewModel.fromPrediction(
          prediction: prediction,
          today: _today,
          cycleDay: cycleContext.dayNumber,
          availableWidth: size.width - 36,
          availableHeight: 280,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prediction = _prediction;
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
                            AppHeader(onLog: _openQuickStateSheet),
                            const SizedBox(height: LetterSpacing.md),
                            CycleHero(
                              cycleContext: TodayCycleContext.fromRecords(
                                records: _records,
                                today: _today,
                              ),
                              onOpenCycle: () =>
                                  widget.onNavigationSelected?.call(0),
                            ),
                            const SizedBox(height: LetterSpacing.xl),
                            TodayCareEntry(onOpenCare: _openCare),
                            const SizedBox(height: LetterSpacing.xl),
                            _buildGravityHorizon(context, prediction),
                            if (prediction != null)
                              const SizedBox(height: LetterSpacing.xl),
                            if (widget.healthRecordRepository != null) ...[
                              TodayHealthRecordEntry(
                                onOpenRecords: _openHealthRecords,
                              ),
                              const SizedBox(height: LetterSpacing.xl),
                            ],
                            if (widget.captureNoteStore != null) ...[
                              TodayCaptureEntry(onOpenCapture: _openCapture),
                              const SizedBox(height: LetterSpacing.xl),
                            ],
                            const LetterSectionTitle(
                              eyebrow: 'A quick check-in',
                              title: 'How are you right now?',
                            ),
                            const SizedBox(height: LetterSpacing.sm),
                            StateGrid(
                              selectedState: selectedState,
                              onSelected: _openStateSheet,
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
          'Choose one starting point. Nothing is saved to your health record yet.',
      child: StateGrid(
        selectedState: selectedState,
        onSelected: (state) => Navigator.pop(context, state),
      ),
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({required this.onLog, super.key});

  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.textScalerOf(context).scale(1) > 1.45 &&
        MediaQuery.sizeOf(context).width < 360;

    return SizedBox(
      height: 54,
      child: Row(
        children: [
          if (!compact) ...[
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                color: LetterColors.teal,
                borderRadius: BorderRadius.circular(LetterRadius.control),
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 17,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: LetterSpacing.sm),
          ],
          Text(
            'LETTER',
            style: TextStyle(
              fontFamily: 'Newsreader',
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.w900,
              letterSpacing: compact ? 0.8 : 2.1,
            ),
          ),
          const Spacer(),
          if (compact)
            IconButton.outlined(
              key: const Key('header-log-button'),
              tooltip: 'Log today',
              onPressed: onLog,
              icon: const Icon(Icons.add),
            )
          else
            OutlinedButton.icon(
              key: const Key('header-log-button'),
              onPressed: onLog,
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
                'Log',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
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
    final range = prediction == null
        ? null
        : '${_formatContextDate(context, prediction.rangeStart)} - '
              '${_formatContextDate(context, prediction.rangeEnd)}';
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
        'Cycle day ${cycleContext.dayNumber}. Letter needs two complete '
            'cycle intervals before estimating a range.',
      TodayCycleKind.betweenPeriods
          when timing == PredictionTiming.currentWindow =>
        'Cycle day ${cycleContext.dayNumber}. Today falls within $range.',
      TodayCycleKind.betweenPeriods
          when timing == PredictionTiming.laterThanEstimate =>
        'Cycle day ${cycleContext.dayNumber}. The recorded estimate was $range.',
      TodayCycleKind.betweenPeriods =>
        'Cycle day ${cycleContext.dayNumber}. Estimated next period: $range.',
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
                'Open Cycle',
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
      padding: const EdgeInsets.all(LetterSpacing.md),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_outlined, color: LetterColors.teal),
              const SizedBox(width: LetterSpacing.sm),
              const Expanded(
                child: Text(
                  'Record what your body is telling you',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: LetterSpacing.xs),
          const Text(
            'Choose a symptom and its intensity when you are ready. '
            'Nothing is inferred from Care.',
            style: TextStyle(color: LetterColors.muted, fontSize: 12),
          ),
          const SizedBox(height: LetterSpacing.sm),
          OutlinedButton.icon(
            key: const Key('open-health-records'),
            onPressed: onOpenRecords,
            icon: const Icon(Icons.add),
            label: const Text('Open health record'),
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
        color: state.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.panel),
          side: BorderSide(
            color: selected ? state.foreground : Colors.transparent,
            width: 2,
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

class StateDetailSheet extends StatefulWidget {
  const StateDetailSheet({required this.state, super.key});

  final TodayState state;

  @override
  State<StateDetailSheet> createState() => _StateDetailSheetState();
}

class _StateDetailSheetState extends State<StateDetailSheet> {
  static const painOptions = [
    'Pelvic cramps',
    'Lower back pain',
    'Headache',
    'Breast tenderness',
    'Joint or muscle pain',
    'Other pelvic pain',
  ];
  final Map<String, String> painRatings = {};
  String selectedSeverity = 'Moderate';
  String? activePain;

  void _togglePain(String pain) {
    setState(() {
      if (painRatings.containsKey(pain)) {
        painRatings.remove(pain);
        if (activePain == pain) {
          activePain = painRatings.keys.firstOrNull;
        }
      } else {
        painRatings[pain] = 'Moderate';
        activePain = pain;
      }
    });
  }

  void _setSeverity(String severity) {
    setState(() {
      selectedSeverity = severity;
      if (activePain != null) {
        painRatings[activePain!] = severity;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPhysical = widget.state == TodayState.physical;
    final activeSeverity = activePain == null
        ? selectedSeverity
        : painRatings[activePain]!;

    return LetterSheetFrame(
      title: isPhysical
          ? 'Where does your body hurt?'
          : 'How ${widget.state.label.toLowerCase()} do you feel?',
      subtitle: isPhysical
          ? 'Choose every pain that applies. This is not saved to your '
                'health record yet.'
          : 'One tap is enough. This is not saved to your health record yet.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPhysical) ...[
            Wrap(
              spacing: LetterSpacing.xs,
              runSpacing: LetterSpacing.xs,
              children: painOptions.map((pain) {
                final selected = painRatings.containsKey(pain);
                return Semantics(
                  selected: selected,
                  button: true,
                  label: '$pain pain location',
                  child: FilterChip(
                    key: Key('pain-${pain.toLowerCase().replaceAll(' ', '-')}'),
                    label: Text(pain),
                    selected: selected,
                    onSelected: (_) => _togglePain(pain),
                    showCheckmark: false,
                    avatar: Icon(
                      selected ? Icons.check : Icons.add,
                      size: 17,
                      color: selected ? Colors.white : LetterColors.violet,
                    ),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : LetterColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    backgroundColor: LetterColors.violetSoft,
                    selectedColor: LetterColors.violet,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LetterRadius.control),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: LetterSpacing.lg),
            LetterEyebrow(
              activePain == null
                  ? 'Select a pain to rate it'
                  : 'Severity for $activePain',
            ),
          ] else
            const LetterEyebrow('Severity'),
          const SizedBox(height: LetterSpacing.sm),
          SeveritySelector(
            selected: activeSeverity,
            enabled: !isPhysical || activePain != null,
            onSelected: _setSeverity,
          ),
          if (isPhysical && painRatings.length > 1) ...[
            const SizedBox(height: LetterSpacing.md),
            Text(
              '${painRatings.length} pain locations added',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LetterColors.violet,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: LetterSpacing.lg),
          FilledButton(
            onPressed: !isPhysical || painRatings.isNotEmpty
                ? () => Navigator.of(context).pop()
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: LetterColors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LetterRadius.control),
              ),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class SeveritySelector extends StatelessWidget {
  const SeveritySelector({
    required this.selected,
    required this.enabled,
    required this.onSelected,
    super.key,
  });

  final String selected;
  final bool enabled;
  final ValueChanged<String> onSelected;

  static const options = ['Mild', 'Moderate', 'Strong', 'Severe'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: LetterColors.canvas,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.control),
      ),
      child: Row(
        children: options.map((option) {
          final isSelected = option == selected;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              enabled: enabled,
              label: '$option severity',
              child: InkWell(
                key: Key('severity-${option.toLowerCase()}'),
                onTap: enabled ? () => onSelected(option) : null,
                borderRadius: BorderRadius.circular(5),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected && enabled
                        ? LetterColors.teal
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    option,
                    maxLines: 1,
                    style: TextStyle(
                      color: !enabled
                          ? LetterColors.muted.withValues(alpha: 0.55)
                          : isSelected
                          ? Colors.white
                          : LetterColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
