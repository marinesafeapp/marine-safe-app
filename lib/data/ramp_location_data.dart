import '../models/ramp_location.dart';
import 'ramp_data.dart';

/// Default list of RampLocation for storage fallback and admin screens.
/// Built from nationwide Australian ramps; address set from name where not specified.
List<RampLocation> get defaultRamps => [
  for (final r in australianRamps)
    RampLocation(
      id: r.id,
      name: r.name,
      address: r.name,
      lat: r.lat,
      lon: r.lon,
      lanes: 2,
      toilets: false,
      pontoon: false,
      parking: true,
      lighting: false,
      hazards: const [],
      imageUrl: null,
      galleryImages: null,
      geofenceRadius: 100,
      tideStationId: null,
      weatherLocationCode: null,
      adminNotes: null,
    ),
];
