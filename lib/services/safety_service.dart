import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/safety_item.dart';

class SafetyService {
  static const key = "safety_items";

  static Future<List<SafetyItem>> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(key);

    if (jsonString == null) return [];

    final List decoded = jsonDecode(jsonString);
    return decoded.map((e) => SafetyItem.fromJson(e)).toList();
  }

  static Future<void> saveItems(List<SafetyItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString =
        jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(key, jsonString);
  }
}
