import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Key used to store pending escalation action when user taps ETA+10 / ETA+20 notification.
const String kPendingEscalationActionKey = 'app.pending_escalation_action';

/// One-time init for OS-level local notifications.
/// Call from main() early (e.g. after WidgetsFlutterBinding.ensureInitialized).
/// Requests permissions (Android 13+ POST_NOTIFICATIONS, iOS), initializes timezone, creates channels.
/// When user taps an escalation notification (e.g. "tap to open SMS"), stores payload for HomeScreen to handle.
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
    requestAlertPermission: true,
    requestSoundPermission: true,
    requestBadgePermission: true,
  );
  const settings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        final p = await SharedPreferences.getInstance();
        await p.setString(kPendingEscalationActionKey, payload);
      }
    },
  );
  await plugin.initialize(settings);

  // If app was launched from a notification tap (cold start), store payload so UI can open SMS
  final details = await plugin.getNotificationAppLaunchDetails();
  if (details?.didNotificationLaunchApp == true &&
      details?.notificationResponse?.payload != null &&
      details!.notificationResponse!.payload!.isNotEmpty) {
    final p = await SharedPreferences.getInstance();
    await p.setString(kPendingEscalationActionKey, details.notificationResponse!.payload!);
  }

  // Android 13+ POST_NOTIFICATIONS; iOS permission via DarwinInitializationSettings
  try {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
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
