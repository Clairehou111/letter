import 'package:flutter/material.dart';
import 'package:letter_mobile/config/app_config.dart';
import 'package:letter_mobile/experience/cycle/cycle_experience.dart';
import 'package:letter_mobile/experience/experience_release_ports.dart';
import 'package:letter_mobile/experience/plus/plus_experience.dart';
import 'package:letter_mobile/experience/reports/reports_experience.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/data/revenue_cat_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/domain/entitlement_repository.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/onboarding/presentation/privacy_explainer_sheet.dart';
import 'package:letter_mobile/features/summary_export/domain/cycle_care_summary.dart';

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
      home: _captureFrame == 'privacy'
          ? const _PrivacyCaptureSurface()
          : _captureFrame == 'report'
          ? ReportsExperience(
              port: _QaReportPort(_reportCaptureInput()),
              canUseClinicianReports: true,
              now: () => DateTime(2026, 9, 19, 12),
            )
          : const _QaShell(),
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
    LocalDate(2026, 6, 22),
    LocalDate(2026, 7, 20),
    LocalDate(2026, 8, 17),
    LocalDate(2026, 9, 14),
  ];
  final periodDays = <SummaryPeriodDay>[
    for (final start in starts)
      for (var day = 0; day < 5; day++) SummaryPeriodDay(start.addDays(day)),
  ];
  final records = <HealthRecord>[
    for (var index = 0; index < starts.length; index++)
      HealthRecord(
        id: 'report-anxiety-$index',
        symptom: SymptomType.anxiety,
        severity: index.isEven
            ? SymptomSeverity.moderate
            : SymptomSeverity.severe,
        functionalImpacts: const <FunctionalImpact>{
          FunctionalImpact.workOrSchool,
        },
        experiencedDate: starts[index].addDays(-3),
        recordedAt: DateTime.utc(
          2026,
          starts[index].month,
          starts[index].day,
        ).subtract(const Duration(days: 3)),
        updatedAt: DateTime.utc(
          2026,
          starts[index].month,
          starts[index].day,
        ).subtract(const Duration(days: 3)),
        provenance: HealthRecordProvenance.sameDay,
        userConfirmed: true,
        vocabularyVersion: healthRecordVocabularyVersion,
      ),
    HealthRecord(
      id: 'report-cramps',
      symptom: SymptomType.cramps,
      severity: SymptomSeverity.mild,
      functionalImpacts: const <FunctionalImpact>{},
      experiencedDate: const LocalDate(2026, 9, 14),
      recordedAt: DateTime.utc(2026, 9, 14, 9),
      updatedAt: DateTime.utc(2026, 9, 14, 9),
      provenance: HealthRecordProvenance.sameDay,
      userConfirmed: true,
      vocabularyVersion: healthRecordVocabularyVersion,
    ),
  ];
  return SummaryExportInput(
    periodDays: periodDays,
    predictions: const <SummaryPredictionRange>[],
    healthRecords: records,
    checkIns: <MomentCheckIn>[
      MomentCheckIn(
        id: 'report-check-in',
        state: MomentCheckInState.irritable,
        occurredAt: DateTime.utc(2026, 9, 11, 9),
        createdAt: DateTime.utc(2026, 9, 11, 9),
      ),
    ],
    careRecords: const [],
    notes: const <SummarySelectableNote>[
      SummarySelectableNote(
        id: 'report-note',
        date: LocalDate(2026, 9, 11),
        label: 'Your reflection',
        text: 'A quieter evening helped me reset.',
        sourceLabel: 'Saved Care reflection · local only',
      ),
    ],
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
        id: 'qa-current',
        startDate: _today,
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
