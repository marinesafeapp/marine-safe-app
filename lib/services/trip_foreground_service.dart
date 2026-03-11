import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../screens/home/services/trip_prefs.dart';
import 'gps_tracking_service.dart';

/// Keeps the app process alive during an active trip so overdue alerts fire
/// even when the app is closed (Samsung/Android often don't deliver
/// scheduled notifications when the app is killed).
const String _channelId = 'marine_safe_trip_foreground';
const int _foregroundNotifId = 1999;
const int _overdueNotifId = 2002; // match HomeNotificationsService.notifOverdueId

@pragma('vm:entry-point')
Future<void> tripServiceOnStart(ServiceInstance service) async {
  // Return immediately so native side can call startForeground() in time (avoids ForegroundServiceDidNotStartInTimeException).
  // Defer all work to next microtask.
  Timer? periodic;
  final plugin = FlutterLocalNotificationsPlugin();
  bool pluginReady = false;

  service.on('stop').listen((_) async {
    // Stop GPS tracking when service stops
    await GPSTrackingService.instance.stopTracking();
    if (service is AndroidServiceInstance) service.stopSelf();
  });

  void checkOverdue() async {
    final tripActive = await TripPrefs.getTripActive();
    if (!tripActive) {
      periodic?.cancel();
      // Stop GPS tracking when trip ends
      await GPSTrackingService.instance.stopTracking();
      await GPSTrackingService.instance.clearAllPoints();
      if (service is AndroidServiceInstance) service.stopSelf();
      return;
    }

    final etaIso = await TripPrefs.getEtaIso();
    final overdueAck = await TripPrefs.getOverdueAck();
    final overdueNotifSent = await TripPrefs.getOverdueNotifSent();
    final rampName = await TripPrefs.getRampName() ?? 'your ramp';

    if (etaIso == null || overdueAck || overdueNotifSent) return;

    final eta = DateTime.tryParse(etaIso);
    final now = DateTime.now();
    final overdueThreshold = eta?.add(const Duration(minutes: 1));
    if (overdueThreshold == null || !now.isAfter(overdueThreshold)) return;

    if (!pluginReady) return;

    // ✅ Fire ONCE per trip after overdue, even if service keeps running.
    await TripPrefs.setOverdueNotifSent(true);
    await plugin.show(
      _overdueNotifId,
      'Marine Safe',
      'OVERDUE return from $rampName — open app to acknowledge',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'marine_safe_overdue_v4',
          'Marine Safe Overdue Alerts',
          channelDescription: 'Overdue return alerts',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 800, 250, 800, 250, 1200]),
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        ),
      ),
    );

    if (service is AndroidServiceInstance && await service.isForegroundService()) {
      await plugin.show(
        _foregroundNotifId,
        'OVERDUE — Marine Safe',
        'Return from $rampName — open app to acknowledge',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Marine Safe Trip',
            channelDescription: 'Active trip',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
          ),
        ),
      );
    }
  }

  // Defer all work so this callback returns immediately (native Android can then call startForeground() in time).
  Timer(Duration.zero, () {
    periodic = Timer.periodic(const Duration(seconds: 15), (_) {
      checkOverdue();
    });
    unawaited((() async {
      try {
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const iosInit = DarwinInitializationSettings(
          requestAlertPermission: true,
          requestSoundPermission: true,
          requestBadgePermission: true,
        );
        const initSettings = InitializationSettings(
          android: androidInit,
          iOS: iosInit,
        );
        await plugin.initialize(initSettings);
        if (Platform.isAndroid) {
          final android = plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
          await android?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            'Marine Safe Trip',
            description: 'Active trip — overdue alerts fire when app is closed',
            importance: Importance.low,
          ));
          await android?.createNotificationChannel(const AndroidNotificationChannel(
            'marine_safe_overdue_v4',
            'Marine Safe Overdue Alerts',
            description: 'Overdue return alerts',
            importance: Importance.max,
          ));
        }
        pluginReady = true;
        checkOverdue();
        
        // Start GPS tracking when service starts and trip is active
        final tripActive = await TripPrefs.getTripActive();
        if (tripActive) {
          await GPSTrackingService.instance.startTracking();
        }
      } catch (_) {}
    })());
  });
}

/// Call from UI when user starts a trip — keeps process alive on Android; on iOS runs overdue checks while app is in foreground.
Future<void> startTripService() async {
  if (kIsWeb) return;
  final service = FlutterBackgroundService();
  await service.startService();
  // Start GPS tracking when trip starts
  await GPSTrackingService.instance.startTracking();
}

/// Call from UI when user ends the trip.
Future<void> stopTripService() async {
  if (kIsWeb) return;
  try {
    await GPSTrackingService.instance.stopTracking();
    await GPSTrackingService.instance.clearAllPoints();
  } catch (e) {
    debugPrint('stopTripService: GPS stop/clear failed: $e');
  }
  try {
    final service = FlutterBackgroundService();
    service.invoke('stop');
  } catch (e) {
    debugPrint('stopTripService: invoke stop failed: $e');
  }
}
