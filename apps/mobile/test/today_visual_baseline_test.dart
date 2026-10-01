import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/today/today_experience_visual_baseline.dart';
import 'package:letter_mobile/experience/today/today_visual_port.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/check_in/data/in_memory_moment_check_in_repository.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/bleeding_flow.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/today/today_cycle_context.dart';

final class _DeferredMoodPort implements TodayVisualPort {
  _DeferredMoodPort(this.delegate, this.onSaveMood);

  final TodayVisualPort delegate;
  final Future<TodayVisualSnapshot> Function(MomentCheckInState) onSaveMood;

  @override
  Future<TodayVisualSnapshot> load() => delegate.load();

  @override
  Future<TodayVisualSnapshot> saveMood(MomentCheckInState state) =>
      onSaveMood(state);

  @override
  Future<TodayVisualSnapshot> startPeriod() => delegate.startPeriod();

  @override
  Future<TodayVisualSnapshot> endOpenPeriodToday() =>
      delegate.endOpenPeriodToday();

  @override
  Future<TodayVisualSnapshot> setFlow(BleedingFlow? flow) =>
      delegate.setFlow(flow);

  @override
  Future<TodayVisualSnapshot> setColor(BleedingColor color) =>
      delegate.setColor(color);

  @override
  Future<TodayVisualSnapshot> saveSymptom(
    SymptomType symptom,
    SymptomSeverity severity,
  ) => delegate.saveSymptom(symptom, severity);

  @override
  Future<TodayVisualSnapshot> removeSymptom(String recordId) =>
      delegate.removeSymptom(recordId);

  @override
  Future<TodayVisualSnapshot> saveNote(String text) => delegate.saveNote(text);

  @override
  Future<TodayVisualSnapshot> saveQuickNote(
    String text, {
    bool keepInComfortKit = false,
  }) => delegate.saveQuickNote(text, keepInComfortKit: keepInComfortKit);

  @override
  Future<TodayVisualSnapshot> updateQuickNote(
    String noteId, {
    required String text,
    required bool keepInComfortKit,
  }) => delegate.updateQuickNote(
    noteId,
    text: text,
    keepInComfortKit: keepInComfortKit,
  );

  @override
  Future<TodayVisualSnapshot> deleteQuickNote(String noteId) =>
      delegate.deleteQuickNote(noteId);

  @override
  Future<TodayVisualSnapshot> saveComfortReminder({
    required bool enabled,
    required int leadDays,
  }) => delegate.saveComfortReminder(enabled: enabled, leadDays: leadDays);

  @override
  Future<void> openCare() => delegate.openCare();
}

final class _LoadOnlyPort implements TodayVisualPort {
  _LoadOnlyPort(this.onLoad, {this.onSaveComfortReminder});

  final Future<TodayVisualSnapshot> Function() onLoad;
  final Future<TodayVisualSnapshot> Function({
    required bool enabled,
    required int leadDays,
  })?
  onSaveComfortReminder;

  @override
  Future<TodayVisualSnapshot> load() => onLoad();

  Never _unsupported() => throw UnsupportedError('write not expected');

  @override
  Future<TodayVisualSnapshot> saveMood(MomentCheckInState state) =>
      _unsupported();

  @override
  Future<TodayVisualSnapshot> startPeriod() => _unsupported();

  @override
  Future<TodayVisualSnapshot> endOpenPeriodToday() => _unsupported();

  @override
  Future<TodayVisualSnapshot> setFlow(BleedingFlow? flow) => _unsupported();

  @override
  Future<TodayVisualSnapshot> setColor(BleedingColor color) => _unsupported();

  @override
  Future<TodayVisualSnapshot> saveSymptom(
    SymptomType symptom,
    SymptomSeverity severity,
  ) => _unsupported();

  @override
  Future<TodayVisualSnapshot> removeSymptom(String recordId) => _unsupported();

  @override
  Future<TodayVisualSnapshot> saveNote(String text) => _unsupported();

  @override
  Future<TodayVisualSnapshot> saveQuickNote(
    String text, {
    bool keepInComfortKit = false,
  }) => _unsupported();

  @override
  Future<TodayVisualSnapshot> updateQuickNote(
    String noteId, {
    required String text,
    required bool keepInComfortKit,
  }) => _unsupported();

  @override
  Future<TodayVisualSnapshot> deleteQuickNote(String noteId) => _unsupported();

