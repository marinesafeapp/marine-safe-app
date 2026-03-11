import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'reliability/reliability_check_service.dart';

/// Type of OS-level issue that blocks or reduces alert reliability.
enum FixIssue {
  notificationsDisabled,
  exactAlarmsDisabled,
  batteryOptimizationEnabled,
  locationPermissionDenied,
  locationPermissionDeniedForever,
  notificationPermissionDenied,
  backgroundLocationDenied,
  unknown,
}

/// Routes the user to the exact system screen to fix a given issue.
/// Android: uses deep-link intents where possible. iOS: openAppSettings().
class FixIssueRouter {
  FixIssueRouter._();

  static const MethodChannel _channel = MethodChannel('marine_safe/system');

  /// Get Android package name from native (avoids hardcoding).
  static Future<String?> _getPackageName() async {
    if (!Platform.isAndroid) return null;
    try {
      final name = await _channel.invokeMethod<String>('getPackageName');
      return name;
    } catch (_) {
      return null;
    }
  }

  /// Open the system screen that fixes [issue]. Prefer exact deep links on Android.
  static Future<void> openFix(FixIssue issue) async {
    if (kIsWeb) return;

    // iOS: Apple only allows jumping to the app's settings page.
    if (Platform.isIOS) {
      await ph.openAppSettings();
      return;
    }

    if (!Platform.isAndroid) return;

    final packageName = await _getPackageName() ?? 'au.com.marinesafe.app';

    // Try platform-specific deep links first.
    try {
      final launched = await _openFixAndroid(issue, packageName);
      if (launched) return;
    } catch (_) {
      // swallow and fallback
    }

    // Fallback: app settings page
    await ph.openAppSettings();
  }

  static Future<bool> _openFixAndroid(FixIssue issue, String packageName) async {
    if (!Platform.isAndroid) return false;

    final AndroidIntent? intent = _buildAndroidIntent(issue, packageName);
    if (intent == null) return false;

    try {
      await intent.launch();
      return true;
    } catch (_) {
      return false;
    }
  }

  static AndroidIntent? _buildAndroidIntent(FixIssue issue, String packageName) {
    switch (issue) {
      case FixIssue.notificationsDisabled:
      case FixIssue.notificationPermissionDenied:
        // Most reliable way across OEMs to open this app's notification settings:
        // android.provider.extra.APP_PACKAGE
        return AndroidIntent(
          action: 'android.settings.APP_NOTIFICATION_SETTINGS',
          arguments: <String, dynamic>{
            'android.provider.extra.APP_PACKAGE': packageName,
          },
        );

      case FixIssue.exactAlarmsDisabled:
        return AndroidIntent(
          action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
          data: 'package:$packageName',
        );

      case FixIssue.batteryOptimizationEnabled:
        return AndroidIntent(
          action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
          data: 'package:$packageName',
        );

      case FixIssue.locationPermissionDeniedForever:
      case FixIssue.locationPermissionDenied:
      case FixIssue.backgroundLocationDenied:
      case FixIssue.unknown:
        // For these, OEM deep links vary too much; openAppSettings() fallback is best.
        return null;
    }
  }

  /// Returns current reliability/permission issues in priority order (first = highest priority).
  static Future<List<FixIssue>> checkReliabilityIssues() async {
    if (kIsWeb) return [];

    final issues = <FixIssue>[];

    final status = await ReliabilityCheckService.instance.check();

    // Notifications
    if (!status.notificationsGranted) {
      if (Platform.isAndroid) {
        final sdk = await _androidSdkInt();
        issues.add(
          sdk >= 33 ? FixIssue.notificationPermissionDenied : FixIssue.notificationsDisabled,
        );
      } else {
        issues.add(FixIssue.notificationsDisabled);
      }
    }

    // Android-only OS reliability toggles
    if (Platform.isAndroid) {
      if (status.exactAlarmsAllowed == false) {
        issues.add(FixIssue.exactAlarmsDisabled);
      }
      if (status.batteryOptimizationDisabled == false) {
        issues.add(FixIssue.batteryOptimizationEnabled);
      }
    }

    // Location permissions (common)
    final locStatus = await ph.Permission.locationWhenInUse.status;
    if (locStatus.isPermanentlyDenied) {
      issues.add(FixIssue.locationPermissionDeniedForever);
    } else if (locStatus.isDenied) {
      issues.add(FixIssue.locationPermissionDenied);
    }

    // Background location (Android)
    if (Platform.isAndroid) {
      final bgStatus = await ph.Permission.locationAlways.status;
      if (bgStatus.isDenied || bgStatus.isPermanentlyDenied) {
        final whenInUse = await ph.Permission.locationWhenInUse.status;
        if (whenInUse.isGranted) {
          issues.add(FixIssue.backgroundLocationDenied);
        }
      }
    }

    return issues;
  }

  static Future<int> _androidSdkInt() async {
    if (!Platform.isAndroid) return 0;
    try {
      final v = await _channel.invokeMethod<int>('getAndroidSdkInt');
      return v ?? 0;
    } catch (_) {
      return 0;
    }
  }
}