import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/notifications/application/cycle_check_in_scheduler.dart';
import 'package:letter_mobile/features/notifications/application/notifying_period_repository.dart';
import 'package:letter_mobile/features/notifications/domain/local_notification_port.dart';
import 'package:letter_mobile/features/privacy/domain/privacy_preferences.dart';
import 'package:letter_mobile/features/privacy/domain/privacy_preferences_repository.dart';
import 'package:letter_mobile/features/privacy/data/secure_privacy_preferences_repository.dart';

PeriodRecord period(String id, LocalDate start, {bool open = false}) {
  return PeriodRecord(
    id: id,
    startDate: start,
    endDate: open ? null : start.addDays(4),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

final class FakeNotificationPort implements LocalNotificationPort {
  NotificationAuthorization authorization = NotificationAuthorization.granted;
  NotificationAuthorization requestedAuthorization =
      NotificationAuthorization.granted;
  int requestCount = 0;
  int cancelCount = 0;
  DateTime? scheduledAt;
  String? title;
  String? body;
  String? payload;

  @override
  Future<NotificationAuthorization> authorizationStatus() async =>
      authorization;

  @override
  Future<void> cancelCycleCheckIn() async {
    cancelCount += 1;
    scheduledAt = null;
  }

  @override
  Future<void> initialize(NotificationTapHandler onTap) async {}

  @override
  Future<NotificationAuthorization> requestAuthorization() async {
    requestCount += 1;
    authorization = requestedAuthorization;
    return requestedAuthorization;
  }

  @override
  Future<void> scheduleCycleCheckIn({
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

void main() {
  group('CycleCheckInScheduler', () {
    test('preferences default to one enabled neutral check-in', () {
      const preferences = PrivacyPreferences();
      expect(preferences.appLockEnabled, isFalse);
      expect(preferences.cycleCheckInEnabled, isTrue);
      expect(
        CycleCheckInScheduler.neutralTitle.toLowerCase(),
        isNot(contains('period')),
      );
      expect(
        CycleCheckInScheduler.neutralBody.toLowerCase(),
        isNot(contains('late')),
      );
    });

    test('privacy preference codec preserves lock and permission state', () {
      const preferences = PrivacyPreferences(
        appLockEnabled: true,
        cycleCheckInEnabled: false,
        notificationPermissionRequested: true,
      );
      final encoded = PrivacyPreferencesCodec.encode(preferences);
      expect(PrivacyPreferencesCodec.decode(encoded), preferences);
    });

    test(
      'schedules at 10 local time after the estimated upper bound',
      () async {
        final repository = InMemoryPeriodRepository(
          seed: [
            period('one', const LocalDate(2026, 1, 1)),
            period('two', const LocalDate(2026, 1, 29)),
            period('three', const LocalDate(2026, 2, 26)),
          ],
        );
        final notifications = FakeNotificationPort();
        final scheduler = CycleCheckInScheduler(
          repository,
          InMemoryPrivacyPreferencesRepository(),
          notifications,
          now: () => DateTime(2026, 3, 1, 9),
        );

        await scheduler.reconcile();

        expect(notifications.scheduledAt, DateTime(2026, 3, 31, 10));
        expect(
          notifications.payload,
          CycleCheckInScheduler.notificationPayload,
        );
        expect(notifications.title, CycleCheckInScheduler.neutralTitle);
        expect(notifications.body, CycleCheckInScheduler.neutralBody);
      },
    );

    test('different cycle lengths produce a different reminder day', () async {
      final repository = InMemoryPeriodRepository(
        seed: [
          period('one', const LocalDate(2026, 1, 1)),
          period('two', const LocalDate(2026, 2, 1)),
          period('three', const LocalDate(2026, 3, 4)),
        ],
      );
      final notifications = FakeNotificationPort();
      final scheduler = CycleCheckInScheduler(
        repository,
        InMemoryPrivacyPreferencesRepository(),
        notifications,
        now: () => DateTime(2026, 3, 5),
      );

      await scheduler.reconcile();

      expect(notifications.scheduledAt, DateTime(2026, 4, 9, 10));
    });

    test('no prediction, an open period, or a past date cancels', () async {
      final notifications = FakeNotificationPort();
      final preferences = InMemoryPrivacyPreferencesRepository();

      await CycleCheckInScheduler(
        InMemoryPeriodRepository(
          seed: [period('one', const LocalDate(2026, 1, 1))],
        ),
        preferences,
        notifications,
      ).reconcile();
      expect(notifications.cancelCount, 1);

      await CycleCheckInScheduler(
        InMemoryPeriodRepository(
          seed: [
            period('one', const LocalDate(2026, 1, 1)),
            period('two', const LocalDate(2026, 1, 29)),
            period('open', const LocalDate(2026, 2, 26), open: true),
          ],
        ),
        preferences,
        notifications,
      ).reconcile();
      expect(notifications.cancelCount, 2);

      await CycleCheckInScheduler(
        InMemoryPeriodRepository(
          seed: [
            period('one', const LocalDate(2026, 1, 1)),
            period('two', const LocalDate(2026, 1, 29)),
            period('three', const LocalDate(2026, 2, 26)),
          ],
        ),
        preferences,
        notifications,
        now: () => DateTime(2026, 4, 1),
      ).reconcile();
      expect(notifications.cancelCount, 3);
    });

    test('denied permission is requested once and never schedules', () async {
      final repository = InMemoryPeriodRepository(
        seed: [
          period('one', const LocalDate(2026, 1, 1)),
          period('two', const LocalDate(2026, 1, 29)),
          period('three', const LocalDate(2026, 2, 26)),
        ],
      );
      final preferences = InMemoryPrivacyPreferencesRepository();
      final notifications = FakeNotificationPort()
        ..authorization = NotificationAuthorization.unknown
        ..requestedAuthorization = NotificationAuthorization.denied;
      final scheduler = CycleCheckInScheduler(
        repository,
        preferences,
        notifications,
        now: () => DateTime(2026, 3, 1),
      );

      await scheduler.reconcile(requestPermission: true);
      await scheduler.reconcile(requestPermission: true);

      expect(notifications.requestCount, 1);
      expect(notifications.scheduledAt, isNull);
      expect(
        (await preferences.load()).notificationPermissionRequested,
        isTrue,
      );
    });
  });

  test(
    'period mutations notify without making reminder failure fail a write',
    () async {
      var notifications = 0;
      final repository = NotifyingPeriodRepository(
        InMemoryPeriodRepository(idGenerator: () => 'one'),
        () async {
          notifications += 1;
          throw StateError('synthetic reminder failure');
        },
      );

      final created = await repository.create(
        const PeriodDraft(
          startDate: LocalDate(2026, 1, 1),
          endDate: LocalDate(2026, 1, 5),
        ),
        today: const LocalDate(2026, 2, 1),
      );
      await repository.update(
        created.id,
        const PeriodDraft(
          startDate: LocalDate(2026, 1, 2),
          endDate: LocalDate(2026, 1, 6),
        ),
        today: const LocalDate(2026, 2, 1),
      );
      await repository.delete(created.id);

      expect(notifications, 3);
      expect(await repository.getAll(), isEmpty);
    },
  );
}
