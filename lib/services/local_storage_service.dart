import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _tripHistoryKey = "trip_history";

  /// Load saved trip history as a List<Map>
  static Future<List<Map<String, dynamic>>> loadTripHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tripHistoryKey);

    if (raw == null) return [];

    try {
      final List decoded = jsonDecode(raw);
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Save List<Map> trip history to storage
  static Future<void> saveTripHistory(
      List<Map<String, dynamic>> history) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(history);
    await prefs.setString(_tripHistoryKey, encoded);
  }

  /// Optional: clear history
  static Future<void> clearTripHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tripHistoryKey);
  }
}
