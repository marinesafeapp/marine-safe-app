import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class GPSStatus extends StatefulWidget {
  const GPSStatus({super.key});

  @override
  State<GPSStatus> createState() => _GPSStatusState();
}

class _GPSStatusState extends State<GPSStatus> {
  bool gpsLocked = false;
  String statusText = "Searching…";

  @override
  void initState() {
    super.initState();
    checkGPS();
  }

  Future<void> checkGPS() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if GPS is enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        statusText = "GPS Off";
        gpsLocked = false;
      });
      return;
    }

    // Check permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      setState(() {
        statusText = "Permission required";
        gpsLocked = false;
      });
      return;
    }

    // If we reach here → GPS available
    final pos = await Geolocator.getCurrentPosition();

    setState(() {
      gpsLocked = true;
      statusText = "Locked (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "GPS lock",
          style: TextStyle(fontSize: 16),
        ),

        Row(
          children: [
            Icon(
              gpsLocked ? Icons.gps_fixed : Icons.gps_not_fixed,
              color: gpsLocked ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              statusText,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ],
    );
  }
}
