import 'package:flutter/material.dart';

class OverdueFlow {
  bool _dialogShowing = false;

  Future<void> showOverdueDialog({
    required BuildContext context,
    required Future<void> Function() onAcknowledge,
  }) async {
    if (_dialogShowing) return;
    _dialogShowing = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text(
          "OVERDUE",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          "Your return ETA has passed.\n\n"
              "If you are safe, acknowledge this alert.\n\n"
              "If you are in danger, call 000 or use VHF Channel 16 immediately.",
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
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