  @override
  Future<TodayVisualSnapshot> saveComfortReminder({
    required bool enabled,
    required int leadDays,
  }) {
    final save = onSaveComfortReminder;
    return save == null
        ? _unsupported()
        : save(enabled: enabled, leadDays: leadDays);
  }

  @override
  Future<void> openCare() => _unsupported();
}

RepositoryTodayVisualPort _emptyPort() {
  const today = LocalDate(2026, 8, 15);
  final now = DateTime(2026, 8, 15, 12);
  return RepositoryTodayVisualPort(
    periodRepository: InMemoryPeriodRepository(clock: () => now),
    checkInRepository: InMemoryMomentCheckInRepository(clock: () => now),
    healthRecordRepository: InMemoryHealthRecordRepository(clock: () => now),
    captureNoteStore: InMemoryCaptureNoteStore(),
    today: () => today,
    now: () => now,
    onCycleDataChanged: () {},
    onOpenCare: () {},
  );
}

Future<TodayVisualSnapshot> _snapshotWithComfort(
  TodayComfortWindowState? comfort,
) async {
  final base = await _emptyPort().load();
  return TodayVisualSnapshot(
    today: base.today,
    containingPeriod: base.containingPeriod,
    openPeriod: base.openPeriod,
    flowRecord: base.flowRecord,
    mood: base.mood,
    symptoms: base.symptoms,
    note: base.note,
    quickNotes: base.quickNotes,
    cycleContext: base.cycleContext,
    rememberedHelpLine: base.rememberedHelpLine,
    comfortWindow: comfort,
  );
}

