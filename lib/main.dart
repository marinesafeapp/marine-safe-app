import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/notifications/notification_bootstrap.dart';
import 'services/trip_foreground_service.dart' show tripServiceOnStart;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // OS-level notifications: timezone + permissions + channels (required for overdue escalation)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await initNotifications();
  }

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    final service = FlutterBackgroundService();
    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: tripServiceOnStart,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: tripServiceOnStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'marine_safe_trip_foreground',
        initialNotificationTitle: 'Marine Safe',
        initialNotificationContent: 'Trip active — overdue alerts will fire when app is closed',
        foregroundServiceNotificationId: 1999,
      ),
    );
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ AUTO SIGN IN (anonymous)
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }

  // ✅ Crashlytics only on Android/iOS (not Web/Windows/macOS)
  final bool crashlyticsSupported = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  if (crashlyticsSupported) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    ui.PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  runApp(const MarineSafeApp());
}

class MarineSafeApp extends StatelessWidget {
  const MarineSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Marine Safe',
      theme: ThemeData.dark(),
      home: const SplashScreen(),
    );
  }
}
