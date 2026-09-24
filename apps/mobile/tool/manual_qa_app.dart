import 'package:flutter/material.dart';
import 'package:letter_mobile/config/app_config.dart';
import 'package:letter_mobile/experience/care/care_body_scene.dart';
import 'package:letter_mobile/experience/care/care_boundary_scene.dart';
import 'package:letter_mobile/experience/care/care_animation_port.dart';
import 'package:letter_mobile/experience/care/care_experience.dart';
import 'package:letter_mobile/experience/care/care_focus_scene.dart';
import 'package:letter_mobile/experience/care/care_heavy_scene.dart';
import 'package:letter_mobile/experience/care/care_release_scene.dart';
import 'package:letter_mobile/experience/cycle/cycle_experience.dart';
import 'package:letter_mobile/experience/experience_release_ports.dart';
import 'package:letter_mobile/experience/plus/plus_experience.dart';
import 'package:letter_mobile/experience/reports/reports_experience.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/experience/today/today_experience.dart';
import 'package:letter_mobile/experience/you/you_experience.dart';
import 'package:letter_mobile/features/auth/domain/auth_service.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/check_in/data/in_memory_moment_check_in_repository.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/cycle/domain/bleeding_flow.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/data/revenue_cat_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/domain/entitlement_repository.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/local_backup/domain/local_backup_models.dart';
import 'package:letter_mobile/features/onboarding/presentation/privacy_explainer_sheet.dart';
import 'package:letter_mobile/features/patterns/domain/patterns_experience_data.dart';
import 'package:letter_mobile/features/patterns/presentation/patterns_experience_screen.dart';
import 'package:letter_mobile/features/privacy/domain/privacy_preferences.dart';
import 'package:letter_mobile/features/summary_export/domain/cycle_care_summary.dart';
import 'package:letter_mobile/features/today/today_cycle_ring_model.dart';

const String _captureFrame = String.fromEnvironment(
  'LETTER_CAPTURE_FRAME',
  defaultValue: '',
);

void main() {
  runApp(const _ManualQaApp());
}

class _ManualQaApp extends StatelessWidget {
  const _ManualQaApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ExperienceFoundation.lightTheme(),
      home: _captureSurface(),
    );
  }

  Widget _captureSurface() => switch (_captureFrame) {
    'privacy' => const _PrivacyCaptureSurface(),
    'backup' => Scaffold(
      backgroundColor: ExperienceColors.canvas,
      body: YouExperience(
        port: _QaYouPort(),
        backupPort: const _QaBackupPort(),
        now: () => DateTime(2026, 9, 19, 12),
      ),
    ),
    'report' => ReportsExperience(
      port: _QaReportPort(_reportCaptureInput()),
      canUseClinicianReports: true,
      now: () => DateTime(2026, 9, 19, 12),
    ),
    'care' => Scaffold(
      backgroundColor: ExperienceColors.careSkyBottom,
      body: SafeArea(
        child: CareExperience(
          careMemoryRepository: InMemoryCareMemoryRepository(),
          regionCode: 'US',
          performanceConstrained: true,
          now: () => DateTime(2026, 9, 19, 20, 34),
        ),
      ),
    ),
    'care-heavy' => Scaffold(
      backgroundColor: ExperienceColors.careSkyBottom,
      body: CareHeavyScene(
        motionPreference: CareSceneMotionPreference.staticFallback,
        onSignal: (_) {},
        onComplete: () {},
        onExit: () {},
        onSafety: () {},
      ),
    ),
    'care-focus' => Scaffold(
      backgroundColor: ExperienceColors.careSkyBottom,
      body: CareFocusScene(
        motionPreference: CareSceneMotionPreference.staticFallback,
        onSignal: (_) {},
        onCompleted: () {},
        onExit: () {},
        onSafety: () {},
        initialStepIndex: 2,
      ),
    ),
    'care-space' => Scaffold(
      backgroundColor: ExperienceColors.careSkyBottom,
      body: CareBoundaryScene(
        motionPreference: CareSceneMotionPreference.staticFallback,
        onSignal: (_) {},
        onCompleted: () {},
        onExit: () {},
        onSafety: () {},
        initialStepIndex: 1,
      ),
    ),
    'care-body' => Scaffold(
      backgroundColor: ExperienceColors.careSkyBottom,
      body: CareBodyScene.build(
        motionPreference: CareSceneMotionPreference.staticFallback,
        onSignal: (_) {},
        onCompleted: () {},
        onExit: () {},
        onSafety: () {},
        resumeStepId: CareBodyScene.warmthStepId,
      ),
    ),
    'care-release' => Scaffold(
      backgroundColor: ExperienceColors.careSkyBottom,
      body: CareReleaseScene(
        motionPreference: CareSceneMotionPreference.staticFallback,
        onSignal: (_) {},
        onCompleted: () {},
        onExit: () {},
        onSafety: () {},
        initialStepIndex: 2,
      ),
    ),
    'tracker-today' => const _TrackerCaptureSurface(
      initialDestination: _TrackerDestination.today,
    ),
    'tracker-cycle' => const _TrackerCaptureSurface(
      initialDestination: _TrackerDestination.cycle,
    ),
    'patterns' => PatternsExperienceScreen(data: _patternsCaptureData()),
    _ => const _QaShell(),
  };
}

