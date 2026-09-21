import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/local_notification_port.dart';

final class FlutterLocalNotificationPort implements LocalNotificationPort {
  FlutterLocalNotificationPort({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _notificationId = 51001;
  static const _channelId = 'letter_cycle_check_in';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  @override
  Future<void> initialize(NotificationTapHandler onTap) async {
    try {
      tz_data.initializeTimeZones();
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null) onTap(payload);
        },
      );
      _ready = true;

      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      final launchPayload = launchDetails?.notificationResponse?.payload;
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchPayload != null) {
        onTap(launchPayload);
      }
    } on Object {
      _ready = false;
    }
  }

  @override
  Future<NotificationAuthorization> authorizationStatus() async {
    if (!_ready) return NotificationAuthorization.unsupported;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final enabled = await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled();
        return enabled == true
            ? NotificationAuthorization.granted
            : NotificationAuthorization.unknown;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final options = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.checkPermissions();
        return options?.isEnabled == true
            ? NotificationAuthorization.granted
            : NotificationAuthorization.unknown;
      }
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final options = await _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.checkPermissions();
        return options?.isEnabled == true
            ? NotificationAuthorization.granted
            : NotificationAuthorization.unknown;
      }
    } on Object {
      return NotificationAuthorization.unsupported;
    }
    return NotificationAuthorization.unsupported;
  }

  @override
  Future<NotificationAuthorization> requestAuthorization() async {
    if (!_ready) return NotificationAuthorization.unsupported;
    try {
      bool? granted;
      if (defaultTargetPlatform == TargetPlatform.android) {
        granted = await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        granted = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true);
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        granted = await _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true);
      } else {
        return NotificationAuthorization.unsupported;
      }
      return granted == true
          ? NotificationAuthorization.granted
          : NotificationAuthorization.denied;
    } on Object {
      return NotificationAuthorization.denied;
    }
  }

  @override
  Future<void> scheduleCycleCheckIn({
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_ready) return;
    await _plugin.zonedSchedule(
      id: _notificationId,
      title: title,
      body: body,
      payload: payload,
      scheduledDate: tz.TZDateTime(
        tz.local,
        scheduledAt.year,
        scheduledAt.month,
        scheduledAt.day,
        scheduledAt.hour,
        scheduledAt.minute,
      ),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Cycle check-in',
          channelDescription: 'A private reminder to update Cycle.',
          playSound: false,
          enableVibration: false,
          channelShowBadge: false,
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelCycleCheckIn() async {
    if (!_ready) return;
    await _plugin.cancel(id: _notificationId);
  }
}
