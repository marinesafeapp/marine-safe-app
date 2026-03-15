import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/user_profile_service.dart';
import 'tides_screen.dart';

enum ForecastCategory {
  weather,
  rainfall,
  wind,
  sun,
  uv,
  tides,
  swell,
  weekly,
}

class WeatherScreen extends StatefulWidget {
  /// When true, this tab is visible; used to refresh forecast when user switches to tab (e.g. after postcode change).
  final bool visible;

  const WeatherScreen({super.key, this.visible = true});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  bool loading = true;
  String? error;

  // Location used for forecast
  String _locationLabel = 'Near you';
  String _locationSource = 'GPS';

  static const String _kLastLat = 'weather.lastLat';
  static const String _kLastLon = 'weather.lastLon';
  static const String _kLastFixMs = 'weather.lastFixMs';

  // Current
  double? temperature;
  double? apparentTemperature;
  double? relativeHumidity;
  double? windSpeed;
  double? windDirection;
  double? windGusts;
  double? visibility;
  int? weatherCode;

  // Hourly (next 24h)
  List<HourlySlot> hourly = [];

  // Daily (next 7 days)
  List<DailySlot> daily = [];

  // Wind chart: 1=24h, 3=72h, 5=120h
  int _windPeriodDays = 1;
  int? _windChartHoverIndex;

  ForecastCategory _selectedCategory = ForecastCategory.weather;

  // Marine (waves, swell, SST) — from Marine API, may be null if unavailable
  double? waveHeight;
  double? swellWaveHeight;
  double? seaSurfaceTemp;

  // Sun & UV (WillyWeather-style)
  double? uvIndex;
  String? sunriseToday;
  String? sunsetToday;

