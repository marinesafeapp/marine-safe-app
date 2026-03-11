class SafetyItem {
  final String name;
  final DateTime? expiry;

  SafetyItem({
    required this.name,
    required this.expiry,
  });

  Map<String, dynamic> toJson() => {
        "name": name,
        "expiry": expiry?.toIso8601String(),
      };

  factory SafetyItem.fromJson(Map<String, dynamic> json) {
    return SafetyItem(
      name: json["name"],
      expiry:
          json["expiry"] != null ? DateTime.parse(json["expiry"]) : null,
    );
  }
}
