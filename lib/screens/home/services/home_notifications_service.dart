import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class HomeNotificationsService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const int notifApproachingId = 2001;
  static const int notifOverdueId = 2002;

  // Repeat IDs: 2101..2112
  static const int overdueRepeatBase = 2100;

  // New channel IDs so Samsung doesn't keep old channel settings
  static const String _channelEtaId = 'marine_safe_eta_v4';
  static const String _channelOverdueId = 'marine_safe_overdue_v4';

  Future<void> init() async {
    if (kIsWeb) return;
    if (_ready) return;

    // ✅ Always initialise timezone database
    tz.initializeTimeZones();

    // ✅ FORCE local timezone to Brisbane (fixes “10 seconds becomes 10 hours”)
    try {
      tz.setLocalLocation(tz.getLocation('Australia/Brisbane'));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Australia/Sydney'));
      } catch (_) {
        // leave default if something is very wrong (won't crash)
      }
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

      // Some devices require this to allow exact while idle
      try {
        await android?.requestExactAlarmsPermission();
      } catch (_) {}
    } catch (_) {}

    _ready = true;
  }

  NotificationDetails _details({required bool overdue}) {
    final channelId = overdue ? _channelOverdueId : _channelEtaId;
    final channelName =
    overdue ? 'Marine Safe Overdue Alerts' : 'Marine Safe ETA Alerts';
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

  Future<void> cancelAll() async {
    await cancelTripNotifications();
    await cancelOverdueRepeats();
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

  Future<void> _zoned({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
  }) async {
    // ✅ Keep it simple: always request exactAllowWhileIdle
    // ignore: avoid_print
    print('Scheduling id=$id at $when (tz=${tz.local.name})');

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

  // ✅ CANARY: schedule one notification 10 seconds from now
  Future<void> debugScheduleIn10s() async {
    if (kIsWeb) return;
    await init();

    final when = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
    await _zoned(
      id: 9999,
      title: 'Marine Safe',
      body: 'CANARY fired (scheduled 10s)',
      when: when,
      details: _details(overdue: true),
    );
  }

  Future<void> scheduleTripNotifications({
    required bool tripActive,
    required DateTime? eta,
    required String rampName,
    required Duration approachingWindow,
    required bool overdueAcknowledged,
  }) async {
    if (kIsWeb) return;
    await init();

    await cancelTripNotifications();

    if (!tripActive || eta == null) {
      await cancelOverdueRepeats();
      return;
    }

    // Use ETA/now as instants (UTC) so scheduling is correct in any device timezone
    final nowTz = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.UTC, DateTime.now().millisecondsSinceEpoch);
    final etaTz = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.UTC, eta.millisecondsSinceEpoch);

    // APPROACHING
    final approachTz = etaTz.subtract(approachingWindow);
    if (approachTz.isAfter(nowTz)) {
      await _zoned(
        id: notifApproachingId,
        title: 'Marine Safe',
        body:
        'Return ETA due in 30 minutes for $rampName\nOpen Marine Safe to extend if needed.',
        when: approachTz,
        details: _details(overdue: false),
      );
    }

    // OVERDUE at ETA (or now+2s if already past)
    final overdueWhen =
    etaTz.isAfter(nowTz) ? etaTz : nowTz.add(const Duration(seconds: 2));

    await _zoned(
      id: notifOverdueId,
      title: 'Marine Safe',
      body: 'OVERDUE return from $rampName — open app to acknowledge',
      when: overdueWhen,
      details: _details(overdue: true),
    );

    // ✅ No repeats. We only want a single overdue alert when the app is closed.
    // (Background service handles the single alert on Android when the app is killed.)
    await cancelOverdueRepeats();

    await debugPrintPending();
  }

  Future<void> debugPrintPending() async {
    if (kIsWeb) return;
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    // ignore: avoid_print
    print('MarineSafe pending notifications: ${pending.length}');
    for (final p in pending) {
      // ignore: avoid_print
      print(' - id=${p.id} title=${p.title}');
    }
  }

  Future<void> showOverdueNow({required String rampName}) async {
    if (kIsWeb) return;
    await init();
    await _plugin.show(
      notifOverdueId,
      'Marine Safe',
      'OVERDUE return from $rampName — open app to acknowledge',
      _details(overdue: true),
    );
  }

  // ✅ Compatibility wrapper (HomeController calls this)
  Future<void> scheduleOverdueRepeats({
    required bool tripActive,
    required DateTime? eta,
    required String rampName,
    required bool overdueAcknowledged,
  }) async {
    return scheduleOverdueRepeatsFromEta(
      tripActive: tripActive,
      eta: eta,
      rampName: rampName,
      overdueAcknowledged: overdueAcknowledged,
    );
  }

  Future<void> scheduleOverdueRepeatsFromEta({
    required bool tripActive,
    required DateTime? eta,
    required String rampName,
    required bool overdueAcknowledged,
    int intervalMinutes = 5,
    int count = 12,
  }) async {
    if (kIsWeb) return;
    if (!tripActive || eta == null) return;
    if (overdueAcknowledged) return;

    await init();
    await cancelOverdueRepeats();

    final nowTz = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.UTC, DateTime.now().millisecondsSinceEpoch);
    final etaTz = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.UTC, eta.millisecondsSinceEpoch);
    final base = etaTz.isAfter(nowTz) ? etaTz : nowTz;

    for (int i = 1; i <= count; i++) {
      final when = base.add(Duration(minutes: intervalMinutes * i));
      await _zoned(
        id: overdueRepeatBase + i,
        title: 'Marine Safe',
        body: 'OVERDUE return from $rampName — open app to acknowledge',
        when: when,
        details: _details(overdue: true),
      );
    }
  }
}
