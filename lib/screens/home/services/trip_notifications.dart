import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Legacy/alternate trip notification service.
/// IMPORTANT:
/// - Uses its OWN IDs so it never cancels HomeNotificationsService schedules.
/// - Keep only if something else still imports it.
class TripNotifications {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // 🔒 Different ID range to avoid clobbering HomeNotificationsService (2001/2002/2101..)
  static const int _notifApproachingId = 7201;
  static const int _notifOverdueId = 7202;
  static const int _overdueRepeatBase = 7300; // 7301..7312

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
    final channelId = overdue ? 'marine_safe_overdue_legacy_v1' : 'marine_safe_eta_legacy_v1';
    final channelName = overdue ? 'Marine Safe Overdue (Legacy)' : 'Marine Safe ETA (Legacy)';
    final channelDesc = overdue ? 'Overdue return alerts (legacy)' : 'Trip ETA alerts (legacy)';

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
    await _plugin.cancel(_notifApproachingId);
    await _plugin.cancel(_notifOverdueId);
  }

  Future<void> cancelOverdueRepeats() async {
    if (kIsWeb) return;
    for (int id = _overdueRepeatBase + 1; id <= _overdueRepeatBase + 12; id++) {
      await _plugin.cancel(id);
    }
  }

  /// Show an immediate overdue notification.
  Future<void> showOverdueNow({required String rampName}) async {
    if (kIsWeb) return;
    await _plugin.show(
      _notifOverdueId,
      'Marine Safe',
      'OVERDUE return from $rampName — open app to acknowledge',
      _details(overdue: true),
    );
  }

  /// Schedule repeating overdue notifications (e.g. every 5 min after ETA).
  Future<void> scheduleOverdueRepeats({required String rampName}) async {
    if (kIsWeb) return;
    await cancelOverdueRepeats();
    final now = DateTime.now();
    for (int i = 1; i <= 12; i++) {
      final when = now.add(Duration(minutes: 5 * i));
      try {
        await _plugin.zonedSchedule(
          _overdueRepeatBase + i,
          'Marine Safe',
          'OVERDUE return from $rampName — open app to acknowledge',
          tz.TZDateTime.from(when, tz.local),
          _details(overdue: true),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {
        await _plugin.zonedSchedule(
          _overdueRepeatBase + i,
          'Marine Safe',
          'OVERDUE return from $rampName — open app to acknowledge',
          tz.TZDateTime.from(when, tz.local),
          _details(overdue: true),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  Future<void> cancelAll() async {
    // ⚠️ Do NOT call _plugin.cancelAll() here — ever.
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
        _notifApproachingId,
        "Marine Safe",
        "Return ETA due in 30 minutes for $rampName\nOpen Marine Safe to extend if needed.",
        approachTime,
        false,
      );
    }

    if (etaTime.isAfter(now)) {
      await zonedSafe(
        _notifOverdueId,
        "Marine Safe",
        "OVERDUE return from $rampName — open app to acknowledge",
        etaTime,
        true,
      );
    }

    // repeats after ETA (pre-scheduled)
    if (!overdueAcknowledged) {
      await cancelOverdueRepeats();
      for (int i = 1; i <= 12; i++) {
        final when = etaTime.add(Duration(minutes: 5 * i));
        if (!when.isAfter(now)) continue;
        await zonedSafe(
          _overdueRepeatBase + i,
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
