import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/app/letter_app.dart';
import 'package:letter_mobile/experience/care/care_experience.dart';
import 'package:letter_mobile/experience/letter_experience_shell.dart';
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