  static const Color _bg = Color(0xFF02050A);
  static const Color _accent = Color(0xFF2CB6FF);
  static const Color _cardBg = Color(0x0DFFFFFF);
  static const Color _surface = Color(0x14FFFFFF);
  static const Color _marineGood = Color(0xFF22C55E);
  static const Color _marineModerate = Color(0xFFEAB308);
  static const Color _marineCaution = Color(0xFFF97316);
  static const Color _marinePoor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    if (widget.visible) _loadWeather();
  }

  @override
  void didUpdateWidget(WeatherScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh when user switches to Forecast tab (e.g. after changing postcode in Profile)
    if (widget.visible && !oldWidget.visible) _loadWeather();
  }

  Future<({double lat, double lon, String label, String source})> _resolveLocation() async {
    // 1) Prefer user's postcode when set (so Forecast updates when postcode changes)
    final postcode = await UserProfileService.instance.getPostcode();
    if (postcode != null && postcode.isNotEmpty) {
      final latLon = await UserProfileService.instance.getPostcodeLatLon();
      if (latLon != null) {
        return (
          lat: latLon.lat,
          lon: latLon.lon,
          label: 'Your postcode ($postcode)',
          source: 'Postcode',
        );
      }
    }

    // 2) Try cached location (avoid repeated prompts / delays)
    try {
      final p = await SharedPreferences.getInstance();
      final lat = p.getDouble(_kLastLat);
      final lon = p.getDouble(_kLastLon);
      final fixMs = p.getInt(_kLastFixMs);
      if (lat != null && lon != null && fixMs != null) {
        final age = DateTime.now().millisecondsSinceEpoch - fixMs;
        // Use cache up to 6 hours old
        if (age < const Duration(hours: 6).inMilliseconds) {
          return (lat: lat, lon: lon, label: 'Near you', source: 'Cached');
        }
      }
    } catch (_) {}

    // 3) Try GPS
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services disabled');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );

      // Cache it
      try {
        final p = await SharedPreferences.getInstance();
        await p.setDouble(_kLastLat, pos.latitude);
        await p.setDouble(_kLastLon, pos.longitude);
        await p.setInt(_kLastFixMs, DateTime.now().millisecondsSinceEpoch);
      } catch (_) {}

      return (lat: pos.latitude, lon: pos.longitude, label: 'Near you', source: 'GPS');
    } catch (_) {
      // 4) Fallback: Mackay (keeps app usable everywhere)
      return (lat: -21.14, lon: 149.18, label: 'Default', source: 'Default');
    }
  }

  Future<void> _loadWeather() async {
    setState(() {
      loading = true;
      error = null;
    });

    final loc = await _resolveLocation();
    final lat = loc.lat;
    final lon = loc.lon;
    _locationLabel = loc.label;
    _locationSource = loc.source;

    try {
      // Weather and marine in parallel; marine may fail for some regions
      final results = await Future.wait([
        http.get(Uri.parse(
          "https://api.open-meteo.com/v1/forecast"
          "?latitude=$lat&longitude=$lon"
          "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,visibility,uv_index"
          "&hourly=temperature_2m,weather_code,precipitation_probability,wind_speed_10m,wind_direction_10m,wind_gusts_10m"
          "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum,sunrise,sunset"
          "&timezone=auto"
          "&forecast_days=8",
        )),
        http.get(Uri.parse(
          "https://marine-api.open-meteo.com/v1/marine"
          "?latitude=$lat&longitude=$lon"
          "&current=wave_height,swell_wave_height,sea_surface_temperature"
          "&timezone=auto"
          "&cell_selection=sea",
        )).catchError((_) => http.Response('{}', 404)),
      ]);

      final res = results[0];
      if (res.statusCode != 200) {
        setState(() {
          error = "Failed to load weather (${res.statusCode})";
          loading = false;
        });
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      final cur = data["current"] as Map<String, dynamic>?;
      final h = data["hourly"] as Map<String, dynamic>?;
      final d = data["daily"] as Map<String, dynamic>?;

      // Marine API response (optional)
      double? waveH;
      double? swellH;
      double? sst;
      if (results[1].statusCode == 200) {
        try {
          final marine = jsonDecode(results[1].body) as Map<String, dynamic>;
          final mCur = marine["current"] as Map<String, dynamic>?;
          if (mCur != null) {
            waveH = _numToDouble(mCur["wave_height"]);
            swellH = _numToDouble(mCur["swell_wave_height"]);
            sst = _numToDouble(mCur["sea_surface_temperature"]);
          }
        } catch (_) {}
      }

      final List<HourlySlot> hourlies = [];
      if (h != null) {
        final times = (h["time"] as List<dynamic>?)?.cast<String>() ?? [];
        final temps = (h["temperature_2m"] as List<dynamic>?)?.cast<num>() ?? [];
        final codes = (h["weather_code"] as List<dynamic>?)?.cast<num>() ?? [];
        final pop = (h["precipitation_probability"] as List<dynamic>?)?.cast<num>() ?? [];
        final wind = (h["wind_speed_10m"] as List<dynamic>?)?.cast<num>() ?? [];
        final windDir = (h["wind_direction_10m"] as List<dynamic>?)?.cast<num>() ?? [];
        final windGusts = (h["wind_gusts_10m"] as List<dynamic>?)?.cast<num>() ?? [];
        final n = times.length;
        for (int i = 0; i < n && i < 120; i++) {
          hourlies.add(HourlySlot(
            time: times[i],
            temperature: temps.isNotEmpty ? temps[i].toDouble() : null,
            weatherCode: codes.isNotEmpty ? codes[i].toInt() : null,
            precipitationProbability: pop.isNotEmpty ? pop[i].toDouble() : null,
            windSpeed: wind.isNotEmpty ? wind[i].toDouble() : null,
            windDirection: windDir.isNotEmpty ? windDir[i].toDouble() : null,
            windGusts: windGusts.isNotEmpty ? windGusts[i].toDouble() : null,
          ));
        }
      }

      final List<DailySlot> dailies = [];
      if (d != null) {
        final times = (d["time"] as List<dynamic>?)?.cast<String>() ?? [];
        final maxT = (d["temperature_2m_max"] as List<dynamic>?)?.cast<num>() ?? [];
        final minT = (d["temperature_2m_min"] as List<dynamic>?)?.cast<num>() ?? [];
        final codes = (d["weather_code"] as List<dynamic>?)?.cast<num>() ?? [];
        final pop = (d["precipitation_probability_max"] as List<dynamic>?)?.cast<num>() ?? [];
        final rain = (d["precipitation_sum"] as List<dynamic>?)?.cast<num>() ?? [];
        final n = times.length;
        for (int i = 0; i < n; i++) {
          dailies.add(DailySlot(
            date: times[i],
            tempMax: maxT.isNotEmpty ? maxT[i].toDouble() : null,
            tempMin: minT.isNotEmpty ? minT[i].toDouble() : null,
            weatherCode: codes.isNotEmpty ? codes[i].toInt() : null,
            precipitationProbability: pop.isNotEmpty ? pop[i].toDouble() : null,
            precipitationSum: rain.isNotEmpty ? rain[i].toDouble() : null,
          ));
        }
      }

      // Sun times from daily[0]
      String? sunriseStr;
      String? sunsetStr;
      if (d != null) {
        final sunrises = (d["sunrise"] as List<dynamic>?)?.cast<String>() ?? [];
        final sunsets = (d["sunset"] as List<dynamic>?)?.cast<String>() ?? [];
        if (sunrises.isNotEmpty) sunriseStr = sunrises[0];
        if (sunsets.isNotEmpty) sunsetStr = sunsets[0];
      }

      setState(() {
        if (cur != null) {
          temperature = _numToDouble(cur["temperature_2m"]);
          apparentTemperature = _numToDouble(cur["apparent_temperature"]);
          relativeHumidity = _numToDouble(cur["relative_humidity_2m"]);
          windSpeed = _numToDouble(cur["wind_speed_10m"]);
          windDirection = _numToDouble(cur["wind_direction_10m"]);
          windGusts = _numToDouble(cur["wind_gusts_10m"]);
          visibility = _numToDouble(cur["visibility"]);
          weatherCode = (cur["weather_code"] as num?)?.toInt();
          uvIndex = _numToDouble(cur["uv_index"]);
        }
        sunriseToday = sunriseStr;
        sunsetToday = sunsetStr;
        waveHeight = waveH;
        swellWaveHeight = swellH;
        seaSurfaceTemp = sst;
        hourly = hourlies;
        daily = dailies;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = "Error loading weather: $e";
        loading = false;
      });
    }
  }

  static double? _numToDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String _windDirectionLabel(double? deg) {
    if (deg == null) return "—";
    return WeatherHelper.windDirectionLabel(deg);
  }

  static String _formatDay(String iso) {
    if (iso.length < 10) return "—";
    final date = DateTime.tryParse(iso);
    if (date == null) return iso.substring(5, 10);
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final today = DateTime.now();
    if (date.day == today.day && date.month == today.month && date.year == today.year) return "Today";
    return days[date.weekday - 1];
  }

  /// Best time to go: scan next 24h for low wind + low rain. Returns (startHour, endHour) or null.
  ({int start, int end})? _bestTimeToGo() {
    if (hourly.isEmpty) return null;
    const maxWindKmh = 25.0;
    const maxRainPct = 30.0;
    int? bestStart;
    int bestLen = 0;
    int runStart = 0;
    int runLen = 0;
    for (int i = 0; i < hourly.length; i++) {
      final w = hourly[i].windSpeed ?? 999;
      final r = hourly[i].precipitationProbability ?? 0;
      final ok = w <= maxWindKmh && r <= maxRainPct;
      if (ok) {
        if (runLen == 0) runStart = i;
        runLen++;
        if (runLen > bestLen) {
          bestLen = runLen;
          bestStart = runStart;
        }
      } else {
        runLen = 0;
      }
    }
    if (bestStart == null || bestLen < 2) return null;
    return (start: bestStart, end: bestStart + bestLen - 1);
  }

  /// km/h to knots (marine standard)
  static double _kmhToKnots(double kmh) => kmh * 0.539957;

  List<HourlySlot> get _windChartSlots {
    final count = _windPeriodDays * 24;
    return hourly.take(count).toList();
  }

  /// Marine conditions: Good / Moderate / Caution / Poor for boating
  /// Considers current weather, wind, visibility, and incoming rain/storms.
  MarineRating _marineRating() {
    final wind = windSpeed ?? 0;
    final gusts = windGusts ?? wind;
    final vis = visibility ?? 10000;
    final code = weatherCode ?? 0;

    // Rain, drizzle, showers, snow, thunderstorms, fog
    final rainOrStorm = (code >= 51 && code <= 82) || code >= 95;
    final fog = code == 45 || code == 48;

    // Incoming bad weather (next 6 hours): high precip chance or storm codes
    bool incomingBad = false;
    for (int i = 0; i < hourly.length && i < 6; i++) {
      final h = hourly[i];
      final pop = h.precipitationProbability ?? 0;
      final hCode = h.weatherCode ?? 0;
      if (pop >= 40 || hCode >= 95 || (hCode >= 51 && hCode <= 82)) {
        incomingBad = true;
        break;
      }
    }

    // Today's forecast: rain or storms expected (caution even if not raining yet)
    bool todayRainOrStorm = false;
    if (daily.isNotEmpty) {
      final d = daily[0];
      final pop = d.precipitationProbability ?? 0;
      final dCode = d.weatherCode ?? 0;
      todayRainOrStorm = pop >= 40 || dCode >= 95 || (dCode >= 51 && dCode <= 82);
    }

    // Poor: currently raining, fog, storms, or very bad wind/vis
    if (rainOrStorm || fog || gusts > 40 || vis < 1000) return MarineRating.poor;
    // Caution: storms/rain coming soon, today's forecast is wet, or marginal wind/vis
    if (incomingBad || todayRainOrStorm || gusts > 30 || wind > 35 || vis < 3000) return MarineRating.caution;
    if (gusts > 20 || wind > 25 || vis < 5000) return MarineRating.moderate;
    return MarineRating.good;
  }

  String _categoryTitle(ForecastCategory c) {
    return switch (c) {
      ForecastCategory.weather => 'Weather',
      ForecastCategory.rainfall => 'Rainfall',
      ForecastCategory.wind => 'Wind',
      ForecastCategory.sun => 'Sun',
      ForecastCategory.uv => 'UV',
      ForecastCategory.tides => 'Tides',
      ForecastCategory.swell => 'Swell',
      ForecastCategory.weekly => '7-day',
    };
  }

  IconData _categoryIcon(ForecastCategory c) {
    return switch (c) {
      ForecastCategory.weather => Icons.wb_cloudy_rounded,
      ForecastCategory.rainfall => Icons.water_drop_rounded,
      ForecastCategory.wind => Icons.air_rounded,
      ForecastCategory.sun => Icons.wb_sunny_rounded,
      ForecastCategory.uv => Icons.light_mode_rounded,
      ForecastCategory.tides => Icons.anchor_rounded,
      ForecastCategory.swell => Icons.waves_rounded,
      ForecastCategory.weekly => Icons.calendar_today_rounded,
    };
  }

  Widget _forecastDrawer(BuildContext context) {
    const menuBg = Color(0xFF0A1628);
    return Drawer(
      backgroundColor: menuBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _categoryTitle(_selectedCategory),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: ForecastCategory.values.map((c) {
                  final selected = _selectedCategory == c;
                  return ListTile(
                    leading: Icon(
                      _categoryIcon(c),
                      color: selected ? _accent : Colors.white70,
                      size: 24,
                    ),
                    title: Text(
                      _categoryTitle(c),
                      style: TextStyle(
                        color: selected ? _accent : Colors.white,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    selected: selected,
                    selectedTileColor: _accent.withValues(alpha: 0.15),
                    onTap: () {
                      Navigator.pop(context);
                      if (c == ForecastCategory.tides) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const TidesScreen()));
                      } else {
                        setState(() => _selectedCategory = c);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _categoryContent() {
    switch (_selectedCategory) {
      case ForecastCategory.weather:
        return [
          _willyWeatherDailyList(),
        ];
      case ForecastCategory.rainfall:
        return [
          _compactSummaryCard(),
          const SizedBox(height: 24),
          _rainChartCard(),
        ];
      case ForecastCategory.wind:
        return [
          _compactSummaryCard(),
          const SizedBox(height: 24),
          _windWillyWeatherCard(),
        ];
      case ForecastCategory.sun:
        return [
          _compactSummaryCard(),
          const SizedBox(height: 24),
          _sunCompactCard(),
        ];
      case ForecastCategory.uv:
        return [
          _compactSummaryCard(),
          const SizedBox(height: 24),
          _uvCompactCard(),
        ];
      case ForecastCategory.tides:
        // Tides opens full screen via drawer tap; this case is fallback only
        return [_compactSummaryCard()];
      case ForecastCategory.swell:
        return [
          _compactSummaryCard(),
          const SizedBox(height: 24),
          _swellCard(),
        ];
      case ForecastCategory.weekly:
        return [
          _willyWeatherDailyList(),
        ];
    }
  }

  /// Minutes from midnight from ISO time string (e.g. "2025-02-19T05:55").
  static int _minutesFromMidnight(String? iso) {
    if (iso == null || iso.length < 16) return 0;
    final h = int.tryParse(iso.substring(11, 13)) ?? 0;
    final m = int.tryParse(iso.substring(14, 16)) ?? 0;
    return h * 60 + m;
  }

  Widget _sunCompactCard() {
    if (sunriseToday == null && sunsetToday == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
        child: const Center(child: Text("No sun data", style: TextStyle(color: Colors.white38, fontSize: 14))),
      );
    }
    final rise = _minutesFromMidnight(sunriseToday);
    final set = _minutesFromMidnight(sunsetToday);
    const totalMins = 24 * 60;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber.withValues(alpha: 0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wb_sunny_rounded, color: Colors.amber, size: 22),
              const SizedBox(width: 8),
              Text("Sun today", style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          // Day-length bar: night | sunrise→sunset (day) | night
          SizedBox(
            height: 36,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final riseX = (rise / totalMins) * w;
                final setX = (set / totalMins) * w;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Background (night)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    // Day segment (gradient)
                    Positioned(
                      left: riseX,
                      width: (setX - riseX).clamp(0.0, w),
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.amber.withValues(alpha: 0.3), Colors.amber.withValues(alpha: 0.5), Colors.amber.withValues(alpha: 0.3)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                    // Sun icon at solar noon
                    if (set > rise) ...[
                      Positioned(
                        left: (riseX + setX) / 2 - 10,
                        top: 4,
                        child: Icon(Icons.wb_sunny_rounded, color: Colors.amber, size: 28),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.nightlight_round, color: Colors.amber.shade700, size: 18),
                  const SizedBox(width: 6),
                  Text(WeatherHelper.formatTimeFromIso(sunriseToday), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 4),
                  Text("Sunrise", style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(WeatherHelper.formatTimeFromIso(sunsetToday), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 4),
                  Text("Sunset", style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                  const SizedBox(width: 6),
                  Icon(Icons.wb_sunny_rounded, color: Colors.amber, size: 18),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _uvCompactCard() {
    if (uvIndex == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
        child: const Center(child: Text("No UV data", style: TextStyle(color: Colors.white38, fontSize: 14))),
      );
    }
    String advice = "Low";
    Color c = _marineGood;
    if (uvIndex! >= 11) { advice = "Extreme — avoid sun"; c = _marinePoor; }
    else if (uvIndex! >= 8) { advice = "Very high — slip, slop, slap"; c = _marineCaution; }
    else if (uvIndex! >= 6) { advice = "High — use protection"; c = _marineModerate; }
    else if (uvIndex! >= 3) { advice = "Moderate"; c = _marineModerate; }
    const double uvMax = 12.0;
    final uv = uvIndex!.clamp(0.0, uvMax);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.light_mode_rounded, color: c, size: 22),
              const SizedBox(width: 8),
              Text("UV Index ${uvIndex!.toStringAsFixed(1)}", style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          // UV gauge bar 0–12 with colored segments
          SizedBox(
            height: 24,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final seg = w / 4; // 4 segments: 0-3, 3-6, 6-8, 8-12
                final colors = [_marineGood, _marineModerate, _marineCaution, _marinePoor];
                return Stack(
                  children: [
                    Row(
                      children: List.generate(4, (i) => Container(
                        width: seg,
                        height: 24,
                        decoration: BoxDecoration(
                          color: colors[i].withValues(alpha: 0.35),
                          borderRadius: BorderRadius.horizontal(
                            left: Radius.circular(i == 0 ? 12 : 0),
                            right: Radius.circular(i == 3 ? 12 : 0),
                          ),
                        ),
                      )),
                    ),
                    // Current value marker
                    Positioned(
                      left: (uv / uvMax * w).clamp(0.0, w - 4) - 2,
                      top: 0,
                      child: Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2), boxShadow: [BoxShadow(color: c, blurRadius: 6)]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text("0", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
              const Spacer(),
              Text("3", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
              const Spacer(),
              Text("6", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
              const Spacer(),
              Text("8", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
              const Spacer(),
              Text("11+", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 10),
          Text(advice, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _swellCard() {
    final hasWave = waveHeight != null;
    final hasSwell = swellWaveHeight != null;
    final hasSst = seaSurfaceTemp != null;
    if (!hasWave && !hasSwell && !hasSst) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
        child: Center(
          child: Text("No marine data for this location", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
        ),
      );
    }
    const barMaxHeight = 80.0;
    const waveScale = 3.0;   // metres
    const swellScale = 3.0;
    const tempMin = 15.0;
    const tempMax = 35.0;
    double normWave = 0, normSwell = 0, normTemp = 0;
    if (waveHeight != null) normWave = (waveHeight! / waveScale).clamp(0.0, 1.0);
    if (swellWaveHeight != null) normSwell = (swellWaveHeight! / swellScale).clamp(0.0, 1.0);
    if (seaSurfaceTemp != null) normTemp = ((seaSurfaceTemp! - tempMin) / (tempMax - tempMin)).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: _accent.withValues(alpha: 0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.waves_rounded, color: _accent, size: 22),
              const SizedBox(width: 8),
              Text("Swell & marine", style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (hasWave) _swellBar("Wave", "${waveHeight!.toStringAsFixed(1)} m", normWave, barMaxHeight, const Color(0xFF3B82F6)),
              if (hasSwell) _swellBar("Swell", "${swellWaveHeight!.toStringAsFixed(1)} m", normSwell, barMaxHeight, const Color(0xFF06B6D4)),
              if (hasSst) _swellBar("Sea", "${seaSurfaceTemp!.toStringAsFixed(0)}°C", normTemp, barMaxHeight, const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _swellBar(String label, String value, double normHeight, double maxH, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          SizedBox(
            height: maxH,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: (maxH * normHeight.clamp(0.05, 1.0)).clamp(8.0, maxH),
                  width: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: _bg,
      drawer: _forecastDrawer(context),
      body: RefreshIndicator(
        onRefresh: _loadWeather,
        color: _accent,
        backgroundColor: _surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: _bg,
              elevation: 0,
              pinned: true,
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              title: Text(
                _categoryTitle(_selectedCategory),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ),
            if (loading)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _accent),
                      SizedBox(height: 16),
                      Text(
                        "Loading forecast…",
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else if (error != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 56, color: Colors.white38),
                        const SizedBox(height: 16),
                        Text(
                          error!,
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        TextButton.icon(
                          onPressed: _loadWeather,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text("Retry"),
                          style: TextButton.styleFrom(foregroundColor: _accent),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + bottomPad),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(_categoryContent()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _sectionLabel(String text, [IconData? icon]) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: _accent.withValues(alpha:0.9)),
            const SizedBox(width: 8),
          ],
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactSummaryCard() {
    final rating = _marineRating();
    final code = weatherCode ?? 0;
    final condition = WeatherHelper.label(code);
    final icon = WeatherHelper.icon(code);
    final temp = temperature?.toStringAsFixed(0) ?? "—";
    final ratingLabel = switch (rating) {
      MarineRating.good => "Good",
      MarineRating.moderate => "Moderate",
      MarineRating.caution => "Caution",
      MarineRating.poor => "Poor",
    };
    final ratingColor = switch (rating) {
      MarineRating.good => _marineGood,
      MarineRating.moderate => _marineModerate,
      MarineRating.caution => _marineCaution,
      MarineRating.poor => _marinePoor,
    };
    final best = _bestTimeToGo();
    final windStr = windSpeed != null
        ? "${_kmhToKnots(windSpeed!).toStringAsFixed(1)} kt${windDirection != null ? " ${_windDirectionLabel(windDirection!)}" : ""}"
        : "—";
    final gustsStr = windGusts != null && windGusts! > (windSpeed ?? 0) + 1
        ? "Gusts ${_kmhToKnots(windGusts!).toStringAsFixed(1)} kt"
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 36, color: _accent),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("$temp°", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                  Text(condition, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ratingColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ratingColor.withValues(alpha: 0.5)),
                ),
                child: Text(ratingLabel, style: TextStyle(color: ratingColor, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _compactChip(Icons.air_rounded, windStr),
              if (gustsStr != null) _compactChip(Icons.grain_rounded, gustsStr),
              if (sunriseToday != null) _compactChip(Icons.wb_sunny_rounded, WeatherHelper.formatTimeFromIso(sunriseToday)),
              if (sunsetToday != null) _compactChip(Icons.nightlight_round, WeatherHelper.formatTimeFromIso(sunsetToday)),
              if (uvIndex != null) _compactChip(Icons.wb_sunny_rounded, "UV ${uvIndex!.toStringAsFixed(1)}"),
              if (best != null) _compactChip(Icons.schedule_rounded, "${_hourTo12h(hourly[best.start].time)}–${_hourTo12h(hourly[best.end].time)} best"),
              if (waveHeight != null) _compactChip(Icons.waves_rounded, "${waveHeight!.toStringAsFixed(1)} m"),
              if (seaSurfaceTemp != null) _compactChip(Icons.thermostat_rounded, "${seaSurfaceTemp!.toStringAsFixed(0)}° sea"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _accent),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  static String _hourTo12h(String iso) {
    if (iso.length < 13) return "—";
    final h = int.tryParse(iso.substring(11, 13)) ?? 0;
    if (h == 0) return "12am";
    if (h == 12) return "12pm";
    if (h < 12) return "${h}am";
    return "${h - 12}pm";
  }

  Widget _windWillyWeatherCard() {
    if (hourly.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: Text("No wind data", style: TextStyle(color: Colors.white38, fontSize: 14)),
        ),
      );
    }

    final slots = _windChartSlots;
    final windKnots = slots.map((h) => _kmhToKnots(h.windSpeed ?? 0)).toList();
    final maxKnots = windKnots.isEmpty ? 10.0 : windKnots.reduce(math.max).clamp(5.0, 99.0);
    const chartHeight = 140.0;
    const yAxisWidth = 44.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withValues(alpha:0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current wind hero (WillyWeather-style)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.air_rounded, color: _accent, size: 22),
                        const SizedBox(width: 6),
                        Text(
                          "Current Speed",
                          style: TextStyle(color: Colors.white.withValues(alpha:0.7), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          windSpeed != null ? "${_kmhToKnots(windSpeed!).toStringAsFixed(1)} knots" : "—",
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                        ),
                        if (windDirection != null) ...[
                          const SizedBox(width: 8),
                          Transform.rotate(
                            angle: windDirection! * math.pi / 180,
                            child: Icon(Icons.arrow_downward_rounded, color: _accent, size: 20),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _windDirectionLabel(windDirection!),
                            style: TextStyle(color: Colors.white.withValues(alpha:0.8), fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (windGusts != null && windGusts! > (windSpeed ?? 0) + 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha:0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Gusts", style: TextStyle(color: Colors.white.withValues(alpha:0.7), fontSize: 11, fontWeight: FontWeight.w600)),
                      Text("${_kmhToKnots(windGusts!).toStringAsFixed(1)} knots", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "$_locationLabel · $_locationSource",
            style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),

          // Period selector
          Row(
            children: [1, 3, 5].map((d) {
              final selected = _windPeriodDays == d;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: d < 5 ? 8 : 0),
                  child: Material(
                    color: selected ? _accent.withValues(alpha:0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => setState(() => _windPeriodDays = d),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selected ? _accent : Colors.white24, width: selected ? 1.5 : 1),
                        ),
                        child: Text(
                          "$d-Day",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected ? _accent : Colors.white70,
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Chart title
          Text("Wind Speed", style: TextStyle(color: Colors.white.withValues(alpha:0.8), fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),

          // Interactive line chart
          LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = constraints.maxWidth - yAxisWidth;
              return GestureDetector(
                onHorizontalDragUpdate: (d) {
                  final x = d.localPosition.dx - yAxisWidth;
                  if (x >= 0 && x < chartWidth && slots.isNotEmpty) {
                    final i = (x / chartWidth * slots.length).floor().clamp(0, slots.length - 1);
                    setState(() => _windChartHoverIndex = i);
                  }
                },
                onHorizontalDragEnd: (_) => setState(() => _windChartHoverIndex = null),
                onTapDown: (d) {
                  final x = d.localPosition.dx - yAxisWidth;
                  if (x >= 0 && x < chartWidth && slots.isNotEmpty) {
                    final i = (x / chartWidth * slots.length).floor().clamp(0, slots.length - 1);
                    setState(() => _windChartHoverIndex = _windChartHoverIndex == i ? null : i);
                  }
                },
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: yAxisWidth,
                          height: chartHeight,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("${maxKnots.round()} knots", style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 10, fontWeight: FontWeight.w600)),
                              Text("${(maxKnots / 2).round()} knots", style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 10, fontWeight: FontWeight.w600)),
                              Text("0 knots", style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: chartHeight,
                            child: CustomPaint(
                              painter: _WindLineChartPainter(
                                values: windKnots,
                                maxY: maxKnots,
                                color: _accent,
                                hoverIndex: _windChartHoverIndex,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_windChartHoverIndex != null && _windChartHoverIndex! < slots.length)
                      _WindTooltip(
                        slot: slots[_windChartHoverIndex!],
                        knots: windKnots[_windChartHoverIndex!],
                        chartWidth: chartWidth,
                        index: _windChartHoverIndex!,
                        total: slots.length,
                        yAxisWidth: yAxisWidth,
                        maxWidth: constraints.maxWidth,
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDay(slots.isNotEmpty ? slots.first.time : ""), style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 10, fontWeight: FontWeight.w600)),
              Text(_formatDay(slots.isNotEmpty ? slots.last.time : ""), style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  /// Visual rainfall chart: 24h bar chart + time blocks with bars.
  Widget _rainChartCard() {
    if (hourly.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
        child: const Center(child: Text("No rain data", style: TextStyle(color: Colors.white38, fontSize: 14))),
      );
    }
    int hourFromIso(String iso) => iso.length >= 13 ? (int.tryParse(iso.substring(11, 13)) ?? 0) : 0;
    final next24h = hourly.take(24).toList();
    final rainValues = next24h.map((h) => h.precipitationProbability ?? 0.0).toList();
    final maxRain = rainValues.isEmpty ? 100.0 : rainValues.reduce(math.max).clamp(10.0, 100.0);
    const chartHeight = 100.0;
    final blocks = [(label: "Morning", start: 6, end: 12), (label: "Afternoon", start: 12, end: 18), (label: "Evening", start: 18, end: 22), (label: "Tonight", start: 22, end: 30)];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_rounded, color: Colors.blue.shade300, size: 22),
              const SizedBox(width: 8),
              Text("Rain chance (next 24h)", style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 20),
          // Hourly bar chart
          SizedBox(
            height: chartHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final barWidth = (w / next24h.length).clamp(2.0, 8.0);
                final spacing = (w - (barWidth * next24h.length)) / (next24h.length - 1);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(next24h.length, (i) {
                    final rain = rainValues[i];
                    final height = (rain / maxRain).clamp(0.05, 1.0) * chartHeight;
                    final intensity = rain / 100.0;
                    Color barColor;
                    if (intensity >= 0.7) {
                      barColor = Colors.red.shade400;
                    } else if (intensity >= 0.5) {
                      barColor = Colors.orange.shade400;
                    } else if (intensity >= 0.3) {
                      barColor = Colors.blue.shade400;
                    } else {
                      barColor = Colors.blue.shade300;
                    }
                    return Container(
                      width: barWidth,
                      margin: EdgeInsets.only(right: i < next24h.length - 1 ? spacing : 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: height.clamp(4.0, chartHeight),
                            decoration: BoxDecoration(
                              color: barColor.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(barWidth / 2)),
                              border: Border.all(color: barColor.withValues(alpha: 0.9), width: 0.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Now", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
              Text("+12h", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
              Text("+24h", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 20),
          // Time blocks with visual bars
          Row(
            children: blocks.map((b) {
              final slots = hourly.where((h) {
                final hr = hourFromIso(h.time);
                if (b.start == 22) return hr >= 22 || hr < 6;
                return hr >= b.start && hr < b.end;
              }).toList();
              final maxRainBlock = slots.isEmpty ? 0.0 : slots.map((s) => s.precipitationProbability ?? 0).reduce(math.max);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Text(b.label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: (maxRainBlock / 100 * 40).clamp(4.0, 40.0),
                              width: 24,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    maxRainBlock >= 70 ? Colors.red.shade400 : maxRainBlock >= 50 ? Colors.orange.shade400 : Colors.blue.shade400,
                                    maxRainBlock >= 70 ? Colors.red.shade300 : maxRainBlock >= 50 ? Colors.orange.shade300 : Colors.blue.shade300,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: (maxRainBlock >= 70 ? Colors.red : maxRainBlock >= 50 ? Colors.orange : Colors.blue).withValues(alpha: 0.6),
                                  width: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text("${maxRainBlock.round()}%", style: TextStyle(color: maxRainBlock >= 50 ? Colors.orange : Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// WillyWeather-style: day-by-day list, today expanded with current temp & feels like, min/max in colored boxes.
  Widget _willyWeatherDailyList() {
    if (daily.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
        child: const Center(child: Text("No forecast data", style: TextStyle(color: Colors.white38, fontSize: 14))),
      );
    }
    const minColor = Color(0xFF3B82F6);
    const maxColor = Color(0xFFEF4444);
    String formatDayDate(String iso) {
      final d = DateTime.tryParse(iso);
      if (d == null) return "—";
      return DateFormat('EEEE MMM d').format(d);
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withValues(alpha: 0.15)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Location bar + marine rating
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white.withValues(alpha: 0.04),
              child: Row(
                children: [
                  Icon(Icons.place_rounded, color: _accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_locationLabel, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                        Text(_locationSource, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                      ],
                    ),
                  ),
                  _marineRatingChip(),
                ],
              ),
            ),
            // Daily rows
            for (int i = 0; i < daily.length; i++) ...[
              _buildWillyWeatherDayRow(
                d: daily[i],
                isToday: i == 0,
                currentTemp: i == 0 ? temperature : null,
                feelsLike: i == 0 ? apparentTemperature : null,
                formatDayDate: formatDayDate,
                minColor: minColor,
                maxColor: maxColor,
              ),
              if (i < daily.length - 1) Divider(height: 1, color: Colors.white.withValues(alpha: 0.08), indent: 16, endIndent: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _marineRatingChip() {
    final r = _marineRating();
    final (label, color) = switch (r) {
      MarineRating.good => ("Good", _marineGood),
      MarineRating.moderate => ("Moderate", _marineModerate),
      MarineRating.caution => ("Caution", _marineCaution),
      MarineRating.poor => ("Poor", _marinePoor),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildWillyWeatherDayRow({
    required DailySlot d,
    required bool isToday,
    double? currentTemp,
    double? feelsLike,
    required String Function(String) formatDayDate,
    required Color minColor,
    required Color maxColor,
  }) {
    final code = d.weatherCode ?? 0;
    final desc = WeatherHelper.label(code);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isToday ? 18 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(WeatherHelper.icon(code), color: _accent, size: isToday ? 40 : 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatDayDate(d.date), style: TextStyle(color: isToday ? _accent : Colors.white70, fontSize: isToday ? 15 : 14, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                if (isToday && (currentTemp != null || feelsLike != null)) ...[
                  const SizedBox(height: 4),
                  Text(currentTemp != null ? "${currentTemp.toStringAsFixed(1)} °C" : "—", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  if (feelsLike != null)
                    Text("Feels like ${feelsLike.toStringAsFixed(1)} °C", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13), overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Min/max boxes (compact so they don't cause overflow)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: minColor.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(6), border: Border.all(color: minColor.withValues(alpha: 0.5))),
                child: Text(d.tempMin != null ? "${d.tempMin!.round()}" : "—", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: maxColor.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(6), border: Border.all(color: maxColor.withValues(alpha: 0.5))),
                child: Text(d.tempMax != null ? "${d.tempMax!.round()}" : "—", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withValues(alpha: 0.5), size: 22),
        ],
      ),
    );
  }

}

class HourlySlot {
  final String time;
  final double? temperature;
  final int? weatherCode;
  final double? precipitationProbability;
  final double? windSpeed;
  final double? windDirection;
  final double? windGusts;

  HourlySlot({
    required this.time,
    this.temperature,
    this.weatherCode,
    this.precipitationProbability,
    this.windSpeed,
    this.windDirection,
    this.windGusts,
  });
}

class DailySlot {
  final String date;
  final double? tempMax;
  final double? tempMin;
  final int? weatherCode;
  final double? precipitationProbability;
  final double? precipitationSum;

  DailySlot({
    required this.date,
    this.tempMax,
    this.tempMin,
    this.weatherCode,
    this.precipitationProbability,
    this.precipitationSum,
  });
}

enum MarineRating { good, moderate, caution, poor }

/// WMO weather code → icon and label (Open-Meteo).
class WeatherHelper {
  static String windDirectionLabel(double deg) {
    const labels = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
    final i = ((deg + 11.25) / 22.5).floor() % 16;
    return labels[i];
  }

  static String windDescriptorKnots(double knots) {
    if (knots < 1) return "Calm";
    if (knots < 4) return "Light air";
    if (knots < 7) return "Light";
    if (knots < 11) return "Gentle";
    if (knots < 17) return "Moderate";
    if (knots < 22) return "Fresh";
    if (knots < 28) return "Strong";
    if (knots < 34) return "Near gale";
    if (knots < 41) return "Gale";
    if (knots < 48) return "Strong gale";
    return "Storm";
  }

  static String formatTimeFromIso(String? iso) {
    if (iso == null || iso.length < 16) return "—";
    final dt = DateTime.tryParse(iso);
    if (dt == null) return "—";
    final h = dt.hour;
    final m = dt.minute;
    final ampm = h >= 12 ? "pm" : "am";
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return "$h12:${m.toString().padLeft(2, '0')} $ampm";
  }

  static IconData icon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code == 1 || code == 2) return Icons.wb_cloudy_rounded;
    if (code == 3) return Icons.cloud_rounded;
    if (code == 45 || code == 48) return Icons.blur_on_rounded;
    if (code >= 51 && code <= 57) return Icons.grain_rounded;
    if (code >= 61 && code <= 67) return Icons.water_drop_rounded;
    if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
    if (code >= 80 && code <= 82) return Icons.water_drop_rounded;
    if (code >= 85 && code <= 86) return Icons.ac_unit_rounded;
    if (code >= 95 && code <= 99) return Icons.thunderstorm_rounded;
    return Icons.cloud_rounded;
  }

  static String label(int code) {
    if (code == 0) return "Clear";
    if (code == 1) return "Mainly clear";
    if (code == 2) return "Partly cloudy";
    if (code == 3) return "Overcast";
    if (code == 45) return "Foggy";
    if (code == 48) return "Rime fog";
    if (code >= 51 && code <= 55) return "Drizzle";
    if (code >= 56 && code <= 57) return "Freezing drizzle";
    if (code >= 61 && code <= 65) return "Rain";
    if (code >= 66 && code <= 67) return "Freezing rain";
    if (code >= 71 && code <= 77) return "Snow";
    if (code >= 80 && code <= 82) return "Rain showers";
    if (code >= 85 && code <= 86) return "Snow showers";
    if (code >= 95 && code <= 99) return "Thunderstorm";
    return "Unknown";
  }
}

/// Paints wind speed line chart with optional hover indicator.
class _WindLineChartPainter extends CustomPainter {
  _WindLineChartPainter({
    required this.values,
    required this.maxY,
    required this.color,
    this.hoverIndex,
  });

  final List<double> values;
  final double maxY;
  final Color color;
  final int? hoverIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final stroke = Paint()
      ..color = color.withValues(alpha:0.9)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final n = values.length;
    final stepX = size.width / (n - 1).clamp(1, n);

    for (int i = 0; i < n; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] / maxY).clamp(0.0, 1.0) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, stroke);

    if (hoverIndex != null && hoverIndex! >= 0 && hoverIndex! < n) {
      final x = hoverIndex! * stepX;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()..color = color.withValues(alpha:0.5)..strokeWidth = 1);
      final y = size.height - (values[hoverIndex!] / maxY).clamp(0.0, 1.0) * size.height;
      canvas.drawCircle(Offset(x, y), 6, Paint()..color = color..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(x, y), 6, Paint()..color = Colors.white..strokeWidth = 2..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _WindLineChartPainter old) =>
      old.values != values || old.maxY != maxY || old.hoverIndex != hoverIndex;
}

/// Tooltip overlay for wind chart hover.
class _WindTooltip extends StatelessWidget {
  const _WindTooltip({
    required this.slot,
    required this.knots,
    required this.chartWidth,
    required this.index,
    required this.total,
    required this.yAxisWidth,
    required this.maxWidth,
  });

  final HourlySlot slot;
  final double knots;
  final double chartWidth;
  final int index;
  final int total;
  final double yAxisWidth;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final stepX = chartWidth / (total - 1).clamp(1, total);
    final x = yAxisWidth + index * stepX;
    final dir = slot.windDirection != null ? WeatherHelper.windDirectionLabel(slot.windDirection!) : "—";
    final desc = WeatherHelper.windDescriptorKnots(knots);
    final timeStr = WeatherHelper.formatTimeFromIso(slot.time);
    const tooltipWidth = 180.0;

    return Positioned(
      left: (x - tooltipWidth / 2).clamp(8.0, maxWidth - tooltipWidth - 8),
      top: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F26),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.4), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Text(
          "$timeStr $dir ${knots.toStringAsFixed(1)} knots $desc",
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
