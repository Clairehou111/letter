import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/comfort_kit/application/comfort_experience_controller.dart';
import 'package:letter_mobile/features/comfort_kit/data/in_memory_comfort_kit_repository.dart';
import 'package:letter_mobile/features/comfort_window/data/comfort_reminder_preference_repositories.dart';
import 'package:letter_mobile/features/patterns/data/repository_pattern_source.dart';
import 'package:letter_mobile/experience/letter_experience_shell.dart';
import 'package:letter_mobile/experience/you/you_experience.dart';
import 'package:letter_mobile/experience/today/today_experience_visual_baseline.dart';
import 'package:letter_mobile/experience/records/observation_picker.dart';
import 'package:letter_mobile/experience/reports/reports_experience.dart';
import 'package:letter_mobile/experience/plus/plus_experience.dart';
import 'package:letter_mobile/features/auth/domain/auth_service.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/check_in/data/in_memory_moment_check_in_repository.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';
import 'package:letter_mobile/features/preparation/data/in_memory_preparation_repository.dart';
import 'package:letter_mobile/features/privacy/domain/privacy_preferences.dart';
import 'package:letter_mobile/features/record_hub/data/drift_record_hub_repository.dart';
import 'package:letter_mobile/features/record_hub/domain/record_session.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_hub_screen.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_entry_section.dart';

const _today = LocalDate(2026, 10, 9);

