import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/vessel.dart';

/// Pro-only: list of vessels. Free users use single boat in profile (profile.boatName etc.).
class VesselsService {
  VesselsService._();
  static final VesselsService instance = VesselsService._();

  static const String _kVesselsJson = 'pro.vessels';
  static const String _kSelectedVesselId = 'pro.selectedVesselId';

  Future<SharedPreferences> _p() => SharedPreferences.getInstance();

  /// Load vessels from persistence (spec: loadVessels).
  Future<List<Vessel>> loadVessels() async => getVessels();

  Future<List<Vessel>> getVessels() async {
    final p = await _p();
    final jsonStr = p.getString(_kVesselsJson);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>?;
      if (list == null) return [];
      return list
          .map((e) => Vessel.fromJson(e as Map<String, dynamic>))
          .where((v) => v.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveVessels(List<Vessel> vessels) async {
    final p = await _p();
    final list = vessels.map((v) => v.toJson()).toList();
    await p.setString(_kVesselsJson, jsonEncode(list));
  }

  /// Save vessels list to persistence (spec: saveVesselsJson).
  Future<void> saveVesselsJson(List<Vessel> vessels) async => _saveVessels(vessels);

  Future<String?> getSelectedVesselId() async {
    final p = await _p();
    final id = (p.getString(_kSelectedVesselId) ?? '').trim();
    return id.isEmpty ? null : id;
  }

  Future<void> setSelectedVesselId(String? id) async {
    final p = await _p();
    if (id == null || id.isEmpty) {
      await p.remove(_kSelectedVesselId);
    } else {
      await p.setString(_kSelectedVesselId, id);
    }
  }

  Future<void> addVessel(Vessel vessel) async {
    final list = await getVessels();
    if (list.any((v) => v.id == vessel.id)) return;
    final now = DateTime.now();
    final v = vessel.createdAt == null
        ? vessel.copyWith(createdAt: now, updatedAt: now)
        : vessel;
    list.add(v);
    await _saveVessels(list);
  }

  Future<void> updateVessel(Vessel vessel) async {
    final list = await getVessels();
    final i = list.indexWhere((v) => v.id == vessel.id);
    if (i < 0) return;
    list[i] = vessel.copyWith(updatedAt: DateTime.now());
    await _saveVessels(list);
  }

  Future<void> deleteVessel(String id) async {
    final list = await getVessels();
    list.removeWhere((v) => v.id == id);
    await _saveVessels(list);
    final selected = await getSelectedVesselId();
    if (selected == id) await setSelectedVesselId(list.isNotEmpty ? list.first.id : null);
  }

  static String generateId() => 'v_${DateTime.now().millisecondsSinceEpoch}';
}
