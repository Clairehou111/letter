import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/check_in/domain/moment_check_in.dart';
import 'package:letter_mobile/features/comfort_window/data/comfort_reminder_preference_repositories.dart';
import 'package:letter_mobile/features/comfort_window/domain/comfort_reminder_preference.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/notifications/application/comfort_window_scheduler.dart';
import 'package:letter_mobile/features/notifications/domain/local_notification_port.dart';
import 'package:letter_mobile/features/patterns/domain/pattern_source.dart';

void main() {
  test(
    'schedules one generic reminder only for opted-in clearer evidence',
    () async {
      final fixture = _fixture();
      final preferences = InMemoryComfortReminderPreferenceRepository();
      await preferences.save(
        ComfortReminderPreference(
          enabled: true,
          leadDays: 2,
          updatedAt: fixture.now,
        ),
      );
      final notifications = _FakeComfortNotificationPort();
      final scheduler = ComfortWindowScheduler(
        InMemoryPeriodRepository(seed: fixture.periods),
        _PatternSource(fixture.source),
        preferences,
        notifications,
        now: () => fixture.now,
      );

      await scheduler.reconcile();

      expect(notifications.scheduledAt, DateTime(2026, 5, 22, 9));
      expect(notifications.title, ComfortWindowScheduler.neutralTitle);
      expect(notifications.body, ComfortWindowScheduler.neutralBody);
      expect(notifications.payload, ComfortWindowScheduler.notificationPayload);
      expect(notifications.cancelCount, 0);
    },
  );

  test('defaults off and cancels without reading sensitive details', () async {
    final fixture = _fixture();
    final notifications = _FakeComfortNotificationPort();
    final scheduler = ComfortWindowScheduler(
      InMemoryPeriodRepository(seed: fixture.periods),
      _PatternSource(fixture.source),
      InMemoryComfortReminderPreferenceRepository(),
      notifications,
      now: () => fixture.now,
    );

    await scheduler.reconcile();

    expect(notifications.scheduledAt, isNull);
    expect(notifications.cancelCount, 1);
  });

  test(
    'does not schedule when notification permission is unavailable',
    () async {
      final fixture = _fixture();
      final preferences = InMemoryComfortReminderPreferenceRepository();
      await preferences.save(
        ComfortReminderPreference(enabled: true, updatedAt: fixture.now),
      );
      final notifications = _FakeComfortNotificationPort(
        authorization: NotificationAuthorization.unknown,
      );
      final scheduler = ComfortWindowScheduler(
        InMemoryPeriodRepository(seed: fixture.periods),
        _PatternSource(fixture.source),
        preferences,
        notifications,
        now: () => fixture.now,
      );

      await scheduler.reconcile();

      expect(notifications.scheduledAt, isNull);
      expect(notifications.cancelCount, 1);
    },
  );

  test(
    'record changes cancel a pending reminder when evidence disappears',
    () async {
      final fixture = _fixture();
      final preferences = InMemoryComfortReminderPreferenceRepository();
      await preferences.save(
        ComfortReminderPreference(enabled: true, updatedAt: fixture.now),
      );
      final source = _PatternSource(fixture.source);
      final notifications = _FakeComfortNotificationPort();
      final scheduler = ComfortWindowScheduler(
        InMemoryPeriodRepository(seed: fixture.periods),
        source,
        preferences,
        notifications,
        now: () => fixture.now,
      );

      await scheduler.reconcile();
      expect(notifications.scheduledAt, isNotNull);

      source.snapshot = PatternSourceSnapshot(
        periods: fixture.periods,
        momentCheckIns: fixture.source.momentCheckIns
            .where((checkIn) => checkIn.state != MomentCheckInState.irritable)
            .toList(growable: false),
      );
      await scheduler.reconcile();

      expect(notifications.cancelCount, 1);
      expect(notifications.scheduledAt, isNull);
    },
  );
}

final class _PatternSource implements PatternSourceReader {
  _PatternSource(this.snapshot);
  PatternSourceSnapshot snapshot;

  @override
  Future<PatternSourceSnapshot> read() async => snapshot;
}

final class _FakeComfortNotificationPort implements ComfortNotificationPort {
  _FakeComfortNotificationPort({
    this.authorization = NotificationAuthorization.granted,
  });

  NotificationAuthorization authorization;
  DateTime? scheduledAt;
  String? title;
  String? body;
  String? payload;
  int cancelCount = 0;

  @override
  Future<NotificationAuthorization> authorizationStatus() async =>
      authorization;

  @override
  Future<void> cancelComfortReminder() async {
    cancelCount++;
    scheduledAt = null;
  }

  @override
  Future<NotificationAuthorization> requestAuthorization() async =>
      authorization;

  @override
  Future<void> scheduleComfortReminder({
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  }) async {
    this.scheduledAt = scheduledAt;
    this.title = title;
    this.body = body;
    this.payload = payload;
  }
}

final class _SchedulerFixture {
  const _SchedulerFixture({
    required this.periods,
    required this.source,
    required this.now,
  });

  final List<PeriodRecord> periods;
  final PatternSourceSnapshot source;
  final DateTime now;
}

_SchedulerFixture _fixture() {
  const first = LocalDate(2026, 1, 1);
  final periods = <PeriodRecord>[
    for (var index = 0; index <= 4; index++)
      PeriodRecord(
        id: 'period-$index',
        startDate: first.addDays(index * 30),
        endDate: first.addDays(index * 30 + 4),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
  ];
  final checkIns = <MomentCheckIn>[];
  var id = 0;
  for (var index = 0; index < 4; index++) {
    final anchor = periods[index + 1].startDate;
    for (final offset in const [-5, -4, -3]) {
      checkIns.add(
        _checkIn(
          'hard-${id++}',
          anchor.addDays(offset),
          MomentCheckInState.irritable,
        ),
      );
    }
    for (final offset in const [-14, -12, -10, -8, -1, 1]) {
      checkIns.add(
        _checkIn(
          'steady-${id++}',
          anchor.addDays(offset),
          MomentCheckInState.steady,
        ),
      );
    }
  }
  return _SchedulerFixture(
    periods: periods,
    source: PatternSourceSnapshot(periods: periods, momentCheckIns: checkIns),
    now: DateTime(2026, 5, 21, 8),
  );
}

MomentCheckIn _checkIn(String id, LocalDate date, MomentCheckInState state) =>
    MomentCheckIn(
      id: id,
      state: state,
      occurredAt: DateTime(date.year, date.month, date.day, 12),
      createdAt: DateTime(date.year, date.month, date.day, 12),
    );
