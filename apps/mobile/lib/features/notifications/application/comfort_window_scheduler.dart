import '../../comfort_window/domain/comfort_reminder_preference.dart';
import '../../comfort_window/domain/comfort_window_engine.dart';
import '../../cycle/domain/cycle_prediction.dart';
import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_repository.dart';
import '../../patterns/domain/pattern_source.dart';
import '../domain/local_notification_port.dart';

final class ComfortWindowScheduler {
  ComfortWindowScheduler(
    this._periodRepository,
    this._patternSource,
    this._preferenceRepository,
    this._notificationPort, {
    ComfortWindowEngine engine = const ComfortWindowEngine(),
    DateTime Function()? now,
    // ignore: prefer_initializing_formals
  }) : _engine = engine,
       _now = now ?? DateTime.now;

  static const notificationPayload = 'letter:comfort-window';
  static const neutralTitle = 'A note from Letter Within';
  static const neutralBody = 'Open Letter Within when you have a moment.';

  final PeriodRepository _periodRepository;
  final PatternSourceReader _patternSource;
  final ComfortReminderPreferenceRepository _preferenceRepository;
  final ComfortNotificationPort _notificationPort;
  final ComfortWindowEngine _engine;
  final DateTime Function() _now;

  Future<void> reconcile({bool requestPermission = false}) async {
    final preference = await _preferenceRepository.load();
    if (!preference.enabled) {
      await _notificationPort.cancelComfortReminder();
      return;
    }
    final now = _now().toLocal();
    final today = LocalDate.fromDateTime(now);
    final periods = CyclePredictionEngine.recordsThrough(
      await _periodRepository.getAll(),
      today,
    );
    final prediction = CyclePredictionEngine.calculate(periods);
    final source = await _patternSource.read();
    final comfort = _engine.calculate(
      source: source,
      periodPrediction: prediction,
      today: today,
    );
    if (comfort == null || !comfort.canOfferReminder) {
      await _notificationPort.cancelComfortReminder();
      return;
    }

    final day = comfort.forecastStart.addDays(-preference.leadDays);
    final scheduledAt = DateTime(
      day.year,
      day.month,
      day.day,
      preference.hour,
      preference.minute,
    );
    if (!scheduledAt.isAfter(now)) {
      await _notificationPort.cancelComfortReminder();
      return;
    }

    var authorization = await _notificationPort.authorizationStatus();
    if (authorization == NotificationAuthorization.unknown &&
        requestPermission) {
      authorization = await _notificationPort.requestAuthorization();
    }
    if (authorization != NotificationAuthorization.granted) {
      await _notificationPort.cancelComfortReminder();
      return;
    }
    await _notificationPort.scheduleComfortReminder(
      scheduledAt: scheduledAt,
      title: neutralTitle,
      body: neutralBody,
      payload: notificationPayload,
    );
  }
}
