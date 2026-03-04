import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencySmsService {
  /// Opens the user's SMS app with a prefilled message.
  /// This does NOT silently send (user must tap Send).
  static Future<void> openSms({
    required BuildContext context,
    required String phoneNumber,
    required String message,
  }) async {
    final number = phoneNumber.trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Emergency contact phone number is missing.")),
      );
      return;
    }

    // sms: scheme (works on Android/iOS)
    final uri = Uri(
      scheme: 'sms',
      path: number,
      queryParameters: <String, String>{
        'body': message,
      },
    );

    final ok = await canLaunchUrl(uri);
    if (!ok) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open SMS app on this device.")),
      );
      return;
    }

    await launchUrl(uri);
  }
}
