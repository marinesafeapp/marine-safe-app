import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'trip_prefs.dart';

class ComplianceIssue {
  final String title;
  final String detail;
  final bool critical;

  const ComplianceIssue({
    required this.title,
    required this.detail,
    required this.critical,
  });
}

class ComplianceService {
  static const _kBoatRego = 'profile.boatRego';
  // Fallback: old Profile keys (Safety Equipment now uses TripPrefs safety.state.json)
  static const _kPfdCount = 'profile.pfds.count';
  static const _kPfdsJson = 'profile.pfds.json';

  static const int _dueSoonDays = 30;

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _fmt(DateTime dt) => "${_two(dt.day)}/${_two(dt.month)}/${dt.year}";

  /// [vesselId] when Pro and a vessel is selected; [boatRegoOverride] when Pro use selected vessel's rego.
  static Future<List<ComplianceIssue>> check({
    required int personsOnBoard,
    String? vesselId,
    String? boatRegoOverride,
  }) async {
    final p = await SharedPreferences.getInstance();
    final issues = <ComplianceIssue>[];

    // 1) Boat rego required (from profile or selected vessel when Pro)
    final boatRego = (boatRegoOverride ?? p.getString(_kBoatRego) ?? '').trim();
    if (boatRego.isEmpty) {
      issues.add(const ComplianceIssue(
        title: "Boat rego missing",
        detail: "Add your boat registration in Boat details (Gear tab) before starting a trip.",
        critical: true,
      ));
    }

    // 2) Safety equipment from TripPrefs (per vessel when Pro)
    final safetyJson = await TripPrefs.getSafetyStateJsonForVessel(vesselId);
    int pfdCount = 0;
    _PfdDateStatus? jacketDateStatus;
    if (safetyJson != null && safetyJson.trim().isNotEmpty) {
      try {
        final state = jsonDecode(safetyJson) as Map<String, dynamic>?;
        if (state != null) {
          // PFD count and inspection dates from safety state
          if (state['pfds'] is List) {
            final pfds = state['pfds'] as List;
            pfdCount = pfds.length;
            jacketDateStatus = _checkPfdDatesFromSafetyState(pfds);
          }
          // EPIRB, flares, extinguisher expiry
          final epirbExpiry = _parseIso(state['epirbExpiry']?.toString());
          final flaresExpiry = _parseIso(state['flaresExpiry']?.toString());
          final extinguisherExpiry = _parseIso(state['extinguisherExpiry']?.toString());

          _addExpiryIssues(issues, 'EPIRB battery', epirbExpiry);
          _addExpiryIssues(issues, 'Flares', flaresExpiry);
          _addExpiryIssues(issues, 'Fire extinguisher', extinguisherExpiry);
        }
      } catch (_) {
        // Fall through to profile fallback
      }
    }

    // Fallback: no safety state – use old profile PFD keys
    if (pfdCount == 0 && jacketDateStatus == null) {
      pfdCount = p.getInt(_kPfdCount) ?? 0;
      jacketDateStatus = await _checkPfdDatesFromProfile(p);
    }

    // 3) Life jacket count vs persons on board
    if (pfdCount <= 0) {
      issues.add(const ComplianceIssue(
        title: "No life jackets recorded",
        detail: "Add life jackets in Gear → Safety equipment before starting a trip.",
        critical: true,
      ));
    } else if (personsOnBoard > 0 && personsOnBoard > pfdCount) {
      issues.add(ComplianceIssue(
        title: "Not enough life jackets",
        detail:
        "People on board: $personsOnBoard\n"
            "Life jackets in Gear: $pfdCount\n\n"
            "Add more life jackets or reduce people on board.",
        critical: true,
      ));
    }

    // 4) PFD inspection dates (expired / due soon / missing)
    if (jacketDateStatus != null) {
      final missing = jacketDateStatus.missingCount;
      final dueSoon = jacketDateStatus.dueSoonCount;
      final expired = jacketDateStatus.expiredCount;

      if (expired > 0) {
        issues.add(ComplianceIssue(
          title: "Life jacket inspection OVERDUE",
          detail:
          "$expired life jacket${expired == 1 ? '' : 's'} have an inspection due date in the past.\n"
              "${jacketDateStatus.expiredLabels.isNotEmpty ? "Overdue: ${jacketDateStatus.expiredLabels.join(', ')}\n" : ""}"
              "Update the date(s) in Gear → Safety equipment.",
          critical: true,
        ));
      }

      if (dueSoon > 0) {
        issues.add(ComplianceIssue(
          title: "Life jacket inspection due soon",
          detail:
          "$dueSoon life jacket${dueSoon == 1 ? '' : 's'} are due within $_dueSoonDays days.\n"
              "${jacketDateStatus.dueSoonLabels.isNotEmpty ? "Due soon: ${jacketDateStatus.dueSoonLabels.join(', ')}\n" : ""}"
              "Consider servicing before your next trip.",
          critical: false,
        ));
      }

      if (missing > 0) {
        issues.add(ComplianceIssue(
          title: "Life jacket dates missing",
          detail:
          "$missing life jacket${missing == 1 ? '' : 's'} have no inspection due date set.\n"
              "${jacketDateStatus.missingLabels.isNotEmpty ? "Missing: ${jacketDateStatus.missingLabels.join(', ')}\n" : ""}"
              "Add dates in Gear → Safety equipment so Marine Safe can warn you.",
          critical: false,
        ));
      }
    }

    return issues;
  }

