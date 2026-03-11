import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// OS-level notification scheduling for trip escalation.
/// No Dart timers for critical scheduling; only zonedSchedule.
class NotificationScheduler {
  NotificationScheduler._();
  static final NotificationScheduler instance = NotificationScheduler._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// DUE at ETA
  static const int idDue = 2001;
  /// OVERDUE at ETA+5 min
  static const int idOverdue = 2002;
  /// ESCALATING: 2101..2112 (every 5 min after ETA+5)
  static const int escalationBase = 2100;
  static const int escalationCount = 12;

  static const String _channelEtaId = 'marine_safe_eta_v4';
  static const String _channelOverdueId = 'marine_safe_overdue_v4';

  Future<void> init() async {
    if (kIsWeb) return;
    if (_ready) return;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Australia/Brisbane'));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Australia/Sydney'));
      } catch (_) {}
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
    );
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);
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
    final channelId = overdue ? _channelOverdueId : _channelEtaId;
    final channelName = overdue
        ? 'Marine Safe Overdue Alerts'
        : 'Marine Safe ETA Alerts';
    final channelDesc = overdue ? 'Overdue return alerts' : 'Trip ETA alerts';
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
        ticker: overdue ? 'Marine Safe OVERDUE' : 'Marine Safe ETA',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );
  }

  /// Cancel all escalation-related notifications (DUE, OVERDUE, ESCALATING).
  Future<void> cancelAllEscalation() async {
    if (kIsWeb) return;
    await init();
    await _plugin.cancel(idDue);
    await _plugin.cancel(idOverdue);
    for (int i = 1; i <= escalationCount; i++) {
      await _plugin.cancel(escalationBase + i);
    }
  }

  Future<void> _zoned({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
  }) async {
    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedule DUE at ETA, OVERDUE at ETA+5 min, ESCALATING every [intervalMinutes] (default 5) for [escalationCount] times.
  /// [lastLocationPayload] optional text to append to body (e.g. "Last known: -21.14, 149.18 at 14:30").
  Future<void> scheduleEscalation({
    required DateTime eta,
    required String rampName,
    String? lastLocationPayload,
    int intervalMinutes = 5,
  }) async {
    if (kIsWeb) return;
    await init();
    await cancelAllEscalation();

    final nowTz = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.local, DateTime.now().millisecondsSinceEpoch);
    final etaTz = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.local, eta.millisecondsSinceEpoch);

    final locationSuffix = (lastLocationPayload != null && lastLocationPayload.isNotEmpty)
        ? '\n$lastLocationPayload'
        : '';

    // Stage DUE: at ETA
    if (etaTz.isAfter(nowTz)) {
      await _zoned(
        id: idDue,
        title: 'Marine Safe',
        body: 'Return ETA is now for $rampName. Open Marine Safe to extend or acknowledge.' + locationSuffix,
        when: etaTz,
        details: _details(overdue: false),
      );
    }

    // Stage OVERDUE: at ETA+5 min
    final overdueWhen = etaTz.add(Duration(minutes: 5));
    if (overdueWhen.isAfter(nowTz)) {
      await _zoned(
        id: idOverdue,
        title: 'Marine Safe',
        body: 'OVERDUE return from $rampName — open app to acknowledge.' + locationSuffix,
        when: overdueWhen,
        details: _details(overdue: true),
      );
    }

    // Stage ESCALATING: every intervalMinutes, 12 times (first at ETA+10, then ETA+15, ...)
    for (int i = 1; i <= escalationCount; i++) {
      final when = etaTz.add(Duration(minutes: 5 + intervalMinutes * i));
      if (!when.isAfter(nowTz)) continue;
      await _zoned(
        id: escalationBase + i,
        title: 'Marine Safe',
        body: 'OVERDUE return from $rampName — open app to acknowledge.' + locationSuffix,
        when: when,
        details: _details(overdue: true),
      );
    }
  }
}