enum _TrackerDestination { today, cycle }

/// Populated, synthetic-only tracker evidence for App Store capture.
///
/// This uses the production Today and Cycle surfaces and the same repository
/// contracts as the shipped shell. The only capture-specific layer is the
/// deterministic fixture and the production-matching tab bar around it.
class _TrackerCaptureSurface extends StatefulWidget {
  const _TrackerCaptureSurface({required this.initialDestination});

  final _TrackerDestination initialDestination;

  @override
  State<_TrackerCaptureSurface> createState() => _TrackerCaptureSurfaceState();
}

class _TrackerCaptureSurfaceState extends State<_TrackerCaptureSurface> {
  static const LocalDate _today = LocalDate(2026, 9, 19);
  static final DateTime _now = DateTime(2026, 9, 19, 13, 45);

  late final List<PeriodRecord> _periodRows = <PeriodRecord>[
    _period('tracker-may', const LocalDate(2026, 5, 23), 4),
    _period('tracker-june', const LocalDate(2026, 6, 20), 4),
    _period('tracker-july', const LocalDate(2026, 7, 19), 4),
    _period('tracker-august', const LocalDate(2026, 8, 16), 4),
    PeriodRecord(
      id: 'tracker-current',
      startDate: const LocalDate(2026, 9, 15),
      endDate: null,
      createdAt: _now,
      updatedAt: _now,
    ),
  ];
  late final InMemoryPeriodRepository _periods = InMemoryPeriodRepository(
    seed: _periodRows,
    clock: () => _now,
  );
  late final InMemoryHealthRecordRepository _health =
      InMemoryHealthRecordRepository(
        seed: _trackerHealthRows(),
        clock: () => _now,
      );
  late final InMemoryMomentCheckInRepository _checkIns =
      InMemoryMomentCheckInRepository(
        seed: <MomentCheckIn>[
          MomentCheckIn(
            id: 'tracker-today-mood',
            state: MomentCheckInState.tender,
            occurredAt: _now,
            createdAt: _now,
          ),
        ],
        clock: () => _now,
      );
  late final InMemoryCaptureNoteStore _notes = InMemoryCaptureNoteStore();
  late final TodayCycleRingModel _ringModel = TodayCycleRingModel.fromRecords(
    records: _periodRows,
    today: _today,
  );

  late int _index = widget.initialDestination == _TrackerDestination.today
      ? 0
      : 1;
  bool _ready = false;

  static PeriodRecord _period(String id, LocalDate start, int endOffset) {
    return PeriodRecord(
      id: id,
      startDate: start,
      endDate: start.addDays(endOffset),
      createdAt: _now,
      updatedAt: _now,
    );
  }