  static DateTime? _parseIso(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    return DateTime.tryParse(s.trim());
  }

  static void _addExpiryIssues(List<ComplianceIssue> issues, String label, DateTime? expiry) {
    if (expiry == null) return;
    final now = DateTime.now();
    final dateOnly = DateTime(expiry.year, expiry.month, expiry.day);
    final todayOnly = DateTime(now.year, now.month, now.day);
    final dueSoonCutoff = todayOnly.add(const Duration(days: _dueSoonDays));

    if (dateOnly.isBefore(todayOnly)) {
      issues.add(ComplianceIssue(
        title: "$label EXPIRED",
        detail: "$label expiry date (${_fmt(dateOnly)}) is in the past. Update in Gear → Safety equipment.",
        critical: true,
      ));
    } else if (!dateOnly.isAfter(dueSoonCutoff)) {
      issues.add(ComplianceIssue(
        title: "$label due soon",
        detail: "$label expires on ${_fmt(dateOnly)} (within $_dueSoonDays days). Consider renewing.",
        critical: false,
      ));
    }
  }

  /// PFD dates from TripPrefs safety.state.json (pfds[].inspectionDue).
  static _PfdDateStatus _checkPfdDatesFromSafetyState(List<dynamic> pfds) {
    final now = DateTime.now();
    final dueSoonCutoff = now.add(const Duration(days: _dueSoonDays));

    int missing = 0, dueSoon = 0, expired = 0;
    final missingLabels = <String>[];
    final dueSoonLabels = <String>[];
    final expiredLabels = <String>[];

    for (int i = 0; i < pfds.length; i++) {
      final item = pfds[i];
      if (item is! Map) continue;
      final label = "Jacket ${i + 1}";
      final iso = (item['inspectionDue'] as dynamic)?.toString();
      if (iso == null || iso.trim().isEmpty) {
        missing++;
        missingLabels.add(label);
        continue;
      }
      final dt = DateTime.tryParse(iso.trim());
      if (dt == null) {
        missing++;
        missingLabels.add(label);
        continue;
      }
      final dateOnly = DateTime(dt.year, dt.month, dt.day);
      final todayOnly = DateTime(now.year, now.month, now.day);
      final cutoffOnly = DateTime(dueSoonCutoff.year, dueSoonCutoff.month, dueSoonCutoff.day);

      if (dateOnly.isBefore(todayOnly)) {
        expired++;
        expiredLabels.add("$label (${_fmt(dateOnly)})");
      } else if (!dateOnly.isAfter(cutoffOnly)) {
        dueSoon++;
        dueSoonLabels.add("$label (${_fmt(dateOnly)})");
      }
    }

    return _PfdDateStatus(
      missingCount: missing,
      dueSoonCount: dueSoon,
      expiredCount: expired,
      missingLabels: missingLabels,
      dueSoonLabels: dueSoonLabels,
      expiredLabels: expiredLabels,
    );
  }

  /// PFD dates from old profile.pfds.json (serviceDue).
  static Future<_PfdDateStatus> _checkPfdDatesFromProfile(SharedPreferences p) async {
    final jsonStr = p.getString(_kPfdsJson);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return const _PfdDateStatus();
    }

    try {
      final raw = jsonDecode(jsonStr);
      if (raw is! List) return const _PfdDateStatus();

      final now = DateTime.now();
      final dueSoonCutoff = now.add(const Duration(days: _dueSoonDays));

      int missing = 0;
      int dueSoon = 0;
      int expired = 0;

      final missingLabels = <String>[];
      final dueSoonLabels = <String>[];
      final expiredLabels = <String>[];

      int index = 0;

      for (final item in raw) {
        index++;
        if (item is! Map) continue;

        final label = (item['label'] as String?)?.trim().isNotEmpty == true
            ? (item['label'] as String).trim()
            : "Jacket $index";

        final sd = item['serviceDue'];

        if (sd is! String || sd.trim().isEmpty) {
          missing++;
          missingLabels.add(label);
          continue;
        }

        final dt = DateTime.tryParse(sd.trim());
        if (dt == null) {
          missing++;
          missingLabels.add(label);
          continue;
        }

        final dateOnly = DateTime(dt.year, dt.month, dt.day);
        final todayOnly = DateTime(now.year, now.month, now.day);
        final cutoffOnly = DateTime(dueSoonCutoff.year, dueSoonCutoff.month, dueSoonCutoff.day);

        if (dateOnly.isBefore(todayOnly)) {
          expired++;
          expiredLabels.add("$label (${_fmt(dateOnly)})");
        } else if (!dateOnly.isAfter(cutoffOnly)) {
          dueSoon++;
          dueSoonLabels.add("$label (${_fmt(dateOnly)})");
        }
      }

      return _PfdDateStatus(
        missingCount: missing,
        dueSoonCount: dueSoon,
        expiredCount: expired,
        missingLabels: missingLabels,
        dueSoonLabels: dueSoonLabels,
        expiredLabels: expiredLabels,
      );
    } catch (_) {
      return const _PfdDateStatus();
    }
  }
}

class _PfdDateStatus {
  final int missingCount;
  final int dueSoonCount;
  final int expiredCount;

  final List<String> missingLabels;
  final List<String> dueSoonLabels;
  final List<String> expiredLabels;

  const _PfdDateStatus({
    this.missingCount = 0,
    this.dueSoonCount = 0,
    this.expiredCount = 0,
    this.missingLabels = const [],
    this.dueSoonLabels = const [],
    this.expiredLabels = const [],
  });
}
