import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class BatterySettingsService {
  /// Opens the system screen where users can set battery to Unrestricted /
  /// disable optimisations (Samsung etc).
  static Future<void> openBatteryOptimisationSettings() async {
    if (!Platform.isAndroid) return;

    // Best target: Battery optimisation settings list
    final intents = <Uri>[
      Uri.parse(
        'intent:#Intent;action=android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS;end',
      ),

      // Fallback: Apps list / App settings area
      Uri.parse('intent:#Intent;action=android.settings.APPLICATION_SETTINGS;end'),
    ];

    for (final uri in intents) {
      try {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      } catch (_) {
        // try next fallback
      }
    }

    // Last resort: open general settings
    try {
      await launchUrl(
        Uri.parse('intent:#Intent;action=android.settings.SETTINGS;end'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // nothing else we can do
    }
  }

  /// Opens THIS app’s details screen (works great on Samsung).
  /// If your package changes later, update the package name below.
  static const MethodChannel _channel = MethodChannel('marine_safe/system');

  /// Opens this app's details screen (battery, notifications). Uses native intent on Android.
  static Future<void> openThisAppDetails() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod<void>('openAppDetails');
      return;
    } catch (_) {
      const pkg = 'com.example.marine_safe_new';
      try {
        final uri = Uri.parse(
          'intent:#Intent;action=android.settings.APPLICATION_DETAILS_SETTINGS;data=package:$pkg;end',
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        await openBatteryOptimisationSettings();
      }
    }
  }
}
