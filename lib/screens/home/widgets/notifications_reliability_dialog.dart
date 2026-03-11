import 'package:flutter/material.dart';

import '../../../services/fix_issue_router.dart';

class NotificationsReliabilityDialog {
  static Future<void> show(BuildContext context) async {
    final issues = await FixIssueRouter.checkReliabilityIssues();
    final topIssue = issues.isNotEmpty ? issues.first : FixIssue.unknown;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        title: const Text(
          'Important:\nNotifications\nReliability',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Some Android phones (especially Samsung) may block Marine Safe '
              'notifications to save battery.\n\n'
              'To ensure overdue and safety alerts always fire:\n\n'
              '• Set Battery usage to “Unrestricted”\n'
              '• Disable Battery optimisation for Marine Safe\n\n'
              'This only takes 30 seconds and greatly improves safety reliability.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Close dialog first so Settings opens cleanly
              Navigator.pop(context);

              // Best experience: open the app’s details screen
              await FixIssueRouter.openFix(topIssue);
            },
            child: const Text('Fix'),
          ),
        ],
      ),
    );
  }
}
