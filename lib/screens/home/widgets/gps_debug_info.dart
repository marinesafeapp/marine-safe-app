import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class GpsDebugInfo extends StatelessWidget {
  final Position? lastPosition;
  final double? autoDetectedRampDistanceM;

  const GpsDebugInfo({
    super.key,
    required this.lastPosition,
    required this.autoDetectedRampDistanceM,
  });

  @override
  Widget build(BuildContext context) {
    if (lastPosition == null) return const SizedBox.shrink();

    return Column(
      children: [
        Text(
          "GPS: ${lastPosition!.latitude.toStringAsFixed(5)}, ${lastPosition!.longitude.toStringAsFixed(5)}",
          style: const TextStyle(color: Colors.white30, fontSize: 11),
        ),
        Text(
          "Accuracy: ±${lastPosition!.accuracy.toStringAsFixed(0)}m  |  RampDist: ${(autoDetectedRampDistanceM ?? 0).toStringAsFixed(0)}m",
          style: const TextStyle(color: Colors.white30, fontSize: 11),
        ),
        if (kIsWeb)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              "Web note: GPS/phone calls can be limited in Chrome. Best test on Android.",
              style: TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ),
      ],
    );
  }
}
