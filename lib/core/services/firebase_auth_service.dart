import 'dart:async';

import '../utils/device_heartbeat.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_service.dart';
import 'realtime_database_service.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> initializePersistence() async {
    await _auth.setPersistence(Persistence.LOCAL);
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;

    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'lastLoginAt': FieldValue.serverTimestamp()})
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        // Login already succeeded. Do not fail authentication
        // because updating login metadata was unsuccessful.
      }
    }

    return credential;
  }

  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;

    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
              'name': name.trim(),
              'email': email.trim(),
              'role': 'Farmer',
              'createdAt': FieldValue.serverTimestamp(),
              'lastLoginAt': FieldValue.serverTimestamp(),
            })
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        try {
          await user.delete().timeout(const Duration(seconds: 5));
        } catch (_) {
          // Best-effort rollback.
        }

        await _auth.signOut();
        rethrow;
      }
    }

    return credential;
  }

  Future<void> resetPassword({required String email}) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> logout() async {
    try {
      realtimeDatabaseService.invalidateCommandSession();
      notificationService.beginLogout();
      await notificationService.removeTokenForCurrentUser().timeout(
        const Duration(seconds: 2),
      );
    } catch (_) {
      // Logout should still continue if token cleanup fails.
    }

    try {
      await _auth.signOut();
    } finally {
      notificationService.endLogout();
      resetDeviceHeartbeatTracker();
    }
  }
}

final firebaseAuthService = FirebaseAuthService();
