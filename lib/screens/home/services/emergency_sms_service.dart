import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import '../../../services/emergency_contact_service.dart';
import '../../../services/user_profile_service.dart';
import '../../../services/gps_tracking_service.dart';
import 'trip_prefs.dart';

class EmergencySmsService {
  static const String _kEmg1Phone = 'profile.emg1.phone';
  static const String _kEmg1Name = 'profile.emg1.name';
  static const String _kEmg2Phone = 'profile.emg2.phone';
  static const String _kEmg2Name = 'profile.emg2.name';

  /// Returns the first available emergency phone (profile emg1, emg2, then Emergency Contacts list).
  static Future<String?> getFirstEmergencyPhone() async {
    final p = await SharedPreferences.getInstance();
    final emg1 = (p.getString(_kEmg1Phone) ?? '').trim();
    if (emg1.isNotEmpty) return emg1;
    final emg2 = (p.getString(_kEmg2Phone) ?? '').trim();
    if (emg2.isNotEmpty) return emg2;
    final list = await EmergencyContactService.loadContacts();
    for (final c in list) {
      final phone = (c.phone).trim();
      if (phone.isNotEmpty) return phone;
    }
    return null;
  }

  /// Primary contact display name (for notification body).
  static Future<String?> getPrimaryContactName() async {
    final p = await SharedPreferences.getInstance();
    final emg1 = (p.getString(_kEmg1Name) ?? '').trim();
    if (emg1.isNotEmpty) return emg1;
    final emg2 = (p.getString(_kEmg2Name) ?? '').trim();
    if (emg2.isNotEmpty) return emg2;
    final list = await EmergencyContactService.loadContacts();
    for (final c in list) {
      final name = (c.name).trim();
      if (name.isNotEmpty) return name;
    }
    return null;
  }

  /// All emergency contacts in order (profile emg1, emg2, then Emergency Contacts list). Phone only.
  static Future<List<String>> getAllEmergencyPhones() async {
    final p = await SharedPreferences.getInstance();
    final seen = <String>{};
    final list = <String>[];
    void add(String phone) {
      final t = phone.trim();
      if (t.isNotEmpty && !seen.contains(t)) {
        seen.add(t);
        list.add(t);
      }
    }
    add(p.getString(_kEmg1Phone) ?? '');
    add(p.getString(_kEmg2Phone) ?? '');
    for (final c in await EmergencyContactService.loadContacts()) {
      add(c.phone);
    }
    return list;
  }

  /// Builds the escalation SMS body (vessel, ramp, planned return, last known location, map link).
  static String buildEscalationSmsBody({
    required String skipperName,
    String? vesselName,
    required String rampName,
    required DateTime plannedReturnEta,
    double? latitude,
    double? longitude,
  }) {
    final vesselLine = (vesselName != null && vesselName.trim().isNotEmpty)
        ? "${skipperName.trim()}'s vessel (${vesselName.trim()}) is overdue."
        : "${skipperName.trim()}'s vessel is overdue.";
    final timeStr = _formatTime(plannedReturnEta);
    final buffer = StringBuffer();
    buffer.writeln('Marine Safe Alert');
    buffer.writeln(vesselLine);
    buffer.writeln('');
    if (latitude != null && longitude != null) {
      buffer.writeln('Last known location: $latitude, $longitude');
      buffer.writeln('https://maps.google.com/?q=$latitude,$longitude');
    } else {
      buffer.writeln('Last known location: unavailable.');
    }
    buffer.writeln('Launch ramp: $rampName');
    buffer.writeln('Planned return: $timeStr');
    buffer.writeln('');
    buffer.writeln('Try contacting the skipper.');
    return buffer.toString();
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $ampm';
  }