  static List<HealthRecord> _trackerHealthRows() {
    HealthRecord row(
      String id,
      LocalDate date,
      SymptomType symptom,
      SymptomSeverity severity, {
      Set<FunctionalImpact> impacts = const <FunctionalImpact>{},
    }) => HealthRecord(
      id: id,
      symptom: symptom,
      severity: severity,
      functionalImpacts: impacts,
      experiencedDate: date,
      recordedAt: DateTime.utc(date.year, date.month, date.day, 9),
      updatedAt: DateTime.utc(date.year, date.month, date.day, 9),
      provenance: date == _today
          ? HealthRecordProvenance.sameDay
          : HealthRecordProvenance.laterRecall,
      userConfirmed: true,
      vocabularyVersion: healthRecordVocabularyVersion,
    );

    return <HealthRecord>[
      row(
        'tracker-today-cramps',
        _today,
        SymptomType.cramps,
        SymptomSeverity.moderate,
        impacts: const <FunctionalImpact>{FunctionalImpact.workOrSchool},
      ),
      row(
        'tracker-today-energy',
        _today,
        SymptomType.lowEnergy,
        SymptomSeverity.severe,
        impacts: const <FunctionalImpact>{
          FunctionalImpact.homeResponsibilities,
        },
      ),
      row(
        'tracker-today-sensitive',
        _today,
        SymptomType.hypersensitivity,
        SymptomSeverity.mild,
      ),
      row(
        'tracker-sep-18-headache',
        const LocalDate(2026, 9, 18),
        SymptomType.headache,
        SymptomSeverity.mild,
      ),
      row(
        'tracker-sep-17-back',
        const LocalDate(2026, 9, 17),
        SymptomType.backPain,
        SymptomSeverity.moderate,
      ),
      row(
        'tracker-sep-16-cramps',
        const LocalDate(2026, 9, 16),
        SymptomType.cramps,
        SymptomSeverity.severe,
        impacts: const <FunctionalImpact>{FunctionalImpact.sleep},
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _seedFacts();
  }

  Future<void> _seedFacts() async {
    for (final entry in <(String, LocalDate, BleedingFlow, BleedingColor)>[
      (
        'tracker-august',
        const LocalDate(2026, 8, 16),
        BleedingFlow.medium,
        BleedingColor.brightRed,
      ),
      (
        'tracker-august',
        const LocalDate(2026, 8, 17),
        BleedingFlow.heavy,
        BleedingColor.darkRed,
      ),
      (
        'tracker-august',
        const LocalDate(2026, 8, 18),
        BleedingFlow.medium,
        BleedingColor.darkRed,
      ),
      (
        'tracker-august',
        const LocalDate(2026, 8, 19),
        BleedingFlow.light,
        BleedingColor.brown,
      ),
      (
        'tracker-current',
        const LocalDate(2026, 9, 15),
        BleedingFlow.medium,
        BleedingColor.brightRed,
      ),
      (
        'tracker-current',
        const LocalDate(2026, 9, 16),
        BleedingFlow.heavy,
        BleedingColor.darkRed,
      ),
      (
        'tracker-current',
        const LocalDate(2026, 9, 17),
        BleedingFlow.medium,
        BleedingColor.darkRed,
      ),
      (
        'tracker-current',
        const LocalDate(2026, 9, 18),
        BleedingFlow.light,
        BleedingColor.brown,
      ),
      ('tracker-current', _today, BleedingFlow.light, BleedingColor.brown),
    ]) {
      await _periods.setFlow(entry.$1, entry.$2, entry.$3, today: _today);
      await _periods.setBleedingColor(entry.$1, entry.$2, entry.$4);
    }
    await _notes.save(
      CaptureNote(
        id: 'tracker-note',
        text: 'Kept the evening quiet and used a heating pad.',
        source: CaptureSource.typed,
        createdAt: _now,
      ),
    );
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: ExperienceColors.canvas,
        body: Center(child: EmberLoadingIndicator(semanticLabel: 'Loading')),
      );
    }

    final pages = <Widget>[
      TodayExperience(
        periodRepository: _periods,
        checkInRepository: _checkIns,
        healthRecordRepository: _health,
        captureNoteStore: _notes,
        today: () => _today,
        now: () => _now,
        onOpenCare: () {},
        onOpenCycleDayEditor: () async => setState(() => _index = 1),
        onOpenCycleBackfill: () => setState(() => _index = 1),
        onCycleDataChanged: () {},
        loadSupportActionPatterns: () async => const [],
      ),
      CycleExperience(
        periodRepository: _periods,
        healthRecordRepository: _health,
        careMemoryRepository: InMemoryCareMemoryRepository(),
        onCycleDataChanged: () {},
        ringModel: _ringModel,
        now: _now,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        height: 80,
        backgroundColor: ExperienceColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: ExperienceColors.emberSoft.withValues(alpha: 0.45),
        selectedIndex: _index,
        onDestinationSelected: (value) {
          if (value < 2) setState(() => _index = value);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.water_drop_outlined),
            selectedIcon: Icon(Icons.water_drop),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.radio_button_unchecked),
            selectedIcon: Icon(Icons.radio_button_checked),
            label: 'Cycle',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            label: 'Care',
          ),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Patterns'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'You'),
        ],
      ),
    );
  }
}

