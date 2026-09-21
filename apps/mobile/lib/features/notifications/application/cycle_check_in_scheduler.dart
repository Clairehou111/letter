import '../../cycle/domain/cycle_prediction.dart';
import '../../cycle/domain/period_repository.dart';
import '../../privacy/domain/privacy_preferences_repository.dart';
import '../domain/local_notification_port.dart';

final class CycleCheckInScheduler {
  CycleCheckInScheduler(
    this._periodRepository,
    this._preferencesRepository,
    this._notificationPort, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const notificationPayload = 'letter:cycle-check-in';
  static const notificationHour = 10;
  static const neutralTitle = 'A note from Letter Within';
  static const neutralBody = 'Open Letter Within when you have a moment.';

  final PeriodRepository _periodRepository;
  final PrivacyPreferencesRepository _preferencesRepository;
  final LocalNotificationPort _notificationPort;
  final DateTime Function() _now;

  Future<void> reconcile({bool requestPermission = false}) async {
    final preferences = await _preferencesRepository.load();
    if (!preferences.cycleCheckInEnabled) {
      await _notificationPort.cancelCycleCheckIn();
      return;
    }

    final records = await _periodRepository.getAll();
    if (records.any((record) => record.isOpen)) {
      await _notificationPort.cancelCycleCheckIn();
      return;
    }

    final prediction = CyclePredictionEngine.calculate(records);
    if (prediction == null) {
      await _notificationPort.cancelCycleCheckIn();
      return;
    }

    final reminderDay = prediction.predictedMensesEnd.addDays(1);
    final scheduledAt = DateTime(
      reminderDay.year,
      reminderDay.month,
      reminderDay.day,
      notificationHour,
    );
    if (!scheduledAt.isAfter(_now())) {
      await _notificationPort.cancelCycleCheckIn();
      return;
    }

    var authorization = await _notificationPort.authorizationStatus();
    if (authorization == NotificationAuthorization.unknown &&
        requestPermission &&
        !preferences.notificationPermissionRequested) {
      authorization = await _notificationPort.requestAuthorization();
      await _preferencesRepository.save(
        preferences.copyWith(notificationPermissionRequested: true),
      );
    }
    if (authorization != NotificationAuthorization.granted) {
      await _notificationPort.cancelCycleCheckIn();
      return;
    }

    await _notificationPort.scheduleCycleCheckIn(
      scheduledAt: scheduledAt,
      title: neutralTitle,
      body: neutralBody,
      payload: notificationPayload,
    );
  }
}
