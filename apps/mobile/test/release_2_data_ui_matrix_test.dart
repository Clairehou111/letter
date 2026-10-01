import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/experience/reports/letter_report_experience_port.dart';
import 'package:letter_mobile/experience/reports/reports_experience.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/experience/today/today_experience_visual_baseline.dart';
import 'package:letter_mobile/experience/today/today_visual_port.dart';
import 'package:letter_mobile/features/care/data/drift_care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/capture/data/drift_capture_note_store.dart';
import 'package:letter_mobile/features/check_in/data/drift_moment_check_in_repository.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/comfort_kit/application/comfort_experience_controller.dart';
import 'package:letter_mobile/features/comfort_kit/data/drift_comfort_kit_repository.dart';
import 'package:letter_mobile/features/comfort_window/data/comfort_reminder_preference_repositories.dart';
import 'package:letter_mobile/features/cycle/data/drift_period_repository.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/domain/entitlement.dart';
import 'package:letter_mobile/features/entitlement/presentation/entitlement_scope.dart';
import 'package:letter_mobile/features/health_records/data/drift_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/health_records/presentation/health_records_screen.dart';
import 'package:letter_mobile/features/patterns/data/repository_pattern_source.dart';
import 'package:letter_mobile/features/patterns/presentation/personal_patterns_route.dart';

