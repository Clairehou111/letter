import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/app/letter_app.dart';
import 'package:letter_mobile/experience/care/care_experience.dart';
import 'package:letter_mobile/experience/letter_experience_shell.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/comfort_kit/application/comfort_experience_controller.dart';
import 'package:letter_mobile/features/comfort_kit/data/in_memory_comfort_kit_repository.dart';
import 'package:letter_mobile/features/comfort_window/data/comfort_reminder_preference_repositories.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/notifications/domain/local_notification_port.dart';
import 'package:letter_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:letter_mobile/features/onboarding/domain/onboarding_profile.dart';

import 'support/widget_test_pump.dart';

void main() {
  testWidgets('real Care destination loads the wired Comfort Kit controller', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final notes = _CountingCaptureNoteStore();
    await notes.save(
      CaptureNote(
        id: 'kept-note',
        text: 'Cancel one thing and make tea.',
        source: CaptureSource.typed,
        createdAt: DateTime.utc(2026, 9, 20),
        keepInComfortKit: true,
      ),
    );

    await tester.pumpWidget(
      LetterApp(
        onboardingRepository: _ReadyOnboardingRepository(),
        captureNoteStore: notes,
        now: () => DateTime(2026, 9, 26, 12),
      ),
    );
    await pumpUntilFound(tester, find.byType(CareExperience));

    final care = tester.widget<CareExperience>(find.byType(CareExperience));
    expect(care.comfortExperienceController, isNotNull);
    expect(notes.getAllCalls, greaterThanOrEqualTo(1));
    final snapshot = await care.comfortExperienceController!.load();
    expect(snapshot.kit.isFormed, isTrue);

    await tester.tap(find.text('Care'));
    await pumpUntilFound(tester, find.text('Your comfort kit'));
    expect(
      tester.getTopLeft(find.text('Your comfort kit')).dy,
      lessThan(tester.getTopLeft(find.text('I want to explode')).dy),
      reason:
          'A formed Comfort Kit is the first Care action beneath the header.',
    );

    await tester.tap(find.text('Your comfort kit'));
    await pumpUntilFound(tester, find.text('Back to care'));
    final primaryScrollController = PrimaryScrollController.of(
      tester.element(find.text('Back to care')),
    );
    expect(primaryScrollController.positions, hasLength(1));
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'resuming reconciles the Comfort Window after local calendar changes',
    (tester) async {
      final notifications = _CountingComfortNotificationPort();
      await tester.pumpWidget(
        LetterApp(
          onboardingRepository: _ReadyOnboardingRepository(),
          periodRepository: InMemoryPeriodRepository(),
          comfortNotificationPort: notifications,
          now: () => DateTime(2026, 9, 26, 12),
        ),
      );
      await pumpUntilFound(tester, find.byType(LetterExperienceShell));
      expect(find.byType(LetterExperienceShell), findsOneWidget);

      notifications.cancelCount = 0;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(notifications.cancelCount, greaterThanOrEqualTo(1));
    },
  );

  testWidgets(
    'opened kit leads with the top-ranked Care action and can use it now',
    (tester) async {
      final first = _careRecord(
        id: 'first-heavy',
        occurredAt: DateTime.utc(2026, 9, 20, 12),
      );
      final second = _careRecord(
        id: 'second-heavy',
        occurredAt: DateTime.utc(2026, 9, 22, 12),
      );
      await _pumpOpenedKit(tester, records: <CareRecord>[first, second]);

      expect(find.text('For right now'), findsNothing);
      expect(find.text('Rest into support'), findsOneWidget);
      expect(find.text('Try this now'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);

      await tester.tap(find.text('Try this now'));
      await tester.pumpAndSettle();

      expect(find.text('I feel heavy'), findsOneWidget);
      expect(find.text('Make this moment smaller'), findsOneWidget);
    },
  );

  testWidgets(
    'opened kit gives remedy, future letter, and quick note distinct objects',
    (tester) async {
      final reflection = CycleReflection(
        id: 'cycle-reflection',
        cycleStartDay: const LocalDate(2026, 9, 1).epochDay,
        observation: null,
        need: null,
        whatHelped: 'Warmth and fewer plans.',
        futureSelfNote: 'Leave tomorrow a little lighter.',
        createdAt: DateTime.utc(2026, 9, 24),
        updatedAt: DateTime.utc(2026, 9, 24),
      );
      final quickNotes = InMemoryCaptureNoteStore();
      await quickNotes.save(
        CaptureNote(
          id: 'kept-note',
          text: 'Tea is already by the bed.',
          source: CaptureSource.typed,
          createdAt: DateTime.utc(2026, 9, 23),
          keepInComfortKit: true,
        ),
      );

      await _pumpOpenedKit(
        tester,
        cycleReflections: <CycleReflection>[reflection],
        quickNotes: quickNotes,
        textScale: 2,
      );

      expect(find.text('For right now'), findsNothing);
      await _scrollUntilVisible(tester, find.text('Warmth and fewer plans.'));
      expect(find.text('Warmth and fewer plans.'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsAtLeastNWidgets(1));
      await _scrollUntilVisible(
        tester,
        find.text('Leave tomorrow a little lighter.'),
      );
      expect(find.text('Leave tomorrow a little lighter.'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsAtLeastNWidgets(1));
      await _scrollUntilVisible(
        tester,
        find.text('Tea is already by the bed.'),
      );
      expect(find.text('Tea is already by the bed.'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsAtLeastNWidgets(1));
      expect(find.text('Try this now'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

CareRecord _careRecord({required String id, required DateTime occurredAt}) {
  return CareRecord(
    id: id,
    mode: CareMode.heavy,
    actionId: 'care.heavy.guided_scene',
    actionLabel: 'Rest into support',
    outcome: CareOutcome.better,
    occurredAt: occurredAt,
    createdAt: occurredAt,
    updatedAt: occurredAt,
    pinned: false,
  );
}

Future<void> _pumpOpenedKit(
  WidgetTester tester, {
  List<CareRecord> records = const <CareRecord>[],
  List<CycleReflection> cycleReflections = const <CycleReflection>[],
  CaptureNoteStore? quickNotes,
  double textScale = 1,
}) async {
  const size = Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final careMemory = InMemoryCareMemoryRepository(
    records: records,
    cycleReflections: cycleReflections,
  );
  final notes = quickNotes ?? InMemoryCaptureNoteStore();
  final controller = ComfortExperienceController(
    patternSource: _StaticPatternSource(
      PatternSourceSnapshot(careRecords: records),
    ),
    careMemory: careMemory,
    quickNotes: notes,
    kitRepository: InMemoryComfortKitRepository(),
    reminderRepository: InMemoryComfortReminderPreferenceRepository(),
    now: () => DateTime(2026, 9, 26, 12),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: size).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: CareExperience(
          careMemoryRepository: careMemory,
          comfortExperienceController: controller,
          performanceConstrained: true,
        ),
      ),
    ),
  );
  await pumpUntilFound(tester, find.text('Your comfort kit'));
  await tester.tap(find.text('Your comfort kit'));
  await pumpUntilFound(tester, find.text('Back to care'));
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20 && finder.evaluate().isEmpty; attempt++) {
    await tester.drag(
      find.byType(ListView).first,
      const Offset(0, -240),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

final class _StaticPatternSource implements PatternSourceReader {
  const _StaticPatternSource(this.snapshot);

  final PatternSourceSnapshot snapshot;

  @override
  Future<PatternSourceSnapshot> read() async => snapshot;
}

final class _CountingComfortNotificationPort
    implements ComfortNotificationPort {
  int cancelCount = 0;

  @override
  Future<NotificationAuthorization> authorizationStatus() async =>
      NotificationAuthorization.granted;

  @override
  Future<void> cancelComfortReminder() async {
    cancelCount += 1;
  }

  @override
  Future<NotificationAuthorization> requestAuthorization() async =>
      NotificationAuthorization.granted;

  @override
  Future<void> scheduleComfortReminder({
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  }) async {}
}

final class _CountingCaptureNoteStore implements CaptureNoteStore {
  final List<CaptureNote> _notes = <CaptureNote>[];
  int getAllCalls = 0;

  @override
  Future<void> delete(CaptureNote note) async {
    _notes.removeWhere((item) => item.id == note.id);
  }

  @override
  Future<List<CaptureNote>> getAll() async {
    getAllCalls += 1;
    return List<CaptureNote>.unmodifiable(_notes);
  }

  @override
  Future<CaptureNote> save(CaptureNote note) async {
    _notes.removeWhere((item) => item.id == note.id);
    _notes.add(note);
    return note;
  }

  @override
  Future<CaptureNote> update(CaptureNote note) => save(note);
}

final class _ReadyOnboardingRepository implements OnboardingRepository {
  OnboardingProfile? _profile = OnboardingProfile();

  @override
  Future<void> clear() async => _profile = null;

  @override
  Future<OnboardingProfile?> load() async => _profile;

  @override
  Future<void> save(OnboardingProfile profile) async => _profile = profile;
}
