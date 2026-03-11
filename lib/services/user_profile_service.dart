import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class UserProfileService {
  UserProfileService._();
  static final UserProfileService instance = UserProfileService._();

  static const String _kUserName = 'profile.userName';
  // ProfileScreen/RegisterScreen use this key
  static const String _kProfileName = 'profile.name';
  static const String _kPostcode = 'profile.postcode';
  static const String _kPostcodeLat = 'profile.postcode.lat';
  static const String _kPostcodeLon = 'profile.postcode.lon';
  static const String _kIsPro = 'profile.isPro';

  Future<SharedPreferences> _p() => SharedPreferences.getInstance();

  // ---------------------------
  // PRO
  // ---------------------------

  /// True if user has Pro (multiple vessels, invite crew). For now stored in prefs; later can sync with Firestore / in-app purchase.
  Future<bool> getIsPro() async {
    final p = await _p();
    return p.getBool(_kIsPro) ?? false;
  }

  Future<void> setPro(bool value) async {
    final p = await _p();
    await p.setBool(_kIsPro, value);
  }

  // ---------------------------
  // POSTCODE
  // ---------------------------

  /// Returns the saved postcode (e.g. "4740") or null if not set.
  Future<String?> getPostcode() async {
    final p = await _p();
    final s = (p.getString(_kPostcode) ?? '').trim();
    return s.isEmpty ? null : s;
  }

  /// Saves postcode. Clears cached lat/lon so next getPostcodeLatLon() will geocode.
  /// Also clears weather screen location cache so Forecast refreshes with the new postcode.
  Future<void> setPostcode(String postcode) async {
    final clean = postcode.trim();
    final p = await _p();
    await p.setString(_kPostcode, clean);
    await clearPostcodeLatLonCache();
    await _clearWeatherLocationCache(p);
  }

  /// Clears cached location used by Forecast so it re-resolves (postcode or GPS) next time.
  static Future<void> _clearWeatherLocationCache(SharedPreferences p) async {
    await p.remove('weather.lastLat');
    await p.remove('weather.lastLon');
    await p.remove('weather.lastFixMs');
  }

  /// Clears cached lat/lon so next getPostcodeLatLon() will geocode/fallback for current postcode.
  /// Call when postcode may have changed so the ramp list uses fresh coords.
  Future<void> clearPostcodeLatLonCache() async {
    final p = await _p();
    await p.remove(_kPostcodeLat);
    await p.remove(_kPostcodeLon);
  }

  /// Fallback (lat, lon) for common Australian postcodes when Nominatim fails.
  static const Map<String, ({double lat, double lon})> _postcodeFallbacks = {
    '3000': (lat: -37.8136, lon: 144.9631), // Melbourne CBD
    '3001': (lat: -37.8136, lon: 144.9631),
    '3002': (lat: -37.8180, lon: 144.9700),
    '3004': (lat: -37.8380, lon: 144.9580), // Melbourne
    '3006': (lat: -37.8380, lon: 144.9580),
    '2000': (lat: -33.8688, lon: 151.2093), // Sydney CBD
    '4000': (lat: -27.4698, lon: 153.0251), // Brisbane CBD
    '5000': (lat: -34.9285, lon: 138.6007), // Adelaide CBD
    '6000': (lat: -31.9505, lon: 115.8605), // Perth CBD
    '7000': (lat: -42.8821, lon: 147.3272), // Hobart
    '0800': (lat: -12.4634, lon: 130.8456), // Darwin
    '4740': (lat: -21.1395, lon: 149.1891), // Mackay
    '3195': (lat: -37.9520, lon: 145.0080), // Sandringham
    '3186': (lat: -37.9080, lon: 144.9880), // Brighton
    '3207': (lat: -37.8680, lon: 144.8280), // Altona
  };

  /// Returns (lat, lon) for the user's postcode: from cache or by geocoding (Australia) and caching.
  /// Uses fallback coords for common postcodes when geocode fails. Returns null if no postcode.
  Future<({double lat, double lon})?> getPostcodeLatLon() async {
    final postcode = await getPostcode();
    if (postcode == null || postcode.isEmpty) return null;

    final p = await _p();
    final latStr = p.getString(_kPostcodeLat);
    final lonStr = p.getString(_kPostcodeLon);
    if (latStr != null && lonStr != null) {
      final lat = double.tryParse(latStr);
      final lon = double.tryParse(lonStr);
      if (lat != null && lon != null) return (lat: lat, lon: lon);
    }

    // Fallback for common postcodes when API fails
    final fallback = _postcodeFallbacks[postcode];
    if (fallback != null) {
      await p.setString(_kPostcodeLat, fallback.lat.toString());
      await p.setString(_kPostcodeLon, fallback.lon.toString());
      return fallback;
    }

    try {
      // Nominatim: use countrycodes=au (ISO 3166-1 alpha-2) for Australian postcodes
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?postalcode=$postcode&countrycodes=au&format=json&limit=1',
      );
      final resp = await http.get(
        uri,
        headers: {'User-Agent': 'MarineSafeApp/1.0 (marine safety)'},
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;

      var list = jsonDecode(resp.body) as List<dynamic>?;
      // Fallback: try free-form query if structured search returns nothing
      if (list == null || list.isEmpty) {
        final fallbackUri = Uri.parse(
          'https://nominatim.openstreetmap.org/search'
          '?q=$postcode+Australia&format=json&limit=1&countrycodes=au',
        );
        final fallbackResp = await http.get(
          fallbackUri,
          headers: {'User-Agent': 'MarineSafeApp/1.0 (marine safety)'},
        ).timeout(const Duration(seconds: 10));
        if (fallbackResp.statusCode != 200) return null;
        list = jsonDecode(fallbackResp.body) as List<dynamic>?;
      }
      if (list == null || list.isEmpty) return null;

      final first = list.first as Map<String, dynamic>?;
      if (first == null) return null;

      final lat = double.tryParse((first['lat'] ?? '').toString());
      final lon = double.tryParse((first['lon'] ?? '').toString());
      if (lat == null || lon == null) return null;
      // Australia roughly: lat -10 to -44, lon 113 to 154
      if (lat > -10 || lat < -44.5 || lon < 112 || lon > 155) return null;

      await p.setString(_kPostcodeLat, lat.toString());
      await p.setString(_kPostcodeLon, lon.toString());
      return (lat: lat, lon: lon);
    } catch (_) {
      return null;
    }
  }

  /// Returns the saved name if present.
  /// If not saved but Firebase displayName exists, it copies it into prefs.
  Future<String?> getUserName() async {
    final p = await _p();
    final fromPrefs = (p.getString(_kUserName) ?? '').trim();
    if (fromPrefs.isNotEmpty) return fromPrefs;

    // Fallback: full profile name (entered in Register/My Profile screens)
    final fromProfile = (p.getString(_kProfileName) ?? '').trim();
    if (fromProfile.isNotEmpty) {
      await p.setString(_kUserName, fromProfile);
      return fromProfile;
    }

    final u = FirebaseAuth.instance.currentUser;
    final dn = (u?.displayName ?? '').trim();
    if (dn.isNotEmpty) {
      await p.setString(_kUserName, dn);
      return dn;
    }

    return null;
  }

  /// Saves locally AND updates FirebaseAuth displayName (if signed in).
  Future<void> setUserName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;

    final p = await _p();
    await p.setString(_kUserName, clean);
    // Keep profile.name in sync as the "main" profile name
    await p.setString(_kProfileName, clean);

    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      try {
        await u.updateDisplayName(clean);
        await u.reload();
      } catch (_) {
        // If updateDisplayName fails (rare), we still keep local name.
      }
    }
  }

  /// Hard requirement: keep asking until a valid name is saved.
  Future<String> ensureUserName(BuildContext context) async {
    // If already have it, done.
    final existing = await getUserName();
    if (!context.mounted) return '';
    if (existing != null && existing.trim().isNotEmpty) return existing.trim();

    String value = '';

    while (true) {
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return AlertDialog(
            title: const Text(
              "Enter your name",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            content: TextField(
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: "e.g. Chrisso",
              ),
              onChanged: (v) => value = v,
              onSubmitted: (_) => Navigator.pop(context, value),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context, value),
                child: const Text("SAVE"),
              ),
            ],
          );
        },
      );
      if (!context.mounted) return value;

      final candidate = (result ?? value).trim();
      if (candidate.length >= 2) {
        await setUserName(candidate);
        return candidate;
      }

      // If user entered something too short, loop again.
      value = '';
    }
  }
}
