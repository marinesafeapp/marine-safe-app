import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'expiry_notification_service.dart';
import '../screens/home/services/trip_prefs.dart';

/// Schedules 14-day and 30-day expiry warnings for boat, trailer, and safety equipment.
/// Notification IDs 6000-6099 (do not overlap with trip notifications).
class ExpiryNotificationScheduler {
  ExpiryNotificationScheduler._();
  static final ExpiryNotificationScheduler instance = ExpiryNotificationScheduler._();

  static const int _idBase = 6000;
  static const int _idBoat30 = 6000;
  static const int _idBoat14 = 6001;
  static const int _idTrailer30 = 6002;
  static const int _idTrailer14 = 6003;
  static const int _idEpirb30 = 6004;
  static const int _idEpirb14 = 6005;
  static const int _idFlares30 = 6006;
  static const int _idFlares14 = 6007;
  static const int _idExtinguisher30 = 6008;
  static const int _idExtinguisher14 = 6009;
  static const int _idPfdBase = 6010; // 6010+2*i = PFD i 30d, 6010+2*i+1 = PFD i 14d
  static const int _idMax = 6099;

  static const String _kBoatRegoExpiry = 'profile.boatRegoExpiry';
  static const String _kTrailerRegoExpiry = 'profile.trailerRegoExpiry';

  bool _tzInitialized = false;

  Future<void> _ensureInit() async {
    if (kIsWeb) return;
    if (!_tzInitialized) {
      tz_data.initializeTimeZones();
      _tzInitialized = true;
    }
    await ExpiryNotificationService.instance.init();
  }

  String _fmtDate(DateTime d) {
    final local = d.toLocal();
    return "${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}";
  }

  /// Schedule at 9:00 local on the given date.
  DateTime _at9am(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day, 9, 0);
  }

  Future<void> _scheduleOne({
    required String label,
    required DateTime? expiryDate,
    required int id30,
    required int id14,
  }) async {
    if (expiryDate == null) return;
    final expiryDay = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final now = DateTime.now();
    final when30 = _at9am(expiryDay.subtract(const Duration(days: 30)));
    final when14 = _at9am(expiryDay.subtract(const Duration(days: 14)));
    final dateStr = _fmtDate(expiryDate);

    if (when30.isAfter(now)) {
      await ExpiryNotificationService.instance.schedule(
        id30,
        'Marine Safe: Expiry reminder',
        '$label expires in 30 days ($dateStr)',
        when30,
      );
    }
    if (when14.isAfter(now)) {
      await ExpiryNotificationService.instance.schedule(
        id14,
        'Marine Safe: Expiry reminder',
        '$label expires in 14 days ($dateStr)',
        when14,
      );
    }
  }

  /// Cancel all expiry notification IDs we use.
  Future<void> _cancelAllExpiry() async {
    final ids = List.generate(_idMax - _idBase + 1, (i) => _idBase + i);
    await ExpiryNotificationService.instance.cancelIds(ids);
  }

  /// Read all expiry dates from storage and schedule 14-day + 30-day warnings.
  /// Call after saving Boat Details or Safety Equipment, and on app startup.
  Future<void> scheduleAllExpiryNotifications() async {
    if (kIsWeb) return;
    try {
      await _ensureInit();
      await _cancelAllExpiry();

      final p = await SharedPreferences.getInstance();
      final boatExpiry = _parseIso(p.getString(_kBoatRegoExpiry));
      final trailerExpiry = _parseIso(p.getString(_kTrailerRegoExpiry));

      await _scheduleOne(label: 'Boat rego', expiryDate: boatExpiry, id30: _idBoat30, id14: _idBoat14);
      await _scheduleOne(label: 'Trailer rego', expiryDate: trailerExpiry, id30: _idTrailer30, id14: _idTrailer14);

      DateTime? epirbExpiry;
      DateTime? flaresExpiry;
      DateTime? extinguisherExpiry;
      List<DateTime?> pfdInspectionDue = [];

      final safetyJson = await TripPrefs.getSafetyStateJson();
      if (safetyJson != null && safetyJson.trim().isNotEmpty) {
        try {
          final state = jsonDecode(safetyJson) as Map<String, dynamic>?;
          if (state != null) {
            epirbExpiry = _parseIso(state['epirbExpiry']?.toString());
            flaresExpiry = _parseIso(state['flaresExpiry']?.toString());
            extinguisherExpiry = _parseIso(state['extinguisherExpiry']?.toString());
            if (state['pfds'] is List) {
              for (final e in state['pfds'] as List) {
                if (e is Map) {
                  final iso = (e['inspectionDue'] as dynamic)?.toString();
                  pfdInspectionDue.add(_parseIso(iso));
                }
              }
            }
          }
        } catch (_) {}
      }

      await _scheduleOne(label: 'EPIRB battery', expiryDate: epirbExpiry, id30: _idEpirb30, id14: _idEpirb14);
      await _scheduleOne(label: 'Flares', expiryDate: flaresExpiry, id30: _idFlares30, id14: _idFlares14);
      await _scheduleOne(label: 'Fire extinguisher', expiryDate: extinguisherExpiry, id30: _idExtinguisher30, id14: _idExtinguisher14);

      for (int i = 0; i < pfdInspectionDue.length && (_idPfdBase + 2 * i + 1) <= _idMax; i++) {
        final due = pfdInspectionDue[i];
        final id30 = _idPfdBase + 2 * i;
        final id14 = _idPfdBase + 2 * i + 1;
        await _scheduleOne(label: 'Life jacket ${i + 1} inspection', expiryDate: due, id30: id30, id14: id14);
      }
    } catch (_) {
      // Ignore (permissions, unsupported platform, etc.)
    }
  }

  static DateTime? _parseIso(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    return DateTime.tryParse(s);
  }
}
