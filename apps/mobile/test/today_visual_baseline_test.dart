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
  Future<void> openCare() => delegate.openCare();
}

final class _LoadOnlyPort implements TodayVisualPort {
  _LoadOnlyPort(this.onLoad);

  final Future<TodayVisualSnapshot> Function() onLoad;

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
      tester.renderObject<RenderParagraph>(title).getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 13),
      ),
      hasLength(1),
    );

    final hero = find.text('A quiet beginning');
    expect(hero, findsOneWidget);
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

  testWidgets('formal low-confidence estimate names its confidence', (
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

    expect(find.textContaining('Estimated next period'), findsOneWidget);
    expect(find.textContaining('low confidence'), findsOneWidget);
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
    await tester.tap(find.text('End period'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End period').last);
    await tester.pumpAndSettle();

    expect(find.text('Period recorded today'), findsOneWidget);
    expect(find.text('Start period'), findsNothing);
    expect((await periods.getAll()).single.endDate, today);
  });
}