/// Native capture surface for the App Store privacy frame.
///
/// This deliberately renders the production privacy explainer rather than a
/// screenshot-only imitation. No account, health record, or network service
/// is involved.
class _PrivacyCaptureSurface extends StatelessWidget {
  const _PrivacyCaptureSurface();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ExperienceColors.canvas,
      body: SafeArea(child: PrivacyExplainerSheet()),
    );
  }
}

SummaryExportInput _reportCaptureInput() {
  const starts = <LocalDate>[
    LocalDate(2026, 6, 20),
    LocalDate(2026, 7, 19),
    LocalDate(2026, 8, 16),
    LocalDate(2026, 9, 15),
  ];
  final periodDays = <SummaryPeriodDay>[
    for (final start in starts)
      for (var day = 0; day < 5; day++) SummaryPeriodDay(start.addDays(day)),
  ];
  final records = <HealthRecord>[];
  for (var index = 0; index < starts.length; index++) {
    final start = starts[index];
    for (final entry in <(String, SymptomType, int, SymptomSeverity)>[
      ('irritability-5', SymptomType.irritability, -5, SymptomSeverity.mild),
      (
        'irritability-3',
        SymptomType.irritability,
        -3,
        SymptomSeverity.moderate,
      ),
      ('irritability-1', SymptomType.irritability, -1, SymptomSeverity.severe),
      ('anxiety-4', SymptomType.anxiety, -4, SymptomSeverity.mild),
      ('anxiety-2', SymptomType.anxiety, -2, SymptomSeverity.moderate),
      ('energy-3', SymptomType.lowEnergy, -3, SymptomSeverity.mild),
      ('energy-1', SymptomType.lowEnergy, -1, SymptomSeverity.moderate),
      ('energy+1', SymptomType.lowEnergy, 1, SymptomSeverity.mild),
      ('cramps-1', SymptomType.cramps, -1, SymptomSeverity.mild),
      ('cramps-0', SymptomType.cramps, 0, SymptomSeverity.severe),
      ('cramps+1', SymptomType.cramps, 1, SymptomSeverity.moderate),
      ('cramps+2', SymptomType.cramps, 2, SymptomSeverity.mild),
    ]) {
      final date = start.addDays(entry.$3);
      final recordedAt = DateTime.utc(date.year, date.month, date.day, 9);
      records.add(
        HealthRecord(
          id: 'report-${entry.$1}-$index',
          symptom: entry.$2,
          severity: entry.$4,
          functionalImpacts: entry.$2 == SymptomType.cramps
              ? const <FunctionalImpact>{}
              : const <FunctionalImpact>{FunctionalImpact.workOrSchool},
          experiencedDate: date,
          recordedAt: recordedAt,
          updatedAt: recordedAt,
          provenance: HealthRecordProvenance.sameDay,
          userConfirmed: true,
          vocabularyVersion: healthRecordVocabularyVersion,
        ),
      );
    }
  }
  return SummaryExportInput(
    periodDays: periodDays,
    predictions: const <SummaryPredictionRange>[],
    healthRecords: records,
    checkIns: <MomentCheckIn>[
      MomentCheckIn(
        id: 'report-check-in',
        state: MomentCheckInState.irritable,
        occurredAt: DateTime.utc(2026, 9, 12, 9),
        createdAt: DateTime.utc(2026, 9, 12, 9),
      ),
    ],
    careRecords: const [],
    notes: const <SummarySelectableNote>[
      SummarySelectableNote(
        id: 'report-note',
        date: LocalDate(2026, 9, 12),
        label: 'Your reflection',
        text: 'A quieter evening helped me reset.',
        sourceLabel: 'Saved Care reflection · local only',
      ),
    ],
  );
}

