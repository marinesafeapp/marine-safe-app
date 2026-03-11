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

/// Marine Safe Escalation Plan:
/// 1. ETA (0–5 min grace): Due notification to skipper
/// 2. ETA+5 min: Overdue alert to skipper
/// 3. ETA+10 min: SMS to primary contact (notification: tap to open SMS)
/// 4. ETA+20 min: SMS to all contacts (notification: tap to open SMS)
/// 5. ETA+30 min: Recommend contact Marine Rescue
/// 6. ETA+60 min: Critical overdue
class TripEscalationService {
  TripEscalationService._();
  static final TripEscalationService instance = TripEscalationService._();

  static const int idDue = 9101;
  static const int idOverdue = 9102;
  static const int idSmsPrimary = 9103;
  static const int idSmsAll = 9104;
  static const int idMarineRescue = 9105;
  static const int idCritical = 9106;

  /// Payloads for notification tap handling (open SMS when user taps ETA+10 / ETA+20 notification).
  static const String payloadSmsPrimary = 'escalation_sms_primary';
  static const String payloadSmsAll = 'escalation_sms_all';

  static const String _payloadSmsPrimary = payloadSmsPrimary;
  static const String _payloadSmsAll = payloadSmsAll;

  static const String _titleDue = 'Marine Safe — Due now';
  static const String _bodyDue = 'ETA reached. Tap to open Marine Safe.';
  static const String _titleOverdue = 'Marine Safe — Overdue';
  static const String _bodyOverdue = 'No check-in received. Tap to open Marine Safe.';
  static const String _titleSmsPrimary = 'Marine Safe — Contact your emergency contact';
  static const String _titleSmsAll = 'Marine Safe — Alert all contacts';
  static const String _titleMarineRescue = 'Marine Safe — Consider Marine Rescue';
  static const String _bodyMarineRescue =
      'Trip is 30 min overdue. Consider contacting Marine Rescue or 000 if you have concerns.';
  static const String _titleCritical = 'Marine Safe — CRITICAL OVERDUE';
  static const String _bodyCritical =
      'Trip is 1 hour overdue. Open Marine Safe to acknowledge or contact emergency services.';

  static List<int> get _allIds =>
      [idDue, idOverdue, idSmsPrimary, idSmsAll, idMarineRescue, idCritical];

  final NotificationScheduler _scheduler = NotificationScheduler.instance;

  /// Schedule full escalation: DUE at ETA, OVERDUE at ETA+5, SMS prompts at +10/+20, Marine Rescue at +30, Critical at +60.
  Future<void> scheduleForTrip({
    required DateTime eta,
    required String tripId,
    String rampName = 'your ramp',
    String? vesselName,
    String? primaryContactName,
  }) async {
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

    final contactLabel = (primaryContactName != null && primaryContactName.trim().isNotEmpty)
        ? primaryContactName.trim()
        : 'your emergency contact';
    await _scheduler.scheduleAt(
      id: idSmsPrimary,
      title: _titleSmsPrimary,
      body: 'Send overdue alert to $contactLabel — tap to open SMS.',
      when: eta.add(const Duration(minutes: 10)),
      payload: _payloadSmsPrimary,
    );
    await _scheduler.scheduleAt(
      id: idSmsAll,
      title: _titleSmsAll,
      body: 'Send overdue alert to all contacts — tap to open SMS.',
      when: eta.add(const Duration(minutes: 20)),
      payload: _payloadSmsAll,
    );
    await _scheduler.scheduleAt(
      id: idMarineRescue,
      title: _titleMarineRescue,
      body: _bodyMarineRescue,
      when: eta.add(const Duration(minutes: 30)),
    );
    await _scheduler.scheduleAt(
      id: idCritical,
      title: _titleCritical,
      body: _bodyCritical,
      when: eta.add(const Duration(minutes: 60)),
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
  Future<void> onEtaChanged(
    DateTime newEta,
    String tripId, {
    String rampName = 'your ramp',
    String? vesselName,
    String? primaryContactName,
  }) async {
    if (kIsWeb) return;
    await scheduleForTrip(
      eta: newEta,
      tripId: tripId,
      rampName: rampName,
      vesselName: vesselName,
      primaryContactName: primaryContactName,
    );
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