Finder _tab(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);
Finder _todayDate(String label) => find.descendant(
  of: find.byKey(const Key('today-shell-header')),
  matching: find.text(label),
);
Finder _recordDate(WidgetTester tester, LocalDate date) => find.descendant(
  of: find.byKey(const Key('record-date')),
  matching: find.text(
    MaterialLocalizations.of(
      tester.element(find.byKey(const Key('record-date'))),
    ).formatMediumDate(date.asLocalDateTime),
  ),
);
Finder get _recordAction => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.label == 'Record today or another date',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
    'four destinations retain selection and Record is an independent action',
    (tester) async {
      final fixture = await _pumpShell(tester);
      for (final label in ['Today', 'Cycle', 'Care', 'Patterns']) {
        expect(_tab(label), findsOneWidget);
        expect(tester.widget<Semantics>(_tab(label)).properties.button, isTrue);
      }
      expect(
        tester.widget<Semantics>(_tab('Today')).properties.selected,
        isTrue,
      );
      expect(
        tester.widget<Semantics>(_recordAction).properties.selected,
        isNull,
      );
      expect(_tab('You'), findsNothing);
      for (final entry in <String, RecordOrigin>{
        'Today': RecordOrigin.today,
        'Cycle': RecordOrigin.cycle,
        'Patterns': RecordOrigin.patterns,
      }.entries) {
        await tester.tap(_tab(entry.key));
        await _settle(tester);
        await tester.tap(_recordAction);
        await _settle(tester);
        final screen = tester.widget<RecordHubScreen>(
          find.byType(RecordHubScreen),
        );
        expect(screen.origin, entry.value);
        expect(screen.initialDate, _today);
        expect(_recordDate(tester, _today), findsOneWidget);
        await _done(tester);
        expect(
          tester.widget<Semantics>(_tab(entry.key)).properties.selected,
          isTrue,
        );
      }
      await tester.tap(_tab('Care'));
      await tester.pump(const Duration(seconds: 1));
      expect(_recordAction.hitTestable(), findsNothing);
      expect(find.text('Return to daylight').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Return to daylight'));
      await _settle(tester);
      expect(
        tester.widget<Semantics>(_tab('Today')).properties.selected,
        isTrue,
      );
      await fixture.close(tester);
    },
  );

  testWidgets(
    'rapid Today shortcut opens one Record route and guard resets after return',
    (tester) async {
      final fixture = await _pumpShell(tester);
      final today = tester.widget<TodayExperienceVisual>(
        find.byType(TodayExperienceVisual),
      );
      final open = today.onOpenRecordSection!;
      final originRoute = ModalRoute.of(
        tester.element(find.byType(TodayExperienceVisual)),
      );
      open(RecordEntrySection.body);
      open(RecordEntrySection.body);
      await _settle(tester);
      expect(find.byType(RecordHubScreen, skipOffstage: false), findsOneWidget);
      final record = tester.widget<RecordHubScreen>(
        find.byType(RecordHubScreen),
      );
      expect(record.origin, RecordOrigin.today);
      expect(record.initialSection, RecordEntrySection.body);
      await _done(tester);
      expect(find.byType(RecordHubScreen, skipOffstage: false), findsNothing);
      expect(
        ModalRoute.of(tester.element(find.byType(TodayExperienceVisual))),
        same(originRoute),
      );
      expect(
        tester.widget<Semantics>(_tab('Today')).properties.selected,
        isTrue,
      );
      tester
          .widget<TodayExperienceVisual>(find.byType(TodayExperienceVisual))
          .onOpenRecordSection!(RecordEntrySection.body);
      await _settle(tester);
      expect(find.byType(RecordHubScreen, skipOffstage: false), findsOneWidget);
      await _done(tester);
      expect(await fixture.health.getAll(), isEmpty);
      await fixture.close(tester);
    },
  );

  testWidgets(
    'Today pinned opens once, saves zero and returns to the retained Today route',
    (tester) async {
      final fixture = await _pumpShell(
        tester,
        pins: [SymptomType.cramps, SymptomType.anxiety],
      );
      final today = tester.widget<TodayExperienceVisual>(
        find.byType(TodayExperienceVisual),
      );
      final originRoute = ModalRoute.of(
        tester.element(find.byType(TodayExperienceVisual)),
      );
      today.onOpenSymptom!(SymptomType.cramps);
      today.onOpenSymptom!(SymptomType.cramps);
      await _settle(tester);
      await _settle(tester);
      expect(find.byType(RecordHubScreen, skipOffstage: false), findsOneWidget);
      expect(
        find.byKey(const Key('observation-fullscreen-editor')),
        findsOneWidget,
      );
      expect(await fixture.health.getAll(), isEmpty);
      await tester.tap(find.byKey(const Key('observation-degree-0')));
      await _settle(tester);
      final saved = (await fixture.health.getAll()).single;
      expect(saved.symptom, SymptomType.cramps);
      expect(saved.severity, SymptomSeverity.notPresent);
      await tester.tap(find.byKey(const Key('observation-editor-close')));
      await _settle(tester);
      expect(find.byType(RecordHubScreen, skipOffstage: false), findsNothing);
      expect(
        ModalRoute.of(tester.element(find.byType(TodayExperienceVisual))),
        same(originRoute),
      );
      expect(
        tester.widget<Semantics>(_tab('Today')).properties.selected,
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('today-pinned-cramps')),
          matching: find.text('Not present'),
        ),
        findsOneWidget,
      );
      expect((await fixture.health.getAll()).single.id, saved.id);
      await fixture.close(tester);
    },
  );

  testWidgets('Today Bleeding opens its controls without creating a fact', (
    tester,
  ) async {
    final fixture = await _pumpShell(tester);
    final shortcut = find.byKey(const Key('today-bleeding-shortcut'));
    await tester.ensureVisible(shortcut);
    await tester.tap(shortcut);
    await _settle(tester);
    // The loaded route expands its disclosure, then reveals the final layout.
    await _settle(tester);
    expect(
      tester
          .widget<RecordHubScreen>(find.byType(RecordHubScreen))
          .initialSection,
      RecordEntrySection.bleeding,
    );
    expect(find.byKey(const Key('record-flow-none')), findsOneWidget);
    expect(
      find.byKey(const Key('record-flow-none')).hitTestable(),
      findsOneWidget,
    );
    expect(
      (await tester.runAsync(() => fixture.hub.getDateFacts(_today)))!.bleeding,
      isNull,
    );
    await _done(tester);
    await fixture.close(tester);
  });

  testWidgets(
    'Settings retains account, protection, backup, reports and Plus routes',
    (tester) async {
      final fixture = await _pumpShell(tester);
      await tester.tap(find.byTooltip('Settings').hitTestable().first);
      await _settle(tester);
      expect(find.byType(YouExperience), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      for (final label in [
        'Protection & preferences',
        'Backup & restore',
        'Clinician reports',
        'Letter Within Plus',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          200,
          scrollable: find
              .descendant(
                of: find.byType(YouExperience),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.text(label).hitTestable(), findsOneWidget);
        if (label == 'Clinician reports') {
          final settingsRoute = ModalRoute.of(
            tester.element(find.byType(YouExperience)),
          );
          await tester.tap(find.text(label));
          await _settle(tester);
          expect(find.byType(ReportsExperience), findsOneWidget);
          Navigator.of(tester.element(find.byType(ReportsExperience))).pop();
          await _settle(tester);
          expect(
            ModalRoute.of(tester.element(find.byType(YouExperience))),
            same(settingsRoute),
          );
        } else if (label == 'Letter Within Plus') {
          await tester.tap(find.text(label));
          await _settle(tester);
          expect(find.byType(PlusExperience), findsOneWidget);
          Navigator.of(tester.element(find.byType(PlusExperience))).pop();
          await _settle(tester);
          expect(fixture.entitlement.current.status.name, 'freeOrUnknown');
        }
      }
      await tester.pageBack();
      await _settle(tester);
      expect(
        tester.widget<Semantics>(_tab('Today')).properties.selected,
        isTrue,
      );
      expect(await fixture.health.getAll(), isEmpty);
      await fixture.close(tester);
    },
  );

  testWidgets('Today All records enters the same dated Record workspace', (
    tester,
  ) async {
    final fixture = await _pumpShell(tester);
    for (final label in ['All records']) {
      final button = find.text(label);
      await tester.ensureVisible(button);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(button);
      await _settle(tester);
      final screen = tester.widget<RecordHubScreen>(
        find.byType(RecordHubScreen),
      );
      expect(screen.initialDate, _today);
      expect(screen.origin, RecordOrigin.today);
      expect(screen.initialSection, null);
      await _done(tester);
    }
    expect(await fixture.health.getAll(), isEmpty);
    await fixture.close(tester);
  });

  testWidgets(
    'Cycle nonbleeding day returns to the exact retained cycle detail',
    (tester) async {
      final fixture = await _pumpShell(tester, periods: [_period()]);
      await tester.tap(_tab('Cycle'));
      await _settle(tester);
      await tester.ensureVisible(find.text('Current cycle').first);
      await tester.tap(find.text('Current cycle').first);
      await _settle(tester);
      final choose = find.text('Choose any day in this cycle');
      final detailRoute = ModalRoute.of(tester.element(choose));
      expect(detailRoute, isNotNull);
      await tester.ensureVisible(choose);
      await tester.tap(choose);
      await _settle(tester);
      await tester.tap(find.byKey(const Key('record-calendar-day-2026-10-07')));
      await _settle(tester);
      final screen = tester.widget<RecordHubScreen>(
        find.byType(RecordHubScreen),
      );
      expect(screen.origin, RecordOrigin.cycle);
      expect(screen.initialDate, const LocalDate(2026, 10, 7));
      expect(await fixture.periods.getAllFlowDays(), isEmpty);
      final search = find.descendant(
        of: find.byType(ObservationPicker),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Cramps');
      await tester.pump();
      await tester.ensureVisible(find.text('Cramps').last);
      await tester.tap(find.text('Cramps').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('observation-degree-0')));
      await tester.tap(find.byKey(const Key('observation-degree-0')));
      await _settle(tester);
      final record = (await fixture.health.getAll()).single;
      expect(record.experiencedDate, const LocalDate(2026, 10, 7));
      expect(record.severity, SymptomSeverity.notPresent);
      expect(record.provenance, HealthRecordProvenance.laterRecall);
      await _done(tester);
      expect(ModalRoute.of(tester.element(choose)), same(detailRoute));
      expect(
        find.textContaining('day 7 of your current cycle'),
        findsOneWidget,
      );
      Navigator.of(tester.element(choose)).pop();
      await _settle(tester);
      expect(
        tester.widget<Semantics>(_tab('Cycle')).properties.selected,
        isTrue,
      );
      await fixture.close(tester);
    },
  );

  testWidgets(
    'Cycle records before its first observed period without inventing bleeding',
    (tester) async {
      final fixture = await _pumpShell(tester, periods: [_period()]);
      await tester.tap(_tab('Cycle'));
      await _settle(tester);
      await tester.tap(find.text('Record any day'));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('record-calendar-day-2026-10-01')));
      await _settle(tester);
      expect(
        tester
            .widget<RecordHubScreen>(find.byType(RecordHubScreen))
            .initialDate,
        const LocalDate(2026, 10, 1),
      );
      await _done(tester);
      await tester.tap(_recordAction);
      await _settle(tester);
      expect(
        tester
            .widget<RecordHubScreen>(find.byType(RecordHubScreen))
            .initialDate,
        _today,
      );
      await _done(tester);
      expect(
        (await fixture.periods.getAll()).single.startDate,
        const LocalDate(2026, 10, 3),
      );
      expect(await fixture.periods.getAllFlowDays(), isEmpty);
      expect(
        tester.widget<Semantics>(_tab('Cycle')).properties.selected,
        isTrue,
      );
      await fixture.close(tester);
    },
  );

  testWidgets(
    'midnight refreshes actual Today but retains an open Record date',
    (tester) async {
      final fixture = await _pumpShell(
        tester,
        now: DateTime(2026, 10, 9, 23, 59, 59),
      );
      expect(_todayDate('Fri, Oct 9'), findsOneWidget);
      await tester.tap(_recordAction);
      await _settle(tester);
      fixture.now = DateTime(2026, 10, 10, 0, 0, 1);
      await tester.pump(const Duration(seconds: 2));
      await _settle(tester);
      expect(_recordDate(tester, _today), findsOneWidget);
      await _done(tester);
      expect(_todayDate('Sat, Oct 10'), findsOneWidget);
      await tester.tap(_recordAction);
      await _settle(tester);
      expect(
        tester
            .widget<RecordHubScreen>(find.byType(RecordHubScreen))
            .initialDate,
        const LocalDate(2026, 10, 10),
      );
      await _done(tester);
      await fixture.close(tester);
    },
  );

  testWidgets(
    'resume refreshes actual Today after a suspended local-day change',
    (tester) async {
      final fixture = await _pumpShell(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      fixture.now = DateTime(2026, 10, 10, 12);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);
      expect(_todayDate('Sat, Oct 10'), findsOneWidget);
      expect(_todayDate('Fri, Oct 9'), findsNothing);
      await tester.tap(_recordAction);
      await _settle(tester);
      expect(
        tester
            .widget<RecordHubScreen>(find.byType(RecordHubScreen))
            .initialDate,
        const LocalDate(2026, 10, 10),
      );
      await _done(tester);
      await fixture.close(tester);
    },
  );
}

