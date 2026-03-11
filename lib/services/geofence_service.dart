import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Simple data model for a ramp geofence.
class RampGeofence {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  const RampGeofence({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });
}

/// Singleton service to manage GPS + geofencing.
class GeofenceService {
  GeofenceService._();

  static final GeofenceService instance = GeofenceService._();

  /// Text shown under "GPS lock" in the UI.
  /// We use a ValueNotifier so the UI can auto-update.
  final ValueNotifier<String> gpsLockText =
      ValueNotifier<String>('Trip inactive');

  /// Name of the ramp we’re currently locked to (if any).
  final ValueNotifier<String?> currentRampName =
      ValueNotifier<String?>(null);

  StreamSubscription<Position>? _positionSub;
  bool _tripActive = false;

  /// Mackay-region ramps (you can extend this list later).
  /// NOTE: Coordinates here are just example data – replace with real
  /// lat/long values when you’re ready to go live.
  final List<RampGeofence> _ramps = const [
    RampGeofence(
      id: 'river_street',
      name: 'River Street Boat Ramp',
      latitude: -21.1418, // example value
      longitude: 149.1984, // example value
      radiusMeters: 150,
    ),
    // TODO: Add Mackay Marina, Victor Creek, Shoal Point etc with real coords.
  ];

  bool get tripActive => _tripActive;

  /// Start watching the user position and checking geofences.
  Future<void> startTrip() async {
    if (_tripActive) return;
    _tripActive = true;

    gpsLockText.value = 'Checking permissions…';

    // 1) Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      gpsLockText.value = 'Location services OFF';
      _tripActive = false;
      return;
    }

    // 2) Check permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        gpsLockText.value = 'Permission denied';
        _tripActive = false;
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      gpsLockText.value = 'Permission denied forever';
      _tripActive = false;
      return;
    }

    // 3) Start stream
    gpsLockText.value = 'Searching near ramps…';

    await _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // metres between updates
      ),
    ).listen(_onPosition, onError: (error) {
      gpsLockText.value = 'Location error';
    });
  }

  /// Stop trip + stop listening to GPS.
  Future<void> stopTrip() async {
    _tripActive = false;
    await _positionSub?.cancel();
    _positionSub = null;
    currentRampName.value = null;
    gpsLockText.value = 'Trip inactive';
  }

  void _onPosition(Position pos) {
    if (!_tripActive) return;

    // Find nearest ramp
    RampGeofence? nearest;
    double? nearestDistance;

    for (final ramp in _ramps) {
      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        ramp.latitude,
        ramp.longitude,
      );

      if (nearestDistance == null || distance < nearestDistance) {
        nearestDistance = distance;
        nearest = ramp;
      }
    }

    if (nearest != null && nearestDistance != null) {
      if (nearestDistance <= nearest.radiusMeters) {
        // Inside a ramp geofence
        currentRampName.value = nearest.name;
        gpsLockText.value = 'Locked: ${nearest.name}';
      } else {
        // Not currently in any ramp zone
        currentRampName.value = null;
        gpsLockText.value = 'Searching near ramps…';
      }
    } else {
      gpsLockText.value = 'Searching…';
    }
  }
}
