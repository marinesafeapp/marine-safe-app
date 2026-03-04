import 'dart:async';

import 'package:flutter/material.dart';

import '../models/home_trip_state.dart';
import '../services/trip_notifications.dart';
import '../services/trip_prefs.dart';

class OverdueAckService {
  Timer? _ticker;

  bool overdueDialogShowing = false;

  void start({
    required HomeTripState state,
    required TripNotifications notifications,
    required VoidCallback onTickNeedsRebuild,
    required Future<void> Function() showAcknowledgeDialog,
  }) {
    _ticker?.cancel();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      // Keep UI fresh
      onTickNeedsRebuild();

      if (!state.tripActive || state.eta == null) return;
      if (state.overdueAcknowledged) return;
      if (state.overdueAlertFiredThisTrip) return;

      if (DateTime.now().isAfter(state.eta!)) {
        state.overdueAlertFiredThisTrip = true;

        final rampName = state.selectedRamp?.name ?? "your ramp";
        await notifications.showOverdueNow(rampName: rampName);
        await notifications.scheduleOverdueRepeats(rampName: rampName);

        // show dialog while open (once)
        await showAcknowledgeDialog();
      }
    });
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> acknowledge({
    required HomeTripState state,
    required TripNotifications notifications,
  }) async {
    state.overdueAcknowledged = true;
    await TripPrefs.setOverdueAck(true);
    await notifications.cancelOverdueRepeats();
  }

  Future<void> showOverdueDialog({
    required BuildContext context,
    required HomeTripState state,
    required TripNotifications notifications,
  }) async {
    if (overdueDialogShowing) return;
    overdueDialogShowing = true;

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
              await acknowledge(state: state, notifications: notifications);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Overdue acknowledged ✅")),
                );
              }
            },
            child: const Text("ACKNOWLEDGE"),
          ),
        ],
      ),
    );

    overdueDialogShowing = false;
  }
}
