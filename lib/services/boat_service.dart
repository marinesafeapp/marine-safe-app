import 'package:shared_preferences/shared_preferences.dart';

class BoatService {
  static const _photoKey = "boat_photo_path";

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
}
