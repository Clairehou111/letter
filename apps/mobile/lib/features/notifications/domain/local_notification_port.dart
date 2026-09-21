enum NotificationAuthorization { unknown, denied, granted, unsupported }

typedef NotificationTapHandler = void Function(String payload);

abstract interface class LocalNotificationPort {
  Future<void> initialize(NotificationTapHandler onTap);

  Future<NotificationAuthorization> authorizationStatus();

  Future<NotificationAuthorization> requestAuthorization();

  Future<void> scheduleCycleCheckIn({
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  });

  Future<void> cancelCycleCheckIn();
}

final class DisabledLocalNotificationPort implements LocalNotificationPort {
  const DisabledLocalNotificationPort();

  @override
  Future<NotificationAuthorization> authorizationStatus() async =>
      NotificationAuthorization.unsupported;

  @override
  Future<void> cancelCycleCheckIn() async {}

  @override
  Future<void> initialize(NotificationTapHandler onTap) async {}

  @override
  Future<NotificationAuthorization> requestAuthorization() async =>
      NotificationAuthorization.unsupported;

  @override
  Future<void> scheduleCycleCheckIn({
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  }) async {}
}
