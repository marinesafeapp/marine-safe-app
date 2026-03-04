import 'package:flutter/foundation.dart' show debugPrint;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class SMSService {
  static Future<void> sendEmergencySMS({
    required List<String> phoneNumbers,
    required String userName,
  }) async {
    try {
      // Get last known or current position
      Position pos = await Geolocator.getCurrentPosition();

      final message = Uri.encodeComponent(
        "Marine Safe Alert:\n"
        "$userName may be in danger.\n"
        "No response to safety checks.\n\n"
        "Last known location:\n"
        "Lat: ${pos.latitude}\n"
        "Lon: ${pos.longitude}\n"
        "Google Maps: https://maps.google.com/?q=${pos.latitude},${pos.longitude}\n"
      );

      for (String number in phoneNumbers) {
        final smsUri = Uri.parse("sms:$number?body=$message");

        // Launch SMS app on mobile
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
        } else {
          throw "Could not launch SMS";
        }
      }
    } catch (e) {
      debugPrint("SMS ERROR: $e");
    }
  }
}
