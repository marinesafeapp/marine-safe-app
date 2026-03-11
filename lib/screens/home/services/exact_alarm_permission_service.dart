import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../services/fix_issue_router.dart';

class ExactAlarmPermissionService {

  static Future<bool> _canScheduleExact() async {
    if (!Platform.isAndroid) return true;

    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ok = await android?.canScheduleExactNotifications();
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Shows a one-time blocking dialog that takes user to "Alarms & reminders"
  static Future<void> ensureExactAlarmsEnabled(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final ok = await _canScheduleExact();
    if (ok) return;

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text(
          "Enable exact alarms",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          "Marine Safe needs permission to schedule exact overdue alerts.\n\n"
              "On Samsung/Android 12+, this is called “Alarms & reminders”.\n\n"
              "Tap OPEN SETTINGS and enable it for Marine Safe, then come back.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("NOT NOW"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FixIssueRouter.openFix(FixIssue.exactAlarmsDisabled);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Fix"),
          ),
        ],
      ),
    );
  }
}
