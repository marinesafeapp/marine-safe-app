import 'package:flutter/material.dart';

import 'package:marine_safe_app_fixed/models/ramp.dart';
import 'package:marine_safe_app_fixed/data/ramp_data.dart';
import 'package:marine_safe_app_fixed/screens/trip_status.dart';

import '../services/trip_prefs.dart';

class HomeTripState {
  static const Duration approachingWindow = Duration(minutes: 30);

  bool tripActive = false;

  Ramp? selectedRamp;

  DateTime? departAt;
  DateTime? eta;

  bool overdueAcknowledged = false;
  bool overdueAlertFiredThisTrip = false;

  int personsOnBoard = 0;

  bool get isOverdue {
    if (!tripActive || eta == null) return false;
    // Overdue stage is defined by OS escalation schedule: ETA + 5 minutes.
    return DateTime.now().isAfter(eta!.add(const Duration(minutes: 5)));
  }

  bool get isApproaching {
    if (!tripActive || eta == null) return false;
    final now = DateTime.now();
    final approach = eta!.subtract(approachingWindow);
    return now.isAfter(approach) && now.isBefore(eta!);
  }

  TripStatus get tripStatus {
    if (!tripActive || eta == null) return TripStatus.ok;
    if (isOverdue && !overdueAcknowledged) return TripStatus.overdue;
    if (isApproaching) return TripStatus.dueSoon;
    return TripStatus.ok;
  }

  String get etaCardText {
    if (eta == null) return "Set your return ETA";
    final dt = eta!;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return "Return ETA: $hh:$mm";
  }

  Future<void> load() async {
    tripActive = await TripPrefs.getTripActive();

    final rampId = await TripPrefs.getRampId();
    if (rampId != null) {
      try {
        selectedRamp = australianRamps.firstWhere((r) => r.id == rampId);
      } catch (_) {
        selectedRamp = null;
      }
    } else {
      selectedRamp = null;
    }

    final iso = await TripPrefs.getEtaIso();
    eta = iso == null ? null : DateTime.tryParse(iso);

    final departAtIso = await TripPrefs.getDepartAtIso();
    departAt = departAtIso == null ? null : DateTime.tryParse(departAtIso);

    overdueAcknowledged = await TripPrefs.getOverdueAck();

    personsOnBoard = await TripPrefs.getPersonsOnBoard();
    if (personsOnBoard <= 0) {
      final last = await TripPrefs.getLastPersonsOnBoard(fallback: 0);
      if (last > 0) personsOnBoard = last;
    }
  }

  Future<void> save() async {
    await TripPrefs.setTripActive(tripActive);
    await TripPrefs.setRampId(selectedRamp?.id);
    await TripPrefs.setEtaIso(eta?.toIso8601String());
    await TripPrefs.setDepartAtIso(departAt?.toIso8601String());
    await TripPrefs.setOverdueAck(overdueAcknowledged);
    await TripPrefs.setPersonsOnBoard(personsOnBoard);
  }

  Future<void> setRamp(Ramp ramp) async {
    selectedRamp = ramp;
    await TripPrefs.setRampId(ramp.id);
  }

  Future<void> pickEta(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 4))),
    );
    if (picked == null) return;

    var dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);

    // If user picks a time earlier than now, assume next day.
    if (dt.isBefore(now)) dt = dt.add(const Duration(days: 1));

    eta = dt;
    await TripPrefs.setEtaIso(eta!.toIso8601String());
  }

  Future<void> extendEta(Duration delta) async {
    if (eta == null) return;
    eta = eta!.add(delta);
    await TripPrefs.setEtaIso(eta!.toIso8601String());
  }

  Future<void> endTripAndClearTripOnly() async {
    tripActive = false;
    departAt = null;
    eta = null;

    overdueAcknowledged = false;
    overdueAlertFiredThisTrip = false;

    await TripPrefs.setTripActive(false);
    await TripPrefs.setEtaIso(null);
    await TripPrefs.setDepartAtIso(null);
    await TripPrefs.setOverdueAck(false);
  }
}
