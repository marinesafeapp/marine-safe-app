import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/fix_issue_router.dart';

class BatteryOptimisationService {
  static const String _kDismissed = 'battery.optimisation.dismissed';

  static Future<void> showIfNeeded(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final p = await SharedPreferences.getInstance();
    final dismissed = p.getBool(_kDismissed) ?? false;
    if (dismissed) return;

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text(
          'Important: Notifications Reliability',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const SingleChildScrollView(
          child: Text(
            '''Some Android phones (especially Samsung) may block Marine Safe notifications to save battery.

To ensure overdue and safety alerts always fire:

• Set Battery usage to “Unrestricted”
• Disable Battery optimisation for Marine Safe

This only takes 30 seconds and greatly improves safety reliability.''',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _markDismissed();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _markDismissed();
              await FixIssueRouter.openFix(FixIssue.batteryOptimizationEnabled);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Fix'),
          ),
        ],
      ),
    );
  }

  static Future<void> _markDismissed() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDismissed, true);
  }
}
