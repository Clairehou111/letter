import '../../comfort_window/domain/comfort_reminder_preference.dart';
import '../../comfort_window/domain/comfort_window.dart';
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
    this.loadWindow,
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

  final Future<ComfortWindowPrediction?> Function()? loadWindow;
  Future<void> _pending = Future<void>.value();
  int _revision = 0;
  String status = 'Off — reminders are optional.';

  Future<void> reconcile({bool requestPermission = false}) {
    final revision = ++_revision;
    final next = _pending.then((_) async {
      if (revision != _revision) return;
      try {
        await _reconcile(revision, requestPermission: requestPermission);
      } on Object {
        if (revision != _revision) return;
        status = 'Unavailable — your records remain on this device.';
        await _notificationPort.cancelComfortReminder();
      }
    });
    _pending = next.catchError((Object _) {});
    return next;
  }

  Future<void> _reconcile(
    int revision, {
    required bool requestPermission,
  }) async {
    final preference = await _preferenceRepository.load();
    if (revision != _revision) return;
    if (!preference.enabled) {
      status = 'Off — reminders are optional.';
      await _notificationPort.cancelComfortReminder();
      return;
    }
    // Ask when the person opts in, even if the forecast is not ready yet.
    // Later data changes reconcile without prompting and can then schedule.
    NotificationAuthorization? authorization;
    if (requestPermission) {
      authorization = await _notificationPort.authorizationStatus();
      if (authorization == NotificationAuthorization.unknown) {
        authorization = await _notificationPort.requestAuthorization();
      }
    }
    final now = _now().toLocal();
    final today = LocalDate.fromDateTime(now);
    ComfortWindowPrediction? comfort;
    if (loadWindow != null) {
      if (revision != _revision) return;
      final currentPreference = await _preferenceRepository.load();
      if (revision != _revision) return;
      if (!currentPreference.enabled) {
        status = 'Off — reminders are optional.';
        await _notificationPort.cancelComfortReminder();
        return;
      }
      comfort = await loadWindow!();
    } else {
      final periods = CyclePredictionEngine.recordsThrough(
        await _periodRepository.getAll(),
        today,
      );
      final prediction = CyclePredictionEngine.calculate(periods);
      final source = await _patternSource.read();
      comfort = _engine.calculate(
        source: source,
        periodPrediction: prediction,
        today: today,
      );
    }
    if (revision != _revision) return;
    if (comfort == null || !comfort.canOfferReminder) {
      status = 'Waiting for reliable evidence.';
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

    authorization ??= await _notificationPort.authorizationStatus();
    if (revision != _revision) return;
    if (authorization != NotificationAuthorization.granted) {
      status = 'Off — notification permission is unavailable.';
      await _notificationPort.cancelComfortReminder();
      return;
    }
    final currentPreference = await _preferenceRepository.load();
    if (revision != _revision) return;
    if (!currentPreference.enabled ||
        currentPreference.leadDays != preference.leadDays ||
        currentPreference.hour != preference.hour ||
        currentPreference.minute != preference.minute) {
      status = 'Off — preferences changed.';
      await _notificationPort.cancelComfortReminder();
      return;
    }
    status = 'On — a neutral reminder is scheduled.';
    await _notificationPort.scheduleComfortReminder(
      scheduledAt: scheduledAt,
      title: neutralTitle,
      body: neutralBody,
      payload: notificationPayload,
    );
  }
}
