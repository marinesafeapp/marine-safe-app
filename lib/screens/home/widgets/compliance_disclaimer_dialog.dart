import 'package:flutter/material.dart';
import '../services/compliance_service.dart';

class ComplianceDisclaimerDialog {
  static Future<bool> show(
      BuildContext context, {
        required List<ComplianceIssue> issues,
      }) async {
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text(
          "Safety & Compliance Warning",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Before starting your trip, please review the following:",
              ),
              const SizedBox(height: 12),
              ...issues.map(
                    (i) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: i.critical
                          ? Colors.redAccent.withValues(alpha:0.6)
                          : Colors.orangeAccent.withValues(alpha:0.6),
                    ),
                    color: i.critical
                        ? Colors.redAccent.withValues(alpha:0.15)
                        : Colors.orangeAccent.withValues(alpha:0.15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i.title,
                        style: TextStyle(
                          color: i.critical
                              ? Colors.redAccent
                              : Colors.orangeAccent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        i.detail,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "You may continue at your own risk, or go back and fix these items.",
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("GO BACK"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("PROCEED ANYWAY"),
          ),
        ],
      ),
    );

    return proceed == true;
  }

  /// Show compliance/PFD issues as informational only (e.g. after changing people on board). Single OK button.
  static Future<void> showInformational(
    BuildContext context, {
    required List<ComplianceIssue> issues,
  }) async {
    if (issues.isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text(
          "PFD & safety notice",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Please review the following:",
              ),
              const SizedBox(height: 12),
              ...issues.map(
                (i) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: i.critical
                          ? Colors.redAccent.withValues(alpha: 0.6)
                          : Colors.orangeAccent.withValues(alpha: 0.6),
                    ),
                    color: i.critical
                        ? Colors.redAccent.withValues(alpha: 0.15)
                        : Colors.orangeAccent.withValues(alpha: 0.15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i.title,
                        style: TextStyle(
                          color: i.critical
                              ? Colors.redAccent
                              : Colors.orangeAccent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        i.detail,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
