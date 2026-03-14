import 'package:shared_preferences/shared_preferences.dart';

class TripPrefs {
  static const _kTripActive = 'trip.active';
  static const _kEtaIso = 'trip.etaIso';
  static const _kRampId = 'trip.rampId';
  static const _kRampName = 'trip.rampName';
  static const _kDepartAtIso = 'trip.departAtIso';

  static const _kPersonsOnBoard = 'trip.personsOnBoard';
  static const _kLastPersonsOnBoard = 'trip.lastPersonsOnBoard';

  static const _kOverdueAck = 'trip.overdueAck';
  static const _kOverdueNotifSent = 'trip.overdueNotifSent';
  static const _kOverdueRecorded = 'trip.overdueRecorded';

  /// Set once after user has seen Alert Reliability (registration or first trip). Never show again per trip.
  static const _kAlertReliabilityAcknowledged = 'app.alert_reliability_acknowledged';

  static const _kSafetyStateJson = 'safety.state.json';

  static Future<SharedPreferences> _p() => SharedPreferences.getInstance();

  // ---- Trip basics ----
  static Future<void> setTripActive(bool v) async =>
      (await _p()).setBool(_kTripActive, v);

  static Future<bool> getTripActive() async =>
      (await _p()).getBool(_kTripActive) ?? false;

  static Future<void> setEtaIso(String? iso) async {
    final p = await _p();
    if (iso == null) {
      await p.remove(_kEtaIso);
    } else {
      await p.setString(_kEtaIso, iso);
    }
  }

  static Future<String?> getEtaIso() async => (await _p()).getString(_kEtaIso);

  static Future<void> setRampId(String? id) async {
    final p = await _p();
    if (id == null) {
      await p.remove(_kRampId);
    } else {
      await p.setString(_kRampId, id);
    }
  }

  static Future<String?> getRampId() async => (await _p()).getString(_kRampId);

  static Future<void> setRampName(String? name) async {
    final p = await _p();
    if (name == null) {
      await p.remove(_kRampName);
    } else {
      await p.setString(_kRampName, name);
    }
  }

  static Future<String?> getRampName() async =>
      (await _p()).getString(_kRampName);

  static Future<void> setDepartAtIso(String? iso) async {
    final p = await _p();
    if (iso == null) {
      await p.remove(_kDepartAtIso);
    } else {
      await p.setString(_kDepartAtIso, iso);
    }
  }

  static Future<String?> getDepartAtIso() async =>
      (await _p()).getString(_kDepartAtIso);

  // ---- People on board ----
  static Future<void> setPersonsOnBoard(int v) async =>
      (await _p()).setInt(_kPersonsOnBoard, v);

  static Future<int> getPersonsOnBoard() async =>
      (await _p()).getInt(_kPersonsOnBoard) ?? 0;

  static Future<void> setLastPersonsOnBoard(int v) async =>
      (await _p()).setInt(_kLastPersonsOnBoard, v);

  static Future<int> getLastPersonsOnBoard({int fallback = 2}) async =>
      (await _p()).getInt(_kLastPersonsOnBoard) ?? fallback;

  // ---- Overdue ----
  static Future<void> setOverdueAck(bool v) async =>
      (await _p()).setBool(_kOverdueAck, v);

  static Future<bool> getOverdueAck() async =>
      (await _p()).getBool(_kOverdueAck) ?? false;

  /// True once we've fired the single overdue alert for this trip.
  /// Used to prevent repeat notifications when the app is reopened.
  static Future<void> setOverdueNotifSent(bool v) async =>
      (await _p()).setBool(_kOverdueNotifSent, v);

  static Future<bool> getOverdueNotifSent() async =>
      (await _p()).getBool(_kOverdueNotifSent) ?? false;

  /// True once the overdue stage has been recorded/handled for the current active trip.
  /// Used to dedupe in-app overdue UI and any legacy emitters across app restarts.
  static Future<void> setOverdueRecorded(bool v) async =>
      (await _p()).setBool(_kOverdueRecorded, v);

  static Future<bool> getOverdueRecorded() async =>
      (await _p()).getBool(_kOverdueRecorded) ?? false;

  // ---- Alert reliability (shown once after registration / first trip) ----
  static Future<void> setAlertReliabilityAcknowledged(bool v) async =>
      (await _p()).setBool(_kAlertReliabilityAcknowledged, v);

  static Future<bool> getAlertReliabilityAcknowledged() async =>
      (await _p()).getBool(_kAlertReliabilityAcknowledged) ?? false;

  // ---- SAFETY / COMPLIANCE ----
  static Future<void> saveSafetyStateJson(String json) async =>
      (await _p()).setString(_kSafetyStateJson, json);

  static Future<String?> getSafetyStateJson() async =>
      (await _p()).getString(_kSafetyStateJson);

  /// Pro: safety state per vessel. [vesselId] null/empty = default (same as getSafetyStateJson).
  /// Key format: safety.vessel.<id> per spec.
  static String _safetyKey(String? vesselId) =>
      vesselId != null && vesselId.isNotEmpty
          ? 'safety.vessel.$vesselId'
          : _kSafetyStateJson;

  static Future<void> saveSafetyStateJsonForVessel(String? vesselId, String json) async =>
      (await _p()).setString(_safetyKey(vesselId), json);

  static Future<String?> getSafetyStateJsonForVessel(String? vesselId) async =>
      (await _p()).getString(_safetyKey(vesselId));
}
