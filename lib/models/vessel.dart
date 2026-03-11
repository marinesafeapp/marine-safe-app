/// A vessel/boat for Pro users (multiple vessels). Free users have a single boat in profile.
/// type: 'boat' | 'jet_ski' | 'other'
class Vessel {
  final String id;
  final String name;
  final String type;
  final String boatRego;
  final DateTime? boatRegoExpiry;
  final String trailerRego;
  final DateTime? trailerRegoExpiry;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Vessel({
    required this.id,
    required this.name,
    this.type = 'boat',
    this.boatRego = '',
    this.boatRegoExpiry,
    this.trailerRego = '',
    this.trailerRegoExpiry,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'boatRego': boatRego,
        'boatRegoExpiry': boatRegoExpiry?.toIso8601String(),
        'trailerRego': trailerRego,
        'trailerRegoExpiry': trailerRegoExpiry?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  static Vessel fromJson(Map<String, dynamic> json) {
    return Vessel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'boat',
      boatRego: json['boatRego'] as String? ?? '',
      boatRegoExpiry: _parseIso(json['boatRegoExpiry'] as String?),
      trailerRego: json['trailerRego'] as String? ?? '',
      trailerRegoExpiry: _parseIso(json['trailerRegoExpiry'] as String?),
      createdAt: _parseIso(json['createdAt'] as String?),
      updatedAt: _parseIso(json['updatedAt'] as String?),
    );
  }

  static DateTime? _parseIso(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  Vessel copyWith({
    String? id,
    String? name,
    String? type,
    String? boatRego,
    DateTime? boatRegoExpiry,
    String? trailerRego,
    DateTime? trailerRegoExpiry,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vessel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      boatRego: boatRego ?? this.boatRego,
      boatRegoExpiry: boatRegoExpiry ?? this.boatRegoExpiry,
      trailerRego: trailerRego ?? this.trailerRego,
      trailerRegoExpiry: trailerRegoExpiry ?? this.trailerRegoExpiry,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
