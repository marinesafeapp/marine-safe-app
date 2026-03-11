import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fetches tide predictions from WorldTides API (worldtides.info).
/// Register at https://www.worldtides.info/register for a free API key.
/// Add your key to [apiKey] below. Without a key, returns null (use sample data).
class TidesApiService {
  TidesApiService._();
  static final TidesApiService instance = TidesApiService._();

  /// WorldTides API key. Get one at https://www.worldtides.info/register (100 free credits).
  /// Set via --dart-define=WORLD_TIDES_API_KEY=your_key or add below for dev.
  static const String apiKey = String.fromEnvironment('WORLD_TIDES_API_KEY', defaultValue: '');

  static const String _baseUrl = 'https://www.worldtides.info/api/v3';

  /// Fetches high/low tide times for a location. Returns null if no key or error.
  Future<TidesApiResult?> fetchTides({
    required double lat,
    required double lon,
    DateTime? date,
    int days = 2,
  }) async {
    if (apiKey.isEmpty) return null;

    final d = date ?? DateTime.now();
    final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    try {
      final uri = Uri.parse(
        '$_baseUrl?extremes&localtime&date=$dateStr&days=$days'
        '&lat=$lat&lon=$lon'
        '&key=$apiKey',
      );

      final res = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Tide request timeout'),
      );

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final status = data['status'] as int?;
      if (status != null && status != 200) return null;

      final extremes = data['extremes'] as List<dynamic>?;
      if (extremes == null || extremes.isEmpty) return null;

      final station = data['station'] as String?;

      final events = <TideEventApi>[];
      for (final e in extremes) {
        final m = e as Map<String, dynamic>;
        final type = m['type'] as String?;
        final dateStr2 = m['date'] as String?;
        final height = (m['height'] as num?)?.toDouble();

        if (type == null || dateStr2 == null) continue;

        final dt = DateTime.tryParse(dateStr2);
        if (dt == null) continue;

        events.add(TideEventApi(
          isHigh: type.toLowerCase() == 'high',
          dateTime: dt,
          height: height,
        ));
      }

      events.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      return TidesApiResult(
        events: events,
        station: station ?? 'WorldTides',
        copyright: data['copyright'] as String? ?? 'Tide data from WorldTides',
      );
    } catch (_) {
      return null;
    }
  }
}

class TideEventApi {
  final bool isHigh;
  final DateTime dateTime;
  final double? height;

  TideEventApi({
    required this.isHigh,
    required this.dateTime,
    this.height,
  });
}

class TidesApiResult {
  final List<TideEventApi> events;
  final String station;
  final String copyright;

  TidesApiResult({
    required this.events,
    required this.station,
    required this.copyright,
  });
}
