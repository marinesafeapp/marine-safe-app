import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen for checking whether you can fish at your location — zones, "My location", zone maps.
class CanWeFishHereScreen extends StatefulWidget {
  const CanWeFishHereScreen({super.key});

  @override
  State<CanWeFishHereScreen> createState() => _CanWeFishHereScreenState();
}

class _CanWeFishHereScreenState extends State<CanWeFishHereScreen> {
  static const Color _bg = Color(0xFF02050A);
  static const Color _accent = Color(0xFF2CB6FF);
  static const String _zoningUrl =
      'https://www.qld.gov.au/environment/coasts-waterways/marine-parks/zoning/about-zoning-and-designated-areas';
  static const String _gbrmpaZoningUrl =
      'https://www2.gbrmpa.gov.au/access/zoning/zoning-maps';

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Could not open link. Try again or open in a browser.')),
        );
      }
    } on Exception catch (e) {
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }

  Future<void> _checkMyLocation() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
              content: Text(
                  'Location services are disabled. Enable them to check your position.')),
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
              content: Text(
                  'Location permission permanently denied. Enable it in device settings.')),
        );
        return;
      }
      scaffoldMessenger.showSnackBar(
        const SnackBar(
            content: Text('Getting your position…'),
            duration: Duration(seconds: 2)),
      );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      _showLocationDialog(
        context,
        lat: position.latitude,
        lon: position.longitude,
      );
    } catch (e) {
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    }
  }

  void _showLocationDialog(BuildContext context,
      {required double lat, required double lon}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F26),
        title: const Text(
          'Your position',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
              style: const TextStyle(
                  color: _accent, fontFamily: 'monospace', fontSize: 15),
            ),
            const SizedBox(height: 12),
            const Text(
              'Open the zone map and find this location to see whether you can fish here. You can also open Google Maps to see your spot.',
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openUrl('https://www.google.com/maps?q=$lat,$lon');
            },
            child: const Text('Show on Google Maps', style: TextStyle(color: _accent)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openUrl(_zoningUrl);
            },
            style: FilledButton.styleFrom(backgroundColor: _accent),
            child: const Text('Open zone map'),
          ),
        ],
      ),
    );
  }

  Widget _zoneLegendRow(Color color, String label, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.white24),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  height: 1.35),
              children: [
                TextSpan(
                    text: '$label — ',
                    style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Can we fish here?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + bottomPad),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'QLD marine park zones — check the official map for your location to see if fishing is allowed.',
              style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.45),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _accent.withValues(alpha: 0.15),
                  _accent.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accent.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: _accent, size: 26),
                    const SizedBox(width: 10),
                    const Text(
                      'Zone legend',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _zoneLegendRow(
                    const Color(0xFF22C55E), 'Green', 'No fishing (Marine National Park)'),
                const SizedBox(height: 6),
                _zoneLegendRow(const Color(0xFFEAB308), 'Yellow',
                    'Limited (Conservation Park — one line, etc.)'),
                const SizedBox(height: 6),
                _zoneLegendRow(const Color(0xFF3B82F6), 'Light blue',
                    'General Use — fishing allowed'),
                const SizedBox(height: 6),
                _zoneLegendRow(const Color(0xFF1D4ED8), 'Dark blue',
                    'Habitat Protection — line fishing, no trawling'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _checkMyLocation,
                        icon: const Icon(Icons.my_location_rounded, size: 20),
                        label: const Text('My location'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _accent,
                          side: BorderSide(color: _accent.withValues(alpha: 0.6)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _openUrl(_zoningUrl),
                        icon: const Icon(Icons.map_rounded, size: 20),
                        label: const Text('Zone map'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _openUrl(_gbrmpaZoningUrl),
                  child: const Text('Great Barrier Reef zone maps',
                      style: TextStyle(color: _accent)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: _accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Rules and zones change. Always check the official QLD Government zone maps or the Qld Fishing app for your area.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
