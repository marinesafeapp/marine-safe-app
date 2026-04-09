import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// One-time init for OS-level local notifications.
/// Call from main() early (e.g. after WidgetsFlutterBinding.ensureInitialized).
/// Initializes timezone and notification channels.
///
/// Note: we intentionally do NOT request OS notification permissions here,
/// so first-time onboarding / registration stays clean. Permissions should be
/// requested later from an in-app button (e.g. Reliability screen).
Future<void> initNotifications() async {
  if (kIsWeb) return;
  if (!Platform.isAndroid && !Platform.isIOS) return;

  // Timezone required for zonedSchedule
  tz.initializeTimeZones();
  try {
    tz.setLocalLocation(tz.getLocation('Australia/Brisbane'));
  } catch (_) {
    try {
      tz.setLocalLocation(tz.getLocation('Australia/Sydney'));
    } catch (_) {}
  }

  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestSoundPermission: false,
    requestBadgePermission: false,
  );
  const settings = InitializationSettings(android: androidInit, iOS: iosInit);
  await plugin.initialize(settings);

  // Android 13+: POST_NOTIFICATIONS permission is requested later (manual button).
  try {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
  } catch (_) {}

  // Create channels (Android) so notifications are not silent
  try {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'marine_safe_escalation',
      'Marine Safe Trip Alerts',
      description: 'Due, overdue and escalating trip notifications',
      importance: Importance.max,
    ));
  } catch (_) {}
}