void main() {
  testWidgets('maximum accessibility text keeps Today usable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(3.2),
            disableAnimations: true,
          ),
          child: TodayExperienceVisual(port: _emptyPort()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = find.text('Letter Within');
    expect(title, findsOneWidget);
    final titleRect = tester.getRect(title);
    expect(titleRect.left, greaterThanOrEqualTo(0));
    expect(titleRect.right, lessThanOrEqualTo(390));
    expect(
      tester
          .renderObject<RenderParagraph>(title)
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 13),
          ),
      hasLength(1),
    );

    final hero = find.text('A quiet beginning');
    expect(hero, findsOneWidget);
    expect(find.text('Private on this device.'), findsOneWidget);
    expect(find.text('Private by default. Always yours.'), findsNothing);
    expect(tester.getRect(hero).top, lessThan(844));
    expect(
      tester
          .renderObject<RenderParagraph>(hero)
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 17),
          )
          .length,
      lessThanOrEqualTo(3),
      reason: 'No word in the three-word hero title may split internally',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed Today load is not presented as learning', (
    tester,
  ) async {
    final port = _LoadOnlyPort(
      () async => throw StateError('forced load failure'),
    );
    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: port)),
    );
    await tester.pumpAndSettle();

    expect(find.text('We couldn’t read today’s notes'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Getting to know you'), findsNothing);
  });

  testWidgets('an older Today read cannot replace a newer cycle revision', (
    tester,
  ) async {
    final stale = Completer<TodayVisualSnapshot>();
    final latest = Completer<TodayVisualSnapshot>();
    var reads = 0;
    final port = _LoadOnlyPort(
      () => reads++ == 0 ? stale.future : latest.future,
    );

    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: port, revision: 0)),
    );
    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: port, revision: 1)),
    );

    final base = await _emptyPort().load();
    final period = PeriodRecord(
      id: 'latest',
      startDate: const LocalDate(2026, 8, 14),
      endDate: null,
      createdAt: DateTime.utc(2026, 8, 14),
      updatedAt: DateTime.utc(2026, 8, 14),
    );
    latest.complete(
      TodayVisualSnapshot(
        today: base.today,
        containingPeriod: period,
        openPeriod: period,
        flowRecord: null,
        mood: null,
        symptoms: const [],
        note: null,
        cycleContext: TodayCycleContext.fromRecords(
          records: [period],
          today: base.today,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Period day 2'), findsOneWidget);

    stale.complete(base);
    await tester.pumpAndSettle();
    expect(find.text('Period day 2'), findsOneWidget);
    expect(find.text('A quiet beginning'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion leaves the loading placeholder still', (
    tester,
  ) async {
    final pending = Completer<TodayVisualSnapshot>();
    final port = _LoadOnlyPort(() => pending.future);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: TodayExperienceVisual(port: port),
        ),
      ),
    );
    await tester.pump();

    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Today chips keep a 48-point touch target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: _emptyPort())),
    );
    await tester.pumpAndSettle();

    final goodChip = find
        .ancestor(of: find.text('Good'), matching: find.byType(GestureDetector))
        .first;
    final size = tester.getSize(goodChip);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets(
    'Today keeps the first mood choice calm and moves extras to More',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: TodayExperienceVisual(port: _emptyPort())),
      );
      await tester.pumpAndSettle();

      final more = find.text('More');
      await tester.scrollUntilVisible(
        more,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Anxious'), findsOneWidget);
      expect(find.text('Energized'), findsNothing);
      expect(find.text('Tender'), findsNothing);

      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.text('Energized'), findsOneWidget);
      expect(find.text('Tender'), findsOneWidget);
      expect(find.text('Overwhelmed'), findsOneWidget);
      expect(find.text('Exhausted'), findsOneWidget);
    },
  );

  testWidgets(
    'a successful Today save announces and gives restrained haptic feedback',
    (tester) async {
      final platformCalls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        platformCalls.add(call);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(
        MaterialApp(home: TodayExperienceVisual(port: _emptyPort())),
      );
      await tester.pumpAndSettle();
      tester.takeAnnouncements();
      final good = find.text('Good');
      await tester.scrollUntilVisible(
        good,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(good);
      await tester.pumpAndSettle();

      expect(
        tester.takeAnnouncements(),
        contains(isAccessibilityAnnouncement('Mood noted — Good')),
      );
      expect(
        platformCalls,
        contains(
          isA<MethodCall>()
              .having((call) => call.method, 'method', 'HapticFeedback.vibrate')
              .having(
                (call) => call.arguments,
                'arguments',
                'HapticFeedbackType.selectionClick',
              ),
        ),
      );
    },
  );

  testWidgets('a difficult mood offers and opens the production Care route', (
    tester,
  ) async {
    const today = LocalDate(2026, 8, 15);
    final now = DateTime(2026, 8, 15, 12);
    var careOpened = false;
    final port = RepositoryTodayVisualPort(
      periodRepository: InMemoryPeriodRepository(clock: () => now),
      checkInRepository: InMemoryMomentCheckInRepository(clock: () => now),
      healthRecordRepository: InMemoryHealthRecordRepository(clock: () => now),
      captureNoteStore: InMemoryCaptureNoteStore(),
      today: () => today,
      now: () => now,
      onCycleDataChanged: () {},
      onOpenCare: () => careOpened = true,
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: port)),
    );
    await tester.pumpAndSettle();

    final irritable = find.text('Irritable');
    await tester.scrollUntilVisible(
      irritable,
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(irritable);
    await tester.pumpAndSettle();

    expect(find.text('This one sounds heavy.'), findsOneWidget);
    final openCare = find.text('Open Care');
    await tester.ensureVisible(openCare);
    await tester.tap(openCare);
    await tester.pumpAndSettle();
    expect(careOpened, isTrue);
  });

  testWidgets(
    'Care doorway stays hidden until a difficult mood save succeeds',
    (tester) async {
      const today = LocalDate(2026, 8, 15);
      final now = DateTime(2026, 8, 15, 12);
      final base = RepositoryTodayVisualPort(
        periodRepository: InMemoryPeriodRepository(clock: () => now),
        checkInRepository: InMemoryMomentCheckInRepository(clock: () => now),
        healthRecordRepository: InMemoryHealthRecordRepository(
          clock: () => now,
        ),
        captureNoteStore: InMemoryCaptureNoteStore(),
        today: () => today,
        now: () => now,
        onCycleDataChanged: () {},
        onOpenCare: () {},
      );
      final pending = Completer<TodayVisualSnapshot>();
      final port = _DeferredMoodPort(base, (_) => pending.future);

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: TodayExperienceVisual(port: port)),
      );
      await tester.pumpAndSettle();

      final irritable = find.text('Irritable');
      await tester.scrollUntilVisible(
        irritable,
        320,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(irritable);
      await tester.pump();

      expect(find.text('Open Care'), findsNothing);

      pending.complete(await base.saveMood(MomentCheckInState.irritable));
      await tester.pumpAndSettle();
      expect(find.text('Open Care'), findsOneWidget);
    },
  );

  testWidgets('failed difficult mood save never exposes the Care doorway', (
    tester,
  ) async {
    const today = LocalDate(2026, 8, 15);
    final now = DateTime(2026, 8, 15, 12);
    final base = RepositoryTodayVisualPort(
      periodRepository: InMemoryPeriodRepository(clock: () => now),
      checkInRepository: InMemoryMomentCheckInRepository(clock: () => now),
      healthRecordRepository: InMemoryHealthRecordRepository(clock: () => now),
      captureNoteStore: InMemoryCaptureNoteStore(),
      today: () => today,
      now: () => now,
      onCycleDataChanged: () {},
      onOpenCare: () {},
    );
    final pending = Completer<TodayVisualSnapshot>();
    final port = _DeferredMoodPort(base, (_) => pending.future);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: port)),
    );
    await tester.pumpAndSettle();

    final irritable = find.text('Irritable');
    await tester.scrollUntilVisible(
      irritable,
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(irritable);
    await tester.pump();
    pending.completeError(StateError('forced save failure'));
    await tester.pumpAndSettle();

    expect(find.text('Open Care'), findsNothing);
    expect(
      find.text("Letter Within couldn't save that. Try again."),
      findsOneWidget,
    );
  });

  testWidgets('Today shows factual remembered help when the gate supplies it', (
    tester,
  ) async {
    const today = LocalDate(2026, 8, 15);
    final now = DateTime(2026, 8, 15, 12);
    final port = RepositoryTodayVisualPort(
      periodRepository: InMemoryPeriodRepository(clock: () => now),
      checkInRepository: InMemoryMomentCheckInRepository(clock: () => now),
      healthRecordRepository: InMemoryHealthRecordRepository(clock: () => now),
      captureNoteStore: InMemoryCaptureNoteStore(),
      today: () => today,
      now: () => now,
      onCycleDataChanged: () {},
      onOpenCare: () {},
      loadRememberedHelpLine: () async =>
          'Apply warmth helped twice before — your check-backs say so.',
    );

    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: port)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Apply warmth helped twice before — your check-backs say so.'),
      findsOneWidget,
    );
  });

  testWidgets('Today stays silent without a reliability-gated Comfort Window', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: _emptyPort())),
    );
    await tester.pumpAndSettle();

    expect(find.text('A pattern is ready'), findsNothing);
    expect(find.text('A gentler plan for these days'), findsNothing);
  });

  testWidgets('Not now stores a decision and removes the reminder invitation', (
    tester,
  ) async {
    var comfort = const TodayComfortWindowState(
      forecastStart: LocalDate(2026, 8, 25),
      forecastEnd: LocalDate(2026, 8, 29),
      preparationVisible: false,
      kitFormed: false,
      reminderConfigured: false,
      reminderEnabled: false,
      reminderLeadDays: 2,
      sourceCycleCount: 3,
    );
    bool? savedEnabled;
    int? savedLeadDays;
    final port = _LoadOnlyPort(
      () => _snapshotWithComfort(comfort),
      onSaveComfortReminder:
          ({required bool enabled, required int leadDays}) async {
            savedEnabled = enabled;
            savedLeadDays = leadDays;
            comfort = TodayComfortWindowState(
              forecastStart: comfort.forecastStart,
              forecastEnd: comfort.forecastEnd,
              preparationVisible: comfort.preparationVisible,
              kitFormed: comfort.kitFormed,
              reminderConfigured: true,
              reminderEnabled: enabled,
              reminderLeadDays: leadDays,
              sourceCycleCount: comfort.sourceCycleCount,
            );
            return _snapshotWithComfort(comfort);
          },
    );

    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: port)),
    );
    await tester.pumpAndSettle();
    expect(find.text('A pattern is ready'), findsOneWidget);

    final notNow = find.descendant(
      of: find.byKey(const ValueKey<String>('comfort-reminder-invitation')),
      matching: find.text('Not now'),
    );
    await tester.scrollUntilVisible(
      notNow,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(notNow);
    await tester.pumpAndSettle();

    expect(savedEnabled, isFalse);
    expect(savedLeadDays, 2);
    expect(find.text('A pattern is ready'), findsNothing);
  });

  testWidgets(
    'preparation window offers the Kit and explicit reminder timing',
    (tester) async {
      var comfort = const TodayComfortWindowState(
        forecastStart: LocalDate(2026, 8, 16),
        forecastEnd: LocalDate(2026, 8, 20),
        preparationVisible: true,
        kitFormed: true,
        reminderConfigured: false,
        reminderEnabled: false,
        reminderLeadDays: 2,
        sourceCycleCount: 4,
      );
      bool? savedEnabled;
      int? savedLeadDays;
      final port = _LoadOnlyPort(
        () => _snapshotWithComfort(comfort),
        onSaveComfortReminder:
            ({required bool enabled, required int leadDays}) async {
              savedEnabled = enabled;
              savedLeadDays = leadDays;
              comfort = TodayComfortWindowState(
                forecastStart: comfort.forecastStart,
                forecastEnd: comfort.forecastEnd,
                preparationVisible: true,
                kitFormed: true,
                reminderConfigured: true,
                reminderEnabled: enabled,
                reminderLeadDays: leadDays,
                sourceCycleCount: comfort.sourceCycleCount,
              );
              return _snapshotWithComfort(comfort);
            },
      );

      await tester.pumpWidget(
        MaterialApp(home: TodayExperienceVisual(port: port)),
      );
      await tester.pumpAndSettle();
      expect(find.text('A gentler plan for these days'), findsOneWidget);
      expect(
        find.text('Estimated harder days · Aug 16–Aug 20'),
        findsOneWidget,
      );
      expect(find.text('Open Comfort Kit'), findsOneWidget);

      final reminder = find.text('Choose reminder');
      await tester.scrollUntilVisible(
        reminder,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(reminder);
      await tester.pumpAndSettle();
      expect(find.text('Choose a quiet reminder'), findsOneWidget);
      expect(find.textContaining('09:00 local time'), findsOneWidget);
      await tester.tap(find.text('1 day before'));
      await tester.tap(find.text('Set reminder'));
      await tester.pumpAndSettle();

      expect(savedEnabled, isTrue);
      expect(savedLeadDays, 1);
      expect(
        find.textContaining('Reminder preference · 1 day before'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Today writes the same facts Cycle reads', (tester) async {
    const today = LocalDate(2026, 8, 15);
    final now = DateTime(2026, 8, 15, 12);
    final periods = InMemoryPeriodRepository(
      seed: <PeriodRecord>[
        PeriodRecord(
          id: 'current',
          startDate: const LocalDate(2026, 8, 13),
          endDate: null,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      clock: () => now,
    );
    final moods = InMemoryMomentCheckInRepository(clock: () => now);
    final symptoms = InMemoryHealthRecordRepository(clock: () => now);
    final port = RepositoryTodayVisualPort(
      periodRepository: periods,
      checkInRepository: moods,
      healthRecordRepository: symptoms,
      captureNoteStore: InMemoryCaptureNoteStore(),
      today: () => today,
      now: () => now,
      onCycleDataChanged: () {},
      onOpenCare: () {},
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: port)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Good').first);
    await tester.pumpAndSettle();
    expect((await moods.getAll()).single.state, MomentCheckInState.good);

    final light = find.text('Light').first;
    await tester.scrollUntilVisible(
      light,
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(light);
    await tester.pumpAndSettle();
    final brightRed = find.text('Bright red').first;
    await tester.scrollUntilVisible(
      brightRed,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(brightRed);
    await tester.pumpAndSettle();
    final flow = (await periods.getAllFlowDays()).single;
    expect(flow.flow, BleedingFlow.light);
    expect(flow.color, BleedingColor.brightRed);

    final add = find.text('Add a symptom');
    await tester.scrollUntilVisible(
      add,
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cramps').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moderate').last);
    await tester.pumpAndSettle();

    final records = await symptoms.getAll();
    expect(records, hasLength(1));
    expect(records.single.symptom, SymptomType.cramps);
    expect(records.single.severity, SymptomSeverity.moderate);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty-history hero reflects a note immediately after save', (
    tester,
  ) async {
    const today = LocalDate(2026, 8, 15);
    final now = DateTime(2026, 8, 15, 12);
    final notes = InMemoryCaptureNoteStore();
    final port = RepositoryTodayVisualPort(
      periodRepository: InMemoryPeriodRepository(clock: () => now),
      checkInRepository: InMemoryMomentCheckInRepository(clock: () => now),
      healthRecordRepository: InMemoryHealthRecordRepository(clock: () => now),
      captureNoteStore: notes,
      today: () => today,
      now: () => now,
      onCycleDataChanged: () {},
      onOpenCare: () {},
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: port)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No notes yet'), findsOneWidget);
    final writeNote = find.text('Write a line for future you');
    await tester.scrollUntilVisible(
      writeNote,
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(writeNote);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'A quiet factual note.');
    await tester.tap(find.text('Keep note'));
    await tester.pumpAndSettle();

    expect(await notes.getAll(), hasLength(1));
    expect(find.textContaining('No notes yet'), findsNothing);
    expect(find.textContaining('Your note is here'), findsOneWidget);
  });

  testWidgets('Quick note UI edits stable rows, updates Kit, and deletes', (
    tester,
  ) async {
    const today = LocalDate(2026, 8, 15);
    final now = DateTime(2026, 8, 15, 12);
    final notes = InMemoryCaptureNoteStore();
    final port = RepositoryTodayVisualPort(
      periodRepository: InMemoryPeriodRepository(clock: () => now),
      checkInRepository: InMemoryMomentCheckInRepository(clock: () => now),
      healthRecordRepository: InMemoryHealthRecordRepository(clock: () => now),
      captureNoteStore: notes,
      today: () => today,
      now: () => now,
      onCycleDataChanged: () {},
      onOpenCare: () {},
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: port)),
    );
    await tester.pumpAndSettle();

    final add = find.byKey(const ValueKey<String>('quick-note-add'));
    await tester.scrollUntilVisible(
      add,
      320,
      scrollable: find.byType(Scrollable).first,
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

    var stored = await notes.getAll();
    expect(stored, hasLength(1));
    final stableId = stored.single.id;
    expect(stored.single.keepInComfortKit, isTrue);
    expect(find.text('In Comfort Kit'), findsOneWidget);

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

    stored = await notes.getAll();
    expect(stored, hasLength(1));
    expect(stored.single.id, stableId);
    expect(stored.single.text, 'Bring the warm blanket.');
    expect(stored.single.keepInComfortKit, isTrue);

    final delete = find.byKey(ValueKey<String>('quick-note-delete-$stableId'));
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await notes.getAll(), isEmpty);
    expect(find.text('Bring the warm blanket.'), findsNothing);
  });

  testWidgets('Today shows the estimate without a confidence grade', (
    tester,
  ) async {
    const today = LocalDate(2026, 9, 20);
    final now = DateTime(2026, 9, 20, 12);
    PeriodRecord period(String id, LocalDate start) => PeriodRecord(
      id: id,
      startDate: start,
      endDate: start.addDays(4),
      createdAt: now,
      updatedAt: now,
    );
    final port = RepositoryTodayVisualPort(
      periodRepository: InMemoryPeriodRepository(
        seed: [
          period('july', const LocalDate(2026, 7, 9)),
          period('august', const LocalDate(2026, 8, 2)),
          period('september', const LocalDate(2026, 9, 9)),
        ],
        clock: () => now,
      ),
      checkInRepository: InMemoryMomentCheckInRepository(clock: () => now),
      healthRecordRepository: InMemoryHealthRecordRepository(clock: () => now),
      captureNoteStore: InMemoryCaptureNoteStore(),
      today: () => today,
      now: () => now,
      onCycleDataChanged: () {},
      onOpenCare: () {},
    );

    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: port)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cycle day 12'), findsOneWidget);
    expect(find.textContaining('Estimated next period'), findsOneWidget);
    expect(find.textContaining('confidence'), findsNothing);
    expect(
      find.textContaining('Based on your recorded period starts'),
      findsNothing,
    );
  });

  testWidgets('ending a same-day period never offers an overlapping start', (
    tester,
  ) async {
    const today = LocalDate(2026, 8, 15);
    final now = DateTime(2026, 8, 15, 12);
    final periods = InMemoryPeriodRepository(
      seed: <PeriodRecord>[
        PeriodRecord(
          id: 'current',
          startDate: today,
          endDate: null,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      clock: () => now,
    );
    final port = RepositoryTodayVisualPort(
      periodRepository: periods,
      checkInRepository: InMemoryMomentCheckInRepository(clock: () => now),
      healthRecordRepository: InMemoryHealthRecordRepository(clock: () => now),
      captureNoteStore: InMemoryCaptureNoteStore(),
      today: () => today,
      now: () => now,
      onCycleDataChanged: () {},
      onOpenCare: () {},
    );

    await tester.pumpWidget(
      MaterialApp(home: TodayExperienceVisual(port: port)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Period day 1'), findsOneWidget);
    expect(find.text('Started Aug 15'), findsOneWidget);
    await tester.tap(find.text('End period'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End period').last);
    await tester.pumpAndSettle();

    expect(find.text('Period recorded today'), findsOneWidget);
    expect(find.text('Start period'), findsNothing);
    expect((await periods.getAll()).single.endDate, today);
  });
}
