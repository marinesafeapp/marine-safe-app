import 'package:shared_preferences/shared_preferences.dart';

/// Stores favourite ramp IDs locally (device-only) using SharedPreferences.
///
/// v1: favourites are NOT synced across devices (we can add Firebase later).
class FavouriteRampsService {
  static const String _key = 'ramps.favourites';

  Future<List<String>> getIds() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_key) ?? <String>[]).where((e) => e.trim().isNotEmpty).toList();
  }

  Future<void> setIds(List<String> ids) async {
    final p = await SharedPreferences.getInstance();
    // de-dupe while preserving order
    final seen = <String>{};
    final clean = <String>[];
    for (final id in ids) {
      final v = id.trim();
      if (v.isEmpty) continue;
      if (seen.add(v)) clean.add(v);
    }
    await p.setStringList(_key, clean);
  }

  Future<bool> isFavourite(String rampId) async {
    final ids = await getIds();
    return ids.contains(rampId);
  }

  Future<List<String>> toggle(String rampId) async {
    final ids = await getIds();
    if (ids.contains(rampId)) {
      ids.removeWhere((x) => x == rampId);
    } else {
      ids.insert(0, rampId); // newest favourites at the top
    }
    await setIds(ids);
    return ids;
  }
}
