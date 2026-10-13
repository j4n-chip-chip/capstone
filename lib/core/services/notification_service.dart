import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://bananadoctor-72ea5-default-rtdb.asia-southeast1.firebasedatabase.app/',
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'bananadoctor_alerts',
    'BananaDoctor Alerts',
    description:
        'Risk alerts, automatic spray updates, safety warnings, and device notifications.',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(settings: initializationSettings);

    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidImplementation?.createNotificationChannel(channel);

    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((
      message,
    ) async {
      await _showForegroundNotification(message);
    });

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      await _saveToken(uid: user.uid, token: token);
    });

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) async {
      if (user == null) {
        return;
      }

      await syncTokenForCurrentUser();
    });

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      await syncTokenForCurrentUser();
    }
  }

  Future<void> syncTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final token = await _messaging.getToken();

    if (token == null || token.trim().isEmpty) {
      return;
    }

    await _saveToken(uid: user.uid, token: token);
  }

  Future<void> _saveToken({required String uid, required String token}) async {
    await _database.ref('user_fcm_tokens/$uid/current').set({
      'token': token,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> removeTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    await _database.ref('user_fcm_tokens/${user.uid}/current').remove();
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final remoteNotification = message.notification;

    final title =
        remoteNotification?.title ??
        message.data['title']?.toString() ??
        'BananaDoctor';

    final body =
        remoteNotification?.body ??
        message.data['body']?.toString() ??
        'A new farm notification is available.';

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'bananadoctor_alerts',
          'BananaDoctor Alerts',
          channelDescription:
              'Risk alerts, automatic spray updates, safety warnings, and device notifications.',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
        ),
      ),
    );
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _authSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
  }
}

final notificationService = NotificationService();
