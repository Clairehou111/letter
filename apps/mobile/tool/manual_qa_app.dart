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
import 'package:letter_mobile/features/summary_export/domain/cycle_care_summary.dart';

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
      home: const _QaShell(),
    );
  }
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
