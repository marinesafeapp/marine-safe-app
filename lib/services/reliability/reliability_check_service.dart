import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Result of an alert reliability check.
/// Ensures overdue notifications work when the app is closed.
class ReliabilityStatus {
  const ReliabilityStatus({
    required this.notificationsGranted,
    this.batteryOptimizationDisabled,
    this.exactAlarmsAllowed,
  });

  final bool notificationsGranted;
  final bool? batteryOptimizationDisabled;
  final bool? exactAlarmsAllowed;

  bool get canProceed => notificationsGranted;
}

/// Cross-platform service to check and fix alert reliability.
/// Notifications must be granted to proceed; battery and exact alarms are recommended.
class ReliabilityCheckService {
  ReliabilityCheckService._();
  static final ReliabilityCheckService instance = ReliabilityCheckService._();

  static const MethodChannel _channel = MethodChannel('marine_safe/system');

  /// Check current reliability status.
  Future<ReliabilityStatus> check() async {
    if (kIsWeb) {
      return const ReliabilityStatus(notificationsGranted: true);
    }

    final notificationsGranted = await _checkNotifications();
    bool? batteryOptimizationDisabled;
    bool? exactAlarmsAllowed;

    if (Platform.isAndroid) {
      batteryOptimizationDisabled = await _checkBatteryOptimization();
      exactAlarmsAllowed = await _checkExactAlarms();
    }

    return ReliabilityStatus(
      notificationsGranted: notificationsGranted,
      batteryOptimizationDisabled: batteryOptimizationDisabled,
      exactAlarmsAllowed: exactAlarmsAllowed,
    );
  }

  Future<bool> _checkNotifications() async {
    try {
      final status = await ph.Permission.notification.status;
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool?> _checkBatteryOptimization() async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<bool?> _checkExactAlarms() async {
    if (!Platform.isAndroid) return null;
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ok = await android?.canScheduleExactNotifications();
      return ok;
    } catch (_) {
      return null;
    }
  }

  /// Request notification permission. On Android 13+ and iOS, shows system prompt.
  Future<void> requestNotificationsPermission() async {
    if (kIsWeb) return;
    try {
      await ph.Permission.notification.request();
    } catch (_) {}
  }

  /// Open app notification settings (or general app settings).
  Future<void> openNotificationSettings() async {
    if (kIsWeb) return;
    try {
      await ph.openAppSettings();
    } catch (_) {}
  }

  /// Open battery optimization settings (Android only).
  Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
    } catch (_) {}
  }

  /// Open exact alarm settings if possible (Android 12+).
  Future<void> openExactAlarmSettingsIfPossible() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openExactAlarmSettings');
    } catch (_) {
      try {
        await _channel.invokeMethod<void>('openAppDetails');
      } catch (_) {}
    }
  }
}