Future<void> _settle(WidgetTester tester) async {
  // Patterns and Care have intentional continuous motion. Advance route
  // transitions explicitly and let the real SQLite worker finish its reads.
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 800));
  // Focused pages are pushed after the loaded Record frame.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _done(WidgetTester tester) async {
  if (find.byKey(const Key('observation-editor-close')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('observation-editor-close')));
    await _settle(tester);
  }
  await tester.tap(find.text('Done').last);
  await _settle(tester);
  expect(find.byType(RecordHubScreen), findsNothing);
}

PeriodRecord _period() => PeriodRecord(
  id: 'synthetic-period',
  startDate: const LocalDate(2026, 10, 3),
  endDate: const LocalDate(2026, 10, 5),
  createdAt: DateTime.utc(2026, 10, 3),
  updatedAt: DateTime.utc(2026, 10, 5),
);

Future<_ShellFixture> _pumpShell(
  WidgetTester tester, {
  DateTime? now,
  List<PeriodRecord> periods = const [],
  List<SymptomType>? pins,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final fixture = _ShellFixture(now ?? DateTime(2026, 10, 9, 12), periods);
  await tester.runAsync(() => fixture.hub.getDateFacts(_today));
  if (pins != null) {
    await tester.runAsync(() => fixture.hub.setPins(SymptomPins(pins)));
  }
  final careMemory = InMemoryCareMemoryRepository();
  final captureNotes = InMemoryCaptureNoteStore(clock: () => fixture.now);
  final moments = InMemoryMomentCheckInRepository(clock: () => fixture.now);
  final comfortKit = InMemoryComfortKitRepository();
  final comfortReminder = InMemoryComfortReminderPreferenceRepository();
  final comfort = ComfortExperienceController(
    patternSource: RepositoryPatternSource(
      healthRecords: fixture.health,
      careMemory: careMemory,
      periods: fixture.periods,
      momentCheckIns: moments,
      now: () => fixture.now,
    ),
    careMemory: careMemory,
    quickNotes: captureNotes,
    kitRepository: comfortKit,
    reminderRepository: comfortReminder,
    now: () => fixture.now,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: ExperienceFoundation.lightTheme(),
      home: LetterExperienceShell(
        periodRepository: fixture.periods,
        careMemoryRepository: careMemory,
        healthRecordRepository: fixture.health,
        captureNoteStore: captureNotes,
        momentCheckInRepository: moments,
        comfortKitRepository: comfortKit,
        comfortReminderPreferenceRepository: comfortReminder,
        comfortExperienceController: comfort,
        preparationRepository: InMemoryPreparationRepository(),
        entitlementRepository: fixture.entitlement,
        reportPort: _ReportPort(),
        youPort: _YouPort(),
        recordHubRepository: fixture.hub,
        now: () => fixture.now,
        onCycleDataChanged: () async {},
      ),
    ),
  );
  addTearDown(() => fixture.close(tester));
  await _settle(tester);
  return fixture;
}

