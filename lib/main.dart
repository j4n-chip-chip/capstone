import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'core/services/firebase_auth_service.dart';
import 'core/services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  if (kIsWeb) {
    await firebaseAuthService.initializePersistence();
  }

  // Start the app first so notification initialization
  // cannot block the Flutter first frame.
  runApp(const BananaDoctorApp());

  // Initialize Android notifications after the app has started.
  if (!kIsWeb) {
    unawaited(
      notificationService.initialize().catchError((error, stackTrace) {
        debugPrint('Notification initialization failed: $error');
      }),
    );
  }
}
