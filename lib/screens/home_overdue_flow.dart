import 'package:flutter/material.dart';

class HomeOverdueFlow {
  bool _dialogShowing = false;

  Future<void> show({
    required BuildContext context,
    required Future<void> Function() onAcknowledge,
    Future<void> Function(BuildContext context)? onOpenSmsToEmergencyContact,
  }) async {
    if (_dialogShowing) return;
    _dialogShowing = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "OVERDUE",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          "Your return ETA has passed.\n\n"
              "If you are safe, acknowledge this alert.\n\n"
              "If you need help, text your emergency contact or call 000 / VHF Channel 16 immediately.",
        ),
        actions: [
          if (onOpenSmsToEmergencyContact != null)
            TextButton(
              onPressed: () async {
                await onOpenSmsToEmergencyContact(ctx);
              },
              child: const Text("TEXT EMERGENCY CONTACT"),
            ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await onAcknowledge();
            },
            child: const Text("ACKNOWLEDGE"),
          ),
        ],
      ),
    );

    _dialogShowing = false;
  }
}
