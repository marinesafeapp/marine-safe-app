/// Normalizes Australian phone to E.164 (e.g. 04xx xxx xxx -> +614xxxxxxxx).
/// Pass-through if already starts with +. Otherwise strips spaces and leading 0.
String phoneToE164(String phone, {String defaultCountryCode = '61'}) {
  String s = phone.trim().replaceAll(RegExp(r'\s'), '');
  if (s.isEmpty) return s;
  if (s.startsWith('+')) return s;
  if (s.startsWith('0')) s = s.substring(1);
  if (s.length >= 9) return '+$defaultCountryCode$s';
  return '+$defaultCountryCode$s';
}

class EmergencyContact {
  final String name;
  final String phone;
  /// True for the primary contact (first in list). Used for ETA+30 SMS.
  final bool isPrimary;

  EmergencyContact({
    required this.name,
    required this.phone,
    this.isPrimary = false,
  });

  String get phoneE164 => phoneToE164(phone);

  Map<String, dynamic> toJson() => {
        "name": name,
        "phone": phone,
        "phoneE164": phoneE164,
        "isPrimary": isPrimary,
      };

  /// For Firestore escalation snapshot: name, phoneE164, isPrimary.
  Map<String, dynamic> toEscalationSnapshot() => {
        "name": name,
        "phoneE164": phoneE164,
        "isPrimary": isPrimary,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: _stringFromJson(json["name"]),
      phone: _stringFromJson(json["phone"]),
      isPrimary: json["isPrimary"] == true,
    );
  }

  static String _stringFromJson(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}