PatternsExperienceData _patternsCaptureData() {
  const starts = <LocalDate>[
    LocalDate(2026, 5, 23),
    LocalDate(2026, 6, 20),
    LocalDate(2026, 7, 19),
    LocalDate(2026, 8, 16),
    LocalDate(2026, 9, 15),
  ];
  final cycles = <PatternsCompletedCycle>[
    for (var index = 0; index < starts.length - 1; index++)
      PatternsCompletedCycle(
        periodId: 'pattern-period-$index',
        startDate: starts[index],
        nextStartDate: starts[index + 1],
        bleedingEndDate: starts[index].addDays(4),
        flowDays: <PatternsFlowDay>[
          PatternsFlowDay(
            date: starts[index],
            flow: BleedingFlow.medium,
            color: BleedingColor.brightRed,
          ),
          PatternsFlowDay(
            date: starts[index].addDays(1),
            flow: BleedingFlow.heavy,
            color: BleedingColor.darkRed,
          ),
          PatternsFlowDay(
            date: starts[index].addDays(2),
            flow: BleedingFlow.medium,
            color: BleedingColor.darkRed,
          ),
          PatternsFlowDay(
            date: starts[index].addDays(3),
            flow: BleedingFlow.light,
            color: BleedingColor.brown,
          ),
        ],
      ),
  ];
  final symptoms = <PatternsSymptomRecord>[];
  final moods = <PatternsMoodRecord>[];
  final care = <PatternsCareRecord>[];
  for (var index = 1; index < starts.length; index++) {
    final start = starts[index];
    symptoms.addAll(<PatternsSymptomRecord>[
      PatternsSymptomRecord(
        id: 'pattern-irritability-$index',
        date: start.addDays(-3),
        category: PatternsSymptomCategory.emotions,
        label: 'Irritability',
        severity: index.isEven
            ? SymptomSeverity.severe
            : SymptomSeverity.moderate,
      ),
      PatternsSymptomRecord(
        id: 'pattern-energy-$index',
        date: start.addDays(-2),
        category: PatternsSymptomCategory.energyAndSleep,
        label: 'Low energy',
        severity: SymptomSeverity.moderate,
      ),
      PatternsSymptomRecord(
        id: 'pattern-cramps-$index',
        date: start,
        category: PatternsSymptomCategory.pain,
        label: 'Cramps',
        severity: SymptomSeverity.moderate,
      ),
    ]);
    moods.add(
      PatternsMoodRecord(
        id: 'pattern-mood-$index',
        date: start.addDays(-2),
        label: 'Irritable',
        tone: PatternsMoodTone.difficult,
        harderCategory: PatternsSymptomCategory.emotions,
      ),
    );
    care.add(
      PatternsCareRecord(
        id: 'pattern-care-$index',
        date: start.addDays(-2),
        actionLabel: 'Apply warmth',
        outcome: index == 1 ? CareOutcome.same : CareOutcome.better,
        reflection: 'Warmth and a quieter evening helped.',
      ),
    );
  }
  care.addAll(<PatternsCareRecord>[
    PatternsCareRecord(
      id: 'pattern-care-quiet-1',
      date: starts[2].addDays(-3),
      actionLabel: 'Quiet presence',
      outcome: CareOutcome.better,
      reflection: 'Ten quiet minutes made the evening feel less crowded.',
    ),
    PatternsCareRecord(
      id: 'pattern-care-quiet-2',
      date: starts[3].addDays(-2),
      actionLabel: 'Quiet presence',
      outcome: CareOutcome.same,
      reflection: 'It gave me room to pause.',
    ),
    PatternsCareRecord(
      id: 'pattern-care-quiet-3',
      date: starts[4].addDays(-3),
      actionLabel: 'Quiet presence',
      outcome: CareOutcome.better,
      reflection: 'A little less input helped.',
    ),
    PatternsCareRecord(
      id: 'pattern-care-movement-1',
      date: starts[3].addDays(-1),
      actionLabel: 'Gentle movement',
      outcome: CareOutcome.better,
      reflection: 'Moving slowly eased some tension.',
    ),
    PatternsCareRecord(
      id: 'pattern-care-movement-2',
      date: starts[4].addDays(-2),
      actionLabel: 'Gentle movement',
      outcome: CareOutcome.same,
      reflection: 'It helped me notice what I needed.',
    ),
    PatternsCareRecord(
      id: 'pattern-care-breathe-1',
      date: starts[3].addDays(-3),
      actionLabel: 'Breathe with me',
      outcome: CareOutcome.same,
      reflection: 'A short rhythm helped me slow down.',
    ),
    PatternsCareRecord(
      id: 'pattern-care-breathe-2',
      date: starts[4].addDays(-1),
      actionLabel: 'Breathe with me',
      outcome: CareOutcome.better,
      reflection: 'I felt more settled afterward.',
    ),
  ]);
  return PatternsExperienceData(
    completedCycles: cycles,
    currentCycle: PatternsCurrentCycle(
      periodId: 'pattern-current',
      startDate: starts.last,
      bleedingEndDate: starts.last.addDays(4),
      flowDays: const <PatternsFlowDay>[
        PatternsFlowDay(
          date: LocalDate(2026, 9, 15),
          flow: BleedingFlow.medium,
          color: BleedingColor.brightRed,
        ),
        PatternsFlowDay(
          date: LocalDate(2026, 9, 16),
          flow: BleedingFlow.heavy,
          color: BleedingColor.darkRed,
        ),
      ],
    ),
    symptoms: symptoms,
    moods: moods,
    care: care,
    today: const LocalDate(2026, 9, 19),
  );
}

