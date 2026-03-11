import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_bootstrap.dart';

/// Wrapper around FlutterLocalNotificationsPlugin for OS-level scheduled notifications.
/// No Dart timers for critical scheduling; use scheduleAt / scheduleRepeatingWindows only.
class NotificationScheduler {
  NotificationScheduler._();
  static final NotificationScheduler instance = NotificationScheduler._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const String _channelId = 'marine_safe_escalation';

  Future<void> _ensureInit() async {
    if (kIsWeb) return;
    if (_ready) return;
    await initNotifications();
    _ready = true;
  }

  NotificationDetails _defaultDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Marine Safe Trip Alerts',
        channelDescription: 'Due, overdue and escalating trip notifications',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 800, 250, 800, 250, 1200]),
        playSound: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );
  }

  /// Schedule a single notification at [when] (interpreted in local timezone).
  /// [payload] is optional and can be used for tap handling.
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await _ensureInit();
    final whenTz = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.local,
      when.millisecondsSinceEpoch,
    );
    if (whenTz.isBefore(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      whenTz,
      _defaultDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Cancel a single scheduled notification by id.
  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _ensureInit();
    await _plugin.cancel(id);
  }

  /// Cancel all scheduled notifications (only those we manage; does not call plugin.cancelAll()).
  /// Call with the list of ids to cancel (e.g. [9101, 9102, 9200..9223]).
  Future<void> cancelAll(Iterable<int> ids) async {
    if (kIsWeb) return;
    await _ensureInit();
    for (final id in ids) {
      await _plugin.cancel(id);
    }
  }

  /// Schedule multiple one-off notifications to simulate repeating: first at [firstWhen], then [firstWhen] + interval, + 2*interval, ... [count] times.
  /// IDs used: [baseId], [baseId+1], ... [baseId+count-1].
  /// Use this instead of periodic because OS periodic is unreliable when app is closed.
  Future<void> scheduleRepeatingWindows({
    required int baseId,
    required DateTime firstWhen,
    required int intervalMinutes,
    required int count,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await _ensureInit();
    final nowTz = tz.TZDateTime.now(tz.local);
    for (int i = 0; i < count; i++) {
      final when = firstWhen.add(Duration(minutes: intervalMinutes * i));
      final whenTz = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.local,
        when.millisecondsSinceEpoch,
      );
      if (!whenTz.isAfter(nowTz)) continue;
      await _plugin.zonedSchedule(
        baseId + i,
        title,
        body,
        whenTz,
        _defaultDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }
}
