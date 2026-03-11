import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Legacy NotificationService.
/// IMPORTANT:
/// - Uses its OWN ID range so it can’t cancel Home trip alarms.
/// - Never uses plugin.cancelAll().
class NotificationsService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // 🔒 Different IDs vs HomeNotificationsService
  static const int notifApproachingId = 6201;
  static const int notifOverdueId = 6202;
  static const int overdueRepeatBase = 6300; // 6301..6312

  Future<void> init() async {
    if (kIsWeb) return;
    if (_ready) return;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Australia/Brisbane'));
    } catch (_) {}

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);
    await _plugin.initialize(settings);

    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      try {
        await android?.requestExactAlarmsPermission();
      } catch (_) {}
    } catch (_) {}

    _ready = true;
  }

  NotificationDetails _details({required bool overdue}) {
    final channelId = overdue ? 'marine_safe_overdue_legacy2_v1' : 'marine_safe_eta_legacy2_v1';
    final channelName = overdue ? 'Marine Safe Overdue (Legacy2)' : 'Marine Safe ETA (Legacy2)';
    final channelDesc = overdue ? 'Overdue return alerts (legacy2)' : 'Trip ETA alerts (legacy2)';

    final vibPattern = overdue
        ? Int64List.fromList([0, 800, 250, 800, 250, 1200])
        : Int64List.fromList([0, 250, 150, 250]);

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        vibrationPattern: vibPattern,
        playSound: true,
      ),
    );
  }

  Future<void> cancelTripNotifications() async {
    if (kIsWeb) return;
    await _plugin.cancel(notifApproachingId);
    await _plugin.cancel(notifOverdueId);
  }

  Future<void> cancelOverdueRepeats() async {
    if (kIsWeb) return;
    for (int id = overdueRepeatBase + 1; id <= overdueRepeatBase + 12; id++) {
      await _plugin.cancel(id);
    }
  }

  Future<void> cancelAll() async {
    // ⚠️ DO NOT use _plugin.cancelAll()
    await cancelTripNotifications();
    await cancelOverdueRepeats();
  }

  Future<void> scheduleTripNotifications({
    required bool tripActive,
    required DateTime? eta,
    required String rampName,
    required Duration approachingWindow,
    required bool overdueAcknowledged,
  }) async {
    if (kIsWeb) return;

    if (!tripActive || eta == null) {
      await cancelAll();
      return;
    }

    await cancelTripNotifications();

    final now = DateTime.now();
    final etaTime = eta;
    final approachTime = etaTime.subtract(approachingWindow);

    Future<void> zonedSafe(int id, String title, String body, DateTime when, bool overdue) async {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(when, tz.local),
          _details(overdue: overdue),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(when, tz.local),
          _details(overdue: overdue),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }

    if (approachTime.isAfter(now)) {
      await zonedSafe(
        notifApproachingId,
        "Marine Safe",
        "Return ETA due in 30 minutes for $rampName\nOpen Marine Safe to extend if needed.",
        approachTime,
        false,
      );
    }

    if (etaTime.isAfter(now)) {
      await zonedSafe(
        notifOverdueId,
        "Marine Safe",
        "OVERDUE return from $rampName — open app to acknowledge",
        etaTime,
        true,
      );
    }

    if (!overdueAcknowledged) {
      await cancelOverdueRepeats();
      for (int i = 1; i <= 12; i++) {
        final when = etaTime.add(Duration(minutes: 5 * i));
        if (!when.isAfter(now)) continue;
        await zonedSafe(
          overdueRepeatBase + i,
          "Marine Safe",
          "OVERDUE return from $rampName — open app to acknowledge",
          when,
          true,
        );
      }
    } else {
      await cancelOverdueRepeats();
    }
  }
}