class _QaShell extends StatefulWidget {
  const _QaShell();

  @override
  State<_QaShell> createState() => _QaShellState();
}

class _QaShellState extends State<_QaShell> {
  static const LocalDate _today = LocalDate(2026, 9, 19);
  static final DateTime _now = DateTime(2026, 9, 19, 12);

  late final InMemoryPeriodRepository _periods = InMemoryPeriodRepository(
    seed: <PeriodRecord>[
      PeriodRecord(
        id: 'qa-may',
        startDate: const LocalDate(2026, 5, 23),
        endDate: const LocalDate(2026, 5, 27),
        createdAt: _now,
        updatedAt: _now,
      ),
      PeriodRecord(
        id: 'qa-june',
        startDate: const LocalDate(2026, 6, 20),
        endDate: const LocalDate(2026, 6, 24),
        createdAt: _now,
        updatedAt: _now,
      ),
      PeriodRecord(
        id: 'qa-july',
        startDate: const LocalDate(2026, 7, 19),
        endDate: const LocalDate(2026, 7, 23),
        createdAt: _now,
        updatedAt: _now,
      ),
      PeriodRecord(
        id: 'qa-august',
        startDate: const LocalDate(2026, 8, 16),
        endDate: const LocalDate(2026, 8, 20),
        createdAt: _now,
        updatedAt: _now,
      ),
      PeriodRecord(
        id: 'qa-current',
        startDate: const LocalDate(2026, 9, 15),
        endDate: null,
        createdAt: _now,
        updatedAt: _now,
      ),
    ],
  );
  late final InMemoryHealthRecordRepository _health =
      InMemoryHealthRecordRepository(
        seed: <HealthRecord>[
          HealthRecord(
            id: 'qa-back-pain',
            symptom: SymptomType.backPain,
            severity: SymptomSeverity.minimal,
            functionalImpacts: const <FunctionalImpact>{},
            experiencedDate: _today,
            recordedAt: _now,
            updatedAt: _now,
            provenance: HealthRecordProvenance.sameDay,
            userConfirmed: true,
            vocabularyVersion: healthRecordVocabularyVersion,
          ),
        ],
      );
  late final EntitlementRepository _entitlement =
      AppConfig.fromEnvironment.revenueCatAppleApiKey.isEmpty
      ? LocalEntitlementRepository()
      : RevenueCatEntitlementRepository(
          appUserId: '00000000-0000-4000-8000-000000000019',
          appleApiKey: AppConfig.fromEnvironment.revenueCatAppleApiKey,
          googleApiKey: '',
          store: RevenueCatStore.apple,
        );

