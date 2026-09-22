import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/experience_release_ports.dart';
import 'package:letter_mobile/experience/plus/plus_experience.dart';
import 'package:letter_mobile/experience/reports/reports_experience.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/data/revenue_cat_entitlement_repository.dart';
import 'package:letter_mobile/features/summary_export/domain/cycle_care_summary.dart';

void main() {
  Future<void> pumpReport(
    WidgetTester tester,
    SummaryExportInput input, {
    Future<PlusCommitResult?> Function(PlusOutcomeContext)? onOpenPlus,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: ReportsExperience(
          port: _Port(input),
          now: () => DateTime(2026, 8, 14, 12),
          onOpenPlusWithContext: onOpenPlus,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('zero completed cycles has no matrix or acquisition', (
    tester,
  ) async {
    await pumpReport(tester, _input(0));
    expect(
      find.textContaining('One completed cycle is needed'),
      findsOneWidget,
    );
    expect(find.text('Cyclical symptom matrix'), findsNothing);
    expect(find.text('Export this report — included with Plus'), findsNothing);
  });

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

  testWidgets('three completed cycles show real matrix and boundary', (
    tester,
  ) async {
    await pumpReport(tester, _input(4), onOpenPlus: (_) async => null);
    await _reveal(tester, find.text('Cyclical symptom matrix'));
    expect(find.text('Cyclical symptom matrix'), findsOneWidget);
    await _reveal(tester, find.text('Export this report — included with Plus'));
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

  testWidgets('artifact tier uses completed cycles inside selected range', (
    tester,
  ) async {
    await pumpReport(
      tester,
      _input(4, first: const LocalDate(2026, 4, 1), intervalDays: 30),
      onOpenPlus: (_) async => null,
    );

    await _reveal(tester, find.text('Two completed cycles in this range'));
    expect(find.text('Two completed cycles in this range'), findsOneWidget);
    expect(find.text('Cyclical symptom matrix'), findsNothing);
    expect(find.text('Export this report — included with Plus'), findsNothing);
  });

  testWidgets('locked range keeps free range and round-trips exact intent', (
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
    await tester.tap(find.text('Last 6 months'));
    await tester.pumpAndSettle();
    expect(captured?.rangeId, 'lastSixMonths');
    expect(captured?.headline, 'Compare 6 months of cycle evidence');
    expect(find.text('5/14/2026 to 8/14/2026'), findsOneWidget);
  });

  testWidgets('activation applies requested range and unlocks export', (
    tester,
  ) async {
    await pumpReport(
      tester,
      _input(4),
      onOpenPlus: (context) async => PlusCommitResult.activated(context),
    );
    await tester.tap(find.text('Last year'));
    await tester.pumpAndSettle();
    expect(find.text('8/14/2025 to 8/14/2026'), findsOneWidget);
    await _reveal(tester, find.text('Export PDF'));
    expect(find.text('Export PDF'), findsOneWidget);
  });

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
    expect(find.textContaining('PREVIEW'), findsNothing);
    expect(find.textContaining('What Plus'), findsNothing);
    expect(find.textContaining('Remembered help'), findsNothing);
    expect(find.textContaining('Deeper patterns'), findsNothing);
    final yearlyTop = tester.getTopLeft(find.text('Yearly')).dy;
    final monthlyTop = tester.getTopLeft(find.text('Monthly')).dy;
    final lifetimeTop = tester.getTopLeft(find.text('Lifetime')).dy;
    expect(yearlyTop, lessThan(monthlyTop));
    expect(monthlyTop, lessThan(lifetimeTop));
  });

  testWidgets('desktop Plus explains store support without claiming offline', (
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

    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: PlusExperience(entitlementRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plans are available in the mobile app'), findsOneWidget);
    expect(find.textContaining('appear to be offline'), findsNothing);
    expect(find.text('Try again'), findsNothing);
  });
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

SummaryExportInput _input(
  int starts, {
  bool recentCare = false,
  LocalDate first = const LocalDate(2026, 4, 20),
  int intervalDays = 28,
}) {
  final periodDays = <SummaryPeriodDay>[
    for (var cycle = 0; cycle < starts; cycle++)
      for (var day = 0; day < 5; day++)
        SummaryPeriodDay(first.addDays(cycle * intervalDays + day)),
  ];
  return SummaryExportInput(
    periodDays: periodDays,
    predictions: const [],
    healthRecords: const [],
    checkIns: const [],
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
