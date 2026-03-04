import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/tides_api_service.dart';
import '../services/user_profile_service.dart';

/// Tide times from postcode (WorldTides API when key configured) or sample data for QLD ports.
class TidesScreen extends StatefulWidget {
  const TidesScreen({super.key});

  @override
  State<TidesScreen> createState() => _TidesScreenState();
}

class _TidesScreenState extends State<TidesScreen> {
  static const Color _bg = Color(0xFF02050A);
  static const Color _accent = Color(0xFF2CB6FF);
  static const String _bomTidesUrl = 'https://www.bom.gov.au/australia/tides/#!/qld';

  /// Day offset: 0 = today, 1 = tomorrow, etc.
  int _dayOffset = 0;
  TideLocation _location = TideData.locations.first;
  bool _locationLoaded = false;

  /// Real tide data from API (when postcode + API key available).
  TidesApiResult? _apiTides;
  bool _apiLoading = false;
  String? _postcode;

  DateTime get _selectedDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + _dayOffset);
  }

  List<TideEvent> get _eventsForSelectedDay {
    if (_apiTides != null) {
      final dayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final apiEvents = _apiTides!.events
          .where((e) => !e.dateTime.isBefore(dayStart) && e.dateTime.isBefore(dayEnd))
          .map((e) => TideEvent(
                isHigh: e.isHigh,
                hour: e.dateTime.hour,
                minute: e.dateTime.minute,
              ))
          .toList();
      apiEvents.sort((a, b) {
        final ta = a.hour * 60 + a.minute;
        final tb = b.hour * 60 + b.minute;
        return ta.compareTo(tb);
      });
      if (apiEvents.isNotEmpty) return apiEvents;
      // Fallback to sample if API returned no events for this day
    }
    return TideData.eventsFor(_location.id, _dayOffset);
  }

  TideEvent? get _nextTide {
    final now = DateTime.now();
    for (final e in _eventsForSelectedDay) {
      final dt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        e.hour,
        e.minute,
      );
      if (_dayOffset == 0 && dt.isBefore(now)) continue;
      return e;
    }
    return null;
  }

  String _formatTime(int hour, int minute) {
    final d = DateTime(2000, 1, 1, hour, minute);
    return DateFormat.jm().format(d);
  }

  @override
  void initState() {
    super.initState();
    _loadLocationFromPostcode();
  }

  /// Auto-select tide location based on user's postcode. Fetches real tides from API when lat/lon available.
  Future<void> _loadLocationFromPostcode() async {
    final postcode = await UserProfileService.instance.getPostcode();
    if (postcode == null || postcode.isEmpty) {
      if (mounted) {
        setState(() {
          _apiTides = null;
          _postcode = null;
          _locationLoaded = true;
        });
      }
      return;
    }

    final latLon = await UserProfileService.instance.getPostcodeLatLon();
    if (mounted) setState(() => _postcode = postcode);

    // Sample data fallback: location by postcode map or nearest
    final locationId = TideData.locationIdForPostcode(postcode);
    if (locationId != null) {
      final loc = TideData.locations.firstWhere(
        (l) => l.id == locationId,
        orElse: () => TideData.locations.first,
      );
      if (mounted) setState(() => _location = loc);
    } else if (latLon != null) {
      final nearest = TideData.nearestLocation(latLon.lat, latLon.lon);
      if (mounted) setState(() => _location = nearest);
    }

    // Fetch real tides from API when we have lat/lon (requires API key in TidesApiService)
    if (latLon != null) {
      if (mounted) setState(() => _apiLoading = true);
      final result = await TidesApiService.instance.fetchTides(
        lat: latLon.lat,
        lon: latLon.lon,
        days: 3,
      );
      if (mounted) {
        setState(() {
          _apiTides = result;
          _apiLoading = false;
          _locationLoaded = true;
        });
      }
    } else {
      if (mounted) setState(() => _locationLoaded = true);
    }
  }

  Future<void> _openBomTides() async {
    final uri = Uri.parse(_bomTidesUrl);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Could not open link. Try again in a browser.')),
        );
      }
    } on Exception catch (e) {
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Could not open link: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final events = _eventsForSelectedDay;
    final nextTide = _nextTide;
    final dateLabel = _dayOffset == 0
        ? 'Today'
        : _dayOffset == 1
            ? 'Tomorrow'
            : DateFormat.E().add_MMMd().format(_selectedDate);

    if (!_locationLoaded) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          title: const Text(
            'Tide times',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Tide times',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadLocationFromPostcode();
          setState(() {});
        },
        color: _accent,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + bottomPad),
          children: [
            if (_apiLoading && _locationLoaded)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _accent)),
                    const SizedBox(width: 10),
                    Text('Updating tides…', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            // Location dropdown
            _locationChip(),
            const SizedBox(height: 16),
            // Date selector
            _dateSelector(dateLabel),
            const SizedBox(height: 20),
            // Tide chart (visual 24h)
            _tideChartCard(events),
            const SizedBox(height: 20),
            // Next tide hero
            if (nextTide != null) _nextTideCard(nextTide, dateLabel),
            if (nextTide != null) const SizedBox(height: 24),
            // Day's tides
            _sectionTitle('Tides for $dateLabel'),
            const SizedBox(height: 12),
            ...events.map((e) => _tideEventTile(e)),
            if (_apiTides != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  _apiTides!.copyright,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _bomLinkCard(),
          ],
        ),
      ),
    );
  }

  Widget _locationChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withValues(alpha: 0.25)),
      ),
      child: _apiTides != null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.place_rounded, color: _accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _postcode != null
                          ? 'Tides for postcode $_postcode'
                          : _apiTides!.station,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<TideLocation>(
                value: _location,
                isExpanded: true,
                dropdownColor: const Color(0xFF1A1F26),
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: _accent),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                items: TideData.locations
                    .map((loc) => DropdownMenuItem(
                          value: loc,
                          child: Row(
                            children: [
                              Icon(Icons.place_rounded, color: _accent, size: 20),
                              const SizedBox(width: 10),
                              Text(loc.name),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (TideLocation? loc) {
                  if (loc != null) setState(() => _location = loc);
                },
              ),
            ),
    );
  }

  Widget _dateSelector(String dateLabel) {
    return Row(
      children: [
        Expanded(child: _dateChip('Today', 0)),
        const SizedBox(width: 10),
        Expanded(child: _dateChip('Tomorrow', 1)),
        if (_apiTides != null) ...[
          const SizedBox(width: 10),
          Expanded(
          child: _dateChip(
            DateFormat.E().format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 2)),
            2,
          ),
        ),
        ],
      ],
    );
  }

  Widget _dateChip(String label, int value) {
    final selected = _dayOffset == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _dayOffset = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _accent.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _accent : Colors.white12,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? _accent : Colors.white70,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _nextTideCard(TideEvent nextTide, String dateLabel) {
    final timeStr = _formatTime(nextTide.hour, nextTide.minute);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent.withValues(alpha: 0.2),
            _accent.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                nextTide.isHigh ? Icons.waves_rounded : Icons.water_drop_rounded,
                color: _accent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Next ${nextTide.isHigh ? "high" : "low"} tide',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            timeStr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _apiTides != null && _postcode != null ? 'Postcode $_postcode' : _location.name,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  /// Simple 24h tide chart: step line between high/low events.
  Widget _tideChartCard(List<TideEvent> events) {
    if (events.isEmpty) return const SizedBox.shrink();
    const chartHeight = 72.0;
    const totalMinutes = 24 * 60;
    // Build points: (minutes from midnight, isHigh). Start/end at low.
    final points = <({int min, bool isHigh})>[];
    points.add((min: 0, isHigh: false));
    for (final e in events) {
      points.add((min: e.hour * 60 + e.minute, isHigh: e.isHigh));
    }
    points.add((min: totalMinutes, isHigh: false));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, color: _accent, size: 18),
              const SizedBox(width: 8),
              Text('Tide level', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                height: chartHeight,
                width: constraints.maxWidth,
                child: CustomPaint(
                  painter: _TideChartPainter(
                    points: points,
                    accent: _accent,
                    totalMinutes: totalMinutes,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('12am', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
              Text('12pm', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
              Text('12am', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tideEventTile(TideEvent e) {
    final timeStr = _formatTime(e.hour, e.minute);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accent.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (e.isHigh ? _accent : const Color(0xFF3B82F6)).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                e.isHigh ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: e.isHigh ? _accent : const Color(0xFF93C5FD),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                e.isHigh ? 'High tide' : 'Low tide',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bomLinkCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openBomTides,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.open_in_new_rounded, color: _accent, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Official BOM tide predictions',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Full tables for all QLD locations',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: _accent, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Data model and sample data ---

class TideLocation {
  final String id;
  final String name;

  const TideLocation({required this.id, required this.name});
}

class TideEvent {
  final bool isHigh;
  final int hour;
  final int minute;

  const TideEvent({required this.isHigh, required this.hour, required this.minute});
}

/// Sample tide data for QLD ports. Times are representative; use BOM for official predictions.
class TideData {
  static const locations = [
    TideLocation(id: 'mackay', name: 'Mackay Outer Harbour'),
    TideLocation(id: 'brisbane', name: 'Brisbane Bar'),
    TideLocation(id: 'cairns', name: 'Cairns'),
    TideLocation(id: 'gladstone', name: 'Gladstone'),
    TideLocation(id: 'bundaberg', name: 'Bundaberg (Burnett Heads)'),
  ];

  /// Approximate lat/lon for each tide location (for distance calculation).
  static const Map<String, ({double lat, double lon})> _locationCoords = {
    'mackay': (lat: -21.1395, lon: 149.1891),
    'brisbane': (lat: -27.4698, lon: 153.0251),
    'cairns': (lat: -16.9186, lon: 145.7781),
    'gladstone': (lat: -23.8485, lon: 151.2569),
    'bundaberg': (lat: -24.8661, lon: 152.3489),
  };

  /// Direct postcode to location mapping (for common postcodes).
  static const Map<String, String> _postcodeToLocation = {
    // Mackay region
    '4740': 'mackay',
    '4741': 'mackay',
    '4742': 'mackay',
    '4743': 'mackay',
    '4744': 'mackay',
    '4745': 'mackay',
    '4746': 'mackay',
    // Brisbane region
    '4000': 'brisbane',
    '4001': 'brisbane',
    '4002': 'brisbane',
    '4003': 'brisbane',
    '4004': 'brisbane',
    '4005': 'brisbane',
    '4006': 'brisbane',
    '4007': 'brisbane',
    '4008': 'brisbane',
    '4009': 'brisbane',
    '4010': 'brisbane',
    '4011': 'brisbane',
    '4012': 'brisbane',
    '4013': 'brisbane',
    '4014': 'brisbane',
    '4017': 'brisbane',
    '4018': 'brisbane',
    '4019': 'brisbane',
    '4020': 'brisbane',
    '4021': 'brisbane',
    '4022': 'brisbane',
    '4025': 'brisbane',
    '4029': 'brisbane',
    '4030': 'brisbane',
    '4031': 'brisbane',
    '4032': 'brisbane',
    '4034': 'brisbane',
    '4035': 'brisbane',
    '4036': 'brisbane',
    '4037': 'brisbane',
    '4051': 'brisbane',
    '4053': 'brisbane',
    '4054': 'brisbane',
    '4055': 'brisbane',
    '4059': 'brisbane',
    '4060': 'brisbane',
    '4061': 'brisbane',
    '4064': 'brisbane',
    '4065': 'brisbane',
    '4066': 'brisbane',
    '4067': 'brisbane',
    '4068': 'brisbane',
    '4069': 'brisbane',
    '4070': 'brisbane',
    '4072': 'brisbane',
    '4073': 'brisbane',
    '4074': 'brisbane',
    '4075': 'brisbane',
    '4076': 'brisbane',
    '4077': 'brisbane',
    '4078': 'brisbane',
    '4101': 'brisbane',
    '4102': 'brisbane',
    '4103': 'brisbane',
    '4104': 'brisbane',
    '4105': 'brisbane',
    '4106': 'brisbane',
    '4107': 'brisbane',
    '4108': 'brisbane',
    '4109': 'brisbane',
    '4110': 'brisbane',
    '4111': 'brisbane',
    '4112': 'brisbane',
    '4113': 'brisbane',
    '4114': 'brisbane',
    '4115': 'brisbane',
    '4116': 'brisbane',
    '4117': 'brisbane',
    '4118': 'brisbane',
    '4119': 'brisbane',
    '4120': 'brisbane',
    '4121': 'brisbane',
    '4122': 'brisbane',
    '4123': 'brisbane',
    '4124': 'brisbane',
    '4125': 'brisbane',
    '4127': 'brisbane',
    '4128': 'brisbane',
    '4129': 'brisbane',
    '4130': 'brisbane',
    '4131': 'brisbane',
    '4132': 'brisbane',
    '4133': 'brisbane',
    '4151': 'brisbane',
    '4152': 'brisbane',
    '4153': 'brisbane',
    '4154': 'brisbane',
    '4155': 'brisbane',
    '4156': 'brisbane',
    '4157': 'brisbane',
    '4158': 'brisbane',
    '4159': 'brisbane',
    '4160': 'brisbane',
    '4161': 'brisbane',
    '4163': 'brisbane',
    '4164': 'brisbane',
    '4165': 'brisbane',
    '4169': 'brisbane',
    '4170': 'brisbane',
    '4171': 'brisbane',
    '4172': 'brisbane',
    '4173': 'brisbane',
    '4174': 'brisbane',
    '4178': 'brisbane',
    '4179': 'brisbane',
    '4183': 'brisbane',
    '4184': 'brisbane',
    // Cairns region
    '4870': 'cairns',
    '4871': 'cairns',
    '4872': 'cairns',
    '4873': 'cairns',
    '4874': 'cairns',
    '4875': 'cairns',
    '4876': 'cairns',
    '4877': 'cairns',
    '4878': 'cairns',
    '4879': 'cairns',
    // Gladstone region
    '4680': 'gladstone',
    '4681': 'gladstone',
    '4682': 'gladstone',
    '4683': 'gladstone',
    '4684': 'gladstone',
    '4685': 'gladstone',
    '4686': 'gladstone',
    '4687': 'gladstone',
    '4688': 'gladstone',
    '4689': 'gladstone',
    '4690': 'gladstone',
    '4691': 'gladstone',
    '4692': 'gladstone',
    '4693': 'gladstone',
    '4694': 'gladstone',
    '4695': 'gladstone',
    '4696': 'gladstone',
    '4697': 'gladstone',
    '4698': 'gladstone',
    '4699': 'gladstone',
    // Bundaberg region
    '4670': 'bundaberg',
    '4671': 'bundaberg',
    '4672': 'bundaberg',
    '4673': 'bundaberg',
    '4674': 'bundaberg',
    '4675': 'bundaberg',
    '4676': 'bundaberg',
    '4677': 'bundaberg',
    '4678': 'bundaberg',
    '4679': 'bundaberg',
  };

  /// Returns tide location ID for a postcode (direct mapping or null).
  static String? locationIdForPostcode(String postcode) {
    return _postcodeToLocation[postcode];
  }

  /// Finds nearest tide location by lat/lon distance.
  static TideLocation nearestLocation(double lat, double lon) {
    String nearestId = 'mackay';
    double minDist = double.infinity;

    for (final entry in _locationCoords.entries) {
      final locLat = entry.value.lat;
      final locLon = entry.value.lon;
      // Simple distance calculation (Haversine would be more accurate but this is fine for QLD)
      final dist = (lat - locLat) * (lat - locLat) + (lon - locLon) * (lon - locLon);
      if (dist < minDist) {
        minDist = dist;
        nearestId = entry.key;
      }
    }

    return locations.firstWhere(
      (l) => l.id == nearestId,
      orElse: () => locations.first,
    );
  }

  /// Base events for "today" per location (approximate; shifts ~50 min per day for other days).
  static const _baseEvents = {
    'mackay': [
      TideEvent(isHigh: true, hour: 5, minute: 30),
      TideEvent(isHigh: false, hour: 11, minute: 45),
      TideEvent(isHigh: true, hour: 18, minute: 5),
    ],
    'brisbane': [
      TideEvent(isHigh: false, hour: 4, minute: 15),
      TideEvent(isHigh: true, hour: 10, minute: 35),
      TideEvent(isHigh: false, hour: 16, minute: 50),
      TideEvent(isHigh: true, hour: 22, minute: 55),
    ],
    'cairns': [
      TideEvent(isHigh: true, hour: 6, minute: 10),
      TideEvent(isHigh: false, hour: 12, minute: 25),
      TideEvent(isHigh: true, hour: 18, minute: 40),
    ],
    'gladstone': [
      TideEvent(isHigh: false, hour: 3, minute: 50),
      TideEvent(isHigh: true, hour: 10, minute: 5),
      TideEvent(isHigh: false, hour: 16, minute: 20),
      TideEvent(isHigh: true, hour: 22, minute: 35),
    ],
    'bundaberg': [
      TideEvent(isHigh: true, hour: 5, minute: 0),
      TideEvent(isHigh: false, hour: 11, minute: 20),
      TideEvent(isHigh: true, hour: 17, minute: 40),
    ],
  };

  /// Lunar day shift in minutes (approx).
  static const int _minutesPerDay = 50;

  static List<TideEvent> eventsFor(String locationId, int dayOffset) {
    final base = _baseEvents[locationId] ?? _baseEvents['mackay']!;
    final shift = dayOffset * _minutesPerDay;
    return base.map((e) {
      var m = e.hour * 60 + e.minute + shift;
      m = m % (24 * 60);
      if (m < 0) m += 24 * 60;
      return TideEvent(isHigh: e.isHigh, hour: m ~/ 60, minute: m % 60);
    }).toList()..sort((a, b) {
        final ta = a.hour * 60 + a.minute;
        final tb = b.hour * 60 + b.minute;
        return ta.compareTo(tb);
      });
  }
}

/// Paints a step line for tide level (high = top, low = bottom) across 24h.
class _TideChartPainter extends CustomPainter {
  _TideChartPainter({
    required this.points,
    required this.accent,
    required this.totalMinutes,
  });

  final List<({int min, bool isHigh})> points;
  final Color accent;
  final int totalMinutes;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final w = size.width;
    final h = size.height;
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = (points[i].min / totalMinutes) * w;
      final y = points[i].isHigh ? 4.0 : h - 4.0;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(w, h);
    fillPath.lineTo(0, h);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()..color = accent.withValues(alpha: 0.15),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (int i = 1; i < points.length - 1; i++) {
      final x = (points[i].min / totalMinutes) * w;
      final y = points[i].isHigh ? 4.0 : h - 4.0;
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()..color = accent,
      );
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TideChartPainter old) =>
      old.points != points || old.accent != accent;
}