const _today = LocalDate(2026, 8, 15);
final _now = DateTime.utc(2026, 8, 15, 12);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  testWidgets(
    'empty Drift tables render intentional empty Today, Patterns, and Reports states',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.close);
      _phone(tester);

      expect(
        await harness.database.select(harness.database.periodRows).get(),
        isEmpty,
      );
      expect(
        await harness.database.select(harness.database.healthRecordRows).get(),
        isEmpty,
      );

      await tester.pumpWidget(
        MaterialApp(home: TodayExperienceVisual(port: harness.todayPort)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TodayExperienceVisual), findsOneWidget);
      await _reveal(
        tester,
        find.byKey(const ValueKey<String>('quick-note-add')),
      );
      expect(
        find.byKey(const ValueKey<String>('quick-note-add')),
        findsOneWidget,
      );

      final paid = LocalEntitlementRepository(
        initial: const EntitlementState(status: EntitlementStatus.activePaid),
      );
      addTearDown(paid.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: LetterTheme.light,
          home: EntitlementScope(
            repository: paid,
            initialState: const EntitlementState(
              status: EntitlementStatus.activePaid,
            ),
            child: PersonalPatternsRoute(
              source: harness.patterns,
              now: () => _now,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('patterns-empty-state')), findsOneWidget);

      await _pumpReports(tester, harness);
      await _reveal(
        tester,
        find.textContaining('One completed cycle is needed'),
      );
      expect(
        find.textContaining('One completed cycle is needed'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'one incomplete cycle stays consistent through database, Reports UI, deletion UI, and reload',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.close);
      _phone(tester);

      await harness.periods.create(
        const PeriodDraft(startDate: LocalDate(2026, 8, 10)),
        today: _today,
      );
      final crying = await harness.health.create(
        const HealthRecordDraft(
          symptom: SymptomType.crying,
          severity: SymptomSeverity.severe,
          experiencedDate: LocalDate(2026, 8, 12),
          provenance: HealthRecordProvenance.laterRecall,
        ),
      );

      expect(
        await harness.database.select(harness.database.periodRows).get(),
        hasLength(1),
      );
      expect(
        await harness.database.select(harness.database.healthRecordRows).get(),
        hasLength(1),
      );

      await _pumpReports(tester, harness);
      await _reveal(
        tester,
        find.textContaining('One completed cycle is needed'),
      );
      expect(
        find.textContaining('One completed cycle is needed'),
        findsOneWidget,
      );
      await _reveal(tester, find.textContaining('Crying · Severe'));
      expect(find.textContaining('Crying · Severe'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: LetterTheme.light,
          home: HealthRecordsScreen(
            repository: harness.health,
            periodRepository: harness.periods,
            now: () => _now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Crying'),
        240,
        scrollable: _verticalScrollable(),
      );
      tester
          .widget<PopupMenuButton<String>>(
            find.byKey(Key('health-record-menu-${crying.id}')),
          )
          .onSelected!('delete');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('health-record-confirm-delete')));
      await tester.pumpAndSettle();

      expect(
        await harness.database.select(harness.database.healthRecordRows).get(),
        isEmpty,
      );
      expect(await harness.health.getAll(), isEmpty);

      await _pumpReports(tester, harness);
      expect(find.textContaining('Crying'), findsNothing);
      expect((await harness.reportPort.load()).healthRecords, isEmpty);
    },
  );

  testWidgets(
    'Quick note UI preserves one database identity and recomputes Comfort Kit and Reports',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.close);
      _phone(tester);

      await tester.pumpWidget(
        MaterialApp(home: TodayExperienceVisual(port: harness.todayPort)),
      );
      await tester.pumpAndSettle();

      final add = find.byKey(const ValueKey<String>('quick-note-add'));
      await tester.scrollUntilVisible(
        add,
        320,
        scrollable: _verticalScrollable(),
      );
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('quick-note-field')),
        'Bring the soft blanket.',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('quick-note-comfort-kit-toggle')),
      );
      await tester.tap(find.text('Keep note'));
      await tester.pumpAndSettle();

      var rows = await harness.database
          .select(harness.database.captureNoteRows)
          .get();
      expect(rows, hasLength(1));
      final stableId = rows.single.id;
      expect(rows.single.keepInComfortKit, isTrue);
      expect(
        (await harness.comfort.load()).kit.visibleItems.single.body,
        'Bring the soft blanket.',
      );
      expect(
        (await harness.reportPort.load()).notes.single.text,
        'Bring the soft blanket.',
      );

      final edit = find.byKey(ValueKey<String>('quick-note-edit-$stableId'));
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('quick-note-field')),
        'Bring the warm blanket.',
      );
      await tester.tap(find.text('Update note'));
      await tester.pumpAndSettle();

      rows = await harness.database
          .select(harness.database.captureNoteRows)
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.id, stableId);
      expect(rows.single.content, 'Bring the warm blanket.');
      expect(
        (await harness.comfort.load()).kit.visibleItems.single.body,
        'Bring the warm blanket.',
      );
      expect(
        (await harness.reportPort.load()).notes.single.text,
        'Bring the warm blanket.',
      );

      final delete = find.byKey(
        ValueKey<String>('quick-note-delete-$stableId'),
      );
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        await harness.database.select(harness.database.captureNoteRows).get(),
        isEmpty,
      );
      expect((await harness.comfort.load()).kit.items, isEmpty);
      expect((await harness.reportPort.load()).notes, isEmpty);
    },
  );

  testWidgets(
    'cycle What helped stays in Drift and reaches Comfort Kit and Patterns',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.close);
      _phone(tester);

      for (final draft in const <PeriodDraft>[
        PeriodDraft(
          startDate: LocalDate(2026, 6, 1),
          endDate: LocalDate(2026, 6, 5),
        ),
        PeriodDraft(
          startDate: LocalDate(2026, 7, 1),
          endDate: LocalDate(2026, 7, 5),
        ),
        PeriodDraft(
          startDate: LocalDate(2026, 8, 1),
          endDate: LocalDate(2026, 8, 5),
        ),
      ]) {
        await harness.periods.create(draft, today: _today);
      }
      await harness.care.saveCycleReflection(
        const LocalDate(2026, 7, 1).epochDay,
        const CycleReflectionDraft(whatHelped: 'Warmth and fewer plans.'),
        startingPeriodId: 'period-1',
      );

      final rows = await harness.database
          .select(harness.database.cycleReflectionRows)
          .get();
      expect(rows.single.whatHelped, 'Warmth and fewer plans.');
      expect(
        (await harness.comfort.load()).kit.items.first.body,
        'Warmth and fewer plans.',
      );
      expect((await harness.patterns.read()).cycleReflections, hasLength(1));

      final paid = LocalEntitlementRepository(
        initial: const EntitlementState(status: EntitlementStatus.activePaid),
      );
      addTearDown(paid.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: LetterTheme.light,
          home: EntitlementScope(
            repository: paid,
            initialState: const EntitlementState(
              status: EntitlementStatus.activePaid,
            ),
            child: PersonalPatternsRoute(
              source: harness.patterns,
              now: () => _now,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('patterns-tab-helped')));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Warmth and fewer plans.'));
      expect(find.text('Warmth and fewer plans.'), findsOneWidget);
    },
  );

  testWidgets(
    'two completed cycles carry Drift symptoms and Care check-back into Patterns and range-correct Reports',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.close);
      _phone(tester);

      for (final draft in const <PeriodDraft>[
        PeriodDraft(
          startDate: LocalDate(2026, 6, 1),
          endDate: LocalDate(2026, 6, 5),
        ),
        PeriodDraft(
          startDate: LocalDate(2026, 7, 1),
          endDate: LocalDate(2026, 7, 5),
        ),
        PeriodDraft(startDate: LocalDate(2026, 8, 1)),
      ]) {
        await harness.periods.create(draft, today: _today);
      }
      await harness.health.create(
        const HealthRecordDraft(
          symptom: SymptomType.cramps,
          severity: SymptomSeverity.moderate,
          experiencedDate: LocalDate(2026, 6, 25),
          provenance: HealthRecordProvenance.sameDay,
        ),
      );
      await harness.health.create(
        const HealthRecordDraft(
          symptom: SymptomType.cramps,
          severity: SymptomSeverity.severe,
          experiencedDate: LocalDate(2026, 7, 27),
          provenance: HealthRecordProvenance.sameDay,
        ),
      );
      await harness.health.create(
        const HealthRecordDraft(
          symptom: SymptomType.headache,
          severity: SymptomSeverity.extreme,
          experiencedDate: LocalDate(2026, 5, 1),
          provenance: HealthRecordProvenance.laterRecall,
        ),
      );
      await harness.care.saveOutcome(
        CareActionCompletion(
          mode: CareMode.physical,
          actionId: 'warmth',
          actionLabel: 'Warmth and quiet',
          occurredAt: DateTime.utc(2026, 7, 28, 12),
        ),
        CareOutcome.better,
      );

      expect(
        await harness.database.select(harness.database.periodRows).get(),
        hasLength(3),
      );
      expect(
        await harness.database.select(harness.database.healthRecordRows).get(),
        hasLength(3),
      );
      expect(
        await harness.database.select(harness.database.careRecordRows).get(),
        hasLength(1),
      );

      final paid = LocalEntitlementRepository(
        initial: const EntitlementState(status: EntitlementStatus.activePaid),
      );
      addTearDown(paid.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: LetterTheme.light,
          home: EntitlementScope(
            repository: paid,
            initialState: const EntitlementState(
              status: EntitlementStatus.activePaid,
            ),
            child: PersonalPatternsRoute(
              source: harness.patterns,
              now: () => _now,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('2 completed cycles'), findsWidgets);
      await tester.tap(find.byKey(const Key('patterns-tab-helped')));
      await tester.pumpAndSettle();
      final careRow = find.byKey(
        const Key('patterns-care-row-Warmth and quiet'),
      );
      await _reveal(tester, careRow);
      expect(careRow, findsOneWidget);
      await tester.tap(careRow);
      await tester.pumpAndSettle();
      expect(find.textContaining('Better'), findsWidgets);

      await _pumpReports(tester, harness);
      await _reveal(tester, find.text('Two completed cycles in this range'));
      expect(find.text('Two completed cycles in this range'), findsOneWidget);
      await _reveal(tester, find.textContaining('Cramps ·').first);
      expect(find.textContaining('Cramps ·'), findsWidgets);
      expect(
        find.textContaining('Headache'),
        findsNothing,
        reason:
            'The May 1 record is outside the free recent-three-month range.',
      );
    },
  );

  testWidgets(
    'irregular multi-cycle Drift facts render in production Patterns and Reports without using the current cycle for Comfort',
    (tester) async {
      final harness = _Harness(
        now: DateTime.utc(2026, 4, 21, 12),
        today: const LocalDate(2026, 4, 21),
      );
      addTearDown(harness.close);
      _phone(tester);

      for (final draft in const <PeriodDraft>[
        PeriodDraft(
          startDate: LocalDate(2026, 1, 1),
          endDate: LocalDate(2026, 1, 5),
        ),
        PeriodDraft(
          startDate: LocalDate(2026, 1, 25),
          endDate: LocalDate(2026, 1, 29),
        ),
        PeriodDraft(
          startDate: LocalDate(2026, 3, 4),
          endDate: LocalDate(2026, 3, 8),
        ),
        PeriodDraft(startDate: LocalDate(2026, 4, 1)),
      ]) {
        await harness.periods.create(
          draft,
          today: const LocalDate(2026, 4, 21),
        );
      }
      await harness.health.create(
        const HealthRecordDraft(
          symptom: SymptomType.cramps,
          severity: SymptomSeverity.moderate,
          experiencedDate: LocalDate(2026, 2, 20),
          provenance: HealthRecordProvenance.sameDay,
        ),
      );
      for (final entry in const <(LocalDate, MomentCheckInState)>[
        (LocalDate(2026, 4, 3), MomentCheckInState.steady),
        (LocalDate(2026, 4, 5), MomentCheckInState.steady),
        (LocalDate(2026, 4, 7), MomentCheckInState.steady),
        (LocalDate(2026, 4, 9), MomentCheckInState.steady),
        (LocalDate(2026, 4, 16), MomentCheckInState.irritable),
        (LocalDate(2026, 4, 17), MomentCheckInState.irritable),
        (LocalDate(2026, 4, 18), MomentCheckInState.irritable),
      ]) {
        await harness.checkIns.create(
          entry.$2,
          occurredAt: entry.$1.asLocalDateTime.add(const Duration(hours: 12)),
        );
      }

      expect(
        await harness.database.select(harness.database.periodRows).get(),
        hasLength(4),
      );
      expect(
        await harness.database.select(harness.database.momentCheckInRows).get(),
        hasLength(7),
      );

      final paid = LocalEntitlementRepository(
        initial: const EntitlementState(status: EntitlementStatus.activePaid),
      );
      addTearDown(paid.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: LetterTheme.light,
          home: EntitlementScope(
            repository: paid,
            initialState: const EntitlementState(
              status: EntitlementStatus.activePaid,
            ),
            child: PersonalPatternsRoute(
              source: harness.patterns,
              now: () => DateTime.utc(2026, 4, 21, 12),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('3 completed cycles'), findsWidgets);
      await tester.tap(find.byKey(const Key('patterns-tab-cycles')));
      await tester.pumpAndSettle();
      expect(find.textContaining('24'), findsWidgets);
      expect(find.textContaining('38'), findsWidgets);

      await _pumpReports(tester, harness);
      expect((await harness.reportPort.load()).healthRecords, hasLength(1));
      await _reveal(tester, find.textContaining('Cramps · Moderate'));
      expect(find.textContaining('Cramps · Moderate'), findsWidgets);

      final comfort = await harness.comfort.load();
      expect(
        comfort.window,
        isNull,
        reason:
            'Only current unfinished-cycle check-ins exist; they must not train the Comfort Window.',
      );
    },
  );
}

final class _Harness {
  _Harness({DateTime? now, LocalDate? today})
    : now = now ?? _now,
      today = today ?? _today,
      database = LetterHealthDatabase(NativeDatabase.memory()) {
    var nextPeriodId = 0;
    periods = DriftPeriodRepository(
      database,
      closeDatabase: false,
      clock: () => this.now,
      idGenerator: () => 'period-${nextPeriodId++}',
    );
    var nextHealthId = 0;
    health = DriftHealthRecordRepository(
      database,
      closeDatabase: false,
      clock: () => this.now,
      idGenerator: () => 'health-${nextHealthId++}',
    );
    var nextCheckInId = 0;
    checkIns = DriftMomentCheckInRepository(
      database,
      closeDatabase: false,
      clock: () => this.now,
      idGenerator: () => 'check-${nextCheckInId++}',
    );
    care = DriftCareMemoryRepository(
      database,
      closeDatabase: false,
      clock: () => this.now,
    );
    notes = DriftCaptureNoteStore(database, closeDatabase: false);
    patterns = RepositoryPatternSource(
      healthRecords: health,
      careMemory: care,
      periods: periods,
      momentCheckIns: checkIns,
      now: () => this.now,
    );
    entitlement = LocalEntitlementRepository();
    reportPort = LetterReportExperiencePort(
      periodRepository: periods,
      careMemoryRepository: care,
      healthRecordRepository: health,
      momentCheckInRepository: checkIns,
      captureNoteStore: notes,
      entitlementRepository: entitlement,
      now: () => this.now,
    );
    comfort = ComfortExperienceController(
      patternSource: patterns,
      careMemory: care,
      quickNotes: notes,
      kitRepository: DriftComfortKitRepository(database),
      reminderRepository: DriftComfortReminderPreferenceRepository(database),
      now: () => this.now,
    );
    todayPort = RepositoryTodayVisualPort(
      periodRepository: periods,
      checkInRepository: checkIns,
      healthRecordRepository: health,
      captureNoteStore: notes,
      today: () => this.today,
      now: () => this.now,
      onCycleDataChanged: () {},
      onOpenCare: () {},
      loadComfortExperience: comfort.load,
    );
  }

  final DateTime now;
  final LocalDate today;
  final LetterHealthDatabase database;
  late final DriftPeriodRepository periods;
  late final DriftHealthRecordRepository health;
  late final DriftMomentCheckInRepository checkIns;
  late final DriftCareMemoryRepository care;
  late final DriftCaptureNoteStore notes;
  late final RepositoryPatternSource patterns;
  late final LocalEntitlementRepository entitlement;
  late final LetterReportExperiencePort reportPort;
  late final ComfortExperienceController comfort;
  late final RepositoryTodayVisualPort todayPort;

  Future<void> close() async {
    entitlement.dispose();
    await database.close();
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder _verticalScrollable() => find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          (widget.axisDirection == AxisDirection.down ||
              widget.axisDirection == AxisDirection.up),
    )
    .first;

Future<void> _pumpReports(WidgetTester tester, _Harness harness) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: ExperienceFoundation.lightTheme(),
      home: ReportsExperience(port: harness.reportPort, now: () => harness.now),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: _verticalScrollable(),
  );
  await tester.pumpAndSettle();
}
