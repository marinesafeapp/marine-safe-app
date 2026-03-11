import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../notifications/notification_scheduler.dart';

/// Persisted escalation state (survives app kill and relaunch).
const String _kTripActive = 'trip_active';
const String _kTripEtaIso = 'trip_eta_iso';
const String _kTripAcked = 'trip_acked';
const String _kTripEnded = 'trip_ended';
const String _kTripId = 'trip_id';
const String _kEscalationEnabled = 'escalation_enabled';

Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

/// Trip escalation: DUE at ETA, OVERDUE at ETA+5, ESCALATING at ETA+10 then every 10 min.
/// Uses OS-level scheduled local notifications only. No Dart timers for critical events.
class TripEscalationService {
  TripEscalationService._();
  static final TripEscalationService instance = TripEscalationService._();

  /// DUE at ETA
  static const int idDue = 9101;
  /// OVERDUE at ETA+5 min
  static const int idOverdue = 9102;
  /// ESCALATING: 9200..9223 (24 slots), first at ETA+10 min, then every 10 min
  static const int escalationBaseId = 9200;
  static const int escalationCount = 24;

  static const String _titleDue = 'Marine Safe — Due now';
  static const String _bodyDue = 'ETA reached. Tap to open Marine Safe.';
  static const String _titleOverdue = 'Marine Safe — Overdue';
  static const String _bodyOverdue = 'No check-in received. Tap to open Marine Safe.';
  static const String _titleEscalating = 'Marine Safe — Overdue (Escalating)';
  static const String _bodyEscalating = 'Still no response. Tap to open Marine Safe.';

  final NotificationScheduler _scheduler = NotificationScheduler.instance;

  /// All notification IDs used by this service (for cancelAll).
  static List<int> get _allIds {
    final list = <int>[idDue, idOverdue];
    for (int i = 0; i < escalationCount; i++) {
      list.add(escalationBaseId + i);
    }
    return list;
  }

  /// Schedule DUE at ETA, OVERDUE at ETA+5, ESCALATING at ETA+10 then every 10 min (24 repeats).
  /// Cancels any existing schedules first. Persists state.
  Future<void> scheduleForTrip({required DateTime eta, required String tripId}) async {
    if (kIsWeb) return;
    await cancelForTrip();

    await _scheduler.scheduleAt(
      id: idDue,
      title: _titleDue,
      body: _bodyDue,
      when: eta,
    );
    await _scheduler.scheduleAt(
      id: idOverdue,
      title: _titleOverdue,
      body: _bodyOverdue,
      when: eta.add(const Duration(minutes: 5)),
    );
    await _scheduler.scheduleRepeatingWindows(
      baseId: escalationBaseId,
      firstWhen: eta.add(const Duration(minutes: 10)),
      intervalMinutes: 10,
      count: escalationCount,
      title: _titleEscalating,
      body: _bodyEscalating,
    );

    final p = await _prefs();
    await p.setBool(_kTripActive, true);
    await p.setString(_kTripEtaIso, eta.toIso8601String());
    await p.setBool(_kTripAcked, false);
    await p.setBool(_kTripEnded, false);
    await p.setString(_kTripId, tripId);
    await p.setBool(_kEscalationEnabled, true);
  }

  /// Cancel all scheduled escalation notifications and persist cancelled state.
  /// Does not clear [trip_acked] so that acknowledgeTrip() can set ack then cancel.
  Future<void> cancelForTrip() async {
    if (kIsWeb) return;
    await _scheduler.cancelAll(_allIds);

    final p = await _prefs();
    await p.setBool(_kTripActive, false);
    await p.setBool(_kTripEnded, true);
    await p.setBool(_kEscalationEnabled, false);
  }

  /// Call when user taps "I'm Safe". Sets ack and cancels all notifications.
  Future<void> acknowledgeTrip() async {
    if (kIsWeb) return;
    final p = await _prefs();
    await p.setBool(_kTripAcked, true);
    await cancelForTrip();
  }

  /// Call when ETA is extended/changed. Reschedules all notifications with new ETA.
  Future<void> onEtaChanged(DateTime newEta, String tripId) async {
    if (kIsWeb) return;
    await scheduleForTrip(eta: newEta, tripId: tripId);
  }

  /// Whether escalation is currently enabled (trip active, not acked, not ended).
  Future<bool> get escalationEnabled async {
    final p = await _prefs();
    final active = p.getBool(_kTripActive) ?? false;
    final acked = p.getBool(_kTripAcked) ?? true;
    final ended = p.getBool(_kTripEnded) ?? true;
    return active && !acked && !ended;
  }
}
