import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/experience_release_ports.dart';
import 'package:letter_mobile/experience/plus/plus_experience.dart';
import 'package:letter_mobile/experience/reports/reports_experience.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/analytics/domain/analytics_service.dart';
import 'package:letter_mobile/features/analytics/presentation/analytics_scope.dart';
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/data/revenue_cat_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/domain/entitlement.dart';
import 'package:letter_mobile/features/entitlement/domain/entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/presentation/entitlement_scope.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/summary_export/domain/cycle_care_summary.dart';

void main() {
  Future<void> pumpReport(
    WidgetTester tester,
    SummaryExportInput input, {
    Future<PlusCommitResult?> Function(PlusOutcomeContext)? onOpenPlus,
    ReportExperiencePort? port,
    VoidCallback? onOpenCycle,
    bool canUseClinicianReports = false,
    EntitlementRepository? entitlementRepository,
    bool hasPlusPreviewAccess = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final report = ReportsExperience(
      port: port ?? _Port(input),
      now: () => DateTime(2026, 8, 14, 12),
      onOpenPlusWithContext: onOpenPlus,
      onOpenCycle: onOpenCycle,
      canUseClinicianReports: canUseClinicianReports,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: entitlementRepository == null
            ? report
            : EntitlementScope(
                repository: entitlementRepository,
                hasPlusPreviewAccess: hasPlusPreviewAccess,
                child: report,
              ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('zero completed cycles has no matrix or acquisition', (
    tester,
  ) async {
    var cycleOpened = false;
    await pumpReport(tester, _input(0), onOpenCycle: () => cycleOpened = true);
    expect(
      find.textContaining('One completed cycle is needed'),
      findsOneWidget,
    );
    expect(find.text('Cyclical symptom matrix'), findsNothing);
    expect(find.text('Export this report — included with Plus'), findsNothing);
    final openCycle = find.byKey(const Key('reports-empty-open-cycle'));
    await _reveal(tester, openCycle);
    await tester.tap(openCycle);
    expect(cycleOpened, isTrue);
  });

  testWidgets(
    'zero completed cycles shows health facts without a check-in ledger',
    (tester) async {
      final recordedAt = DateTime.utc(2026, 8, 10, 12);
      await pumpReport(
        tester,
        _input(
          1,
          healthRecords: <HealthRecord>[
            HealthRecord(
              id: 'crying',
              symptom: SymptomType.crying,
              severity: SymptomSeverity.severe,
              functionalImpacts: const <FunctionalImpact>{},
              experiencedDate: const LocalDate(2026, 8, 10),
              recordedAt: recordedAt,
              updatedAt: recordedAt,
              provenance: HealthRecordProvenance.sameDay,
              userConfirmed: true,
              vocabularyVersion: healthRecordVocabularyVersion,
            ),
          ],
          checkIns: <MomentCheckIn>[
            MomentCheckIn(
              id: 'overwhelmed',
              state: MomentCheckInState.overwhelmed,
              occurredAt: recordedAt,
              createdAt: recordedAt,
            ),
          ],
        ),
      );

      await _reveal(tester, find.textContaining('Crying · Severe'));
      expect(find.textContaining('Crying · Severe'), findsOneWidget);
      expect(find.textContaining('Overwhelmed'), findsNothing);
      expect(find.text('Check-ins'), findsNothing);
    },
  );

  testWidgets('report readiness counts period days, not unrelated check-ins', (
    tester,
  ) async {
    await pumpReport(
      tester,
      SummaryExportInput(
        periodDays: const <SummaryPeriodDay>[
          SummaryPeriodDay(LocalDate(2026, 8, 14)),
        ],
        predictions: const [],
        healthRecords: const [],
        checkIns: <MomentCheckIn>[
          MomentCheckIn(
            id: 'yesterday-mood',
            state: MomentCheckInState.steady,
            occurredAt: DateTime(2026, 8, 13, 12),
            createdAt: DateTime(2026, 8, 13, 12),
          ),
        ],
        careRecords: const [],
        notes: const [],
      ),
    );

    expect(find.textContaining('1 period day recorded'), findsOneWidget);
    expect(find.textContaining('2 days recorded'), findsNothing);
  });

  testWidgets(
    'one observed start remains an open span, not a completed cycle',
    (tester) async {
      await pumpReport(tester, _input(1), onOpenPlus: (_) async => null);

      expect(
        find.textContaining('One completed cycle is needed'),
        findsOneWidget,
      );
      expect(find.text('Cyclical symptom matrix'), findsNothing);
      expect(
        find.text('Export this report — included with Plus'),
        findsNothing,
      );
    },
  );

  testWidgets('one completed cycle states that recurrence is unavailable', (
    tester,
  ) async {
    await pumpReport(tester, _input(2));
    await _reveal(tester, find.text('One cycle cannot show recurrence.'));
    expect(find.text('One cycle cannot show recurrence.'), findsOneWidget);
    expect(find.text('Cyclical symptom matrix'), findsNothing);
    expect(find.textContaining('pattern', findRichText: true), findsNothing);
  });

  testWidgets('two completed cycles use aligned timelines, not matrix', (
    tester,
  ) async {
    await pumpReport(tester, _input(3));
    await _reveal(tester, find.text('Two completed cycles in this range'));
    expect(find.text('Two completed cycles in this range'), findsOneWidget);
    expect(
      find.text('A third completed cycle in this range enables comparison.'),
      findsOneWidget,
    );
    expect(find.text('Cyclical symptom matrix'), findsNothing);
    expect(find.text('Export this report — included with Plus'), findsNothing);
  });

  testWidgets('three completed cycles hide clinical matrix behind boundary', (
    tester,
  ) async {
    await pumpReport(tester, _input(4), onOpenPlus: (_) async => null);
    await _reveal(tester, find.text('Export this report — included with Plus'));
    expect(find.text('Cyclical symptom matrix'), findsNothing);
    expect(
      find.text('Showing Last 3 months · 3 completed cycles in range'),
      findsOneWidget,
    );
    expect(find.text('Compare all 3 completed cycles'), findsOneWidget);
    expect(
      find.text('Export this report — included with Plus'),
      findsOneWidget,
    );
  });

  testWidgets('unlocked in-app matrix keeps its report hierarchy', (
    tester,
  ) async {
    await pumpReport(tester, _input(4), canUseClinicianReports: true);

    final matrix = find.text('Cyclical symptom matrix');
    await _reveal(tester, matrix);
    expect(matrix, findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/reports_twin_matrix_in_app_390x844.png'),
    );
  });

  testWidgets('ninety daily check-ins stay bounded in the in-app report', (
    tester,
  ) async {
    final checkIns = <MomentCheckIn>[
      for (var day = 0; day < 90; day += 1)
        MomentCheckIn(
          id: 'daily-$day',
          state: MomentCheckInState.overwhelmed,
          occurredAt: DateTime(2026, 5, 17 + day, 12),
          createdAt: DateTime(2026, 5, 17 + day, 12),
        ),
    ];
    await pumpReport(
      tester,
      _input(4, checkIns: checkIns),
      canUseClinicianReports: true,
    );

    await _reveal(
      tester,
      find.textContaining('more difficult check-ins in this range'),
    );
    expect(find.text('Difficult Today check-ins'), findsOneWidget);
    expect(
      find.text(
        '+ 82 more difficult check-ins in this range. '
        'Raw CSV keeps every check-in.',
      ),
      findsOneWidget,
    );
    expect(find.text('Check-ins'), findsNothing);
    expect(find.text('90 moments'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('artifact tier uses completed cycles inside selected range', (
    tester,
  ) async {
    await pumpReport(
      tester,
      _input(4, first: const LocalDate(2026, 4, 1), intervalDays: 30),
      onOpenPlus: (_) async => null,
    );

    await _reveal(tester, find.text('One cycle cannot show recurrence.'));
    expect(find.text('One cycle cannot show recurrence.'), findsOneWidget);
    expect(find.text('Two completed cycles in this range'), findsNothing);
    expect(find.text('Cyclical symptom matrix'), findsNothing);
    expect(find.text('Export this report — included with Plus'), findsNothing);
  });

  testWidgets('free preview never shows facts before its selected range', (
    tester,
  ) async {
    final recordedAt = DateTime.utc(2026, 5, 20, 12);
    HealthRecord record(String id, SymptomType symptom, LocalDate date) =>
        HealthRecord(
          id: id,
          symptom: symptom,
          severity: SymptomSeverity.moderate,
          functionalImpacts: const <FunctionalImpact>{},
          experiencedDate: date,
          recordedAt: recordedAt,
          updatedAt: recordedAt,
          provenance: HealthRecordProvenance.sameDay,
          userConfirmed: true,
          vocabularyVersion: healthRecordVocabularyVersion,
        );
    await pumpReport(
      tester,
      _input(
        4,
        first: const LocalDate(2026, 4, 1),
        intervalDays: 30,
        healthRecords: <HealthRecord>[
          record('before', SymptomType.cramps, const LocalDate(2026, 5, 10)),
          record('inside', SymptomType.crying, const LocalDate(2026, 5, 20)),
        ],
      ),
    );

    await _reveal(tester, find.textContaining('Crying · Moderate'));
    expect(find.textContaining('Crying · Moderate'), findsOneWidget);
    expect(find.textContaining('Cramps · Moderate'), findsNothing);
    expect(find.textContaining('5/10/2026'), findsNothing);
  });

  testWidgets('ranges beyond three months open Plus and preserve selection', (
    tester,
  ) async {
    PlusOutcomeContext? captured;
    await pumpReport(
      tester,
      _input(4),
      onOpenPlus: (context) async {
        captured = context;
        return const PlusCommitResult.dismissed();
      },
    );
    expect(find.text('5/14/2026 to 8/14/2026'), findsOneWidget);
    await _reveal(tester, find.text('Last 6 months'));
    final sixMonthRow = find.ancestor(
      of: find.text('Last 6 months'),
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(sixMonthRow).onTap!();
    await tester.pumpAndSettle();
    await _returnToTop(tester);
    expect(captured?.kind, PlusOutcomeIntentKind.seeAllCycles);
    expect(captured?.rangeId, 'lastSixMonths');
    expect(find.text('5/14/2026 to 8/14/2026'), findsOneWidget);
    expect(find.text('2/12/2026 to 8/14/2026'), findsNothing);
  });

  testWidgets('activation applies requested range and unlocks export', (
    tester,
  ) async {
    await pumpReport(
      tester,
      _input(4),
      onOpenPlus: (context) async => PlusCommitResult.activated(context),
    );
    await _reveal(tester, find.text('Last year'));
    final yearRow = find.ancestor(
      of: find.text('Last year'),
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(yearRow).onTap!();
    await tester.pumpAndSettle();
    await _returnToTop(tester);
    expect(find.text('8/14/2025 to 8/14/2026'), findsOneWidget);
    await _reveal(tester, find.text('Cyclical symptom matrix'));
    expect(find.text('Cyclical symptom matrix'), findsOneWidget);
    await _reveal(tester, find.text('Export Clinical Pattern Report'));
    expect(find.text('Export Clinical Pattern Report'), findsOneWidget);
  });

  testWidgets('paid exports use factual formats and show the saved path', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async {
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final port = _RecordingExportPort(_input(1));
    await pumpReport(
      tester,
      port.input,
      port: port,
      canUseClinicianReports: true,
    );

    await _reveal(tester, find.text('Export Visit Summary'));
    await tester.tap(find.text('Export Visit Summary'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(port.lastFormat, ReportExportFormat.visitSummaryPdf);
    await _reveal(tester, find.text('Saved locally at'));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.data == '/Documents/letter/visit-summary.pdf',
      ),
      findsOneWidget,
    );

    await _reveal(tester, find.text('Export raw CSV'));
    await tester.tap(find.text('Export raw CSV'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(port.lastFormat, ReportExportFormat.rawCsv);
    await _reveal(tester, find.text('Saved locally at'));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.data == '/Documents/letter/records.csv',
      ),
      findsOneWidget,
    );
  });

  testWidgets('free users open Plus without invoking the file export port', (
    tester,
  ) async {
    PlusOutcomeContext? captured;
    final port = _RecordingExportPort(_input(2));
    await pumpReport(
      tester,
      port.input,
      port: port,
      onOpenPlus: (context) async {
        captured = context;
        return const PlusCommitResult.dismissed();
      },
    );

    await _reveal(tester, find.text('Export Visit Summary'));
    await tester.tap(find.text('Export Visit Summary'));
    await tester.pumpAndSettle();
    expect(captured?.kind, PlusOutcomeIntentKind.export);
    expect(port.lastFormat, isNull);

    captured = null;
    await _reveal(tester, find.text('Export raw CSV'));
    await tester.tap(find.text('Export raw CSV'));
    await tester.pumpAndSettle();
    expect(captured?.kind, PlusOutcomeIntentKind.export);
    expect(port.lastFormat, isNull);
  });

  testWidgets('no-card Preview unlocks in-app depth but not file generation', (
    tester,
  ) async {
    final repository = LocalEntitlementRepository();
    addTearDown(repository.dispose);
    PlusOutcomeContext? captured;
    final port = _RecordingExportPort(_input(4));
    await pumpReport(
      tester,
      port.input,
      port: port,
      entitlementRepository: repository,
      hasPlusPreviewAccess: true,
      onOpenPlus: (context) async {
        captured = context;
        return const PlusCommitResult.dismissed();
      },
    );

    await _reveal(tester, find.text('Cyclical symptom matrix'));
    expect(find.text('Cyclical symptom matrix'), findsOneWidget);
    await _returnToTop(tester);
    await tester.tap(find.text('Last 6 months'));
    await tester.pumpAndSettle();
    await _returnToTop(tester);
    expect(captured?.kind, PlusOutcomeIntentKind.seeAllCycles);
    expect(find.text('5/14/2026 to 8/14/2026'), findsOneWidget);

    captured = null;
    await _reveal(tester, find.text('Export Visit Summary'));
    await tester.tap(find.text('Export Visit Summary'));
    await tester.pumpAndSettle();
    expect(captured?.kind, PlusOutcomeIntentKind.export);
    expect(port.lastFormat, isNull);
  });

  for (final status in <EntitlementStatus>[
    EntitlementStatus.lapsed,
    EntitlementStatus.offlineUnknown,
  ]) {
    testWidgets(
      'live ${status.name} returns an open paid range to the free preview',
      (tester) async {
        final repository = LocalEntitlementRepository(
          initial: const EntitlementState(status: EntitlementStatus.activePaid),
        );
        addTearDown(repository.dispose);
        await pumpReport(
          tester,
          _input(6, first: const LocalDate(2026, 1, 1)),
          entitlementRepository: repository,
          hasPlusPreviewAccess: true,
        );

        await tester.tap(find.text('All records'));
        await tester.pumpAndSettle();
        expect(find.text('1/1/2026 to 8/14/2026'), findsOneWidget);

        repository.debugSet(EntitlementState(status: status));
        await tester.pumpAndSettle();

        expect(find.text('5/14/2026 to 8/14/2026'), findsOneWidget);
        expect(find.text('1/1/2026 to 8/14/2026'), findsNothing);
      },
    );

    testWidgets(
      'live ${status.name} blocks generation while Reports stays open',
      (tester) async {
        final repository = _RefreshEntitlementRepository(
          refreshState: EntitlementState(status: status),
        );
        addTearDown(repository.dispose);
        PlusOutcomeContext? captured;
        final port = _RecordingExportPort(_input(2));
        await pumpReport(
          tester,
          port.input,
          port: port,
          entitlementRepository: repository,
          onOpenPlus: (context) async {
            captured = context;
            return const PlusCommitResult.dismissed();
          },
        );

        await _reveal(tester, find.text('Export Visit Summary'));
        await tester.tap(find.text('Export Visit Summary'));
        await tester.pumpAndSettle();
        expect(repository.refreshCalls, 1);
        expect(captured?.kind, PlusOutcomeIntentKind.export);
        expect(port.lastFormat, isNull);
      },
    );
  }

  testWidgets('recent Care suppresses contextual acquisition', (tester) async {
    var opened = false;
    await pumpReport(
      tester,
      _input(4, recentCare: true),
      onOpenPlus: (context) async {
        opened = true;
        return const PlusCommitResult.dismissed();
      },
    );
    expect(find.text('Export this report — included with Plus'), findsNothing);
    await tester.tap(find.text('Last 6 months'));
    await tester.pumpAndSettle();
    expect(opened, isFalse);
  });

  testWidgets('commitment surface has no fabricated preview or feature grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: PlusExperience(
          entitlementRepository: LocalEntitlementRepository(),
          outcomeContext: const PlusOutcomeContext.export(
            headline: 'Export as PDF for a clinician',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Export as PDF for a clinician'), findsOneWidget);
    expect(find.text('Best for learning your pattern'), findsNothing);
    expect(find.textContaining('keeps working offline'), findsNothing);
    expect(find.text('Renews yearly until canceled'), findsOneWidget);
    expect(find.textContaining('PREVIEW'), findsNothing);
    expect(find.text('Restore a previous purchase'), findsOneWidget);
    expect(find.textContaining('may vary by region'), findsNothing);
    expect(find.textContaining('What Plus'), findsNothing);
    expect(find.textContaining('Remembered help'), findsNothing);
    expect(find.textContaining('Deeper patterns'), findsNothing);
    final yearlyTop = tester.getTopLeft(find.text('Yearly')).dy;
    final monthlyTop = tester.getTopLeft(find.text('Monthly')).dy;
    final lifetimeTop = tester.getTopLeft(find.text('Lifetime')).dy;
    expect(yearlyTop, lessThan(monthlyTop));
    expect(monthlyTop, lessThan(lifetimeTop));
  });

  testWidgets('active lifetime purchase shows the plan without filler', (
    tester,
  ) async {
    final repository = LocalEntitlementRepository(
      initial: const EntitlementState(
        status: EntitlementStatus.activePaid,
        planId: 'letter_lifetime',
      ),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: PlusExperience(entitlementRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plus is active'), findsOneWidget);
    expect(find.text('Lifetime'), findsOneWidget);
    expect(find.textContaining('\$99.99'), findsNothing);
    expect(find.textContaining('Plus access is yours for life'), findsNothing);
    expect(find.textContaining('Cancelled access'), findsNothing);
    expect(find.text('View plans'), findsOneWidget);
    expect(find.text('Restore a previous purchase'), findsNothing);
    expect(find.textContaining('may vary by region'), findsNothing);
    await tester.tap(find.text('View plans'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plus-plan-letter_monthly')), findsOneWidget);
    expect(find.byKey(const Key('plus-plan-letter_yearly')), findsOneWidget);
    expect(find.byKey(const Key('plus-plan-letter_lifetime')), findsOneWidget);
    expect(find.text('Current plan'), findsOneWidget);
    expect(find.text('Included with Lifetime'), findsNWidgets(2));
    expect(find.textContaining('\$99.99'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('plus-plan-letter_lifetime')),
    );
    await tester.tap(find.byKey(const Key('plus-plan-letter_lifetime')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a plan'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const Key('plus-plan-letter_monthly')),
    );
    await tester.tap(find.byKey(const Key('plus-plan-letter_monthly')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Continue with Monthly'), findsNothing);
    expect(find.textContaining('Continue with Yearly'), findsNothing);
  });

  testWidgets('lifetime access still reveals a separate active subscription', (
    tester,
  ) async {
    final repository = _ManagedEntitlementRepository(
      Uri.parse('https://apps.apple.com/account/subscriptions'),
      initial: EntitlementState(
        status: EntitlementStatus.activePaid,
        planId: 'letter_lifetime',
        activeSubscriptions: [
          ActivePlanPeriod(
            productId: 'letter_monthly',
            expiresAt: DateTime.utc(2030, 11, 2),
            willRenew: true,
          ),
        ],
      ),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: PlusExperience(entitlementRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lifetime'), findsOneWidget);
    expect(
      find.text('A separate subscription is also active in the store.'),
      findsOneWidget,
    );
    expect(find.text('View plans'), findsOneWidget);
    expect(find.text('Manage subscription'), findsOneWidget);
    await tester.tap(find.text('View plans'));
    await tester.pumpAndSettle();
    expect(find.text('Included with Lifetime'), findsNWidgets(2));
    expect(find.text('Choose a plan'), findsNothing);
  });

  testWidgets('active subscription offers three plans except the current one', (
    tester,
  ) async {
    final repository = LocalEntitlementRepository(
      initial: const EntitlementState(
        status: EntitlementStatus.activePaid,
        planId: 'letter_monthly',
      ),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: PlusExperience(entitlementRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plus is active'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.textContaining('\$7.99'), findsNothing);
    expect(find.textContaining('Cancelled access'), findsNothing);
    expect(find.text('Yearly'), findsNothing);
    expect(find.textContaining('one-time purchase'), findsNothing);
    expect(find.text('Restore a previous purchase'), findsNothing);
    final changePlan = find.text('Change plan');
    expect(changePlan, findsOneWidget);
    await tester.ensureVisible(changePlan);
    await tester.tap(changePlan);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plus-plan-letter_monthly')), findsOneWidget);
    expect(find.byKey(const Key('plus-plan-letter_yearly')), findsOneWidget);
    expect(find.byKey(const Key('plus-plan-letter_lifetime')), findsOneWidget);
    expect(find.text('Current plan'), findsOneWidget);
    expect(find.textContaining('\$39.99'), findsWidgets);
    expect(find.textContaining('Renews yearly until canceled'), findsOneWidget);
    expect(find.text('Choose a plan'), findsOneWidget);
    final monthlyCard = find.byKey(const Key('plus-plan-letter_monthly'));
    expect(
      tester
          .widget<Opacity>(
            find.descendant(of: monthlyCard, matching: find.byType(Opacity)),
          )
          .opacity,
      0.72,
    );
    await tester.ensureVisible(
      find.byKey(const Key('plus-plan-letter_lifetime')),
    );
    await tester.tap(find.byKey(const Key('plus-plan-letter_lifetime')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Continue with Lifetime'), findsOneWidget);
    expect(find.text('Manage subscription'), findsNothing);
    expect(find.textContaining('unavailable in this store'), findsNothing);
  });

  testWidgets('active subscription shows the store-reported renewal date', (
    tester,
  ) async {
    final repository = LocalEntitlementRepository(
      initial: EntitlementState(
        status: EntitlementStatus.activePaid,
        planId: 'letter_monthly',
        expiresAt: DateTime.utc(2030, 11, 2),
        willRenew: true,
      ),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: PlusExperience(entitlementRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Renews on Sat, Nov 2, 2030'), findsOneWidget);
    expect(find.textContaining('Access until'), findsNothing);
  });

  testWidgets('canceled subscription shows access end, not renewal', (
    tester,
  ) async {
    final repository = LocalEntitlementRepository(
      initial: EntitlementState(
        status: EntitlementStatus.activePaid,
        planId: 'letter_yearly',
        expiresAt: DateTime.utc(2030, 11, 2),
        willRenew: false,
      ),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: PlusExperience(entitlementRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Access until Sat, Nov 2, 2030'), findsOneWidget);
    expect(find.textContaining('Renews on'), findsNothing);
  });

  testWidgets('overlapping plans show newest activity and latest access date', (
    tester,
  ) async {
    final repository = LocalEntitlementRepository(
      initial: EntitlementState(
        status: EntitlementStatus.activePaid,
        planId: 'letter_yearly',
        activeSubscriptions: [
          ActivePlanPeriod(
            productId: 'letter_yearly',
            purchasedAt: DateTime.utc(2030, 9, 1),
            expiresAt: DateTime.utc(2030, 11, 2),
            willRenew: true,
          ),
          ActivePlanPeriod(
            productId: 'letter_monthly',
            purchasedAt: DateTime.utc(2030, 9, 2),
            expiresAt: DateTime.utc(2030, 10, 2),
            willRenew: true,
          ),
        ],
      ),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: PlusExperience(entitlementRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Yearly'), findsNothing);
    expect(
      find.text('Current Plus access through at least Sat, Nov 2, 2030'),
      findsOneWidget,
    );
    expect(
      find.text('Another subscription is also active in the store.'),
      findsOneWidget,
    );
    expect(find.text('Change plan'), findsOneWidget);
    await tester.tap(find.text('Change plan'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plus-plan-letter_monthly')), findsOneWidget);
    expect(find.byKey(const Key('plus-plan-letter_yearly')), findsOneWidget);
    expect(find.byKey(const Key('plus-plan-letter_lifetime')), findsOneWidget);
    expect(find.text('Current plan'), findsOneWidget);
    expect(find.text('Already active'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('plus-plan-letter_yearly')),
    );
    await tester.tap(find.byKey(const Key('plus-plan-letter_yearly')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a plan'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('plus-plan-letter_lifetime')),
    );
    await tester.tap(find.byKey(const Key('plus-plan-letter_lifetime')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Continue with Lifetime'), findsOneWidget);
  });

  testWidgets('active store state with a past period keeps the reported date', (
    tester,
  ) async {
    final repository = LocalEntitlementRepository(
      initial: EntitlementState(
        status: EntitlementStatus.activePaid,
        planId: 'letter_monthly',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 2)),
        willRenew: true,
      ),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: PlusExperience(entitlementRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Last reported period ended'), findsOneWidget);
    expect(find.textContaining('Renews on'), findsNothing);
  });

  testWidgets('plan change remains usable at compact width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = LocalEntitlementRepository(
      initial: EntitlementState(
        status: EntitlementStatus.activePaid,
        planId: 'letter_yearly',
        expiresAt: DateTime.utc(2030, 11, 2),
        willRenew: true,
      ),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: PlusExperience(entitlementRepository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change plan'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plus-plan-letter_monthly')), findsOneWidget);
    expect(find.byKey(const Key('plus-plan-letter_yearly')), findsOneWidget);
    expect(find.byKey(const Key('plus-plan-letter_lifetime')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active monthly plan opens the store management link', (
    tester,
  ) async {
    final managementUrl = Uri.parse(
      'https://apps.apple.com/account/subscriptions',
    );
    final repository = _ManagedEntitlementRepository(managementUrl);
    addTearDown(repository.dispose);
    final openedUrls = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: PlusExperience(
          entitlementRepository: repository,
          openLegalUrl: (url) async {
            openedUrls.add(url);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final manage = find.text('Manage subscription');
    await tester.ensureVisible(manage);
    await tester.tap(manage);
    await tester.pumpAndSettle();
    expect(openedUrls, <Uri>[managementUrl]);
  });

  testWidgets('active Monthly switches to Yearly in the normal sheet flow', (
    tester,
  ) async {
    final repository = LocalEntitlementRepository(
      initial: const EntitlementState(
        status: EntitlementStatus.activePaid,
        planId: 'letter_monthly',
      ),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => PlusExperience.open(
                context,
                entitlementRepository: repository,
              ),
              child: const Text('Open Plus'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Plus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change plan'));
    await tester.pumpAndSettle();
    final yearly = find.byKey(const Key('plus-plan-letter_yearly'));
    await tester.ensureVisible(yearly);
    await tester.tap(yearly);
    await tester.pumpAndSettle();
    final purchase = find.textContaining('Continue with Yearly');
    await tester.ensureVisible(purchase);
    await tester.tap(purchase);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(repository.current.planId, 'letter_yearly');
    expect(repository.current.hasPremiumAccess, isTrue);
    expect(find.text('Open Plus'), findsOneWidget);
  });

  testWidgets('empty Restore result covers subscriptions and lifetime', (
    tester,
  ) async {
    final repository = LocalEntitlementRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: PlusExperience(entitlementRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    final restore = find.text('Restore a previous purchase');
    await tester.ensureVisible(restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();

    expect(
      find.text('No active Plus purchase was found for this store account.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'locked report ranges keep the pattern report analytics context',
    (tester) async {
      final analytics = _RecordingAnalyticsService();
      await tester.pumpWidget(
        AnalyticsScope(
          service: analytics,
          child: MaterialApp(
            theme: ExperienceFoundation.lightTheme(),
            home: PlusExperience(
              entitlementRepository: LocalEntitlementRepository(),
              outcomeContext: const PlusOutcomeContext.seeAllCycles(
                headline: 'Compare 6 months of cycle evidence',
                rangeId: 'lastSixMonths',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(analytics.events, hasLength(2));
      expect(analytics.events.first.event, isA<PaywallViewedEvent>());
      expect(analytics.events.first.event.toProperties(), const {
        'context': 'patternReport',
      });
      expect(analytics.events.last.event.toProperties(), const {
        'result': 'loaded',
      });
    },
  );

  testWidgets('Plus failure offers retry and functional legal links', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = RevenueCatEntitlementRepository(
      appUserId: '550e8400-e29b-41d4-a716-446655440000',
      appleApiKey: 'appl_public_key',
      googleApiKey: '',
      store: null,
    );
    addTearDown(repository.dispose);
    final openedUrls = <Uri>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: PlusExperience(
          entitlementRepository: repository,
          openLegalUrl: (url) async {
            openedUrls.add(url);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plans are unavailable'), findsOneWidget);
    expect(find.text('Please try again after an app update.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('desktop build'), findsNothing);
    expect(find.textContaining('Google Play'), findsNothing);

    final privacyLink = find.text('Privacy Policy');
    await tester.ensureVisible(privacyLink);
    await tester.tap(privacyLink);
    final termsLink = find.text('Terms of Use');
    await tester.ensureVisible(termsLink);
    await tester.tap(termsLink);
    expect(openedUrls, <Uri>[
      Uri.parse('https://letterwithin.app/privacy'),
      Uri.parse(
        'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
      ),
    ]);
  });

  testWidgets('Plus retry loads plans after an ordinary store failure', (
    tester,
  ) async {
    final repository = _RetryPlansRepository();
    final analytics = _RecordingAnalyticsService();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      AnalyticsScope(
        service: analytics,
        child: MaterialApp(
          theme: ExperienceFoundation.lightTheme(),
          home: PlusExperience(entitlementRepository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Plans could not be loaded'), findsOneWidget);
    expect(analytics.events.last.event.toProperties(), const {
      'result': 'failed',
      'reason': 'unknown',
    });

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Plans could not be loaded'), findsNothing);
    expect(repository.loadCalls, 2);
    expect(analytics.events.last.event.toProperties(), const {
      'result': 'loaded',
    });
  });

  testWidgets('Plus reloads plans when account store setup finishes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = RevenueCatEntitlementRepository(
      appUserId: '',
      appleApiKey: 'appl_public_key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: _ReadyRevenueCatClient(),
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: PlusExperience(entitlementRepository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Connect an account for Plus'), findsOneWidget);
    expect(find.text('Restore a previous purchase'), findsNothing);
    expect(find.text('Choose a plan'), findsNothing);

    await repository.identifyAuthenticatedUser(
      '550e8400-e29b-41d4-a716-446655440000',
    );
    await tester.pumpAndSettle();
    expect(find.text('Connect an account for Plus'), findsNothing);
    expect(find.textContaining('\$29.99'), findsWidgets);
  });

  testWidgets('Plus points an accountless user to Settings Account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = RevenueCatEntitlementRepository(
      appUserId: '',
      appleApiKey: 'appl_public_key',
      googleApiKey: '',
      store: RevenueCatStore.apple,
      client: _ReadyRevenueCatClient(),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => PlusExperience.open(
                context,
                entitlementRepository: repository,
              ),
              child: const Text('Open Plus'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Plus'));
    await tester.pumpAndSettle();
    expect(find.text('Connect an account for Plus'), findsOneWidget);
    expect(find.text('Restore a previous purchase'), findsNothing);
    expect(find.text('Choose a plan'), findsNothing);
    expect(
      find.text('Open Settings → Account to create or connect an account.'),
      findsOneWidget,
    );
    expect(find.text('Open account settings'), findsNothing);
  });
}

final class _ReadyRevenueCatClient implements RevenueCatClient {
  @override
  Future<void> configure({
    required String apiKey,
    required String appUserId,
  }) async {}

  @override
  Future<void> clearUser() async {}

  @override
  Future<List<RevenueCatPlanOffer>> loadPlans() async => const [
    RevenueCatPlanOffer(
      productId: 'letter_yearly',
      priceLabel: '\$29.99 / year',
    ),
  ];

  @override
  Future<RevenueCatCustomerState> currentCustomerState() async =>
      const RevenueCatCustomerState(
        hasActiveEntitlement: false,
        hasPurchasedLetterProduct: false,
      );

  @override
  Future<RevenueCatCustomerState> purchase(String productId) =>
      currentCustomerState();

  @override
  Future<RevenueCatCustomerState> restore() => currentCustomerState();
}

class _Port implements ReportExperiencePort {
  _Port(this.input);

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

class _RecordingExportPort implements ReportExperiencePort {
  _RecordingExportPort(this.input);

  final SummaryExportInput input;
  ReportExportFormat? lastFormat;

  @override
  Future<SummaryExportInput> load() async => input;

  @override
  Future<ExperienceFileReceipt> export({
    required SummaryDateRange range,
    required Set<String> selectedNoteIds,
    required ReportExportFormat format,
  }) async {
    lastFormat = format;
    final fileName = format == ReportExportFormat.rawCsv
        ? 'records.csv'
        : 'visit-summary.pdf';
    return ExperienceFileReceipt(
      outcome: ExperienceFileOutcome.savedOnly,
      localPath: '/Documents/letter/$fileName',
    );
  }
}

final class _ManagedEntitlementRepository extends LocalEntitlementRepository {
  _ManagedEntitlementRepository(this.url, {EntitlementState? initial})
    : super(
        initial:
            initial ??
            const EntitlementState(
              status: EntitlementStatus.activePaid,
              planId: 'letter_monthly',
            ),
      );

  final Uri url;

  @override
  Future<Uri?> managementUrl() async => url;
}

final class _RefreshEntitlementRepository extends LocalEntitlementRepository {
  _RefreshEntitlementRepository({required this.refreshState})
    : super(
        initial: const EntitlementState(status: EntitlementStatus.activePaid),
      );

  final EntitlementState refreshState;
  int refreshCalls = 0;

  @override
  Future<EntitlementState> refresh() async {
    refreshCalls += 1;
    return refreshState;
  }
}

final class _RetryPlansRepository extends LocalEntitlementRepository {
  int loadCalls = 0;

  @override
  Future<List<LetterPlan>> loadPlans() async {
    loadCalls += 1;
    if (loadCalls == 1) throw StateError('temporary store failure');
    return letterPlans;
  }
}

final class _RecordingAnalyticsService implements AnalyticsService {
  final List<AnalyticsPayload> events = <AnalyticsPayload>[];

  @override
  bool get isEnabled => true;

  @override
  Future<void> track(AnalyticsPayload payload) async => events.add(payload);

  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}

  @override
  Future<void> dispose() async {}
}

SummaryExportInput _input(
  int starts, {
  bool recentCare = false,
  LocalDate first = const LocalDate(2026, 5, 18),
  int intervalDays = 28,
  List<HealthRecord> healthRecords = const <HealthRecord>[],
  List<MomentCheckIn> checkIns = const <MomentCheckIn>[],
}) {
  final periodDays = <SummaryPeriodDay>[
    for (var cycle = 0; cycle < starts; cycle++)
      for (var day = 0; day < 5; day++)
        SummaryPeriodDay(first.addDays(cycle * intervalDays + day)),
  ];
  return SummaryExportInput(
    periodDays: periodDays,
    predictions: const [],
    healthRecords: healthRecords,
    checkIns: checkIns,
    careRecords: recentCare
        ? <CareRecord>[
            CareRecord(
              id: 'recent',
              mode: CareMode.heavy,
              actionId: 'quiet',
              actionLabel: 'Quiet presence',
              outcome: CareOutcome.same,
              occurredAt: DateTime(2026, 8, 14, 11),
              createdAt: DateTime(2026, 8, 14, 11),
              updatedAt: DateTime(2026, 8, 14, 11),
              pinned: false,
            ),
          ]
        : const [],
    notes: const [],
  );
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final scrollable = find
      .byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      )
      .first;
  for (var attempt = 0; attempt < 20 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(scrollable, const Offset(0, -500));
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _returnToTop(WidgetTester tester) async {
  final scrollable = find
      .byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      )
      .first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
}
