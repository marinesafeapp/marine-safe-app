import 'package:flutter/foundation.dart' show kIsWeb;

import '../screens/home/services/trip_prefs.dart';
import 'escalation_prefs.dart';
import 'gps_tracking_service.dart';
import 'notification_scheduler.dart';

/// Cross-platform overdue escalation: schedule OS-level notifications,
/// persist state so it survives app kill/reboot. No Dart timers for critical scheduling.
class TripEscalationService {
  TripEscalationService._();
  static final TripEscalationService instance = TripEscalationService._();

  /// Minutes between repeated OVERDUE alerts while the app is closed.
  /// User must reopen the app and acknowledge to stop these.
  static const int escalationIntervalMinutes = 2;

  /// Schedule DUE at ETA, OVERDUE at ETA+5 min, ESCALATING every 5 min (12 times).
  /// Call when trip is started with ETA. Persists escalation state.
  Future<void> scheduleEscalation({
    required DateTime eta,
    required String rampName,
  }) async {
    if (kIsWeb) return;

    await EscalationPrefs.setStage('due');
    await NotificationScheduler.instance.scheduleEscalation(
      eta: eta,
      rampName: rampName,
      lastLocationPayload: await _lastLocationPayload(),
      intervalMinutes: escalationIntervalMinutes,
    );
  }

  /// Build optional "Last known: lat, lng at HH:mm" from local GPS or Firestore.
  Future<String?> _lastLocationPayload() async {
    try {
      final point = await GPSTrackingService.instance.getLastPoint();
      if (point == null) return null;
      final t = point.timestamp;
      final timeStr = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      return 'Last known: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)} at $timeStr';
    } catch (_) {
      return null;
    }
  }

  /// Cancel all scheduled escalation notifications and clear persisted escalation state.
  /// Call when user taps "I'm Safe" (acknowledge) or ends trip.
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await NotificationScheduler.instance.cancelAllEscalation();
    await EscalationPrefs.clear();
  }

  /// Call when user acknowledges overdue (I'm Safe). Cancels all notifications.
  Future<void> acknowledge() async {
    await TripPrefs.setOverdueAck(true);
    await cancelAll();
  }

  /// Call when user ends trip. Cancels all notifications and clears escalation state.
  Future<void> onTripEnded() async {
    await cancelAll();
  }

  /// Rehydrate from prefs and optionally re-schedule if trip is active and not acknowledged.
  /// Call on app startup / resume so state survives kill/reboot.
  Future<void> rehydrateAndRescheduleIfNeeded() async {
    if (kIsWeb) return;

    final tripActive = await TripPrefs.getTripActive();
    final acknowledged = await TripPrefs.getOverdueAck();
    final etaIso = await TripPrefs.getEtaIso();
    final rampName = await TripPrefs.getRampName() ?? 'your ramp';

    if (!tripActive || acknowledged || etaIso == null) {
      await cancelAll();
      return;
    }

    final eta = DateTime.tryParse(etaIso);
    if (eta == null) return;

    // Re-schedule so OS has correct notifications (survives reboot / app reinstall flow)
    await scheduleEscalation(eta: eta, rampName: rampName);
  }
}