  int _index = 0;

  @override
  void dispose() {
    _entitlement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      CycleExperience(
        periodRepository: _periods,
        healthRecordRepository: _health,
        careMemoryRepository: InMemoryCareMemoryRepository(),
        onCycleDataChanged: () {},
        now: _now,
      ),
      SafeArea(
        bottom: false,
        child: PlusExperience(entitlementRepository: _entitlement),
      ),
      ReportsExperience(
        port: _QaReportPort(
          SummaryExportInput(
            periodDays: const <SummaryPeriodDay>[SummaryPeriodDay(_today)],
            predictions: const [],
            healthRecords: const [],
            checkIns: <MomentCheckIn>[
              MomentCheckIn(
                id: 'qa-yesterday-mood',
                state: MomentCheckInState.steady,
                occurredAt: _now.subtract(const Duration(days: 1)),
                createdAt: _now.subtract(const Duration(days: 1)),
              ),
            ],
            careRecords: const [],
            notes: const [],
          ),
        ),
        now: () => _now,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.water_drop), label: 'Cycle'),
          NavigationDestination(icon: Icon(Icons.add_circle), label: 'Plus'),
          NavigationDestination(icon: Icon(Icons.description), label: 'Report'),
        ],
      ),
    );
  }
}

class _QaReportPort implements ReportExperiencePort {
  const _QaReportPort(this.input);

  final SummaryExportInput input;

  @override
  Future<SummaryExportInput> load() async => input;

  @override
  Future<ExperienceFileReceipt> export({
    required SummaryDateRange range,
    required Set<String> selectedNoteIds,
    required ReportExportFormat format,
  }) async =>
      const ExperienceFileReceipt(outcome: ExperienceFileOutcome.savedOnly);
}

class _QaYouPort implements YouExperiencePort {
  @override
  AuthState get account => const AuthState(
    status: AuthStatus.authenticated,
    userId: '00000000-0000-4000-8000-000000000019',
    email: 'you@example.com',
  );

  @override
  PrivacyPreferences get privacy => const PrivacyPreferences();

  @override
  Stream<AuthState> watchAccount() => Stream<AuthState>.value(account);

  @override
  Future<void> savePrivacy(PrivacyPreferences preferences) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteServerAccount() async {}
}

class _QaBackupPort implements BackupExperiencePort {
  const _QaBackupPort();

  @override
  String get localDestinationDescription => 'your Letter folder';

  @override
  Future<bool> hasStoredPassphrase() async => false;

  @override
  Future<ExperienceFileReceipt> exportEncrypted({
    required String passphrase,
    required bool rememberPassphrase,
  }) async => const ExperienceFileReceipt(
    outcome: ExperienceFileOutcome.savedOnly,
    localPath: 'Letter/letter-backup-2026-09-19.letter',
  );

  @override
  Future<LocalBackupImportPreview?> prepareImport({
    required String passphrase,
    required LocalBackupImportPolicy policy,
  }) async => null;

  @override
  Future<void> commitPreparedImport() async {}

  @override
  Future<void> discardPreparedImport() async {}
}
