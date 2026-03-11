import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/ramp_location_data.dart';
import '../models/ramp_location.dart';

class RampStorageService {
  static const String _key = "admin_ramps";

  /// Load ramps from storage. If none saved, fall back to default ramps.
  static Future<List<RampLocation>> loadAllRamps() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw == null) {
      return List<RampLocation>.from(defaultRamps);
    }

    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => RampLocation.fromMap(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Save the full list of ramps (overwrites previous).
  static Future<void> _saveAll(List<RampLocation> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(list.map((r) => r.toMap()).toList());
    await prefs.setString(_key, encoded);
  }

  /// Insert or update a ramp by ID.
  static Future<void> upsertRamp(RampLocation ramp) async {
    final list = await loadAllRamps();
    final index = list.indexWhere((r) => r.id == ramp.id);

    if (index >= 0) {
      list[index] = ramp;
    } else {
      list.add(ramp);
    }

    await _saveAll(list);
  }

  /// Delete a ramp.
  static Future<void> deleteRamp(RampLocation ramp) async {
    final list = await loadAllRamps();
    list.removeWhere((r) => r.id == ramp.id);
    await _saveAll(list);
  }

  /// Alias for loadAllRamps (used by RampManagerScreen).
  static Future<List<RampLocation>> loadRamps() async => loadAllRamps();

  /// Save the full list of ramps (overwrites previous). Used by RampManagerScreen.
  static Future<void> saveRamps(List<RampLocation> list) async => _saveAll(list);
}
