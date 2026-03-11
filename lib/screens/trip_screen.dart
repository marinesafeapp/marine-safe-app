import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  // Must match HomeScreen keys
  static const String _kTripActive = 'tripActive';
  static const String _kEtaIso = 'etaIso';
  static const String _kRampId = 'rampId';

  bool tripActive = false;
  DateTime? eta;
  String? rampId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();

    final active = p.getBool(_kTripActive) ?? false;
    final etaIso = p.getString(_kEtaIso);
    final parsedEta =
    (etaIso == null || etaIso.trim().isEmpty) ? null : DateTime.tryParse(etaIso);

    final rid = p.getString(_kRampId);

    if (!mounted) return;
    setState(() {
      tripActive = active;
      eta = parsedEta;
      rampId = rid;
    });
  }

  Future<void> _startTrip() async {
    final p = await SharedPreferences.getInstance();

    final rid = p.getString(_kRampId);
    final etaIso = p.getString(_kEtaIso);
    final parsedEta =
    (etaIso == null || etaIso.trim().isEmpty) ? null : DateTime.tryParse(etaIso);

    if (rid == null || rid.trim().isEmpty) {
      _toast("Select a Launch Ramp first (Home screen).");
      return;
    }
    if (parsedEta == null) {
      _toast("Set an ETA first (Home screen).");
      return;
    }

    await p.setBool(_kTripActive, true);

    if (!mounted) return;
    Navigator.pop(context); // auto return to Home
  }

  Future<void> _endTrip() async {
    final p = await SharedPreferences.getInstance();

    await p.setBool(_kTripActive, false);
    await p.remove(_kEtaIso);
    await p.remove(_kRampId);

    if (!mounted) return;
    Navigator.pop(context); // auto return to Home
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _timeOnly(DateTime dt) => "${_two(dt.hour)}:${_two(dt.minute)}";

  @override
  Widget build(BuildContext context) {
    final subtitle = tripActive
        ? "ETA: ${eta == null ? '—' : _timeOnly(eta!)}  •  Ramp: ${rampId ?? '—'}"
        : "Set ramp + ETA on Home, then start.";

    return Scaffold(
      backgroundColor: const Color(0xFF02050A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF02050A),
        elevation: 0,
        title: const Text("Trip Control", style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                tripActive ? Icons.directions_boat : Icons.anchor,
                size: 84,
                color: tripActive ? Colors.greenAccent : Colors.white54,
              ),
              const SizedBox(height: 18),
              Text(
                tripActive ? "Trip is ACTIVE" : "Trip is STOPPED",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: tripActive ? Colors.greenAccent : Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 28),
              if (!tripActive)
                ElevatedButton(onPressed: _startTrip, child: const Text("START TRIP")),
              if (tripActive)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.black),
                  onPressed: _endTrip,
                  child: const Text("END TRIP"),
                ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () async {
                  await _load();
                  _toast("Refreshed");
                },
                child: const Text("Refresh state"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
