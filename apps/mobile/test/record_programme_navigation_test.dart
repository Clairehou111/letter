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
import 'package:letter_mobile/features/auth/domain/auth_service.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/check_in/data/in_memory_moment_check_in_repository.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/preparation/data/in_memory_preparation_repository.dart';
import 'package:letter_mobile/features/privacy/domain/privacy_preferences.dart';
import 'package:letter_mobile/features/record_hub/data/drift_record_hub_repository.dart';
import 'package:letter_mobile/features/record_hub/domain/record_session.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_hub_screen.dart';

import 'package:letter_mobile/features/record_hub/data/drift_record_programme_repository.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_programme_screen.dart';

const _today = LocalDate(2026, 10, 9);
Finder _tab(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
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
    'free Patterns enrolls without ratings and opens shared Record; Today continues',
    (tester) async {
      final fixture = await _pumpShell(tester);
      expect(fixture.entitlement.current.status.name, 'freeOrUnknown');
      expect(
        find.byKey(const Key('pattern-record-entrance')).hitTestable(),
        findsNothing,
      );
      await tester.tap(_tab('Patterns'));
      await _settle(tester);
      await tester.tap(
        find.byKey(const Key('pattern-record-entrance')).hitTestable(),
      );
      await _settle(tester);
      expect(find.byType(RecordProgrammeScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('programme-start')));
      await _settle(tester);
      final checkbox = find.widgetWithText(CheckboxListTile, 'Cramps');
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();
      await tester.tap(find.text('Save fields'));
      await _settle(tester);
      final programme = await tester.runAsync(fixture.programme.getCurrent);
      expect(programme!.configurations.single.symptoms, [SymptomType.cramps]);
      expect(await fixture.health.getAll(), isEmpty);
      final facts = await tester.runAsync(
        () => fixture.hub.getDateFacts(_today),
      );
      expect(facts!.impact, isNull);
      final programmeRoute = ModalRoute.of(
        tester.element(find.byType(RecordProgrammeScreen)),
      );
      final cramps = find.widgetWithText(ActionChip, 'Cramps').first;
      await tester.ensureVisible(cramps);
      await tester.tap(cramps);
      await _settle(tester);
      final screen = tester.widget<RecordHubScreen>(
        find.byType(RecordHubScreen),
      );
      expect(screen.initialDate, _today);
      expect(screen.origin, RecordOrigin.patterns);
      expect(screen.initialSymptom, SymptomType.cramps);
      await tester.ensureVisible(find.byKey(const Key('observation-degree-0')));
      await tester.tap(find.byKey(const Key('observation-degree-0')));
      await _settle(tester);
      final source = (await fixture.health.getAll()).single;
      expect(source.experiencedDate, _today);
      expect(source.severity, SymptomSeverity.notPresent);
      await _done(tester);
      expect(
        ModalRoute.of(tester.element(find.byType(RecordProgrammeScreen))),
        same(programmeRoute),
      );
      await tester.pageBack();
      await _settle(tester);
      expect(
        tester.widget<Semantics>(_tab('Patterns')).properties.selected,
        isTrue,
      );
      await tester.tap(_tab('Today'));
      await _settle(tester);
      final todayContinuation = find.descendant(
        of: find.byKey(const ValueKey<String>('destination-today')),
        matching: find.byKey(const Key('pattern-record-entrance')),
      );
      await tester.ensureVisible(todayContinuation);
      await tester.pump(const Duration(milliseconds: 800));
      expect(todayContinuation.hitTestable(), findsOneWidget);
      await tester.tap(todayContinuation);
      await _settle(tester);
      expect(find.text('Your selected fields'), findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(ActionChip, 'Cramps').first,
      );
      await tester.tap(find.widgetWithText(ActionChip, 'Cramps').first);
      await _settle(tester);
      expect(
        tester.widget<RecordHubScreen>(find.byType(RecordHubScreen)).origin,
        RecordOrigin.today,
      );
      final mild = find.byKey(const Key('observation-degree-2'));
      await tester.ensureVisible(mild);
      await tester.tap(mild);
      await _settle(tester);
      final revised = (await fixture.health.getAll()).single;
      expect(revised.id, source.id);
      expect(revised.severity, SymptomSeverity.mild);
      expect(
        (await tester.runAsync(fixture.programme.getCurrent))!.id,
        programme.id,
      );
      await _done(tester);
      await tester.pageBack();
      await _settle(tester);
      expect(
        tester.widget<Semantics>(_tab('Today')).properties.selected,
        isTrue,
      );
      expect(fixture.entitlement.current.status.name, 'freeOrUnknown');
      expect(tester.takeException(), isNull);
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
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump(const Duration(milliseconds: 320));
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

Future<_ShellFixture> _pumpShell(
  WidgetTester tester, {
  DateTime? now,
  List<PeriodRecord> periods = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final fixture = _ShellFixture(now ?? DateTime(2026, 10, 9, 12), periods);
  await tester.runAsync(() => fixture.hub.getDateFacts(_today));
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
        programmeRepository: fixture.programme,
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
    programme = DriftRecordProgrammeRepository(database, clock: () => now);
  }
  DateTime now;
  final database = LetterHealthDatabase(NativeDatabase.memory());
  final InMemoryPeriodRepository periods;
  final entitlement = LocalEntitlementRepository();
  late final DriftRecordHubRepository hub;
  late final InMemoryHealthRecordRepository health;
  late final DriftRecordProgrammeRepository programme;
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
