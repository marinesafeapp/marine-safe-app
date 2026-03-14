import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BoatService {
  static const _photoKey = "boat_photo_path";
  static const _photoListKey = "boat_photo_paths";

  /// Single photo (legacy / free): one boat picture.
  static Future<void> saveBoatPhotoPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_photoKey);
      return;
    }
    await prefs.setString(_photoKey, path);
  }

  static Future<String?> getBoatPhotoPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_photoKey);
  }

  /// Multiple photos (Pro): list of paths. Empty list = none.
  static Future<void> saveBoatPhotoPaths(List<String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    if (paths.isEmpty) {
      await prefs.remove(_photoListKey);
      await prefs.remove(_photoKey);
      return;
    }
    await prefs.setString(_photoListKey, jsonEncode(paths));
    await prefs.setString(_photoKey, paths.first);
  }

  /// Returns saved boat photo paths. Pro can have multiple; free uses first only.
  static Future<List<String>> getBoatPhotoPaths() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_photoListKey);
    if (json != null) {
      try {
        final list = jsonDecode(json) as List<dynamic>;
        return list.map((e) => e.toString()).where((p) => p.isNotEmpty).toList();
      } catch (_) {}
    }
    final single = prefs.getString(_photoKey);
    if (single != null && single.isNotEmpty) return [single];
    return [];
  }

  /// Max photos for Pro; free = 1.
  static const int maxPhotosFree = 1;
  static const int maxPhotosPro = 10;
}
