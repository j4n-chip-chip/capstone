import 'package:flutter/foundation.dart';

import '../utils/notification_policy.dart';

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
    databaseURL: 'https://bananadoctor-72ea5-default-rtdb.asia-southeast1.firebasedatabase.app/',
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'bananadoctor_alerts',
    'BananaDoctor Alerts',
    description: 'Risk alerts, automatic spray updates, safety warnings, and device notifications.',
    importance: Importance.high,
  );

  Future<void>? _initialization;
  bool _suspended = false;
  bool _loggingOut = false;
  int _sessionVersion = 0;
  String? _lastToken;

  Future<void> initialize() => _initialization ??= _initialize();

  void beginLogout() {
    _loggingOut = true;
    _suspended = true;
    _sessionVersion++;
    unawaited(_clearLocalNotifications());
  }

  void endLogout() {
    _loggingOut = false;
    _suspended = FirebaseAuth.instance.currentUser == null;
  }

  Future<void> _clearLocalNotifications() async {
    if (kIsWeb) return;
    try {
      await _localNotifications.cancelAll().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Notifications may not have initialized on this platform.
    }
  }

  Future<void> _initialize() async {
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
    ) {
      unawaited(
        _showForegroundNotification(message).catchError((Object error) {
          debugPrint('Unable to display a foreground notification.');
        }),
      );
    });
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _suspended) return;
      unawaited(
        _saveToken(uid: user.uid, token: token).catchError((Object error) {
          debugPrint('Unable to synchronize the refreshed notification token.');
        }),
      );
    });
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _sessionVersion++;
      _suspended = _loggingOut || user == null;
      if (user == null) {
        unawaited(_clearLocalNotifications());
      } else if (!_suspended) {
        unawaited(
          syncTokenForCurrentUser().catchError((Object error) {
            debugPrint('Unable to synchronize the account notification token.');
          }),
        );
      }
    });
  }

  Future<void> syncTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final version = _sessionVersion;
    final token = await _messaging.getToken();
    if (_suspended ||
        version != _sessionVersion ||
        FirebaseAuth.instance.currentUser?.uid != user.uid)
      return;

    if (token == null || token.trim().isEmpty) {
      return;
    }

    await _saveToken(uid: user.uid, token: token);
  }

  Future<void> _saveToken({required String uid, required String token}) async {
    if (_suspended || FirebaseAuth.instance.currentUser?.uid != uid) return;
    _lastToken = token;
    await _database.ref('user_fcm_tokens/$uid/current').set({
      'token': token,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> removeTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = _lastToken;
    if (user == null || token == null || kIsWeb) return;
    // Retain the existing sender contract, but never delete another phone's
    // token. Per-installation storage requires a coordinated backend migration.
    await Future.wait([
      _database.ref('user_fcm_tokens/${user.uid}/current').runTransaction((
        value,
      ) {
        if (value is! Map || value['token'] != token)
          return Transaction.abort();
        return Transaction.success(null);
      }, applyLocally: false),
      _messaging.deleteToken(),
    ]);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = notificationForSession(
      currentUid: FirebaseAuth.instance.currentUser?.uid,
      suspended: _suspended,
      data: message.data,
      title: message.notification?.title,
      body: message.notification?.body,
    );
    if (notification == null) return;
    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'bananadoctor_alerts',
          'BananaDoctor Alerts',
          channelDescription: 'Risk alerts, automatic spray updates, safety warnings, and device notifications.',
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
