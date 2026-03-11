import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class ExpiryNotificationService {
  ExpiryNotificationService._();
  static final ExpiryNotificationService instance = ExpiryNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const String _channelId = 'marine_safe_alerts';
  static const String _channelName = 'Marine Safe Alerts';
  static const String _channelDesc = 'Trip and safety alerts';

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // ✅ Android 13+ runtime permission prompt
    await android?.requestNotificationsPermission();

    // ✅ Create channel (Android 8+)
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
    );
    await android?.createNotificationChannel(channel);
  }

  // ✅ quick “does it show at all?” test
  Future<void> showTestNow() async {
    await _plugin.show(
      999,
      'Marine Safe Test',
      'If you see this, notifications are working.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Cancel a single notification by id (e.g. so we don't cancel trip notifications).
  Future<void> cancel(int id) async => _plugin.cancel(id);

  /// Cancel multiple notification ids (e.g. 6000-6099 for expiry alerts).
  Future<void> cancelIds(Iterable<int> ids) async {
    for (final id in ids) {
      await _plugin.cancel(id);
    }
  }

  // ✅ schedule an alert at a specific time
  Future<void> schedule(
      int id,
      String title,
      String body,
      DateTime when,
      ) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );
  }
}
