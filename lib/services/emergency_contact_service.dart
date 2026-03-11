import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact.dart';

class EmergencyContactService {
  static const String key = "emergency_contacts";

  static Future<List<EmergencyContact>> loadContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(key);
      if (jsonString == null || jsonString.isEmpty) return [];

      final decoded = jsonDecode(jsonString);
      if (decoded is! List) return [];

      final list = <EmergencyContact>[];
      for (final e in decoded) {
        if (e is! Map<String, dynamic>) continue;
        try {
          list.add(EmergencyContact.fromJson(e));
        } catch (_) {
          // Skip malformed entry
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveContacts(List<EmergencyContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(contacts.map((c) => c.toJson()).toList());
    await prefs.setString(key, jsonString);
  }
}
