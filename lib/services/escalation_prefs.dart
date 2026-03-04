import 'package:shared_preferences/shared_preferences.dart';

/// Persisted escalation state so it survives app kill/reboot.
/// Used by TripEscalationService; no Dart timers for critical scheduling.
class EscalationPrefs {
  static const _kStage = 'escalation.stage';
  static const _kLastFiredDueAt = 'escalation.lastFiredDueAt';
  static const _kLastFiredOverdueAt = 'escalation.lastFiredOverdueAt';
  static const _kLastFiredEscalatingAt = 'escalation.lastFiredEscalatingAt';

  static Future<SharedPreferences> _p() => SharedPreferences.getInstance();

  /// Current escalation stage: none | due | overdue | escalating
  static Future<void> setStage(String stage) async =>
      (await _p()).setString(_kStage, stage);

  static Future<String> getStage() async =>
      (await _p()).getString(_kStage) ?? 'none';

  /// Last time a DUE notification was fired (ISO string; for debugging/audit)
  static Future<void> setLastFiredDueAt(String? iso) async {
    final p = await _p();
    if (iso == null) {
      await p.remove(_kLastFiredDueAt);
    } else {
      await p.setString(_kLastFiredDueAt, iso);
    }
  }

  static Future<String?> getLastFiredDueAt() async =>
      (await _p()).getString(_kLastFiredDueAt);

  static Future<void> setLastFiredOverdueAt(String? iso) async {
    final p = await _p();
    if (iso == null) {
      await p.remove(_kLastFiredOverdueAt);
    } else {
      await p.setString(_kLastFiredOverdueAt, iso);
    }
  }

  static Future<String?> getLastFiredOverdueAt() async =>
      (await _p()).getString(_kLastFiredOverdueAt);

  static Future<void> setLastFiredEscalatingAt(String? iso) async {
    final p = await _p();
    if (iso == null) {
      await p.remove(_kLastFiredEscalatingAt);
    } else {
      await p.setString(_kLastFiredEscalatingAt, iso);
    }
  }

  static Future<String?> getLastFiredEscalatingAt() async =>
      (await _p()).getString(_kLastFiredEscalatingAt);

  /// Clear all escalation state (e.g. when trip ends or acknowledged)
  static Future<void> clear() async {
    final p = await _p();
    await p.remove(_kStage);
    await p.remove(_kLastFiredDueAt);
    await p.remove(_kLastFiredOverdueAt);
    await p.remove(_kLastFiredEscalatingAt);
  }
}
