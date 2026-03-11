import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class OverdueNotificationService {
  static const int baseId = 2100;
  static const int maxAlerts = 12; // eg every 5 mins for 1 hour

  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  /// Schedule overdue alerts starting at ETA
  static Future<void> scheduleOverdueNotifications(DateTime eta) async {
    // Always clear old ones first
    await cancelOverdueNotifications();

    for (int i = 0; i < maxAlerts; i++) {
      final id = baseId + i + 1;

      final scheduledTime = tz.TZDateTime.from(
        eta.add(Duration(minutes: i * 5)),
        tz.local,
      );

      await _plugin.zonedSchedule(
        id,
        'Marine Safe',
        i == 0
            ? 'You are now OVERDUE. Please check in.'
            : 'Still overdue. Please confirm you are safe.',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'overdue_channel',
            'Overdue Alerts',
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
            fullScreenIntent: true,
          ),
          iOS: DarwinNotificationDetails(
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Cancel all overdue alerts
  static Future<void> cancelOverdueNotifications() async {
    for (int i = 0; i < maxAlerts; i++) {
      await _plugin.cancel(baseId + i + 1);
    }
  }
}