  /// Legacy: builds the overdue alert message (kept for manual "Text emergency contact" button).
  static String buildOverdueAlertMessage({
    required String userName,
    double? latitude,
    double? longitude,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Marine Safe Alert:');
    buffer.writeln('$userName may be in danger.');
    buffer.writeln('No response to safety checks.');
    buffer.writeln('');
    if (latitude != null && longitude != null) {
      buffer.writeln('Last known location:');
      buffer.writeln('Lat: $latitude');
      buffer.writeln('Lon: $longitude');
      buffer.writeln('Google Maps: https://maps.google.com/?q=$latitude,$longitude');
    } else {
      buffer.writeln('Last known location: unavailable.');
    }
    return buffer.toString();
  }

  /// Opens the SMS app with the full escalation message to the primary contact.
  /// Uses trip context from TripPrefs (vessel, ramp, ETA). Call when user taps ETA+10 or ETA+20 notification.
  static Future<void> openEscalationSmsToPrimaryContact(BuildContext context) async {
    final phone = await getFirstEmergencyPhone();
    if (phone == null || phone.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an emergency contact in Profile to use this.')),
      );
      return;
    }
    final tripActive = await TripPrefs.getTripActive();
    final etaIso = await TripPrefs.getEtaIso();
    final rampName = (await TripPrefs.getRampName())?.trim() ?? 'Unknown ramp';
    final vesselName = await TripPrefs.getVesselName();
    final skipperName = await UserProfileService.instance.getUserName() ?? 'Skipper';
    final eta = etaIso != null ? DateTime.tryParse(etaIso) : null;

    double? lat;
    double? lon;
    try {
      final lastPoint = await GPSTrackingService.instance.getLastPoint();
      if (lastPoint != null) {
        lat = lastPoint.latitude;
        lon = lastPoint.longitude;
      }
    } catch (_) {}
    if (lat == null || lon == null) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
        lat = pos.latitude;
        lon = pos.longitude;
      } catch (_) {}
    }

    final plannedReturn = eta ?? DateTime.now();
    final message = buildEscalationSmsBody(
      skipperName: skipperName,
      vesselName: vesselName,
      rampName: rampName,
      plannedReturnEta: plannedReturn,
      latitude: lat,
      longitude: lon,
    );
    if (!context.mounted) return;
    await openSms(context: context, phoneNumber: phone, message: message);
  }

  /// Opens the SMS app with an overdue alert to the first emergency contact.
  /// Use from the overdue dialog so the user can quickly text their contact.
  /// Uses full escalation format when trip is active, else simple format.
  static Future<void> openEmergencySmsForOverdue(BuildContext context) async {
    final phone = await getFirstEmergencyPhone();
    if (phone == null || phone.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an emergency contact in Profile to use this.'),
        ),
      );
      return;
    }

    final tripActive = await TripPrefs.getTripActive();
    final etaIso = await TripPrefs.getEtaIso();
    final rampName = (await TripPrefs.getRampName())?.trim() ?? 'Unknown ramp';
    final vesselName = await TripPrefs.getVesselName();
    final skipperName = await UserProfileService.instance.getUserName() ?? 'Trip user';
    final eta = etaIso != null ? DateTime.tryParse(etaIso) : null;

    double? lat;
    double? lon;
    try {
      final lastPoint = await GPSTrackingService.instance.getLastPoint();
      if (lastPoint != null) {
        lat = lastPoint.latitude;
        lon = lastPoint.longitude;
      }
    } catch (_) {}
    if (lat == null || lon == null) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
        lat = pos.latitude;
        lon = pos.longitude;
      } catch (_) {}
    }

    final message = (tripActive && eta != null)
        ? buildEscalationSmsBody(
            skipperName: skipperName,
            vesselName: vesselName,
            rampName: rampName,
            plannedReturnEta: eta,
            latitude: lat,
            longitude: lon,
          )
        : buildOverdueAlertMessage(
            userName: skipperName,
            latitude: lat,
            longitude: lon,
          );
    if (!context.mounted) return;
    await openSms(context: context, phoneNumber: phone, message: message);
  }

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