final class _ShellFixture {
  _ShellFixture(this.now, List<PeriodRecord> seeds)
    : periods = InMemoryPeriodRepository(seed: seeds) {
    hub = DriftRecordHubRepository(database, clock: () => now);
    health = InMemoryHealthRecordRepository(clock: () => now);
  }
  DateTime now;
  final database = LetterHealthDatabase(NativeDatabase.memory());
  final InMemoryPeriodRepository periods;
  final entitlement = LocalEntitlementRepository();
  late final DriftRecordHubRepository hub;
  late final InMemoryHealthRecordRepository health;
  bool _closed = false;
  Future<void> close(WidgetTester tester) async {
    if (_closed) return;
    _closed = true;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(database.close);
    await entitlement.dispose();
  }
}

final class _YouPort implements YouExperiencePort {
  @override
  AuthState get account => const AuthState(status: AuthStatus.offlineOrExpired);
  @override
  PrivacyPreferences get privacy => const PrivacyPreferences();
  @override
  Stream<AuthState> watchAccount() => const Stream.empty();
  @override
  Future<void> savePrivacy(PrivacyPreferences preferences) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> deleteServerAccount() async {}
}

final class _ReportPort implements ReportExperiencePort {
  @override
  Future<SummaryExportInput> load() async => const SummaryExportInput(
    periodDays: [],
    predictions: [],
    healthRecords: [],
    checkIns: [],
    careRecords: [],
    notes: [],
  );
  @override
  Future<ExperienceFileReceipt> export({
    required SummaryDateRange range,
    required Set<String> selectedNoteIds,
    required ReportExportFormat format,
  }) async =>
      const ExperienceFileReceipt(outcome: ExperienceFileOutcome.cancelled);
}
