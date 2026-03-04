/// Full ramp details used by admin, details screen, and storage.
class RampLocation {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lon;
  final int lanes;
  final bool toilets;
  final bool pontoon;
  final bool parking;
  final bool lighting;
  final List<String> hazards;
  final String? imageUrl;
  final List<String>? galleryImages;
  final double geofenceRadius;
  final String? tideStationId;
  final String? weatherLocationCode;
  final String? adminNotes;

  const RampLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lon,
    this.lanes = 2,
    this.toilets = false,
    this.pontoon = false,
    this.parking = true,
    this.lighting = false,
    this.hazards = const [],
    this.imageUrl,
    this.galleryImages,
    this.geofenceRadius = 100,
    this.tideStationId,
    this.weatherLocationCode,
    this.adminNotes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'lat': lat,
      'lon': lon,
      'lanes': lanes,
      'toilets': toilets,
      'pontoon': pontoon,
      'parking': parking,
      'lighting': lighting,
      'hazards': hazards,
      'imageUrl': imageUrl,
      'galleryImages': galleryImages,
      'geofenceRadius': geofenceRadius,
      'tideStationId': tideStationId,
      'weatherLocationCode': weatherLocationCode,
      'adminNotes': adminNotes,
    };
  }

  static RampLocation fromMap(Map<String, dynamic> map) {
    return RampLocation(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      address: map['address'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lon: (map['lon'] as num?)?.toDouble() ?? 0,
      lanes: map['lanes'] as int? ?? 2,
      toilets: map['toilets'] as bool? ?? false,
      pontoon: map['pontoon'] as bool? ?? false,
      parking: map['parking'] as bool? ?? true,
      lighting: map['lighting'] as bool? ?? false,
      hazards: map['hazards'] != null
          ? List<String>.from(map['hazards'] as List)
          : const [],
      imageUrl: map['imageUrl'] as String?,
      galleryImages: map['galleryImages'] != null
          ? List<String>.from(map['galleryImages'] as List)
          : null,
      geofenceRadius: (map['geofenceRadius'] as num?)?.toDouble() ?? 100,
      tideStationId: map['tideStationId'] as String?,
      weatherLocationCode: map['weatherLocationCode'] as String?,
      adminNotes: map['adminNotes'] as String?,
    );
  }
}
